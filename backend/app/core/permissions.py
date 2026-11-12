"""Role-based access control and authentication context dependencies."""

import uuid
from typing import Optional, Sequence
from dataclasses import dataclass
from fastapi import Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import decode_access_token


@dataclass
class AuthContext:
    user: any
    org: Optional[any] = None
    membership: Optional[any] = None

    @property
    def user_id(self) -> uuid.UUID:
        return self.user.id

    @property
    def org_id(self) -> Optional[uuid.UUID]:
        return self.org.id if self.org else None

    @property
    def org_type(self) -> Optional[str]:
        return self.org.org_type if self.org else None

    @property
    def org_role(self) -> Optional[str]:
        return self.membership.org_role if self.membership else None

    @property
    def is_admin(self) -> bool:
        return getattr(self.user, "is_platform_admin", False)


async def get_current_user_and_context(
    authorization: Optional[str] = Header(None, alias="Authorization"),
    db: AsyncSession = Depends(get_db),
) -> AuthContext:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "UNAUTHENTICATED", "message": "Missing or invalid authorization header"}},
        )

    token = authorization.split(" ", 1)[1]
    try:
        payload = decode_access_token(token)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "TOKEN_EXPIRED" if "expired" in str(exc) else "UNAUTHENTICATED", "message": str(exc)}},
        )

    user_id_str = payload.get("sub")
    if not user_id_str:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "UNAUTHENTICATED", "message": "Token payload missing subject"}},
        )

    from app.models.identity import User, Organisation, OrgMembership
    try:
        user_uuid = uuid.UUID(user_id_str)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "UNAUTHENTICATED", "message": "Invalid user ID in token"}},
        )

    user = await db.get(User, user_uuid)
    if not user or user.status != "ACTIVE":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "UNAUTHENTICATED", "message": "User not found or inactive"}},
        )

    # Active organisation from JWT claim if present
    claimed_org_id = payload.get("org_id")
    org = None
    membership = None

    if claimed_org_id:
        try:
            org_uuid = uuid.UUID(claimed_org_id)
            org = await db.get(Organisation, org_uuid)
            mem_stmt = select(OrgMembership).where(
                OrgMembership.user_id == user.id,
                OrgMembership.org_id == org_uuid,
            )
            res = await db.execute(mem_stmt)
            membership = res.scalar_one_or_none()
        except Exception:
            pass

    # If no claimed org or not found, pick the first membership
    if not org:
        mem_stmt = select(OrgMembership).where(OrgMembership.user_id == user.id)
        res = await db.execute(mem_stmt)
        membership = res.scalar_one_or_none()
        if membership:
            org = await db.get(Organisation, membership.org_id)

    return AuthContext(user=user, org=org, membership=membership)


def require(*roles_or_types: str):
    """
    Dependency factory to check if the caller has any of the required:
    - org_type (e.g. GENERATOR, COLLECTOR, RECYCLER, NGO, EPR_CLIENT)
    - org_role (e.g. OWNER, ADMIN, MEMBER, VIEWER)
    - or is platform admin.
    """
    async def _guard(context: AuthContext = Depends(get_current_user_and_context)) -> AuthContext:
        if context.is_admin:
            return context

        if not roles_or_types:
            return context

        has_org_type = context.org_type in roles_or_types
        has_org_role = context.org_role in roles_or_types

        if not (has_org_type or has_org_role):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "error": {
                        "code": "FORBIDDEN_ROLE",
                        "message": f"Action requires one of: {list(roles_or_types)}. Current org_type='{context.org_type}', role='{context.org_role}'",
                    }
                },
            )

        # Check organisation approval status
        if context.org and context.org.approval_status not in ("APPROVED", "ACTIVE"):
            # Generators are auto-approved, others must be approved
            if context.org_type != "GENERATOR":
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail={"error": {"code": "ORG_NOT_APPROVED", "message": f"Organisation {context.org.legal_name} is {context.org.approval_status}"}},
                )

        return context

    return _guard
