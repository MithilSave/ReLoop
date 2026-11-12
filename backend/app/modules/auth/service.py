"""Authentication and membership business logic service."""

import hashlib
import uuid
from datetime import datetime, timezone, timedelta
from typing import Optional, Tuple
from fastapi import HTTPException, status
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password, verify_password, create_access_token, create_refresh_token, decode_access_token
from app.models.identity import User, Organisation, OrgMembership, RefreshToken
from app.models.profiles import (
    GeneratorProfile,
    CollectorProfile,
    RecyclerProfile,
    NGOProfile,
    EPRClientProfile,
)
from app.modules.auth.schemas import RegisterRequest, LoginRequest, SwitchOrgRequest


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


async def register_user(db: AsyncSession, req: RegisterRequest) -> Tuple[User, Organisation, str, str]:
    if not req.email and not req.phone:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": {"code": "VALIDATION_ERROR", "message": "Email or phone must be provided"}},
        )

    # Check existing user
    stmt = select(User).where(
        or_(
            User.email == str(req.email) if req.email else False,
            User.phone == req.phone if req.phone else False,
        )
    )
    res = await db.execute(stmt)
    if res.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"error": {"code": "USER_ALREADY_EXISTS", "message": "A user with this email or phone already exists"}},
        )

    # Create user
    user = User(
        full_name=req.full_name,
        email=str(req.email) if req.email else None,
        phone=req.phone,
        password_hash=hash_password(req.password),
        status="ACTIVE",
    )
    db.add(user)
    await db.flush()

    # Create organisation: GENERATOR orgs are auto-approved; others start PENDING
    org_type = req.org.org_type.upper()
    initial_status = "APPROVED" if org_type == "GENERATOR" else "PENDING"

    org = Organisation(
        org_type=org_type,
        legal_name=req.org.legal_name,
        display_name=req.org.display_name or req.org.legal_name,
        city_id=req.org.city_id,
        address=req.org.address,
        lat=req.org.lat,
        lng=req.org.lng,
        gstin=req.org.gstin,
        approval_status=initial_status,
    )
    db.add(org)
    await db.flush()

    # Create default type-specific profile
    if org_type == "GENERATOR":
        db.add(GeneratorProfile(org_id=org.id, generator_kind="COMMERCIAL"))
    elif org_type == "COLLECTOR":
        db.add(CollectorProfile(org_id=org.id, service_radius_km=25.0, daily_capacity_kg=2000.0, min_pickup_kg=50.0))
    elif org_type == "RECYCLER":
        db.add(RecyclerProfile(org_id=org.id, processing_type="RECYCLING", monthly_capacity_kg=50000.0))
    elif org_type == "NGO":
        db.add(NGOProfile(org_id=org.id, registration_type="Section 8"))
    elif org_type == "EPR_CLIENT":
        db.add(EPRClientProfile(org_id=org.id, pibo_type="BRAND_OWNER"))

    # Add user as OWNER of this org
    membership = OrgMembership(
        user_id=user.id,
        org_id=org.id,
        org_role="OWNER",
    )
    db.add(membership)
    await db.flush()

    # Generate tokens
    access_token = create_access_token({"sub": str(user.id), "org_id": str(org.id), "role": "OWNER", "org_type": org_type})
    refresh_token = create_refresh_token({"sub": str(user.id)})

    # Record refresh token
    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=hash_token(refresh_token),
            expires_at=datetime.now(timezone.utc) + timedelta(days=30),
        )
    )
    await db.commit()

    return user, org, access_token, refresh_token


