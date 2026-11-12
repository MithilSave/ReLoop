"""Transport consignments API router."""

import uuid
from datetime import datetime, timezone
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.permissions import require, AuthContext
from app.models.batches import WasteBatch, BatchEvent
from app.models.intelligence import TransportConsignment, ConsignmentItem
from app.models.identity import Organisation
from app.modules.consignments.schemas import ConsignmentCreateInput, ConsignmentOut, ConsignmentItemOut

router = APIRouter(prefix="/consignments", tags=["consignments"])


def utcnow():
    return datetime.now(timezone.utc)


@router.post("", response_model=ConsignmentOut, status_code=status.HTTP_201_CREATED)
async def create_consignment(
    input_data: ConsignmentCreateInput,
    context: AuthContext = Depends(require("COLLECTOR")),
    db: AsyncSession = Depends(get_db),
):
    if not input_data.batch_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": {"code": "VALIDATION_ERROR", "message": "At least one batch must be included"}},
        )

    # Verify destination recycler
    rec_org = await db.get(Organisation, input_data.destination_recycler_org_id)
    if not rec_org or rec_org.org_type != "RECYCLER":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "NOT_FOUND", "message": "Destination recycler organisation not found"}},
        )

    # Verify and transition batches
    batches_to_consign = []
    for b_id in input_data.batch_ids:
        batch = await db.get(WasteBatch, b_id)
        if not batch:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": {"code": "NOT_FOUND", "message": f"Batch {b_id} not found"}},
            )
        if batch.assigned_collector_org_id != context.org_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "FORBIDDEN_ORG", "message": f"Batch {batch.batch_code} not assigned to you"}},
            )
        if batch.status != "PICKED_UP":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={"error": {"code": "INVALID_STATE_TRANSITION", "message": f"Batch {batch.batch_code} must be PICKED_UP (currently {batch.status})"}},
            )
        batches_to_consign.append(batch)

    # Generate consignment code
    year = utcnow().year
    count_stmt = select(TransportConsignment)
    res = await db.execute(count_stmt)
    total_consignments = len(res.scalars().all()) + 1
    code = f"TC-MUM-{year}-{total_consignments:05d}"

    consignment = TransportConsignment(
        consignment_code=code,
        collector_org_id=context.org_id,
        destination_recycler_org_id=input_data.destination_recycler_org_id,
        aggregation_plan_id=input_data.aggregation_plan_id,
        vehicle_no=input_data.vehicle_no,
        dispatched_at=utcnow(),
        status="IN_TRANSIT",
    )
    db.add(consignment)
    await db.flush()

    items_out = []
    for b in batches_to_consign:
        item = ConsignmentItem(consignment_id=consignment.id, batch_id=b.id)
        db.add(item)
        b.status = "IN_TRANSIT"
        b.destination_recycler_org_id = input_data.destination_recycler_org_id

        event = BatchEvent(
            batch_id=b.id,
            event_type="DISPATCHED",
            from_status="PICKED_UP",
            to_status="IN_TRANSIT",
            actor_user_id=context.user_id,
            actor_org_id=context.org_id,
            payload={"consignment_code": consignment.consignment_code, "vehicle_no": input_data.vehicle_no},
        )
        db.add(event)

        items_out.append(
            ConsignmentItemOut(
                batch_id=b.id,
                batch_code=b.batch_code,
                status=b.status,
                estimated_kg=b.estimated_kg,
            )
        )

    await db.commit()
    return ConsignmentOut(
        id=consignment.id,
        consignment_code=consignment.consignment_code,
        collector_org_id=consignment.collector_org_id,
        destination_recycler_org_id=consignment.destination_recycler_org_id,
        vehicle_no=consignment.vehicle_no,
        dispatched_at=consignment.dispatched_at,
        arrived_at=consignment.arrived_at,
        status=consignment.status,
        items=items_out,
    )


@router.get("", response_model=List[ConsignmentOut])
async def list_consignments(
    context: AuthContext = Depends(require("COLLECTOR", "RECYCLER")),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(TransportConsignment).order_by(desc(TransportConsignment.created_at))
    if not context.is_admin:
        if context.org_type == "COLLECTOR":
            stmt = stmt.where(TransportConsignment.collector_org_id == context.org_id)
        elif context.org_type == "RECYCLER":
            stmt = stmt.where(TransportConsignment.destination_recycler_org_id == context.org_id)

    res = await db.execute(stmt)
    consignments = res.scalars().all()

    output = []
    for c in consignments:
        items_stmt = select(ConsignmentItem, WasteBatch).join(
            WasteBatch, ConsignmentItem.batch_id == WasteBatch.id
        ).where(ConsignmentItem.consignment_id == c.id)
        items_res = await db.execute(items_stmt)
        items_out = [
            ConsignmentItemOut(
                batch_id=b.id,
                batch_code=b.batch_code,
                status=b.status,
                estimated_kg=b.estimated_kg,
            )
            for item, b in items_res.all()
        ]
        output.append(
            ConsignmentOut(
                id=c.id,
                consignment_code=c.consignment_code,
                collector_org_id=c.collector_org_id,
                destination_recycler_org_id=c.destination_recycler_org_id,
                vehicle_no=c.vehicle_no,
                dispatched_at=c.dispatched_at,
                arrived_at=c.arrived_at,
                status=c.status,
                items=items_out,
            )
        )
    return output


@router.get("/{id}", response_model=ConsignmentOut)
async def get_consignment(
    id: uuid.UUID,
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    c = await db.get(TransportConsignment, id)
    if not c:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Consignment not found"}})

    items_stmt = select(ConsignmentItem, WasteBatch).join(
        WasteBatch, ConsignmentItem.batch_id == WasteBatch.id
    ).where(ConsignmentItem.consignment_id == c.id)
    items_res = await db.execute(items_stmt)
    items_out = [
        ConsignmentItemOut(
            batch_id=b.id,
            batch_code=b.batch_code,
            status=b.status,
            estimated_kg=b.estimated_kg,
        )
        for item, b in items_res.all()
    ]

    return ConsignmentOut(
        id=c.id,
        consignment_code=c.consignment_code,
        collector_org_id=c.collector_org_id,
        destination_recycler_org_id=c.destination_recycler_org_id,
        vehicle_no=c.vehicle_no,
        dispatched_at=c.dispatched_at,
        arrived_at=c.arrived_at,
        status=c.status,
        items=items_out,
    )


@router.post("/{id}/arrive")
async def mark_consignment_arrived(
    id: uuid.UUID,
    context: AuthContext = Depends(require("RECYCLER")),
    db: AsyncSession = Depends(get_db),
):
    c = await db.get(TransportConsignment, id)
    if not c:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Consignment not found"}})
    if c.destination_recycler_org_id != context.org_id and not context.is_admin:
        raise HTTPException(status_code=403, detail={"error": {"code": "FORBIDDEN_ORG", "message": "Not destination recycler"}})

    c.status = "ARRIVED"
    c.arrived_at = utcnow()
    await db.commit()
    return {"status": "ok", "consignment_status": "ARRIVED", "arrived_at": c.arrived_at}
