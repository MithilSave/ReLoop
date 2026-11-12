"""Recycler API router."""

import uuid
from datetime import date, datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, and_, func, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.permissions import require, AuthContext
from app.core.audit import log_audit_event
from app.models.batches import WasteBatch, BatchEvent
from app.models.reference import MaterialCategory
from app.models.offers import RecyclerOffer
from app.models.custody import RecyclerReceipt, ProcessingRecord, ProcessingInput
from app.models.allocations import Certificate, EPRAllocation
from app.models.ngo import NGOVerification
from app.models.profiles import RecyclerProfile
from app.models.documents import DocumentLink
from app.modules.recycler.schemas import (
    RecyclerOfferCreate,
    RecyclerOfferOut,
    RecyclerReceiptInput,
    RecyclerReceiptCorrectionInput,
    ProcessingRecordCreate,
    CertificateCreate,
)

router = APIRouter(prefix="/recycler", tags=["recycler"])

RECEIVABLE_STATUSES = ("PICKED_UP", "IN_TRANSIT")


async def _processed_input_kg(db: AsyncSession, batch_id: uuid.UUID) -> float:
    """Input kg of a batch already consumed by current processing records (integration patch #3)."""
    stmt = select(func.coalesce(func.sum(ProcessingInput.input_kg), 0.0)).join(
        ProcessingRecord, ProcessingInput.processing_record_id == ProcessingRecord.id
    ).where(ProcessingInput.batch_id == batch_id, ProcessingRecord.is_current.is_(True))
    res = await db.execute(stmt)
    return float(res.scalar() or 0.0)


def utcnow():
    return datetime.now(timezone.utc)


# ── OFFERS ────────────────────────────────────────────────

