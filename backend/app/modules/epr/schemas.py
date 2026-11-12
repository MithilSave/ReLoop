"""EPR module schemas."""

import uuid
from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class EPRTargetInput(BaseModel):
    reporting_period: str  # e.g. FY2026-27
    packaging_category: str  # CAT_I, CAT_II, CAT_III, CAT_IV
    target_kg: float = Field(..., gt=0)
    source_note: Optional[str] = None


class EPRTargetOut(BaseModel):
    id: uuid.UUID
    epr_org_id: uuid.UUID
    reporting_period: str
    packaging_category: str
    target_kg: float
    source_note: Optional[str] = None

    class Config:
        from_attributes = True


class AllocationCreateInput(BaseModel):
    processing_record_id: uuid.UUID
    epr_org_id: uuid.UUID
    certificate_id: Optional[uuid.UUID] = None
    packaging_category: str
    reporting_period: str
    quantity_kg: float = Field(..., gt=0)
    request_id: Optional[uuid.UUID] = None


class AllocationReverseInput(BaseModel):
    reason: str


class AllocationRequestInput(BaseModel):
    recycler_org_id: uuid.UUID
    packaging_category: str
    reporting_period: str
    quantity_kg: float = Field(..., gt=0)
    note: Optional[str] = None


class AllocationOut(BaseModel):
    id: uuid.UUID
    processing_record_id: uuid.UUID
    epr_org_id: uuid.UUID
    certificate_id: Optional[uuid.UUID] = None
    packaging_category: str
    reporting_period: str
    quantity_kg: float
    status: str
    reverses_allocation_id: Optional[uuid.UUID] = None
    reason: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class EPRReportCreateInput(BaseModel):
    period: str
    format: str = "pdf"  # pdf, csv
