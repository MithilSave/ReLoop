"""Consignments schemas."""

import uuid
from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel


class ConsignmentCreateInput(BaseModel):
    batch_ids: List[uuid.UUID]
    destination_recycler_org_id: uuid.UUID
    vehicle_no: Optional[str] = None
    aggregation_plan_id: Optional[uuid.UUID] = None


class ConsignmentItemOut(BaseModel):
    batch_id: uuid.UUID
    batch_code: str
    status: str
    estimated_kg: float


class ConsignmentOut(BaseModel):
    id: uuid.UUID
    consignment_code: str
    collector_org_id: uuid.UUID
    destination_recycler_org_id: uuid.UUID
    vehicle_no: Optional[str] = None
    dispatched_at: datetime
    arrived_at: Optional[datetime] = None
    status: str
    items: List[ConsignmentItemOut] = []

    class Config:
        from_attributes = True
