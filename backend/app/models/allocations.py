"""Certificates and EPR Allocations."""

import uuid
from datetime import date, datetime, timezone
from sqlalchemy import (
    Column,
    Date,
    DateTime,
    Float,
    ForeignKey,
    String,
    Text,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


def utcnow():
    return datetime.now(timezone.utc)


class Certificate(Base):
    __tablename__ = "certificates"
    __table_args__ = (
        UniqueConstraint("recycler_org_id", "certificate_ref", name="uq_cert_recycler_ref"),
    )

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    recycler_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="RESTRICT"), nullable=False, index=True)
    processing_record_id = Column(Uuid, ForeignKey("processing_records.id", ondelete="RESTRICT"), nullable=False, index=True)
    certificate_ref = Column(String(128), nullable=False)
    packaging_category = Column(String(32), nullable=False)  # CAT_I, CAT_II, CAT_III, CAT_IV
    certificate_kg = Column(Float, nullable=False)
    issued_on = Column(Date, default=date.today, nullable=False)
    status = Column(String(32), default="RECORDED", nullable=False)  # RECORDED, DISPUTED, WITHDRAWN
    evidence_doc_id = Column(Uuid, nullable=True)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    recycler_org = relationship("Organisation")
    processing_record = relationship("ProcessingRecord", back_populates="certificates")
    allocations = relationship("EPRAllocation", back_populates="certificate")


class EPRAllocation(Base):
    __tablename__ = "epr_allocations"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    processing_record_id = Column(Uuid, ForeignKey("processing_records.id", ondelete="RESTRICT"), nullable=False, index=True)
    epr_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="RESTRICT"), nullable=False, index=True)
    certificate_id = Column(Uuid, ForeignKey("certificates.id", ondelete="SET NULL"), nullable=True, index=True)
    packaging_category = Column(String(32), nullable=False)
    reporting_period = Column(String(32), nullable=False, index=True)  # e.g. FY2026-27
    quantity_kg = Column(Float, nullable=False)
    status = Column(String(32), default="ACTIVE", nullable=False, index=True)  # ACTIVE, REVERSED
    reverses_allocation_id = Column(Uuid, ForeignKey("epr_allocations.id", ondelete="SET NULL"), nullable=True)
    reason = Column(Text, nullable=True)
    requested_by_user_id = Column(Uuid, nullable=True)
    created_by_user_id = Column(Uuid, nullable=False)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    processing_record = relationship("ProcessingRecord", back_populates="allocations")
    epr_org = relationship("Organisation")
    certificate = relationship("Certificate", back_populates="allocations")