async def authenticate_user(db: AsyncSession, req: LoginRequest) -> Tuple[User, Optional[Organisation], Optional[str], str, str]:
    stmt = select(User).where(
        or_(
            User.email == req.login,
            User.phone == req.login,
        )
    )
    res = await db.execute(stmt)
    user = res.scalar_one_or_none()

    if not user or not verify_password(req.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "UNAUTHENTICATED", "message": "Invalid email/phone or password"}},
        )

    if user.status != "ACTIVE":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "USER_SUSPENDED", "message": "User account is suspended"}},
        )

    # Get active or primary membership
    mem_stmt = select(OrgMembership, Organisation).join(Organisation, OrgMembership.org_id == Organisation.id).where(OrgMembership.user_id == user.id)
    mem_res = await db.execute(mem_stmt)
    first_row = mem_res.first()

    org = None
    role = None
    if first_row:
        membership, org = first_row
        role = membership.org_role

    access_token = create_access_token({
        "sub": str(user.id),
        "org_id": str(org.id) if org else None,
        "role": role,
        "org_type": org.org_type if org else None,
    })
    refresh_token = create_refresh_token({"sub": str(user.id)})

    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=hash_token(refresh_token),
            expires_at=datetime.now(timezone.utc) + timedelta(days=30),
        )
    )
    await db.commit()

    return user, org, role, access_token, refresh_token


async def switch_active_org(db: AsyncSession, user_id: uuid.UUID, org_id: uuid.UUID) -> Tuple[Organisation, str, str]:
    stmt = select(OrgMembership, Organisation).join(Organisation, OrgMembership.org_id == Organisation.id).where(
        OrgMembership.user_id == user_id,
        OrgMembership.org_id == org_id,
    )
    res = await db.execute(stmt)
    row = res.first()
    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "NOT_FOUND", "message": "Organisation membership not found"}},
        )

    membership, org = row
    access_token = create_access_token({
        "sub": str(user_id),
        "org_id": str(org.id),
        "role": membership.org_role,
        "org_type": org.org_type,
    })
    refresh_token = create_refresh_token({"sub": str(user_id)})

    db.add(
        RefreshToken(
            user_id=user_id,
            token_hash=hash_token(refresh_token),
            expires_at=datetime.now(timezone.utc) + timedelta(days=30),
        )
    )
    await db.commit()

    return org, access_token, refresh_token


async def refresh_tokens(db: AsyncSession, refresh_token_raw: str) -> Tuple[User, Optional[Organisation], Optional[str], str, str]:
    try:
        payload = decode_access_token(refresh_token_raw)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "UNAUTHENTICATED", "message": "Invalid refresh token"}},
        )

    user_id = uuid.UUID(payload.get("sub"))
    token_h = hash_token(refresh_token_raw)

    stmt = select(RefreshToken).where(
        RefreshToken.user_id == user_id,
        RefreshToken.token_hash == token_h,
        RefreshToken.revoked_at.is_(None),
    )
    res = await db.execute(stmt)
    record = res.scalar_one_or_none()

    if not record or record.expires_at < datetime.now(timezone.utc):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "UNAUTHENTICATED", "message": "Refresh token expired or revoked"}},
        )

    # Revoke old refresh token (token rotation)
    record.revoked_at = datetime.now(timezone.utc)

    user = await db.get(User, user_id)
    if not user or user.status != "ACTIVE":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "UNAUTHENTICATED", "message": "User not active"}},
        )

    mem_stmt = select(OrgMembership, Organisation).join(Organisation, OrgMembership.org_id == Organisation.id).where(OrgMembership.user_id == user.id)
    mem_res = await db.execute(mem_stmt)
    first_row = mem_res.first()

    org = None
    role = None
    if first_row:
        membership, org = first_row
        role = membership.org_role

    new_access_token = create_access_token({
        "sub": str(user.id),
        "org_id": str(org.id) if org else None,
        "role": role,
        "org_type": org.org_type if org else None,
    })
    new_refresh_token = create_refresh_token({"sub": str(user.id)})

    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=hash_token(new_refresh_token),
            expires_at=datetime.now(timezone.utc) + timedelta(days=30),
        )
    )
    await db.commit()

    return user, org, role, new_access_token, new_refresh_token
