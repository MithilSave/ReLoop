"""Batches API router."""

import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import select, or_, and_, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.permissions import get_current_user_and_context, require, AuthContext
from app.models.batches import WasteBatch, BatchEvent
from app.models.reference import MaterialCategory
from app.models.identity import Organisation
from app.modules.batches.schemas import (
    BatchCreateInput,
    BatchUpdateInput,
    BatchDetailOut,
    BatchEventOut,
)
from app.modules.batches.service import (
    create_batch,
    calculate_batch_quantities,
    get_batch_verification_summary,
    generate_qr_image_bytes,
)

router = APIRouter(prefix="/batches", tags=["batches"])


async def _resolve_batch(db: AsyncSession, id_or_code: str) -> WasteBatch:
    batch = None
    try:
        b_uuid = uuid.UUID(id_or_code)
        batch = await db.get(WasteBatch, b_uuid)
    except ValueError:
        pass

    if not batch:
        stmt = select(WasteBatch).where(WasteBatch.batch_code == id_or_code)
        res = await db.execute(stmt)
        batch = res.scalar_one_or_none()

    if not batch:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "NOT_FOUND", "message": f"Batch '{id_or_code}' not found"}},
        )
    return batch


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_new_batch(
    input_data: BatchCreateInput,
    context: AuthContext = Depends(require("GENERATOR")),
    db: AsyncSession = Depends(get_db),
):
    batch = await create_batch(db, context.org_id, context.user_id, input_data)
    return {
        "id": str(batch.id),
        "batch_code": batch.batch_code,
        "qr_token": batch.qr_token,
        "status": batch.status,
        "qr_url": f"/api/v1/batches/{batch.id}/qr",
    }


