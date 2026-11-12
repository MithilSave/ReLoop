"""NGO module schemas."""

import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel


class NGODecisionInput(BaseModel):
    decision: str  # VERIFIED, FLAGGED, REJECTED, REQUIRES_CORRECTION
    comments: Optional[str] = None
    evidence_doc_ids: Optional[List[uuid.UUID]] = []
    follow_up_required: Optional[str] = None


class DocumentRequestInput(BaseModel):
    addressed_to_org_id: uuid.UUID
    request_text: str


class NGOVerificationOut(BaseModel):
    id: uuid.UUID
    batch_id: uuid.UUID
    batch_code: str
    ngo_org_id: uuid.UUID
    reviewer_user_id: Optional[uuid.UUID] = None
    decision: str
    reviewed_record_versions: Dict[str, Any] = {}
    evidence_doc_ids: List[uuid.UUID] = []
    comments: Optional[str] = None
    follow_up_required: Optional[str] = None
    is_current: bool
    created_at: datetime

    class Config:
        from_attributes = True
