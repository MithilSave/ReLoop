"""Identity models – User, Organisation, OrgMembership, RefreshToken."""

import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    String,
    Text,
    Uuid,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


def utcnow():
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    full_name = Column(String(255), nullable=False)
    email = Column(String(255), unique=True, nullable=True, index=True)
    phone = Column(String(32), unique=True, nullable=True, index=True)
    password_hash = Column(String(255), nullable=False)
    is_platform_admin = Column(Boolean, default=False, nullable=False)
    status = Column(String(32), default="ACTIVE", nullable=False)  # ACTIVE, SUSPENDED
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    memberships = relationship("OrgMembership", back_populates="user", cascade="all, delete-orphan")


class Organisation(Base):
    __tablename__ = "organisations"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    org_type = Column(String(32), nullable=False, index=True)  # GENERATOR, COLLECTOR, RECYCLER, NGO, EPR_CLIENT
    legal_name = Column(String(255), nullable=False)
    display_name = Column(String(255), nullable=True)
    city_id = Column(String(32), default="MUM", nullable=False)
    address = Column(Text, nullable=False)
    lat = Column(Float, nullable=True)
    lng = Column(Float, nullable=True)
    gstin = Column(String(32), nullable=True)
    approval_status = Column(String(32), default="PENDING", nullable=False)  # PENDING, APPROVED, REJECTED, SUSPENDED
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    memberships = relationship("OrgMembership", back_populates="org", cascade="all, delete-orphan")
    generator_profile = relationship("GeneratorProfile", uselist=False, back_populates="org")
    collector_profile = relationship("CollectorProfile", uselist=False, back_populates="org")
    recycler_profile = relationship("RecyclerProfile", uselist=False, back_populates="org")
    ngo_profile = relationship("NGOProfile", uselist=False, back_populates="org")
    epr_client_profile = relationship("EPRClientProfile", uselist=False, back_populates="org")


class OrgMembership(Base):
    __tablename__ = "org_memberships"

    user_id = Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="CASCADE"), primary_key=True)
    org_role = Column(String(32), default="MEMBER", nullable=False)  # OWNER, ADMIN, MEMBER, VIEWER

    user = relationship("User", back_populates="memberships")
    org = relationship("Organisation", back_populates="memberships")


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id = Column(Uuid, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    token_hash = Column(String(255), unique=True, nullable=False, index=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    revoked_at = Column(DateTime(timezone=True), nullable=True)
