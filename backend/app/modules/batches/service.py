"""Batches business logic service."""

import io
import secrets
import uuid
from datetime import datetime, timezone
from typing import List, Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy import select, func, or_, desc
from sqlalchemy.ext.asyncio import AsyncSession
import qrcode

from app.core.audit import log_audit_event
from app.models.batches import WasteBatch, BatchEvent
from app.models.reference import MaterialCategory
from app.models.identity import Organisation
from app.models.custody import PickupRecord, RecyclerReceipt, ProcessingRecord, ProcessingInput
from app.models.allocations import EPRAllocation
from app.models.ngo import NGOVerification
from app.models.documents import DocumentLink
from app.modules.batches.schemas import BatchCreateInput, BatchUpdateInput, BatchQuantities, VerificationSummary, BatchDetailOut


def utcnow():
    return datetime.now(timezone.utc)


async def generate_batch_code(db: AsyncSession, city_id: str = "MUM") -> str:
    year = datetime.now(timezone.utc).year
    # Count existing batches to format 6-digit sequence
    stmt = select(func.count(WasteBatch.id))
    res = await db.execute(stmt)
    count = (res.scalar() or 0) + 1
    return f"RL-{city_id}-{year}-{count:06d}"


def generate_qr_token() -> str:
    return secrets.token_urlsafe(32)


async def calculate_batch_quantities(db: AsyncSession, batch: WasteBatch) -> BatchQuantities:
    # 1. Estimated
    est = f"{batch.estimated_kg:.3f}"

    # 2. Collected
    col_stmt = select(PickupRecord).where(
        PickupRecord.batch_id == batch.id,
        PickupRecord.is_current.is_(True),
    )
    col_res = await db.execute(col_stmt)
    pickup = col_res.scalar_one_or_none()
    collected = f"{pickup.collected_kg:.3f}" if pickup else None

    # 3. Received / Accepted / Rejected
    rec_stmt = select(RecyclerReceipt).where(
        RecyclerReceipt.batch_id == batch.id,
        RecyclerReceipt.is_current.is_(True),
    )
    rec_res = await db.execute(rec_stmt)
    receipt = rec_res.scalar_one_or_none()
    received = f"{receipt.received_kg:.3f}" if receipt else None
    accepted = f"{receipt.accepted_kg:.3f}" if receipt else None
    rejected = f"{receipt.rejected_kg:.3f}" if receipt else None

    # 4. Processed
    inp_stmt = select(ProcessingInput, ProcessingRecord).join(
        ProcessingRecord, ProcessingInput.processing_record_id == ProcessingRecord.id
    ).where(
        ProcessingInput.batch_id == batch.id,
        ProcessingRecord.is_current.is_(True),
    )
    inp_res = await db.execute(inp_stmt)
    input_row = inp_res.first()
    processed = None
    processed_val = 0.0
    rec_id = None
    if input_row:
        p_inp, p_rec = input_row
        processed_val = p_inp.apportioned_output_kg
        processed = f"{processed_val:.3f}"
        rec_id = p_rec.id

    # 5. NGO Verified
    ngo_stmt = select(NGOVerification).where(
        NGOVerification.batch_id == batch.id,
        NGOVerification.is_current.is_(True),
    ).order_by(desc(NGOVerification.created_at))
    ngo_res = await db.execute(ngo_stmt)
    ngo_ver = ngo_res.scalar_one_or_none()
    ngo_verified = None
    if ngo_ver and ngo_ver.decision == "VERIFIED":
        if processed:
            ngo_verified = processed
        elif accepted:
            ngo_verified = accepted
        else:
            ngo_verified = collected or est

    # 6. EPR Allocated
    epr_allocated = None
    if rec_id and input_row:
        p_inp, p_rec = input_row
        alloc_stmt = select(func.coalesce(func.sum(EPRAllocation.quantity_kg), 0.0)).where(
            EPRAllocation.processing_record_id == rec_id,
            EPRAllocation.status == "ACTIVE",
        )
        alloc_res = await db.execute(alloc_stmt)
        total_rec_alloc = alloc_res.scalar() or 0.0
        if p_rec.output_kg and p_rec.output_kg > 0:
            batch_share = (p_inp.apportioned_output_kg / p_rec.output_kg) * total_rec_alloc
            epr_allocated = f"{batch_share:.3f}"
        else:
            epr_allocated = "0.000"

    return BatchQuantities(
        estimated_kg=est,
        collected_kg=collected,
        received_kg=received,
        accepted_kg=accepted,
        rejected_kg=rejected,
        processed_kg=processed,
        ngo_verified_kg=ngo_verified,
        epr_allocated_kg=epr_allocated,
    )


