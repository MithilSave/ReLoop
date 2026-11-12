"""Organisations and admin approval router."""

import uuid
from typing import Any, Dict
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.permissions import get_current_user_and_context, require, AuthContext
from app.models.identity import Organisation, OrgMembership, User
from app.models.profiles import (
    GeneratorProfile,
    CollectorProfile,
    RecyclerProfile,
    NGOProfile,
    EPRClientProfile,
)
from app.modules.orgs.schemas import OrgUpdateInput, AddMemberInput, ApproveOrgInput, OrgProfileDetailOut

router = APIRouter(prefix="/orgs", tags=["organisations"])
admin_router = APIRouter(prefix="/admin/orgs", tags=["admin"])


async def _get_profile_dict(db: AsyncSession, org: Organisation) -> Dict[str, Any]:
    profile_dict = {}
    if org.org_type == "GENERATOR":
        p = await db.get(GeneratorProfile, org.id)
        if p:
            profile_dict = {"generator_kind": p.generator_kind, "payout_upi_ref_masked": p.payout_upi_ref_masked}
    elif org.org_type == "COLLECTOR":
        p = await db.get(CollectorProfile, org.id)
        if p:
            profile_dict = {
                "service_radius_km": p.service_radius_km,
                "daily_capacity_kg": p.daily_capacity_kg,
                "min_pickup_kg": p.min_pickup_kg,
                "vehicle_types": p.vehicle_types,
                "reliability_score": p.reliability_score,
            }
    elif org.org_type == "RECYCLER":
        p = await db.get(RecyclerProfile, org.id)
        if p:
            profile_dict = {
                "pwp_registration_no": p.pwp_registration_no,
                "registration_valid_until": str(p.registration_valid_until) if p.registration_valid_until else None,
                "spcb": p.spcb,
                "processing_type": p.processing_type,
                "monthly_capacity_kg": p.monthly_capacity_kg,
                "facility_address": p.facility_address,
            }
    elif org.org_type == "NGO":
        p = await db.get(NGOProfile, org.id)
        if p:
            profile_dict = {
                "registration_no": p.registration_no,
                "registration_type": p.registration_type,
                "agreement_valid_until": str(p.agreement_valid_until) if p.agreement_valid_until else None,
            }
    elif org.org_type == "EPR_CLIENT":
        p = await db.get(EPRClientProfile, org.id)
        if p:
            profile_dict = {
                "epr_registration_no": p.epr_registration_no,
                "pibo_type": p.pibo_type,
                "compliance_contact": p.compliance_contact,
            }
    return profile_dict


@router.get("/me", response_model=OrgProfileDetailOut)
async def get_my_org(
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    if not context.org:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "NOT_FOUND", "message": "No active organisation"}},
        )

    profile_dict = await _get_profile_dict(db, context.org)
    return OrgProfileDetailOut(
        id=context.org.id,
        org_type=context.org.org_type,
        legal_name=context.org.legal_name,
        display_name=context.org.display_name,
        city_id=context.org.city_id,
        address=context.org.address,
        lat=context.org.lat,
        lng=context.org.lng,
        gstin=context.org.gstin,
        approval_status=context.org.approval_status,
        profile=profile_dict,
    )


@router.patch("/me", response_model=OrgProfileDetailOut)
async def update_my_org(
    req: OrgUpdateInput,
    context: AuthContext = Depends(require("OWNER", "ADMIN")),
    db: AsyncSession = Depends(get_db),
):
    org = context.org
    if req.display_name is not None:
        org.display_name = req.display_name
    if req.address is not None:
        org.address = req.address
    if req.lat is not None:
        org.lat = req.lat
    if req.lng is not None:
        org.lng = req.lng
    if req.gstin is not None:
        org.gstin = req.gstin

    if req.profile_data:
        if org.org_type == "GENERATOR":
            p = await db.get(GeneratorProfile, org.id)
            if p and "generator_kind" in req.profile_data:
                p.generator_kind = req.profile_data["generator_kind"]
        elif org.org_type == "COLLECTOR":
            p = await db.get(CollectorProfile, org.id)
            if p:
                if "service_radius_km" in req.profile_data:
                    p.service_radius_km = float(req.profile_data["service_radius_km"])
                if "daily_capacity_kg" in req.profile_data:
                    p.daily_capacity_kg = float(req.profile_data["daily_capacity_kg"])

    await db.commit()
    profile_dict = await _get_profile_dict(db, org)
    return OrgProfileDetailOut(
        id=org.id,
        org_type=org.org_type,
        legal_name=org.legal_name,
        display_name=org.display_name,
        city_id=org.city_id,
        address=org.address,
        lat=org.lat,
        lng=org.lng,
        gstin=org.gstin,
        approval_status=org.approval_status,
        profile=profile_dict,
    )


