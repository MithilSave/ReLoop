"""Digital Material Passport and Yield API router."""

import uuid
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, and_, func, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.permissions import require, AuthContext
from app.models.batches import WasteBatch, BatchEvent
from app.models.reference import MaterialCategory
from app.models.identity import Organisation
from app.models.profiles import GeneratorProfile
from app.models.custody import PickupRecord, RecyclerReceipt, ProcessingRecord, ProcessingInput
from app.models.allocations import Certificate, EPRAllocation
from app.models.ngo import NGOVerification
from app.models.documents import Document, DocumentLink
from app.models.audit import AnomalyFlag, AIPrediction
from app.models.intelligence import TransportConsignment, ConsignmentItem
from app.modules.batches.service import calculate_batch_quantities

router = APIRouter(tags=["passport"])


@router.get("/passports/{batch_code}")
async def get_material_passport(
    batch_code: str,
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(WasteBatch).where(WasteBatch.batch_code == batch_code)
    res = await db.execute(stmt)
    batch = res.scalar_one_or_none()
    if not batch:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": f"Batch '{batch_code}' not found"}})

    mat = await db.get(MaterialCategory, batch.material_category_id)
    gen_org = await db.get(Organisation, batch.generator_org_id)
    gen_prof = await db.get(GeneratorProfile, batch.generator_org_id)

    # Privacy filtering: EPR client sees locality and generator type only
    is_epr_client = context.org_type == "EPR_CLIENT"
    generator_info = {
        "generator_type": gen_prof.generator_kind if gen_prof else "COMMERCIAL",
        "locality": batch.locality,
        "city_id": gen_org.city_id if gen_org else "MUM",
    }
    if not is_epr_client:
        generator_info["legal_name"] = gen_org.legal_name if gen_org else None
        generator_info["address"] = batch.pickup_address

    # Quantities
    quantities = await calculate_batch_quantities(db, batch)

    # Custody records
    p_stmt = select(PickupRecord).where(PickupRecord.batch_id == batch.id).order_by(PickupRecord.version.asc())
    p_res = await db.execute(p_stmt)
    pickups = [{
        "version": p.version,
        "is_current": p.is_current,
        "collected_kg": p.collected_kg,
        "rate": p.generator_rate_per_kg,
        "confirmed_at": p.confirmed_at,
        "handover_method": p.handover_method,
    } for p in p_res.scalars().all()]

    # Consignment
    c_stmt = select(TransportConsignment).join(
        ConsignmentItem, TransportConsignment.id == ConsignmentItem.consignment_id
    ).where(ConsignmentItem.batch_id == batch.id)
    c_res = await db.execute(c_stmt)
    consignment = c_res.scalar_one_or_none()

    # Receipts
    r_stmt = select(RecyclerReceipt).where(RecyclerReceipt.batch_id == batch.id).order_by(RecyclerReceipt.version.asc())
    r_res = await db.execute(r_stmt)
    receipts = [{
        "version": r.version,
        "is_current": r.is_current,
        "received_kg": r.received_kg,
        "accepted_kg": r.accepted_kg,
        "rejected_kg": r.rejected_kg,
        "quality_grade": r.quality_grade,
        "contamination_pct": r.contamination_pct,
        "received_at": r.received_at,
    } for r in r_res.scalars().all()]

    # Processing runs
    runs_stmt = select(ProcessingInput, ProcessingRecord).join(
        ProcessingRecord, ProcessingInput.processing_record_id == ProcessingRecord.id
    ).where(ProcessingInput.batch_id == batch.id)
    runs_res = await db.execute(runs_stmt)
    processing_runs = []
    record_ids = []
    for inp, rec in runs_res.all():
        record_ids.append(rec.id)
        processing_runs.append({
            "record_code": rec.record_code,
            "input_kg": inp.input_kg,
            "apportioned_output_kg": inp.apportioned_output_kg,
            "run_yield_pct": rec.yield_pct,
            "measurement_status": rec.measurement_status,
            "output_form": rec.output_form,
            "run_started_at": rec.run_started_at,
            "run_ended_at": rec.run_ended_at,
        })

    # Certificates
    certificates = []
    if record_ids:
        cert_stmt = select(Certificate).where(Certificate.processing_record_id.in_(record_ids))
        cert_res = await db.execute(cert_stmt)
        certificates = [{
            "certificate_ref": c.certificate_ref,
            "packaging_category": c.packaging_category,
            "certificate_kg": c.certificate_kg,
            "issued_on": c.issued_on,
            "status": c.status,
        } for c in cert_res.scalars().all()]

    # NGO decision history
    ngo_stmt = select(NGOVerification, Organisation).outerjoin(
        Organisation, NGOVerification.ngo_org_id == Organisation.id
    ).where(NGOVerification.batch_id == batch.id).order_by(NGOVerification.created_at.asc())
    n_res = await db.execute(ngo_stmt)
    verifications = [{
        "decision": v.decision,
        "ngo_name": org.legal_name if org else None,
        "comments": v.comments,
        "is_current": v.is_current,
        "created_at": v.created_at,
    } for v, org in n_res.all()]

    # EPR allocations history
    allocations = []
    if record_ids:
        alloc_stmt = select(EPRAllocation).where(EPRAllocation.processing_record_id.in_(record_ids)).order_by(EPRAllocation.created_at.asc())
        a_res = await db.execute(alloc_stmt)
        for a in a_res.scalars().all():
            # If viewer is EPR client, show only allocations belonging to this client
            if is_epr_client and a.epr_org_id != context.org_id:
                continue
            allocations.append({
                "allocation_id": a.id,
                "reporting_period": a.reporting_period,
                "packaging_category": a.packaging_category,
                "quantity_kg": a.quantity_kg,
                "status": a.status,
                "is_reversal": a.reverses_allocation_id is not None,
                "created_at": a.created_at,
            })

    # Documents with SHA-256
    docs_stmt = select(Document).join(DocumentLink, Document.id == DocumentLink.document_id).where(
        DocumentLink.entity_id == batch.id
    )
    d_res = await db.execute(docs_stmt)
    documents = [{
        "doc_type": d.doc_type,
        "sha256": d.sha256,
        "mime_type": d.mime_type,
        "created_at": d.created_at,
    } for d in d_res.scalars().all()]

    # Anomaly flags
    flags_stmt = select(AnomalyFlag).where(AnomalyFlag.batch_id == batch.id)
    f_res = await db.execute(flags_stmt)
    anomalies = [{
        "rule_code": f.rule_code,
        "severity": f.severity,
        "status": f.status,
        "created_at": f.created_at,
    } for f in f_res.scalars().all()]

    return {
        "batch_code": batch.batch_code,
        "qr_token": batch.qr_token,
        "status": batch.status,
        "material": {
            "code": mat.code if mat else "OTHER",
            "name": mat.name if mat else None,
            "resin_code": mat.resin_code if mat else None,
        },
        "generator": generator_info,
        "quantities": quantities.model_dump(),
        "custody": {
            "pickup_records": pickups,
            "consignment": {
                "consignment_code": consignment.consignment_code,
                "vehicle_no": consignment.vehicle_no,
                "status": consignment.status,
            } if consignment else None,
            "receipts": receipts,
            "processing_runs": processing_runs,
        },
        "statutory_certificates": certificates,
        "verifications": verifications,
        "epr_allocations": allocations,
        "documents": documents,
        "anomalies": anomalies,
    }


@router.post("/passports/{batch_code}/snapshot", status_code=status.HTTP_201_CREATED)
async def snapshot_passport(
    batch_code: str,
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(WasteBatch).where(WasteBatch.batch_code == batch_code)
    res = await db.execute(stmt)
    batch = res.scalar_one_or_none()
    if not batch:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Batch not found"}})

    doc_id = uuid.uuid4()
    doc = Document(
        id=doc_id,
        owner_org_id=context.org_id,
        storage_key=f"passports/{batch.batch_code}-{doc_id}.pdf",
        mime_type="application/pdf",
        doc_type="REPORT",
        status="READY",
        uploaded_by_user_id=context.user_id,
    )
    db.add(doc)
    db.add(DocumentLink(document_id=doc.id, entity_type="waste_batch", entity_id=batch.id))
    await db.commit()

    return {
        "status": "ok",
        "document_id": doc.id,
        "storage_key": doc.storage_key,
        "message": "Immutable passport snapshot generated",
    }


@router.get("/yield")
async def get_yield_analytics(
    recycler_id: Optional[uuid.UUID] = Query(None),
    material: Optional[str] = Query(None),
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(ProcessingRecord, MaterialCategory).join(
        MaterialCategory, ProcessingRecord.material_category_id == MaterialCategory.id
    ).where(ProcessingRecord.is_current.is_(True))

    if recycler_id:
        stmt = stmt.where(ProcessingRecord.recycler_org_id == recycler_id)
    elif context.org_type == "RECYCLER":
        stmt = stmt.where(ProcessingRecord.recycler_org_id == context.org_id)

    if material:
        stmt = stmt.where(MaterialCategory.code == material.upper())

    res = await db.execute(stmt)
    records = res.all()

    completed_runs = []
    incomplete_runs = []

    for r, m in records:
        item = {
            "record_code": r.record_code,
            "material": m.code,
            "input_kg": r.input_kg,
            "output_kg": r.output_kg,
            "residue_kg": r.residue_kg,
            "yield_pct": r.yield_pct,
            "run_started_at": r.run_started_at,
        }
        if r.measurement_status == "COMPLETE":
            completed_runs.append(item)
        else:
            incomplete_runs.append(item)

    avg_yield = round(sum(r["yield_pct"] for r in completed_runs) / len(completed_runs), 2) if completed_runs else 0.0

    return {
        "average_yield_pct": avg_yield,
        "completed_runs_count": len(completed_runs),
        "incomplete_runs_count": len(incomplete_runs),
        "completed_runs": completed_runs,
        "incomplete_runs": incomplete_runs,
    }