@router.post("/offers", status_code=status.HTTP_201_CREATED)
async def create_recycler_offer(
    req: RecyclerOfferCreate,
    context: AuthContext = Depends(require("RECYCLER")),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(MaterialCategory).where(MaterialCategory.code == req.material_code.upper())
    res = await db.execute(stmt)
    mat = res.scalar_one_or_none()
    if not mat:
        raise HTTPException(status_code=400, detail={"error": {"code": "INVALID_MATERIAL", "message": "Material not found"}})

    offer = RecyclerOffer(
        recycler_org_id=context.org_id,
        material_category_id=mat.id,
        price_per_kg=req.price_per_kg,
        min_kg=req.min_kg,
        quality_spec=req.quality_spec,
        max_contamination_pct=req.max_contamination_pct,
        valid_from=req.valid_from or utcnow(),
        valid_to=req.valid_to,
        is_active=True,
    )
    db.add(offer)
    await db.commit()
    await db.refresh(offer)
    return {"status": "ok", "offer_id": offer.id}


@router.get("/offers", response_model=List[RecyclerOfferOut])
async def list_own_offers(
    context: AuthContext = Depends(require("RECYCLER")),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(RecyclerOffer, MaterialCategory).join(
        MaterialCategory, RecyclerOffer.material_category_id == MaterialCategory.id
    ).where(RecyclerOffer.recycler_org_id == context.org_id).order_by(desc(RecyclerOffer.created_at))
    res = await db.execute(stmt)
    return [
        RecyclerOfferOut(
            id=off.id,
            recycler_org_id=off.recycler_org_id,
            material_code=mat.code,
            price_per_kg=off.price_per_kg,
            min_kg=off.min_kg,
            quality_spec=off.quality_spec,
            max_contamination_pct=off.max_contamination_pct,
            valid_from=off.valid_from,
            valid_to=off.valid_to,
            is_active=off.is_active,
        )
        for off, mat in res.all()
    ]


@router.get("/offers/public", response_model=List[RecyclerOfferOut])
async def list_public_recycler_offers(
    material: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(RecyclerOffer, MaterialCategory).join(
        MaterialCategory, RecyclerOffer.material_category_id == MaterialCategory.id
    ).where(RecyclerOffer.is_active.is_(True), RecyclerOffer.valid_to >= utcnow())

    if material:
        stmt = stmt.where(MaterialCategory.code == material.upper())

    res = await db.execute(stmt)
    return [
        RecyclerOfferOut(
            id=off.id,
            recycler_org_id=off.recycler_org_id,
            material_code=mat.code,
            price_per_kg=off.price_per_kg,
            min_kg=off.min_kg,
            quality_spec=off.quality_spec,
            max_contamination_pct=off.max_contamination_pct,
            valid_from=off.valid_from,
            valid_to=off.valid_to,
            is_active=off.is_active,
        )
        for off, mat in res.all()
    ]


# ── INCOMING BATCHES ──────────────────────────────────────

@router.get("/incoming")
async def get_incoming_batches(
    context: AuthContext = Depends(require("RECYCLER")),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(WasteBatch).where(
        WasteBatch.destination_recycler_org_id == context.org_id,
        WasteBatch.status.in_(["IN_TRANSIT", "ASSIGNED"]),
    ).order_by(desc(WasteBatch.created_at))
    res = await db.execute(stmt)
    batches = res.scalars().all()
    return [{
        "batch_id": b.id,
        "batch_code": b.batch_code,
        "qr_token": b.qr_token,
        "estimated_kg": b.estimated_kg,
        "status": b.status,
        "locality": b.locality,
        "pickup_address": b.pickup_address,
    } for b in batches]


# ── RECEIPTS ──────────────────────────────────────────────

@router.post("/receipts", status_code=status.HTTP_201_CREATED)
async def create_recycler_receipt(
    req: RecyclerReceiptInput,
    context: AuthContext = Depends(require("RECYCLER")),
    db: AsyncSession = Depends(get_db),
):
    # Strict validation: accepted + rejected == received
    if abs((req.accepted_kg + req.rejected_kg) - req.received_kg) > 0.001:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"error": {"code": "QUANTITY_INCONSISTENT", "message": f"accepted_kg ({req.accepted_kg}) + rejected_kg ({req.rejected_kg}) must equal received_kg ({req.received_kg})"}},
        )

    # Locate batch
    batch = None
    if req.batch_id:
        batch = await db.get(WasteBatch, req.batch_id)
    elif req.qr_token:
        stmt = select(WasteBatch).where(WasteBatch.qr_token == req.qr_token)
        res = await db.execute(stmt)
        batch = res.scalar_one_or_none()

    if not batch:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Batch not found"}})

    # Integration patch #3: only collected batches can be received, once, by their destination.
    if batch.status not in RECEIVABLE_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"error": {"code": "INVALID_STATE_TRANSITION", "message": f"Batch {batch.batch_code} is {batch.status}; only PICKED_UP or IN_TRANSIT batches can be received"}},
        )
    if batch.destination_recycler_org_id and batch.destination_recycler_org_id != context.org_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "FORBIDDEN_ORG", "message": f"Batch {batch.batch_code} is consigned to another recycler"}},
        )
    existing_stmt = select(RecyclerReceipt).where(RecyclerReceipt.batch_id == batch.id, RecyclerReceipt.is_current.is_(True))
    if (await db.execute(existing_stmt)).scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"error": {"code": "RECEIPT_EXISTS", "message": f"Batch {batch.batch_code} already has a receipt; submit a correction instead"}},
        )

    # Fetch active offer price if available
    offer_stmt = select(RecyclerOffer).where(
        RecyclerOffer.recycler_org_id == context.org_id,
        RecyclerOffer.material_category_id == batch.material_category_id,
        RecyclerOffer.is_active.is_(True),
    )
    off_res = await db.execute(offer_stmt)
    offer = off_res.scalar_one_or_none()
    price = offer.price_per_kg if offer else 0.0

    receipt = RecyclerReceipt(
        batch_id=batch.id,
        recycler_org_id=context.org_id,
        received_kg=req.received_kg,
        accepted_kg=req.accepted_kg,
        rejected_kg=req.rejected_kg,
        quality_grade=req.quality_grade,
        contamination_pct=req.contamination_pct,
        price_per_kg=price,
        recycler_offer_id=offer.id if offer else None,
        rejection_disposition=req.rejection_disposition,
        received_at=utcnow(),
        version=1,
        is_current=True,
    )
    db.add(receipt)
    await db.flush()

    if req.document_ids:
        for doc_id in req.document_ids:
            db.add(DocumentLink(document_id=doc_id, entity_type="recycler_receipt", entity_id=receipt.id))

    # Update batch status
    old_status = batch.status
    new_status = "RECEIVED" if req.accepted_kg > 0 else "REJECTED_AT_RECEIPT"
    batch.status = new_status
    batch.destination_recycler_org_id = context.org_id

    event = BatchEvent(
        batch_id=batch.id,
        event_type="RECEIVED",
        from_status=old_status,
        to_status=new_status,
        actor_user_id=context.user_id,
        actor_org_id=context.org_id,
        payload={"received_kg": req.received_kg, "accepted_kg": req.accepted_kg, "rejected_kg": req.rejected_kg},
    )
    db.add(event)
    await db.commit()

    return {
        "status": "ok",
        "receipt_id": receipt.id,
        "batch_code": batch.batch_code,
        "batch_status": new_status,
        "accepted_kg": receipt.accepted_kg,
        "rejected_kg": receipt.rejected_kg,
    }


