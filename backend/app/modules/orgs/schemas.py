"""Organisation schemas."""

import uuid
from typing import Any, Dict, List, Optional
from pydantic import BaseModel


class OrgUpdateInput(BaseModel):
    display_name: Optional[str] = None
    address: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    gstin: Optional[str] = None
    profile_data: Optional[Dict[str, Any]] = None


class AddMemberInput(BaseModel):
    email_or_phone: str
    org_role: str = "MEMBER"  # OWNER, ADMIN, MEMBER, VIEWER


class ApproveOrgInput(BaseModel):
    decision: str  # APPROVED, REJECTED, SUSPENDED
    note: Optional[str] = None


class OrgProfileDetailOut(BaseModel):
    id: uuid.UUID
    org_type: str
    legal_name: str
    display_name: Optional[str] = None
    city_id: str
    address: str
    lat: Optional[float] = None
    lng: Optional[float] = None
    gstin: Optional[str] = None
    approval_status: str
    profile: Optional[Dict[str, Any]] = None

    class Config:
        from_attributes = True
