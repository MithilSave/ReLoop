"""Collections and pickup API router."""

import random
import uuid
from datetime import datetime, timezone, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, and_, or_, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.permissions import require, AuthContext
from app.core.audit import log_audit_event
from app.models.batches import WasteBatch, BatchEvent
from app.models.offers import CollectionOffer
from app.models.custody import PickupRecord
from app.models.identity import Organisation
from app.models.documents import DocumentLink
from app.models.audit import AnomalyFlag
from app.models.payments import Payment
from app.modules.collections.schemas import (
    CollectionOfferInput,
    CollectionOfferOut,
    PickupInput,
    HandoverConfirmInput,
)

router = APIRouter(tags=["collections"])


def utcnow():
    return datetime.now(timezone.utc)


@router.get("/collections/available")
async def list_available_collections(
    lat: Optional[float] = Query(None),
    lng: Optional[float] = Query(None),
    radius_km: Optional[float] = Query(25.0),
    context: AuthContext = Depends(require("COLLECTOR")),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(WasteBatch).where(WasteBatch.status == "LISTED").order_by(desc(WasteBatch.created_at))
    res = await db.execute(stmt)
    batches = res.scalars().all()

    results = []
    for b in batches:
        # Distance calculation
        dist = 0.0
        if lat and lng and b.lat and b.lng:
            # Haversine approximation
            dist = round(((lat - b.lat)**2 + (lng - b.lng)**2)**0.5 * 111, 2)
            if dist > radius_km:
                continue
        results.append({
            "id": b.id,
            "batch_code": b.batch_code,
            "material_category_id": b.material_category_id,
            "estimated_kg": b.estimated_kg,
            "pickup_address": b.pickup_address,
            "locality": b.locality,
            "lat": b.lat,
            "lng": b.lng,
            "distance_km": dist,
            "available_from": b.available_from,
            "available_to": b.available_to,
        })
    return results


@router.post("/collections/{batch_id}/offers", status_code=status.HTTP_201_CREATED)
async def create_collection_offer(
    batch_id: uuid.UUID,
    input_data: CollectionOfferInput,
    context: AuthContext = Depends(require("COLLECTOR")),
    db: AsyncSession = Depends(get_db),
):
    batch = await db.get(WasteBatch, batch_id)
    if not batch:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Batch not found"}})
    if batch.status != "LISTED":
        raise HTTPException(
            status_code=409,
            detail={"error": {"code": "INVALID_STATE_TRANSITION", "message": f"Batch is in {batch.status} status"}},
        )

    # Check for existing open offer
    stmt = select(CollectionOffer).where(
        CollectionOffer.batch_id == batch_id,
        CollectionOffer.collector_org_id == context.org_id,
        CollectionOffer.status == "OPEN",
    )
    res = await db.execute(stmt)
    if res.scalar_one_or_none():
        raise HTTPException(
            status_code=409,
            detail={"error": {"code": "DUPLICATE_OFFER", "message": "An open offer already exists for this batch"}},
        )

    offer = CollectionOffer(
        batch_id=batch_id,
        collector_org_id=context.org_id,
        generator_rate_per_kg=input_data.generator_rate_per_kg,
        proposed_pickup_at=input_data.proposed_pickup_at,
        status="OPEN",
        expires_at=utcnow() + timedelta(days=2),
    )
    db.add(offer)
    await db.commit()
    await db.refresh(offer)
    return {"status": "ok", "offer_id": offer.id}


@router.get("/batches/{batch_id}/offers", response_model=List[CollectionOfferOut])
async def list_batch_offers(
    batch_id: uuid.UUID,
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(CollectionOffer, Organisation).join(
        Organisation, CollectionOffer.collector_org_id == Organisation.id
    ).where(CollectionOffer.batch_id == batch_id).order_by(desc(CollectionOffer.generator_rate_per_kg))
    res = await db.execute(stmt)

    offers = []
    for off, org in res.all():
        offers.append(
            CollectionOfferOut(
                id=off.id,
                batch_id=off.batch_id,
                collector_org_id=off.collector_org_id,
                collector_name=org.legal_name,
                generator_rate_per_kg=off.generator_rate_per_kg,
                proposed_pickup_at=off.proposed_pickup_at,
                status=off.status,
                expires_at=off.expires_at,
                created_at=off.created_at,
            )
        )
    return offers


@router.post("/batches/{batch_id}/offers/{offer_id}/accept")
async def accept_collection_offer(
    batch_id: uuid.UUID,
    offer_id: uuid.UUID,
    context: AuthContext = Depends(require("GENERATOR")),
    db: AsyncSession = Depends(get_db),
):
    batch = await db.get(WasteBatch, batch_id)
    if not batch:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Batch not found"}})
    if batch.generator_org_id != context.org_id and not context.is_admin:
        raise HTTPException(status_code=403, detail={"error": {"code": "FORBIDDEN_ORG", "message": "Not owner"}})
    if batch.status != "LISTED":
        raise HTTPException(
            status_code=409,
            detail={"error": {"code": "OFFER_ALREADY_ACCEPTED", "message": f"Batch is already {batch.status}"}},
        )

    offer = await db.get(CollectionOffer, offer_id)
    if not offer or offer.batch_id != batch.id:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Offer not found"}})

    # Accept this offer, decline others
    offer.status = "ACCEPTED"
    batch.status = "ASSIGNED"
    batch.assigned_collector_org_id = offer.collector_org_id
    batch.accepted_offer_id = offer.id

    other_stmt = select(CollectionOffer).where(
        CollectionOffer.batch_id == batch_id,
        CollectionOffer.id != offer_id,
        CollectionOffer.status == "OPEN",
    )
    other_res = await db.execute(other_stmt)
    for other in other_res.scalars().all():
        other.status = "DECLINED"

    event = BatchEvent(
        batch_id=batch.id,
        event_type="OFFER_ACCEPTED",
        from_status="LISTED",
        to_status="ASSIGNED",
        actor_user_id=context.user_id,
        actor_org_id=context.org_id,
        payload={"offer_id": str(offer.id), "collector_org_id": str(offer.collector_org_id)},
    )
    db.add(event)
    await db.commit()
    return {"status": "ok", "batch_status": "ASSIGNED", "assigned_collector_org_id": batch.assigned_collector_org_id}


@router.post("/collections/{batch_id}/withdraw")
async def withdraw_collection(
    batch_id: uuid.UUID,
    context: AuthContext = Depends(require("COLLECTOR")),
    db: AsyncSession = Depends(get_db),
):
    batch = await db.get(WasteBatch, batch_id)
    if not batch or batch.assigned_collector_org_id != context.org_id:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Assigned batch not found"}})

    batch.status = "LISTED"
    batch.assigned_collector_org_id = None
    batch.accepted_offer_id = None

    event = BatchEvent(
        batch_id=batch.id,
        event_type="COLLECTOR_WITHDRAWN",
        from_status="ASSIGNED",
        to_status="LISTED",
        actor_user_id=context.user_id,
        actor_org_id=context.org_id,
        payload={"reason": "Collector withdrew from assignment"},
    )
    db.add(event)
    await db.commit()
    return {"status": "ok", "batch_status": "LISTED"}


@router.post("/collections/{batch_id}/pickup")
async def record_pickup(
    batch_id: uuid.UUID,
    input_data: PickupInput,
    context: AuthContext = Depends(require("COLLECTOR")),
    db: AsyncSession = Depends(get_db),
):
    batch = await db.get(WasteBatch, batch_id)
    if not batch:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Batch not found"}})
    if batch.assigned_collector_org_id != context.org_id and not context.is_admin:
        raise HTTPException(status_code=403, detail={"error": {"code": "FORBIDDEN_ORG", "message": "Not assigned collector"}})
    if batch.status != "ASSIGNED":
        raise HTTPException(
            status_code=409,
            detail={"error": {"code": "INVALID_STATE_TRANSITION", "message": f"Cannot pick up batch in status {batch.status}"}},
        )

    # Offer rate
    rate = 15.0  # default rate
    if batch.accepted_offer_id:
        off = await db.get(CollectionOffer, batch.accepted_offer_id)
        if off:
            rate = off.generator_rate_per_kg

    # Generate 6-digit OTP
    otp_code = f"{random.randint(100000, 999999)}"

    # Check discrepancy (> 120% of estimate)
    if input_data.collected_kg > 1.2 * batch.estimated_kg:
        anomaly = AnomalyFlag(
            rule_code="PICKUP_WEIGHT_EXCESS",
            severity="WARN",
            batch_id=batch.id,
            entity_type="pickup_record",
            entity_id=batch.id,
            details={
                "estimated_kg": batch.estimated_kg,
                "collected_kg": input_data.collected_kg,
                "pct": round((input_data.collected_kg / batch.estimated_kg) * 100, 1),
            },
            status="OPEN",
        )
        db.add(anomaly)

    pickup = PickupRecord(
        batch_id=batch.id,
        collector_org_id=context.org_id,
        collector_user_id=context.user_id,
        collected_kg=input_data.collected_kg,
        generator_rate_per_kg=rate,
        handover_method="OTP",
        otp_code=otp_code,
        notes=input_data.notes,
        is_current=True,
    )
    db.add(pickup)
    await db.flush()

    if input_data.document_ids:
        for doc_id in input_data.document_ids:
            db.add(DocumentLink(document_id=doc_id, entity_type="pickup_record", entity_id=pickup.id))

    await db.commit()
    return {
        "pickup_record_id": pickup.id,
        "otp_required": True,
        "otp": otp_code,  # Provided for demo/testing handover confirmation
        "message": "Pickup logged. Provide OTP to generator for handover confirmation.",
    }


@router.post("/batches/{batch_id}/handover/confirm")
async def confirm_handover(
    batch_id: uuid.UUID,
    input_data: HandoverConfirmInput,
    context: AuthContext = Depends(require("GENERATOR")),
    db: AsyncSession = Depends(get_db),
):
    batch = await db.get(WasteBatch, batch_id)
    if not batch:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Batch not found"}})
    if batch.generator_org_id != context.org_id and not context.is_admin:
        raise HTTPException(status_code=403, detail={"error": {"code": "FORBIDDEN_ORG", "message": "Not owner"}})

    stmt = select(PickupRecord).where(PickupRecord.batch_id == batch.id, PickupRecord.is_current.is_(True))
    res = await db.execute(stmt)
    pickup = res.scalar_one_or_none()
    if not pickup:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "No pickup record found"}})

    # Validate OTP or QR token
    valid = False
    if input_data.otp and pickup.otp_code == input_data.otp:
        valid = True
    elif input_data.qr_token and batch.qr_token == input_data.qr_token:
        valid = True

    if not valid:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"error": {"code": "OTP_INVALID", "message": "Invalid OTP code or QR token"}},
        )

    pickup.generator_confirmed_by_user_id = context.user_id
    pickup.confirmed_at = utcnow()
    batch.status = "PICKED_UP"

    event = BatchEvent(
        batch_id=batch.id,
        event_type="PICKED_UP",
        from_status="ASSIGNED",
        to_status="PICKED_UP",
        actor_user_id=context.user_id,
        actor_org_id=context.org_id,
        payload={"collected_kg": pickup.collected_kg, "rate": pickup.generator_rate_per_kg},
    )
    db.add(event)

    # Create simulated payment for generator payout
    amount = round(pickup.collected_kg * pickup.generator_rate_per_kg, 2)
    payment = Payment(
        batch_id=batch.id,
        payment_type="GENERATOR_PAYOUT",
        payer_org_id=pickup.collector_org_id,
        payee_org_id=batch.generator_org_id,
        quantity_kg=pickup.collected_kg,
        rate=pickup.generator_rate_per_kg,
        amount=amount,
        status="PENDING",
    )
    db.add(payment)

    await db.commit()
    return {
        "status": "ok",
        "batch_status": "PICKED_UP",
        "collected_kg": pickup.collected_kg,
        "payment_generated": amount,
    }


@router.get("/collections/jobs")
async def list_collector_jobs(
    status_filter: Optional[str] = Query(None, alias="status"),
    context: AuthContext = Depends(require("COLLECTOR")),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(WasteBatch).where(WasteBatch.assigned_collector_org_id == context.org_id).order_by(desc(WasteBatch.created_at))
    if status_filter:
        stmt = stmt.where(WasteBatch.status == status_filter.upper())

    res = await db.execute(stmt)
    batches = res.scalars().all()
    return [{
        "batch_id": b.id,
        "batch_code": b.batch_code,
        "status": b.status,
        "estimated_kg": b.estimated_kg,
        "pickup_address": b.pickup_address,
        "locality": b.locality,
        "created_at": b.created_at,
    } for b in batches]