@router.post("/receipts/{id}/corrections")
async def correct_recycler_receipt(
    id: uuid.UUID,
    req: RecyclerReceiptCorrectionInput,
    context: AuthContext = Depends(require("RECYCLER")),
    db: AsyncSession = Depends(get_db),
):
    old = await db.get(RecyclerReceipt, id)
    if not old or old.recycler_org_id != context.org_id:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Receipt not found"}})
    if not old.is_current:
        raise HTTPException(status_code=409, detail={"error": {"code": "NOT_CURRENT", "message": "Only current receipt can be corrected"}})

    if abs((req.accepted_kg + req.rejected_kg) - req.received_kg) > 0.001:
        raise HTTPException(
            status_code=422,
            detail={"error": {"code": "QUANTITY_INCONSISTENT", "message": "accepted + rejected must equal received"}},
        )

    already_processed = await _processed_input_kg(db, old.batch_id)
    if req.accepted_kg + 0.001 < already_processed:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"error": {"code": "ACCEPTED_BELOW_PROCESSED", "message": f"{already_processed:.3f} kg of this batch is already in processing runs; accepted kg cannot be lower",
                              "details": {"processed_input_kg": f"{already_processed:.3f}"}}},
        )
    old.is_current = False
    new_receipt = RecyclerReceipt(
        batch_id=old.batch_id,
        recycler_org_id=old.recycler_org_id,
        received_kg=req.received_kg,
        accepted_kg=req.accepted_kg,
        rejected_kg=req.rejected_kg,
        quality_grade=req.quality_grade,
        contamination_pct=req.contamination_pct,
        price_per_kg=old.price_per_kg,
        recycler_offer_id=old.recycler_offer_id,
        rejection_disposition=f"Correction: {req.reason}",
        received_at=utcnow(),
        version=old.version + 1,
        supersedes_id=old.id,
        is_current=True,
    )
    db.add(new_receipt)

    event = BatchEvent(
        batch_id=old.batch_id,
        event_type="CORRECTION_SUBMITTED",
        from_status=None,
        to_status=None,
        actor_user_id=context.user_id,
        actor_org_id=context.org_id,
        payload={"reason": req.reason, "version": new_receipt.version},
    )
    db.add(event)
    await db.commit()
    return {"status": "ok", "new_receipt_id": new_receipt.id, "version": new_receipt.version}


# ── PROCESSING RUNS ───────────────────────────────────────

