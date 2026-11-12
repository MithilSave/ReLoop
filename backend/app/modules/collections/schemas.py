"""Collections schemas."""

import uuid
from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class CollectionOfferInput(BaseModel):
    generator_rate_per_kg: float = Field(..., gt=0)
    proposed_pickup_at: datetime


class CollectionOfferOut(BaseModel):
    id: uuid.UUID
    batch_id: uuid.UUID
    collector_org_id: uuid.UUID
    collector_name: Optional[str] = None
    generator_rate_per_kg: float
    proposed_pickup_at: datetime
    status: str
    expires_at: datetime
    created_at: datetime

    class Config:
        from_attributes = True


class PickupInput(BaseModel):
    collected_kg: float = Field(..., gt=0)
    document_ids: Optional[List[uuid.UUID]] = []
    notes: Optional[str] = None


class HandoverConfirmInput(BaseModel):
    otp: Optional[str] = None
    qr_token: Optional[str] = None
