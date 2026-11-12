"""Participant profile models."""

import uuid
from datetime import date, datetime, timezone
from sqlalchemy import (
    Column,
    Date,
    DateTime,
    Float,
    ForeignKey,
    JSON,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


def utcnow():
    return datetime.now(timezone.utc)


class GeneratorProfile(Base):
    __tablename__ = "generator_profiles"

    org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="CASCADE"), primary_key=True)
    generator_kind = Column(String(32), default="COMMERCIAL", nullable=False)  # HOUSEHOLD, SOCIETY, COMMERCIAL, INSTITUTION, OTHER
    payout_upi_ref_masked = Column(String(64), nullable=True)

    org = relationship("Organisation", back_populates="generator_profile")


class CollectorProfile(Base):
    __tablename__ = "collector_profiles"

    org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="CASCADE"), primary_key=True)
    service_radius_km = Column(Float, default=25.0, nullable=False)
    daily_capacity_kg = Column(Float, default=2000.0, nullable=False)
    min_pickup_kg = Column(Float, default=50.0, nullable=False)
    vehicle_types = Column(JSON, default=list, nullable=False)  # e.g. ["Tata Ace", "3-Wheeler EV"]
    reliability_score = Column(Float, default=1.0, nullable=True)

    org = relationship("Organisation", back_populates="collector_profile")


class CollectorMaterial(Base):
    __tablename__ = "collector_materials"

    org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="CASCADE"), primary_key=True)
    material_category_id = Column(SmallInteger, ForeignKey("material_categories.id", ondelete="CASCADE"), primary_key=True)


class RecyclerProfile(Base):
    __tablename__ = "recycler_profiles"

    org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="CASCADE"), primary_key=True)
    pwp_registration_no = Column(String(64), unique=True, nullable=True)
    registration_valid_until = Column(Date, nullable=True)
    spcb = Column(String(64), default="MPCB", nullable=True)
    processing_type = Column(String(64), default="RECYCLING", nullable=False)  # RECYCLING, CO_PROCESSING, WASTE_TO_ENERGY, OTHER
    monthly_capacity_kg = Column(Float, default=50000.0, nullable=False)
    facility_address = Column(Text, nullable=True)

    org = relationship("Organisation", back_populates="recycler_profile")


class NGOProfile(Base):
    __tablename__ = "ngo_profiles"

    org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="CASCADE"), primary_key=True)
    registration_no = Column(String(64), nullable=True)
    registration_type = Column(String(64), default="Section 8", nullable=True)  # Trust, Society, Section 8
    coi_declaration_doc_id = Column(Uuid, nullable=True)
    agreement_valid_until = Column(Date, nullable=True)

    org = relationship("Organisation", back_populates="ngo_profile")


class EPRClientProfile(Base):
    __tablename__ = "epr_client_profiles"

    org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="CASCADE"), primary_key=True)
    epr_registration_no = Column(String(64), unique=True, nullable=True)
    pibo_type = Column(String(32), default="BRAND_OWNER", nullable=False)  # PRODUCER, IMPORTER, BRAND_OWNER
    compliance_contact = Column(String(255), nullable=True)

    org = relationship("Organisation", back_populates="epr_client_profile")


class NGOScope(Base):
    __tablename__ = "ngo_scopes"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    ngo_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="CASCADE"), nullable=False, index=True)
    material_category_id = Column(SmallInteger, ForeignKey("material_categories.id", ondelete="SET NULL"), nullable=True)
    locality = Column(String(128), nullable=True)
    recycler_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="SET NULL"), nullable=True)
    valid_from = Column(DateTime(timezone=True), default=utcnow, nullable=False)
    valid_to = Column(DateTime(timezone=True), nullable=True)


class EPRTarget(Base):
    __tablename__ = "epr_targets"
    __table_args__ = (
        UniqueConstraint("epr_org_id", "reporting_period", "packaging_category", name="uq_epr_target_period_cat"),
    )

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    epr_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="CASCADE"), nullable=False, index=True)
    reporting_period = Column(String(32), nullable=False)  # e.g. FY2026-27
    packaging_category = Column(String(32), nullable=False)  # CAT_I, CAT_II, CAT_III, CAT_IV
    target_kg = Column(Float, nullable=False)
    source_note = Column(Text, nullable=True)
