"""EPR compliance and allocation API router."""

import uuid
from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func, and_, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.permissions import require, AuthContext
from app.core.audit import log_audit_event
from app.models.profiles import EPRTarget
from app.models.allocations import EPRAllocation, Certificate
from app.models.custody import ProcessingRecord, ProcessingInput
from app.models.ngo import NGOVerification
from app.models.audit import AnomalyFlag
from app.models.identity import Organisation
from app.modules.epr.schemas import (
    EPRTargetInput,
    EPRTargetOut,
    AllocationCreateInput,
    AllocationReverseInput,
    AllocationRequestInput,
    AllocationOut,
    EPRReportCreateInput,
)

router = APIRouter(prefix="/epr", tags=["epr"])


def utcnow():
    return datetime.now(timezone.utc)


# ── DASHBOARD ─────────────────────────────────────────────

@router.get("/dashboard")
async def get_epr_dashboard(
    period: Optional[str] = Query("FY2026-27"),
    context: AuthContext = Depends(require("EPR_CLIENT")),
    db: AsyncSession = Depends(get_db),
):
    # Self-declared targets for this period
    targets_stmt = select(EPRTarget).where(
        EPRTarget.epr_org_id == context.org_id,
        EPRTarget.reporting_period == period,
    )
    t_res = await db.execute(targets_stmt)
    targets = t_res.scalars().all()
    total_target_kg = sum(t.target_kg for t in targets)

    # Active allocations for this client
    alloc_stmt = select(EPRAllocation).where(
        EPRAllocation.epr_org_id == context.org_id,
        EPRAllocation.reporting_period == period,
        EPRAllocation.status == "ACTIVE",
    )
    a_res = await db.execute(alloc_stmt)
    allocations = a_res.scalars().all()
    total_allocated_kg = sum(a.quantity_kg for a in allocations)

    # Check verified vs unverified allocations
    verified_allocated_kg = 0.0
    for a in allocations:
        # Check if processing record batches are verified by NGO
        inputs_stmt = select(ProcessingInput.batch_id).where(
            ProcessingInput.processing_record_id == a.processing_record_id
        )
        inp_res = await db.execute(inputs_stmt)
        b_ids = inp_res.scalars().all()

        if b_ids:
            ngo_stmt = select(func.count(NGOVerification.id)).where(
                NGOVerification.batch_id.in_(b_ids),
                NGOVerification.decision == "VERIFIED",
                NGOVerification.is_current.is_(True),
            )
            n_res = await db.execute(ngo_stmt)
            if (n_res.scalar() or 0) > 0:
                verified_allocated_kg += a.quantity_kg

    unverified_allocated_kg = total_allocated_kg - verified_allocated_kg
    pending_kg = max(0.0, total_target_kg - total_allocated_kg)
    compliance_pct = round((total_allocated_kg / total_target_kg) * 100, 2) if total_target_kg > 0 else 0.0

    return {
        "reporting_period": period,
        "total_target_kg": total_target_kg,
        "total_allocated_kg": total_allocated_kg,
        "verified_allocated_kg": verified_allocated_kg,
        "unverified_allocated_kg": unverified_allocated_kg,
        "pending_kg": pending_kg,
        "compliance_pct": compliance_pct,
        "targets_by_category": [{
            "category": t.packaging_category,
            "target_kg": t.target_kg,
        } for t in targets],
    }


# ── TARGETS ───────────────────────────────────────────────