@router.post("/processing-records", status_code=status.HTTP_201_CREATED)
async def create_processing_record(
    req: ProcessingRecordCreate,
    context: AuthContext = Depends(require("RECYCLER")),
    db: AsyncSession = Depends(get_db),
):
    mat_stmt = select(MaterialCategory).where(MaterialCategory.code == req.material_code.upper())
    mat_res = await db.execute(mat_stmt)
    mat = mat_res.scalar_one_or_none()
    if not mat:
        raise HTTPException(status_code=400, detail={"error": {"code": "INVALID_MATERIAL", "message": "Material not found"}})

    total_input = sum(inp.input_kg for inp in req.inputs)
    if total_input <= 0:
        raise HTTPException(status_code=422, detail={"error": {"code": "QUANTITY_INCONSISTENT", "message": "Input kg must be greater than 0"}})

    # Validate output + residue <= input
    if (req.output_kg + req.residue_kg) > total_input + 0.001:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"error": {"code": "QUANTITY_INCONSISTENT", "message": f"Output ({req.output_kg}) + residue ({req.residue_kg}) exceeds total input ({total_input})"}},
        )

    # Validate eligible <= output
    if req.eligible_kg > req.output_kg + 0.001:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"error": {"code": "QUANTITY_INCONSISTENT", "message": f"Eligible kg ({req.eligible_kg}) exceeds output kg ({req.output_kg})"}},
        )

    # Integration patch #3: validate every input against accepted stock before writing anything.
    requested_by_batch: dict = {}
    receipt_for_batch: dict = {}
    for inp in req.inputs:
        rcpt = await db.get(RecyclerReceipt, inp.recycler_receipt_id)
        if not rcpt:
            raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": f"Receipt {inp.recycler_receipt_id} not found"}})
        if rcpt.recycler_org_id != context.org_id:
            raise HTTPException(status_code=403, detail={"error": {"code": "FORBIDDEN_ORG", "message": "Receipt does not belong to you"}})
        if not rcpt.is_current:
            raise HTTPException(status_code=409, detail={"error": {"code": "NOT_CURRENT", "message": "Receipt has been superseded by a correction; use the current version"}})
        b = await db.get(WasteBatch, rcpt.batch_id)
        if b and b.material_category_id != mat.id:
            raise HTTPException(
                status_code=422,
                detail={"error": {"code": "MATERIAL_MISMATCH", "message": f"Batch {b.batch_code} is not {mat.code}; a run processes one material"}},
            )
        receipt_for_batch[rcpt.batch_id] = rcpt
        requested_by_batch[rcpt.batch_id] = requested_by_batch.get(rcpt.batch_id, 0.0) + inp.input_kg
    for batch_id, requested in requested_by_batch.items():
        rcpt = receipt_for_batch[batch_id]
        processed = await _processed_input_kg(db, batch_id)
        available = max(0.0, rcpt.accepted_kg - processed)
        if requested > available + 0.001:
            b = await db.get(WasteBatch, batch_id)
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={"error": {"code": "INPUT_EXCEEDS_AVAILABLE",
                                  "message": f"Batch {b.batch_code if b else batch_id}: requested {requested:.3f} kg exceeds available {available:.3f} kg",
                                  "details": {"accepted_kg": f"{rcpt.accepted_kg:.3f}", "processed_input_kg": f"{processed:.3f}", "available_kg": f"{available:.3f}"}}},
            )

    # Compute yield
    yield_pct = round((req.output_kg / total_input) * 100, 3)
    unaccounted_kg = round(total_input - req.output_kg - req.residue_kg, 3)

    # Generate record code
    count_stmt = select(ProcessingRecord)
    c_res = await db.execute(count_stmt)
    run_num = len(c_res.scalars().all()) + 1
    record_code = f"PR-{utcnow().year}-{run_num:05d}"

    proc_record = ProcessingRecord(
        record_code=record_code,
        recycler_org_id=context.org_id,
        material_category_id=mat.id,
        run_started_at=req.run_started_at,
        run_ended_at=req.run_ended_at,
        input_kg=total_input,
        output_kg=req.output_kg,
        residue_kg=req.residue_kg,
        output_form=req.output_form,
        eligible_kg=req.eligible_kg,
        eligibility_basis=req.eligibility_basis,
        measurement_status="COMPLETE",
        yield_pct=yield_pct,
        unaccounted_kg=unaccounted_kg,
        version=1,
        is_current=True,
    )
    db.add(proc_record)
    await db.flush()

    # Process inputs & update batches
    for inp in req.inputs:
        rcpt = await db.get(RecyclerReceipt, inp.recycler_receipt_id)
        if not rcpt:
            raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": f"Receipt {inp.recycler_receipt_id} not found"}})
        if rcpt.recycler_org_id != context.org_id:
            raise HTTPException(status_code=403, detail={"error": {"code": "FORBIDDEN_ORG", "message": "Receipt does not belong to you"}})

        apportioned_output = round((inp.input_kg / total_input) * req.output_kg, 3)
        p_inp = ProcessingInput(
            processing_record_id=proc_record.id,
            recycler_receipt_id=rcpt.id,
            batch_id=rcpt.batch_id,
            input_kg=inp.input_kg,
            apportioned_output_kg=apportioned_output,
        )
        db.add(p_inp)

        # Update batch status to PROCESSED
        batch = await db.get(WasteBatch, rcpt.batch_id)
        if batch:
            old_s = batch.status
            batch.status = "PROCESSED"
            db.add(
                BatchEvent(
                    batch_id=batch.id,
                    event_type="PROCESSED",
                    from_status=old_s,
                    to_status="PROCESSED",
                    actor_user_id=context.user_id,
                    actor_org_id=context.org_id,
                    payload={"record_code": record_code, "apportioned_output_kg": apportioned_output},
                )
            )

            # Automatically create pending NGOVerification row for this batch if not already present
            ngo_chk = select(NGOVerification).where(
                NGOVerification.batch_id == batch.id,
                NGOVerification.is_current.is_(True),
            )
            ngo_res = await db.execute(ngo_chk)
            if not ngo_res.scalar_one_or_none():
                # Pick any registered NGO for initial assignment
                from app.models.identity import Organisation
                ngo_org_stmt = select(Organisation).where(Organisation.org_type == "NGO", Organisation.approval_status == "APPROVED")
                ngo_org_res = await db.execute(ngo_org_stmt)
                ngo_org = ngo_org_res.scalars().first()
                if ngo_org:
                    db.add(
                        NGOVerification(
                            batch_id=batch.id,
                            ngo_org_id=ngo_org.id,
                            decision="PENDING",
                            reviewed_record_versions={"processing_record_id": str(proc_record.id)},
                            is_current=True,
                        )
                    )

    await db.commit()
    return {
        "status": "ok",
        "processing_record_id": proc_record.id,
        "record_code": proc_record.record_code,
        "input_kg": proc_record.input_kg,
        "output_kg": proc_record.output_kg,
        "yield_pct": proc_record.yield_pct,
        "eligible_kg": proc_record.eligible_kg,
        "measurement_status": "COMPLETE",
    }