@router.post("/me/members")
async def add_org_member(
    req: AddMemberInput,
    context: AuthContext = Depends(require("OWNER", "ADMIN")),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(User).where(or_(User.email == req.email_or_phone, User.phone == req.email_or_phone))
    res = await db.execute(stmt)
    target_user = res.scalar_one_or_none()

    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "NOT_FOUND", "message": "User with specified email or phone does not exist"}},
        )

    mem_stmt = select(OrgMembership).where(
        OrgMembership.user_id == target_user.id,
        OrgMembership.org_id == context.org.id,
    )
    mem_res = await db.execute(mem_stmt)
    existing_mem = mem_res.scalar_one_or_none()

    if existing_mem:
        existing_mem.org_role = req.org_role.upper()
    else:
        new_mem = OrgMembership(
            user_id=target_user.id,
            org_id=context.org.id,
            org_role=req.org_role.upper(),
        )
        db.add(new_mem)

    await db.commit()
    return {"status": "ok", "message": f"User {target_user.full_name} added as {req.org_role}"}


@admin_router.post("/{id}/approve")
async def approve_org(
    id: uuid.UUID,
    req: ApproveOrgInput,
    context: AuthContext = Depends(get_current_user_and_context),
    db: AsyncSession = Depends(get_db),
):
    if not context.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "FORBIDDEN_ROLE", "message": "Only platform admins can approve organisations"}},
        )

    org = await db.get(Organisation, id)
    if not org:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": {"code": "NOT_FOUND", "message": "Organisation not found"}},
        )

    org.approval_status = req.decision.upper()
    await db.commit()
    return {"status": "ok", "org_id": org.id, "approval_status": org.approval_status, "note": req.note}


# ── DIRECTORY (integration patch #1) ───────────────────────
# Read-only listing so participants can choose counterparties by name
# (consignment destination, allocation client, recycler records) and so
# platform admins can find organisations awaiting approval.

_DIRECTORY_TYPES = {"GENERATOR", "COLLECTOR", "RECYCLER", "NGO", "EPR_CLIENT"}


async def _directory_entry(db: AsyncSession, org: Organisation, include_contact: bool) -> Dict[str, Any]:
    entry: Dict[str, Any] = {
        "id": org.id,
        "org_type": org.org_type,
        "legal_name": org.legal_name,
        "display_name": org.display_name,
        "city_id": org.city_id,
        "approval_status": org.approval_status,
    }
    # Public registration fields only; no payout or contact data.
    if org.org_type == "RECYCLER":
        p = await db.get(RecyclerProfile, org.id)
        if p:
            entry["registration"] = {
                "pwp_registration_no": p.pwp_registration_no,
                "registration_valid_until": str(p.registration_valid_until) if p.registration_valid_until else None,
                "processing_type": p.processing_type,
                "spcb": p.spcb,
            }
    elif org.org_type == "EPR_CLIENT":
        p = await db.get(EPRClientProfile, org.id)
        if p:
            entry["registration"] = {"epr_registration_no": p.epr_registration_no, "pibo_type": p.pibo_type}
    elif org.org_type == "NGO":
        p = await db.get(NGOProfile, org.id)
        if p:
            entry["registration"] = {"registration_no": p.registration_no, "registration_type": p.registration_type}
    if include_contact:
        entry["address"] = org.address
        entry["gstin"] = org.gstin
    return entry


@router.get("")
async def list_organisations(
    org_type: str | None = None,
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    """Approved organisations, optionally filtered by type. Generators are never listed (privacy)."""
    stmt = select(Organisation).where(Organisation.approval_status == "APPROVED").order_by(Organisation.legal_name)
    if org_type:
        t = org_type.upper()
        if t not in _DIRECTORY_TYPES:
            raise HTTPException(status_code=400, detail={"error": {"code": "VALIDATION_ERROR", "message": f"Unknown org_type '{org_type}'"}})
        stmt = stmt.where(Organisation.org_type == t)
    stmt = stmt.where(Organisation.org_type != "GENERATOR")
    res = await db.execute(stmt)
    return [await _directory_entry(db, o, include_contact=False) for o in res.scalars().all()]


@admin_router.get("")
async def admin_list_organisations(
    status_filter: str | None = Query(None, alias="status"),
    org_type: str | None = None,
    context: AuthContext = Depends(get_current_user_and_context),
    db: AsyncSession = Depends(get_db),
):
    if not context.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"error": {"code": "FORBIDDEN_ROLE", "message": "Only platform admins can list all organisations"}},
        )
    stmt = select(Organisation).order_by(Organisation.created_at.desc() if hasattr(Organisation, "created_at") else Organisation.legal_name)
    if status_filter:
        stmt = stmt.where(Organisation.approval_status == status_filter.upper())
    if org_type:
        stmt = stmt.where(Organisation.org_type == org_type.upper())
    res = await db.execute(stmt)
    return [await _directory_entry(db, o, include_contact=True) for o in res.scalars().all()]