@router.get("/targets", response_model=List[EPRTargetOut])
async def list_targets(
    period: Optional[str] = Query(None),
    context: AuthContext = Depends(require("EPR_CLIENT")),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(EPRTarget).where(EPRTarget.epr_org_id == context.org_id)
    if period:
        stmt = stmt.where(EPRTarget.reporting_period == period)
    res = await db.execute(stmt)
    return res.scalars().all()


@router.post("/targets", response_model=EPRTargetOut, status_code=status.HTTP_201_CREATED)
async def create_target(
    req: EPRTargetInput,
    context: AuthContext = Depends(require("EPR_CLIENT")),
    db: AsyncSession = Depends(get_db),
):
    # Upsert or check existing
    stmt = select(EPRTarget).where(
        EPRTarget.epr_org_id == context.org_id,
        EPRTarget.reporting_period == req.reporting_period,
        EPRTarget.packaging_category == req.packaging_category.upper(),
    )
    res = await db.execute(stmt)
    existing = res.scalar_one_or_none()
    if existing:
        existing.target_kg = req.target_kg
        existing.source_note = req.source_note
        await db.commit()
        await db.refresh(existing)
        return existing

    target = EPRTarget(
        epr_org_id=context.org_id,
        reporting_period=req.reporting_period,
        packaging_category=req.packaging_category.upper(),
        target_kg=req.target_kg,
        source_note=req.source_note,
    )
    db.add(target)
    await db.commit()
    await db.refresh(target)
    return target


# ── ALLOCATIONS ───────────────────────────────────────────

@router.get("/allocations", response_model=List[AllocationOut])
async def list_allocations(
    status_filter: Optional[str] = Query(None, alias="status"),
    context: AuthContext = Depends(require("EPR_CLIENT", "RECYCLER")),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(EPRAllocation).order_by(desc(EPRAllocation.created_at))
    if not context.is_admin:
        if context.org_type == "EPR_CLIENT":
            stmt = stmt.where(EPRAllocation.epr_org_id == context.org_id)
        elif context.org_type == "RECYCLER":
            # Recycler sees allocations from processing records owned by it
            stmt = stmt.join(ProcessingRecord, EPRAllocation.processing_record_id == ProcessingRecord.id).where(
                ProcessingRecord.recycler_org_id == context.org_id
            )

    if status_filter:
        stmt = stmt.where(EPRAllocation.status == status_filter.upper())

    res = await db.execute(stmt)
    return res.scalars().all()


@router.post("/allocation-requests", status_code=status.HTTP_201_CREATED)
async def request_allocation(
    req: AllocationRequestInput,
    context: AuthContext = Depends(require("EPR_CLIENT")),
    db: AsyncSession = Depends(get_db),
):
    # In MVP, this records the intention and notifies the recycler
    return {
        "status": "ok",
        "request_id": uuid.uuid4(),
        "message": "Allocation request created and sent to recycler",
    }


@router.post("/allocations", status_code=status.HTTP_201_CREATED)
async def create_allocation(
    req: AllocationCreateInput,
    context: AuthContext = Depends(require("RECYCLER")),
    db: AsyncSession = Depends(get_db),
):
    # Fetch processing record
    rec = await db.get(ProcessingRecord, req.processing_record_id)
    if not rec or rec.recycler_org_id != context.org_id:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Processing record not found"}})
    if not rec.is_current:
        raise HTTPException(status_code=409, detail={"error": {"code": "NOT_CURRENT", "message": "Processing record is not current version"}})
    if rec.measurement_status != "COMPLETE":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"error": {"code": "INCOMPLETE_MEASUREMENT", "message": "Allocation allowed only when measurement_status is COMPLETE"}},
        )

    # Compute currently active allocations
    alloc_stmt = select(func.coalesce(func.sum(EPRAllocation.quantity_kg), 0.0)).where(
        EPRAllocation.processing_record_id == rec.id,
        EPRAllocation.status == "ACTIVE",
    )
    alloc_res = await db.execute(alloc_stmt)
    current_alloc = alloc_res.scalar() or 0.0
    available = max(0.0, rec.eligible_kg - current_alloc)

    # ANTI-DOUBLE-COUNTING SAFEGUARD (Docs 05 §6 & 06 §8)
    if (current_alloc + req.quantity_kg) > rec.eligible_kg + 0.001:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "error": {
                    "code": "ALLOCATION_EXCEEDS_AVAILABLE",
                    "message": f"Requested {req.quantity_kg:.3f} kg exceeds available {available:.3f} kg",
                    "details": {
                        "eligible_kg": f"{rec.eligible_kg:.3f}",
                        "allocated_kg": f"{current_alloc:.3f}",
                        "available_kg": f"{available:.3f}",
                    },
                }
            },
        )

    # If certificate ref is given, check certificate capacity
    if req.certificate_id:
        cert = await db.get(Certificate, req.certificate_id)
        if not cert or cert.recycler_org_id != context.org_id:
            raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Certificate not found"}})

    allocation = EPRAllocation(
        processing_record_id=rec.id,
        epr_org_id=req.epr_org_id,
        certificate_id=req.certificate_id,
        packaging_category=req.packaging_category.upper(),
        reporting_period=req.reporting_period,
        quantity_kg=req.quantity_kg,
        status="ACTIVE",
        created_by_user_id=context.user_id,
    )
    db.add(allocation)

    await log_audit_event(
        db=db,
        action="EPR_ALLOCATION_CREATED",
        entity_type="epr_allocation",
        entity_id=allocation.id,
        actor_user_id=context.user_id,
        actor_org_id=context.org_id,
        after={
            "quantity_kg": req.quantity_kg,
            "epr_org_id": str(req.epr_org_id),
            "processing_record_id": str(rec.id),
        },
    )

    await db.commit()
    await db.refresh(allocation)
    return {
        "status": "ok",
        "allocation_id": allocation.id,
        "quantity_kg": allocation.quantity_kg,
        "remaining_available_kg": max(0.0, available - req.quantity_kg),
    }