@router.get("/processing-records")
async def list_processing_records(
    context: AuthContext = Depends(require("RECYCLER")),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(ProcessingRecord, MaterialCategory).join(
        MaterialCategory, ProcessingRecord.material_category_id == MaterialCategory.id
    ).where(
        ProcessingRecord.recycler_org_id == context.org_id,
        ProcessingRecord.is_current.is_(True),
    ).order_by(desc(ProcessingRecord.created_at))
    res = await db.execute(stmt)

    output = []
    for rec, mat in res.all():
        # Get active allocated kg
        alloc_stmt = select(func.coalesce(func.sum(EPRAllocation.quantity_kg), 0.0)).where(
            EPRAllocation.processing_record_id == rec.id,
            EPRAllocation.status == "ACTIVE",
        )
        alloc_res = await db.execute(alloc_stmt)
        allocated_kg = alloc_res.scalar() or 0.0

        output.append({
            "id": rec.id,
            "record_code": rec.record_code,
            "material_code": mat.code,
            "run_started_at": rec.run_started_at,
            "run_ended_at": rec.run_ended_at,
            "input_kg": rec.input_kg,
            "output_kg": rec.output_kg,
            "residue_kg": rec.residue_kg,
            "eligible_kg": rec.eligible_kg,
            "allocated_kg": allocated_kg,
            "available_kg": max(0.0, rec.eligible_kg - allocated_kg),
            "yield_pct": rec.yield_pct,
            "measurement_status": rec.measurement_status,
        })
    return output


# ── STATUTORY CERTIFICATES ────────────────────────────────

@router.post("/processing-records/{id}/certificates", status_code=status.HTTP_201_CREATED)
async def add_certificate(
    id: uuid.UUID,
    req: CertificateCreate,
    context: AuthContext = Depends(require("RECYCLER")),
    db: AsyncSession = Depends(get_db),
):
    rec = await db.get(ProcessingRecord, id)
    if not rec or rec.recycler_org_id != context.org_id:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Processing record not found"}})

    # Check duplicate certificate ref for this recycler
    dup_stmt = select(Certificate).where(
        Certificate.recycler_org_id == context.org_id,
        Certificate.certificate_ref == req.certificate_ref,
    )
    dup_res = await db.execute(dup_stmt)
    if dup_res.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"error": {"code": "DUPLICATE_CERTIFICATE_REF", "message": f"Certificate ref '{req.certificate_ref}' already recorded"}},
        )

    # Validate certificate_kg <= output_kg
    if rec.output_kg and req.certificate_kg > rec.output_kg:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"error": {"code": "QUANTITY_INCONSISTENT", "message": f"Certificate kg ({req.certificate_kg}) cannot exceed run output kg ({rec.output_kg})"}},
        )

    cert = Certificate(
        recycler_org_id=context.org_id,
        processing_record_id=rec.id,
        certificate_ref=req.certificate_ref,
        packaging_category=req.packaging_category,
        certificate_kg=req.certificate_kg,
        issued_on=req.issued_on or date.today(),
        status="RECORDED",
        evidence_doc_id=req.evidence_doc_id,
    )
    db.add(cert)
    await db.commit()
    await db.refresh(cert)
    return {
        "status": "ok",
        "certificate_id": cert.id,
        "certificate_ref": cert.certificate_ref,
        "certificate_kg": cert.certificate_kg,
    }