async def get_batch_verification_summary(db: AsyncSession, batch_id: uuid.UUID) -> Optional[VerificationSummary]:
    stmt = select(NGOVerification, Organisation).outerjoin(
        Organisation, NGOVerification.ngo_org_id == Organisation.id
    ).where(
        NGOVerification.batch_id == batch_id,
        NGOVerification.is_current.is_(True),
    ).order_by(desc(NGOVerification.created_at))
    res = await db.execute(stmt)
    row = res.first()
    if not row:
        return None
    ver, org = row
    return VerificationSummary(
        decision=ver.decision,
        ngo=org.legal_name if org else None,
        at=ver.created_at,
        comments=ver.comments,
    )


async def create_batch(
    db: AsyncSession,
    generator_org_id: uuid.UUID,
    user_id: uuid.UUID,
    input_data: BatchCreateInput,
) -> WasteBatch:
    # Validate material category
    stmt = select(MaterialCategory).where(MaterialCategory.code == input_data.material_code.upper())
    res = await db.execute(stmt)
    mat = res.scalar_one_or_none()
    if not mat:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": {"code": "INVALID_MATERIAL", "message": f"Material '{input_data.material_code}' not found"}},
        )

    # Fetch generator org for city_id
    gen_org = await db.get(Organisation, generator_org_id)
    city_id = gen_org.city_id if gen_org else "MUM"

    batch_code = await generate_batch_code(db, city_id)
    qr_token = generate_qr_token()

    batch = WasteBatch(
        batch_code=batch_code,
        qr_token=qr_token,
        generator_org_id=generator_org_id,
        material_category_id=mat.id,
        ai_prediction_id=input_data.ai_prediction_id,
        estimated_kg=input_data.estimated_kg,
        pickup_address=input_data.pickup_address,
        lat=input_data.lat,
        lng=input_data.lng,
        locality=input_data.locality,
        available_from=input_data.available_from,
        available_to=input_data.available_to,
        status="LISTED",
    )
    db.add(batch)
    await db.flush()

    # Link documents if provided
    if input_data.document_ids:
        for doc_id in input_data.document_ids:
            db.add(DocumentLink(document_id=doc_id, entity_type="waste_batch", entity_id=batch.id))

    # Event
    event = BatchEvent(
        batch_id=batch.id,
        event_type="CREATED",
        from_status=None,
        to_status="LISTED",
        actor_user_id=user_id,
        actor_org_id=generator_org_id,
        payload={"estimated_kg": input_data.estimated_kg, "material": mat.code},
    )
    db.add(event)

    await log_audit_event(
        db=db,
        action="BATCH_CREATED",
        entity_type="waste_batch",
        entity_id=batch.id,
        actor_user_id=user_id,
        actor_org_id=generator_org_id,
        after={"batch_code": batch.batch_code, "status": "LISTED", "estimated_kg": batch.estimated_kg},
    )

    await db.commit()
    await db.refresh(batch)
    return batch


def generate_qr_image_bytes(qr_token: str) -> bytes:
    qr = qrcode.QRCode(version=1, box_size=10, border=4)
    qr.add_data(f"reloop://batch/{qr_token}")
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    buffer = io.BytesIO()
    img.save(buffer, format="PNG")
    return buffer.getvalue()
