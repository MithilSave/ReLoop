"""Authentication API router."""

from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.permissions import get_current_user_and_context, AuthContext
from app.models.identity import OrgMembership, Organisation
from app.modules.auth.schemas import (
    RegisterRequest,
    LoginRequest,
    SwitchOrgRequest,
    RefreshTokenRequest,
    AuthResponse,
    MeResponse,
    UserOut,
    OrgOut,
    MembershipOut,
)
from app.modules.auth.service import (
    register_user,
    authenticate_user,
    switch_active_org,
    refresh_tokens,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def register(req: RegisterRequest, db: AsyncSession = Depends(get_db)):
    user, org, access_token, refresh_token = await register_user(db, req)
    return AuthResponse(
        user=UserOut.model_validate(user),
        org=OrgOut.model_validate(org),
        role="OWNER",
        access_token=access_token,
        refresh_token=refresh_token,
    )


@router.post("/login", response_model=AuthResponse)
async def login(req: LoginRequest, db: AsyncSession = Depends(get_db)):
    user, org, role, access_token, refresh_token = await authenticate_user(db, req)
    return AuthResponse(
        user=UserOut.model_validate(user),
        org=OrgOut.model_validate(org) if org else None,
        role=role,
        access_token=access_token,
        refresh_token=refresh_token,
    )


@router.get("/me", response_model=MeResponse)
async def get_me(
    context: AuthContext = Depends(get_current_user_and_context),
    db: AsyncSession = Depends(get_db),
):
    # Fetch all memberships
    stmt = select(OrgMembership, Organisation).join(Organisation, OrgMembership.org_id == Organisation.id).where(
        OrgMembership.user_id == context.user.id
    )
    res = await db.execute(stmt)
    memberships = []
    for mem, org in res.all():
        memberships.append(
            MembershipOut(
                org_id=org.id,
                org_name=org.legal_name,
                org_type=org.org_type,
                org_role=mem.org_role,
                approval_status=org.approval_status,
            )
        )

    return MeResponse(
        user=UserOut.model_validate(context.user),
        active_org=OrgOut.model_validate(context.org) if context.org else None,
        active_role=context.org_role,
        memberships=memberships,
    )


@router.post("/switch-org", response_model=AuthResponse)
async def switch_org(
    req: SwitchOrgRequest,
    context: AuthContext = Depends(get_current_user_and_context),
    db: AsyncSession = Depends(get_db),
):
    org, access_token, refresh_token = await switch_active_org(db, context.user.id, req.org_id)
    return AuthResponse(
        user=UserOut.model_validate(context.user),
        org=OrgOut.model_validate(org),
        role=context.org_role,
        access_token=access_token,
        refresh_token=refresh_token,
    )


@router.post("/refresh", response_model=AuthResponse)
async def refresh(req: RefreshTokenRequest, db: AsyncSession = Depends(get_db)):
    user, org, role, access_token, refresh_token = await refresh_tokens(db, req.refresh_token)
    return AuthResponse(
        user=UserOut.model_validate(user),
        org=OrgOut.model_validate(org) if org else None,
        role=role,
        access_token=access_token,
        refresh_token=refresh_token,
    )