# ── CAPACITY ──────────────────────────────────────────────

@router.get("/capacity")
async def get_recycler_capacity(
    context: AuthContext = Depends(require("RECYCLER")),
    db: AsyncSession = Depends(get_db),
):
    prof = await db.get(RecyclerProfile, context.org_id)
    monthly_cap = prof.monthly_capacity_kg if prof else 50000.0

    # Processed this month
    start_of_month = datetime(utcnow().year, utcnow().month, 1, tzinfo=timezone.utc)
    stmt = select(func.coalesce(func.sum(ProcessingRecord.output_kg), 0.0)).where(
        ProcessingRecord.recycler_org_id == context.org_id,
        ProcessingRecord.created_at >= start_of_month,
        ProcessingRecord.is_current.is_(True),
    )
    res = await db.execute(stmt)
    processed_this_month = res.scalar() or 0.0
    utilization_pct = round((processed_this_month / monthly_cap) * 100, 2) if monthly_cap > 0 else 0.0

    return {
        "monthly_capacity_kg": monthly_cap,
        "processed_this_month_kg": processed_this_month,
        "utilization_pct": utilization_pct,
        "remaining_capacity_kg": max(0.0, monthly_cap - processed_this_month),
    }


@router.get("/receipts")
async def list_recycler_receipts(
    include_history: bool = Query(False),
    context: AuthContext = Depends(require("RECYCLER")),
    db: AsyncSession = Depends(get_db),
):
    """Receipts recorded by the caller (integration patch #2). Current versions by default."""
    stmt = select(RecyclerReceipt, WasteBatch, MaterialCategory).join(
        WasteBatch, RecyclerReceipt.batch_id == WasteBatch.id
    ).join(
        MaterialCategory, WasteBatch.material_category_id == MaterialCategory.id
    ).where(RecyclerReceipt.recycler_org_id == context.org_id).order_by(desc(RecyclerReceipt.received_at))
    if not include_history:
        stmt = stmt.where(RecyclerReceipt.is_current.is_(True))
    res = await db.execute(stmt)
    out = []
    for r, b, m in res.all():
        processed = await _processed_input_kg(db, b.id) if r.is_current else None
        out.append({
            "id": r.id,
            "batch_id": b.id,
            "batch_code": b.batch_code,
            "batch_status": b.status,
            "material_code": m.code,
            "version": r.version,
            "is_current": r.is_current,
            "supersedes_id": r.supersedes_id,
            "received_kg": r.received_kg,
            "accepted_kg": r.accepted_kg,
            "rejected_kg": r.rejected_kg,
            "quality_grade": r.quality_grade,
            "contamination_pct": r.contamination_pct,
            "rejection_disposition": r.rejection_disposition,
            "received_at": r.received_at,
            "processed_input_kg": processed,
            "available_kg": max(0.0, r.accepted_kg - processed) if processed is not None else None,
        })
    return out