@router.get("", response_model=List[BatchDetailOut])
async def list_batches(
    status_filter: Optional[str] = Query(None, alias="status"),
    material: Optional[str] = Query(None),
    locality: Optional[str] = Query(None),
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(WasteBatch).order_by(desc(WasteBatch.created_at))

    # Role scoping
    if not context.is_admin:
        if context.org_type == "GENERATOR":
            stmt = stmt.where(WasteBatch.generator_org_id == context.org_id)
        elif context.org_type == "COLLECTOR":
            stmt = stmt.where(
                or_(
                    WasteBatch.assigned_collector_org_id == context.org_id,
                    WasteBatch.status == "LISTED",
                )
            )
        elif context.org_type == "RECYCLER":
            stmt = stmt.where(
                or_(
                    WasteBatch.destination_recycler_org_id == context.org_id,
                    WasteBatch.status.in_(["IN_TRANSIT", "RECEIVED", "PROCESSED"]),
                )
            )

    if status_filter:
        stmt = stmt.where(WasteBatch.status == status_filter.upper())
    if locality:
        stmt = stmt.where(WasteBatch.locality.ilike(f"%{locality}%"))

    res = await db.execute(stmt)
    batches = res.scalars().all()

    output = []
    for b in batches:
        # Match material filter if given
        mat = await db.get(MaterialCategory, b.material_category_id)
        if material and mat and mat.code.upper() != material.upper():
            continue

        gen_org = await db.get(Organisation, b.generator_org_id)
        col_org = await db.get(Organisation, b.assigned_collector_org_id) if b.assigned_collector_org_id else None
        rec_org = await db.get(Organisation, b.destination_recycler_org_id) if b.destination_recycler_org_id else None

        quantities = await calculate_batch_quantities(db, b)
        verification = await get_batch_verification_summary(db, b.id)

        output.append(
            BatchDetailOut(
                id=b.id,
                batch_code=b.batch_code,
                qr_token=b.qr_token,
                status=b.status,
                material=mat.code if mat else "OTHER",
                material_name=mat.name if mat else None,
                generator_org_id=b.generator_org_id,
                generator_name=gen_org.legal_name if gen_org else None,
                pickup_address=b.pickup_address,
                locality=b.locality,
                lat=b.lat,
                lng=b.lng,
                available_from=b.available_from,
                available_to=b.available_to,
                assigned_collector_org_id=b.assigned_collector_org_id,
                assigned_collector_name=col_org.legal_name if col_org else None,
                destination_recycler_org_id=b.destination_recycler_org_id,
                destination_recycler_name=rec_org.legal_name if rec_org else None,
                quantities=quantities,
                verification=verification,
                created_at=b.created_at,
            )
        )
    return output


@router.get("/{id_or_code}", response_model=BatchDetailOut)
async def get_batch_by_id_or_code(
    id_or_code: str,
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    b = await _resolve_batch(db, id_or_code)
    mat = await db.get(MaterialCategory, b.material_category_id)
    gen_org = await db.get(Organisation, b.generator_org_id)
    col_org = await db.get(Organisation, b.assigned_collector_org_id) if b.assigned_collector_org_id else None
    rec_org = await db.get(Organisation, b.destination_recycler_org_id) if b.destination_recycler_org_id else None

    quantities = await calculate_batch_quantities(db, b)
    verification = await get_batch_verification_summary(db, b.id)

    return BatchDetailOut(
        id=b.id,
        batch_code=b.batch_code,
        qr_token=b.qr_token,
        status=b.status,
        material=mat.code if mat else "OTHER",
        material_name=mat.name if mat else None,
        generator_org_id=b.generator_org_id,
        generator_name=gen_org.legal_name if gen_org else None,
        pickup_address=b.pickup_address,
        locality=b.locality,
        lat=b.lat,
        lng=b.lng,
        available_from=b.available_from,
        available_to=b.available_to,
        assigned_collector_org_id=b.assigned_collector_org_id,
        assigned_collector_name=col_org.legal_name if col_org else None,
        destination_recycler_org_id=b.destination_recycler_org_id,
        destination_recycler_name=rec_org.legal_name if rec_org else None,
        quantities=quantities,
        verification=verification,
        created_at=b.created_at,
    )


@router.patch("/{id}")
async def patch_batch(
    id: uuid.UUID,
    req: BatchUpdateInput,
    context: AuthContext = Depends(require("GENERATOR")),
    db: AsyncSession = Depends(get_db),
):
    b = await db.get(WasteBatch, id)
    if not b:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Batch not found"}})
    if b.generator_org_id != context.org_id and not context.is_admin:
        raise HTTPException(status_code=403, detail={"error": {"code": "FORBIDDEN_ORG", "message": "Not owner"}})
    if b.status != "LISTED":
        raise HTTPException(
            status_code=409,
            detail={"error": {"code": "INVALID_STATE_TRANSITION", "message": f"Cannot edit batch in status {b.status}"}},
        )

    if req.estimated_kg is not None:
        b.estimated_kg = req.estimated_kg
    if req.pickup_address is not None:
        b.pickup_address = req.pickup_address
    if req.lat is not None:
        b.lat = req.lat
    if req.lng is not None:
        b.lng = req.lng
    if req.locality is not None:
        b.locality = req.locality
    if req.available_from is not None:
        b.available_from = req.available_from
    if req.available_to is not None:
        b.available_to = req.available_to

    await db.commit()
    return {"status": "ok", "message": "Batch updated"}


@router.post("/{id}/cancel")
async def cancel_batch(
    id: uuid.UUID,
    context: AuthContext = Depends(require("GENERATOR")),
    db: AsyncSession = Depends(get_db),
):
    b = await db.get(WasteBatch, id)
    if not b:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Batch not found"}})
    if b.generator_org_id != context.org_id and not context.is_admin:
        raise HTTPException(status_code=403, detail={"error": {"code": "FORBIDDEN_ORG", "message": "Not owner"}})
    if b.status not in ["LISTED", "ASSIGNED"]:
        raise HTTPException(
            status_code=409,
            detail={"error": {"code": "INVALID_STATE_TRANSITION", "message": f"Cannot cancel batch in status {b.status}"}},
        )

    old_status = b.status
    b.status = "CANCELLED"

    event = BatchEvent(
        batch_id=b.id,
        event_type="CANCELLED",
        from_status=old_status,
        to_status="CANCELLED",
        actor_user_id=context.user_id,
        actor_org_id=context.org_id,
        payload={"reason": "Cancelled by generator"},
    )
    db.add(event)
    await db.commit()
    return {"status": "ok", "batch_code": b.batch_code, "new_status": "CANCELLED"}


@router.get("/{id}/qr")
async def get_batch_qr(
    id: uuid.UUID,
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    b = await db.get(WasteBatch, id)
    if not b:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Batch not found"}})

    img_bytes = generate_qr_image_bytes(b.qr_token)
    return Response(content=img_bytes, media_type="image/png")


@router.get("/{id}/events", response_model=List[BatchEventOut])
async def get_batch_events(
    id: uuid.UUID,
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(BatchEvent).where(BatchEvent.batch_id == id).order_by(BatchEvent.id.asc())
    res = await db.execute(stmt)
    return res.scalars().all()


@router.get("/{id}/trace")
async def get_batch_trace(
    id: uuid.UUID,
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    b = await db.get(WasteBatch, id)
    if not b:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Batch not found"}})

    # Gather custody trace
    from app.models.custody import PickupRecord, RecyclerReceipt, ProcessingInput, ProcessingRecord
    from app.models.allocations import Certificate, EPRAllocation

    p_stmt = select(PickupRecord).where(PickupRecord.batch_id == b.id, PickupRecord.is_current.is_(True))
    p_res = await db.execute(p_stmt)
    pickup = p_res.scalar_one_or_none()

    r_stmt = select(RecyclerReceipt).where(RecyclerReceipt.batch_id == b.id, RecyclerReceipt.is_current.is_(True))
    r_res = await db.execute(r_stmt)
    receipt = r_res.scalar_one_or_none()

    inputs_stmt = select(ProcessingInput, ProcessingRecord).join(
        ProcessingRecord, ProcessingInput.processing_record_id == ProcessingRecord.id
    ).where(ProcessingInput.batch_id == b.id, ProcessingRecord.is_current.is_(True))
    inputs_res = await db.execute(inputs_stmt)
    runs = inputs_res.all()

    processing_info = []
    for inp, rec in runs:
        processing_info.append({
            "record_code": rec.record_code,
            "run_started_at": rec.run_started_at,
            "input_kg": inp.input_kg,
            "apportioned_output_kg": inp.apportioned_output_kg,
            "yield_pct": rec.yield_pct,
            "measurement_status": rec.measurement_status,
        })

    return {
        "batch_id": b.id,
        "batch_code": b.batch_code,
        "status": b.status,
        "pickup": {
            "collected_kg": pickup.collected_kg,
            "confirmed_at": pickup.confirmed_at,
            "handover_method": pickup.handover_method,
        } if pickup else None,
        "receipt": {
            "received_kg": receipt.received_kg,
            "accepted_kg": receipt.accepted_kg,
            "rejected_kg": receipt.rejected_kg,
            "quality_grade": receipt.quality_grade,
        } if receipt else None,
        "processing_runs": processing_info,
    }
