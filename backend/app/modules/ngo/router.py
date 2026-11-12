"""NGO verification and impact API router."""

import uuid
from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, and_, func, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.permissions import require, AuthContext
from app.models.batches import WasteBatch, BatchEvent
from app.models.reference import MaterialCategory
from app.models.ngo import NGOVerification
from app.models.profiles import NGOScope
from app.models.custody import PickupRecord, RecyclerReceipt, ProcessingRecord, ProcessingInput
from app.models.audit import AnomalyFlag
from app.models.documents import DocumentLink, Document
from app.modules.ngo.schemas import (
    NGODecisionInput,
    DocumentRequestInput,
    NGOVerificationOut,
)

router = APIRouter(prefix="/ngo", tags=["ngo"])


def utcnow():
    return datetime.now(timezone.utc)


@router.get("/verifications")
async def list_verifications(
    decision: Optional[str] = Query(None),
    context: AuthContext = Depends(require("NGO")),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(NGOVerification, WasteBatch).join(
        WasteBatch, NGOVerification.batch_id == WasteBatch.id
    ).where(
        NGOVerification.is_current.is_(True),
    ).order_by(desc(NGOVerification.created_at))

    if decision:
        stmt = stmt.where(NGOVerification.decision == decision.upper())

    res = await db.execute(stmt)
    output = []
    for ver, b in res.all():
        output.append({
            "id": ver.id,
            "batch_id": b.id,
            "batch_code": b.batch_code,
            "material_category_id": b.material_category_id,
            "estimated_kg": b.estimated_kg,
            "status": b.status,
            "decision": ver.decision,
            "reviewer_user_id": ver.reviewer_user_id,
            "comments": ver.comments,
            "created_at": ver.created_at,
        })
    return output


@router.get("/verifications/{id}")
async def get_verification_detail(
    id: uuid.UUID,
    context: AuthContext = Depends(require("NGO")),
    db: AsyncSession = Depends(get_db),
):
    ver = await db.get(NGOVerification, id)
    if not ver:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Verification record not found"}})

    batch = await db.get(WasteBatch, ver.batch_id)
    if not batch:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Batch not found"}})

    # Fetch all versions of custody records
    pickups_stmt = select(PickupRecord).where(PickupRecord.batch_id == batch.id).order_by(PickupRecord.version.asc())
    p_res = await db.execute(pickups_stmt)
    pickups = p_res.scalars().all()

    receipts_stmt = select(RecyclerReceipt).where(RecyclerReceipt.batch_id == batch.id).order_by(RecyclerReceipt.version.asc())
    r_res = await db.execute(receipts_stmt)
    receipts = r_res.scalars().all()

    # Open anomaly flags
    flags_stmt = select(AnomalyFlag).where(AnomalyFlag.batch_id == batch.id)
    f_res = await db.execute(flags_stmt)
    flags = f_res.scalars().all()

    # Documents
    docs_stmt = select(Document).join(DocumentLink, Document.id == DocumentLink.document_id).where(
        DocumentLink.entity_id == batch.id
    )
    d_res = await db.execute(docs_stmt)
    docs = d_res.scalars().all()

    return {
        "verification": {
            "id": ver.id,
            "batch_id": ver.batch_id,
            "decision": ver.decision,
            "reviewer_user_id": ver.reviewer_user_id,
            "comments": ver.comments,
            "follow_up_required": ver.follow_up_required,
            "created_at": ver.created_at,
        },
        "batch": {
            "batch_code": batch.batch_code,
            "status": batch.status,
            "estimated_kg": batch.estimated_kg,
            "locality": batch.locality,
            "pickup_address": batch.pickup_address,
        },
        "custody": {
            "pickup_records": [{
                "id": p.id,
                "version": p.version,
                "is_current": p.is_current,
                "collected_kg": p.collected_kg,
                "rate": p.generator_rate_per_kg,
                "confirmed_at": p.confirmed_at,
            } for p in pickups],
            "recycler_receipts": [{
                "id": r.id,
                "version": r.version,
                "is_current": r.is_current,
                "received_kg": r.received_kg,
                "accepted_kg": r.accepted_kg,
                "rejected_kg": r.rejected_kg,
                "quality_grade": r.quality_grade,
                "contamination_pct": r.contamination_pct,
            } for r in receipts],
        },
        "anomalies": [{
            "id": f.id,
            "rule_code": f.rule_code,
            "severity": f.severity,
            "status": f.status,
            "details": f.details,
        } for f in flags],
        "documents": [{
            "id": d.id,
            "doc_type": d.doc_type,
            "sha256": d.sha256,
            "mime_type": d.mime_type,
        } for d in docs],
    }


@router.post("/verifications/{id}/claim")
async def claim_verification(
    id: uuid.UUID,
    context: AuthContext = Depends(require("NGO")),
    db: AsyncSession = Depends(get_db),
):
    ver = await db.get(NGOVerification, id)
    if not ver:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Verification record not found"}})

    ver.decision = "UNDER_REVIEW"
    ver.reviewer_user_id = context.user_id
    await db.commit()
    return {"status": "ok", "decision": "UNDER_REVIEW", "reviewer_user_id": ver.reviewer_user_id}


@router.post("/verifications/{id}/decision")
async def submit_verification_decision(
    id: uuid.UUID,
    req: NGODecisionInput,
    context: AuthContext = Depends(require("NGO")),
    db: AsyncSession = Depends(get_db),
):
    old_ver = await db.get(NGOVerification, id)
    if not old_ver:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Verification record not found"}})

    dec = req.decision.upper()
    if dec not in ["VERIFIED", "FLAGGED", "REJECTED", "REQUIRES_CORRECTION"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": {"code": "VALIDATION_ERROR", "message": f"Invalid decision '{dec}'"}},
        )

    # Flip old record
    old_ver.is_current = False

    # Create new row
    new_ver = NGOVerification(
        batch_id=old_ver.batch_id,
        ngo_org_id=context.org_id,
        reviewer_user_id=context.user_id,
        decision=dec,
        reviewed_record_versions=old_ver.reviewed_record_versions,
        evidence_doc_ids=[str(doc_id) for doc_id in req.evidence_doc_ids] if req.evidence_doc_ids else [],
        comments=req.comments,
        follow_up_required=req.follow_up_required,
        supersedes_id=old_ver.id,
        is_current=True,
    )
    db.add(new_ver)

    batch = await db.get(WasteBatch, old_ver.batch_id)
    if batch:
        event = BatchEvent(
            batch_id=batch.id,
            event_type=f"NGO_{dec}",
            from_status=None,
            to_status=None,
            actor_user_id=context.user_id,
            actor_org_id=context.org_id,
            payload={"decision": dec, "comments": req.comments},
        )
        db.add(event)

    if dec == "FLAGGED":
        db.add(
            AnomalyFlag(
                rule_code="NGO_FLAGGED_IRREGULARITY",
                severity="HIGH",
                batch_id=old_ver.batch_id,
                entity_type="ngo_verification",
                entity_id=new_ver.id,
                details={"comments": req.comments, "reported_by": str(context.user_id)},
                status="OPEN",
            )
        )

    await db.commit()
    return {
        "status": "ok",
        "verification_id": new_ver.id,
        "decision": new_ver.decision,
        "batch_id": new_ver.batch_id,
    }


@router.post("/verifications/{id}/document-requests")
async def request_document(
    id: uuid.UUID,
    req: DocumentRequestInput,
    context: AuthContext = Depends(require("NGO")),
    db: AsyncSession = Depends(get_db),
):
    ver = await db.get(NGOVerification, id)
    if not ver:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Verification record not found"}})

    # Record notification or event
    batch = await db.get(WasteBatch, ver.batch_id)
    if batch:
        db.add(
            BatchEvent(
                batch_id=batch.id,
                event_type="DOCUMENT_REQUESTED",
                from_status=None,
                to_status=None,
                actor_user_id=context.user_id,
                actor_org_id=context.org_id,
                payload={"addressed_to": str(req.addressed_to_org_id), "request": req.request_text},
            )
        )
        await db.commit()

    return {"status": "ok", "message": "Document request sent successfully"}


@router.get("/reports")
async def list_ngo_reports(
    context: AuthContext = Depends(require("NGO")),
    db: AsyncSession = Depends(get_db),
):
    # Summary of verified batches
    stmt = select(func.count(NGOVerification.id), NGOVerification.decision).where(
        NGOVerification.ngo_org_id == context.org_id,
        NGOVerification.is_current.is_(True),
    ).group_by(NGOVerification.decision)
    res = await db.execute(stmt)
    counts = {decision: count for count, decision in res.all()}

    return {
        "status": "ok",
        "counts_by_decision": counts,
        "reporting_period": "FY2026-27",
    }


@router.get("/impact")
async def get_ngo_impact(
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    # Total verified kg
    verified_batches_stmt = select(NGOVerification.batch_id).where(
        NGOVerification.decision == "VERIFIED",
        NGOVerification.is_current.is_(True),
    )
    v_res = await db.execute(verified_batches_stmt)
    v_batch_ids = v_res.scalars().all()

    total_verified_kg = 0.0
    if v_batch_ids:
        weight_stmt = select(func.coalesce(func.sum(RecyclerReceipt.accepted_kg), 0.0)).where(
            RecyclerReceipt.batch_id.in_(v_batch_ids),
            RecyclerReceipt.is_current.is_(True),
        )
        w_res = await db.execute(weight_stmt)
        total_verified_kg = w_res.scalar() or 0.0

    return {
        "total_verified_kg": total_verified_kg,
        "verified_batch_count": len(v_batch_ids),
        "co2_saved_kg_est": round(total_verified_kg * 1.5, 2),
        "fossil_fuel_offset_liters_est": round(total_verified_kg * 0.8, 2),
    }
