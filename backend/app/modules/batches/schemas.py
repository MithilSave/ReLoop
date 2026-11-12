"""Batches schemas."""

import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class BatchCreateInput(BaseModel):
    material_code: str
    estimated_kg: float = Field(..., gt=0)
    pickup_address: str
    lat: Optional[float] = None
    lng: Optional[float] = None
    locality: Optional[str] = None
    available_from: datetime
    available_to: datetime
    document_ids: Optional[List[uuid.UUID]] = []
    ai_prediction_id: Optional[uuid.UUID] = None


class BatchUpdateInput(BaseModel):
    estimated_kg: Optional[float] = Field(None, gt=0)
    pickup_address: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    locality: Optional[str] = None
    available_from: Optional[datetime] = None
    available_to: Optional[datetime] = None


class BatchQuantities(BaseModel):
    estimated_kg: str
    collected_kg: Optional[str] = None
    received_kg: Optional[str] = None
    accepted_kg: Optional[str] = None
    rejected_kg: Optional[str] = None
    processed_kg: Optional[str] = None
    ngo_verified_kg: Optional[str] = None
    epr_allocated_kg: Optional[str] = None


class VerificationSummary(BaseModel):
    decision: str
    ngo: Optional[str] = None
    at: Optional[datetime] = None
    comments: Optional[str] = None


class BatchDetailOut(BaseModel):
    id: uuid.UUID
    batch_code: str
    qr_token: str
    status: str
    material: str
    material_name: Optional[str] = None
    generator_org_id: uuid.UUID
    generator_name: Optional[str] = None
    pickup_address: str
    locality: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    available_from: datetime
    available_to: datetime
    assigned_collector_org_id: Optional[uuid.UUID] = None
    assigned_collector_name: Optional[str] = None
    destination_recycler_org_id: Optional[uuid.UUID] = None
    destination_recycler_name: Optional[str] = None
    quantities: BatchQuantities
    verification: Optional[VerificationSummary] = None
    created_at: datetime

    class Config:
        from_attributes = True


class BatchEventOut(BaseModel):
    id: int
    batch_id: uuid.UUID
    event_type: str
    from_status: Optional[str] = None
    to_status: Optional[str] = None
    actor_user_id: Optional[uuid.UUID] = None
    actor_org_id: Optional[uuid.UUID] = None
    payload: Dict[str, Any]
    created_at: datetime

    class Config:
        from_attributes = True
