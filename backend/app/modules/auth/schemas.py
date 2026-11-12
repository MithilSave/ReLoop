"""Auth module Pydantic schemas."""

import uuid
from typing import List, Optional
from pydantic import BaseModel, EmailStr


class OrgRegisterInput(BaseModel):
    org_type: str  # GENERATOR, COLLECTOR, RECYCLER, NGO, EPR_CLIENT
    legal_name: str
    display_name: Optional[str] = None
    city_id: str = "MUM"
    address: str
    lat: Optional[float] = None
    lng: Optional[float] = None
    gstin: Optional[str] = None


class RegisterRequest(BaseModel):
    full_name: str
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    password: str
    org: OrgRegisterInput


class LoginRequest(BaseModel):
    login: str  # email or phone
    password: str


class SwitchOrgRequest(BaseModel):
    org_id: uuid.UUID


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class UserOut(BaseModel):
    id: uuid.UUID
    full_name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    is_platform_admin: bool
    status: str

    class Config:
        from_attributes = True


class OrgOut(BaseModel):
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

    class Config:
        from_attributes = True


class MembershipOut(BaseModel):
    org_id: uuid.UUID
    org_name: str
    org_type: str
    org_role: str
    approval_status: str


class AuthResponse(BaseModel):
    user: UserOut
    org: Optional[OrgOut] = None
    role: Optional[str] = None
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class MeResponse(BaseModel):
    user: UserOut
    active_org: Optional[OrgOut] = None
    active_role: Optional[str] = None
    memberships: List[MembershipOut] = []
