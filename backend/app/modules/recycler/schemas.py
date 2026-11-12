"""Recycler module schemas."""

import uuid
from datetime import date, datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class RecyclerOfferCreate(BaseModel):
    material_code: str
    price_per_kg: float = Field(..., gt=0)
    min_kg: float = Field(100.0, gt=0)
    quality_spec: Optional[str] = None
    max_contamination_pct: float = Field(5.0, ge=0, le=100)
    valid_from: Optional[datetime] = None
    valid_to: datetime


class RecyclerOfferOut(BaseModel):
    id: uuid.UUID
    recycler_org_id: uuid.UUID
    material_code: str
    price_per_kg: float
    min_kg: float
    quality_spec: Optional[str] = None
    max_contamination_pct: float
    valid_from: datetime
    valid_to: datetime
    is_active: bool

    class Config:
        from_attributes = True


class RecyclerReceiptInput(BaseModel):
    batch_id: Optional[uuid.UUID] = None
    qr_token: Optional[str] = None
    received_kg: float = Field(..., ge=0)
    accepted_kg: float = Field(..., ge=0)
    rejected_kg: float = Field(0.0, ge=0)
    quality_grade: str = "A"  # A, B, C
    contamination_pct: float = Field(0.0, ge=0, le=100)
    rejection_disposition: Optional[str] = None
    document_ids: Optional[List[uuid.UUID]] = []


class RecyclerReceiptCorrectionInput(BaseModel):
    received_kg: float = Field(..., ge=0)
    accepted_kg: float = Field(..., ge=0)
    rejected_kg: float = Field(0.0, ge=0)
    quality_grade: str = "A"
    contamination_pct: float = Field(0.0, ge=0, le=100)
    reason: str


class ProcessingInputItem(BaseModel):
    recycler_receipt_id: uuid.UUID
    input_kg: float = Field(..., gt=0)


class ProcessingRecordCreate(BaseModel):
    material_code: str
    run_started_at: datetime
    run_ended_at: datetime
    inputs: List[ProcessingInputItem]
    output_kg: float = Field(..., ge=0)
    residue_kg: float = Field(0.0, ge=0)
    output_form: Optional[str] = "flakes"
    eligible_kg: float = Field(..., ge=0)
    eligibility_basis: Optional[str] = None
    document_ids: Optional[List[uuid.UUID]] = []


class CertificateCreate(BaseModel):
    certificate_ref: str
    packaging_category: str  # CAT_I, CAT_II, CAT_III, CAT_IV
    certificate_kg: float = Field(..., gt=0)
    issued_on: Optional[date] = None
    evidence_doc_id: Optional[uuid.UUID] = None