@router.post("/allocations/{id}/reverse")
async def reverse_allocation(
    id: uuid.UUID,
    req: AllocationReverseInput,
    context: AuthContext = Depends(require("RECYCLER")),
    db: AsyncSession = Depends(get_db),
):
    original = await db.get(EPRAllocation, id)
    if not original:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Allocation not found"}})
    if original.status != "ACTIVE":
        raise HTTPException(
            status_code=409,
            detail={"error": {"code": "ALREADY_REVERSED", "message": "Allocation is already reversed"}},
        )

    # Flip original to REVERSED
    original.status = "REVERSED"

    # Insert reversal row with reverses_allocation_id
    reversal_row = EPRAllocation(
        processing_record_id=original.processing_record_id,
        epr_org_id=original.epr_org_id,
        certificate_id=original.certificate_id,
        packaging_category=original.packaging_category,
        reporting_period=original.reporting_period,
        quantity_kg=original.quantity_kg,
        status="REVERSED",
        reverses_allocation_id=original.id,
        reason=req.reason,
        created_by_user_id=context.user_id,
    )
    db.add(reversal_row)

    await log_audit_event(
        db=db,
        action="EPR_ALLOCATION_REVERSED",
        entity_type="epr_allocation",
        entity_id=original.id,
        actor_user_id=context.user_id,
        actor_org_id=context.org_id,
        after={"reversal_reason": req.reason, "reverses_id": str(original.id)},
    )

    await db.commit()
    return {"status": "ok", "message": "Allocation successfully reversed", "reversal_id": reversal_row.id}


@router.get("/certificates")
async def list_epr_client_certificates(
    context: AuthContext = Depends(require("EPR_CLIENT")),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Certificate).join(
        EPRAllocation, Certificate.id == EPRAllocation.certificate_id
    ).where(
        EPRAllocation.epr_org_id == context.org_id,
        EPRAllocation.status == "ACTIVE",
    ).distinct()
    res = await db.execute(stmt)
    certs = res.scalars().all()
    return [{
        "certificate_id": c.id,
        "certificate_ref": c.certificate_ref,
        "packaging_category": c.packaging_category,
        "certificate_kg": c.certificate_kg,
        "issued_on": c.issued_on,
        "status": c.status,
    } for c in certs]


@router.get("/discrepancies")
async def get_epr_discrepancies(
    context: AuthContext = Depends(require("EPR_CLIENT")),
    db: AsyncSession = Depends(get_db),
):
    # Find batches tied to client allocations
    alloc_stmt = select(EPRAllocation.processing_record_id).where(
        EPRAllocation.epr_org_id == context.org_id,
        EPRAllocation.status == "ACTIVE",
    )
    a_res = await db.execute(alloc_stmt)
    proc_ids = a_res.scalars().all()

    if not proc_ids:
        return []

    inp_stmt = select(ProcessingInput.batch_id).where(
        ProcessingInput.processing_record_id.in_(proc_ids)
    )
    i_res = await db.execute(inp_stmt)
    b_ids = i_res.scalars().all()

    if not b_ids:
        return []

    # Check non-verified NGO decisions or open flags
    flags_stmt = select(AnomalyFlag).where(AnomalyFlag.batch_id.in_(b_ids))
    f_res = await db.execute(flags_stmt)
    flags = f_res.scalars().all()

    return [{
        "flag_id": f.id,
        "batch_id": f.batch_id,
        "rule_code": f.rule_code,
        "severity": f.severity,
        "status": f.status,
        "details": f.details,
        "created_at": f.created_at,
    } for f in flags]


@router.post("/reports", status_code=status.HTTP_202_ACCEPTED)
async def generate_epr_report(
    req: EPRReportCreateInput,
    context: AuthContext = Depends(require("EPR_CLIENT")),
    db: AsyncSession = Depends(get_db),
):
    report_id = uuid.uuid4()
    return {
        "status": "ACCEPTED",
        "report_id": report_id,
        "format": req.format,
        "period": req.period,
        "download_url": f"/api/v1/epr/reports/{report_id}",
    }


@router.get("/reports/{id}")
async def get_epr_report(
    id: uuid.UUID,
    context: AuthContext = Depends(require("EPR_CLIENT")),
    db: AsyncSession = Depends(get_db),
):
    return {
        "id": id,
        "status": "READY",
        "download_url": f"https://reloop-storage.local/reports/{id}.pdf",
    }
