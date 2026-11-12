"""Custody records – Pickup, Recycler receipt, Processing run and input lineage."""

import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    SmallInteger,
    String,
    Text,
    Uuid,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


def utcnow():
    return datetime.now(timezone.utc)


class PickupRecord(Base):
    __tablename__ = "pickup_records"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    batch_id = Column(Uuid, ForeignKey("waste_batches.id", ondelete="CASCADE"), nullable=False, index=True)
    collector_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="RESTRICT"), nullable=False, index=True)
    collector_user_id = Column(Uuid, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    collected_kg = Column(Float, nullable=False)
    generator_rate_per_kg = Column(Float, nullable=False)
    handover_method = Column(String(32), default="OTP", nullable=False)  # OTP, QR
    otp_code = Column(String(16), nullable=True)
    generator_confirmed_by_user_id = Column(Uuid, nullable=True)
    confirmed_at = Column(DateTime(timezone=True), nullable=True)
    aggregation_plan_id = Column(Uuid, nullable=True)
    notes = Column(Text, nullable=True)
    version = Column(Integer, default=1, nullable=False)
    supersedes_id = Column(Uuid, nullable=True)
    is_current = Column(Boolean, default=True, nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    batch = relationship("WasteBatch", back_populates="pickup_records")
    collector_org = relationship("Organisation")


class RecyclerReceipt(Base):
    __tablename__ = "recycler_receipts"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    batch_id = Column(Uuid, ForeignKey("waste_batches.id", ondelete="CASCADE"), nullable=False, index=True)
    recycler_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="RESTRICT"), nullable=False, index=True)
    received_kg = Column(Float, nullable=False)
    accepted_kg = Column(Float, nullable=False)
    rejected_kg = Column(Float, default=0.0, nullable=False)
    quality_grade = Column(String(16), default="A", nullable=False)  # A, B, C
    contamination_pct = Column(Float, default=0.0, nullable=False)
    price_per_kg = Column(Float, default=0.0, nullable=False)
    recycler_offer_id = Column(Uuid, nullable=True)
    rejection_disposition = Column(Text, nullable=True)
    received_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)
    version = Column(Integer, default=1, nullable=False)
    supersedes_id = Column(Uuid, nullable=True)
    is_current = Column(Boolean, default=True, nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    batch = relationship("WasteBatch", back_populates="receipts")
    recycler_org = relationship("Organisation")


class ProcessingRecord(Base):
    __tablename__ = "processing_records"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    record_code = Column(String(64), unique=True, nullable=False, index=True)
    recycler_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="RESTRICT"), nullable=False, index=True)
    material_category_id = Column(SmallInteger, ForeignKey("material_categories.id", ondelete="RESTRICT"), nullable=False, index=True)
    run_started_at = Column(DateTime(timezone=True), nullable=False)
    run_ended_at = Column(DateTime(timezone=True), nullable=False)
    input_kg = Column(Float, nullable=False)
    output_kg = Column(Float, nullable=True)
    residue_kg = Column(Float, nullable=True)
    output_form = Column(String(64), nullable=True)  # flakes, granules, pellets, etc.
    eligible_kg = Column(Float, default=0.0, nullable=False)
    eligibility_basis = Column(Text, nullable=True)
    measurement_status = Column(String(32), default="INCOMPLETE", nullable=False)  # COMPLETE, INCOMPLETE
    yield_pct = Column(Float, nullable=True)
    unaccounted_kg = Column(Float, nullable=True)
    version = Column(Integer, default=1, nullable=False)
    supersedes_id = Column(Uuid, nullable=True)
    is_current = Column(Boolean, default=True, nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    recycler_org = relationship("Organisation")
    material_category = relationship("MaterialCategory")
    inputs = relationship("ProcessingInput", back_populates="processing_record", cascade="all, delete-orphan")
    certificates = relationship("Certificate", back_populates="processing_record")
    allocations = relationship("EPRAllocation", back_populates="processing_record")


class ProcessingInput(Base):
    __tablename__ = "processing_inputs"

    processing_record_id = Column(Uuid, ForeignKey("processing_records.id", ondelete="CASCADE"), primary_key=True)
    recycler_receipt_id = Column(Uuid, ForeignKey("recycler_receipts.id", ondelete="RESTRICT"), primary_key=True)
    batch_id = Column(Uuid, ForeignKey("waste_batches.id", ondelete="CASCADE"), nullable=False, index=True)
    input_kg = Column(Float, nullable=False)
    apportioned_output_kg = Column(Float, default=0.0, nullable=False)

    processing_record = relationship("ProcessingRecord", back_populates="inputs")
    receipt = relationship("RecyclerReceipt")
    batch = relationship("WasteBatch")
