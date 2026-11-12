"""Waste batch and batch event models."""

import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    BigInteger,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    JSON,
    SmallInteger,
    String,
    Text,
    Uuid,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


def utcnow():
    return datetime.now(timezone.utc)


class WasteBatch(Base):
    __tablename__ = "waste_batches"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    batch_code = Column(String(64), unique=True, nullable=False, index=True)
    qr_token = Column(String(128), unique=True, nullable=False, index=True)
    generator_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="RESTRICT"), nullable=False, index=True)
    material_category_id = Column(SmallInteger, ForeignKey("material_categories.id", ondelete="RESTRICT"), nullable=False, index=True)
    ai_prediction_id = Column(Uuid, nullable=True)
    estimated_kg = Column(Float, nullable=False)
    pickup_address = Column(Text, nullable=False)
    lat = Column(Float, nullable=True)
    lng = Column(Float, nullable=True)
    locality = Column(String(128), nullable=True, index=True)
    available_from = Column(DateTime(timezone=True), nullable=False)
    available_to = Column(DateTime(timezone=True), nullable=False)
    status = Column(String(32), default="LISTED", nullable=False, index=True)
    assigned_collector_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="SET NULL"), nullable=True, index=True)
    accepted_offer_id = Column(Uuid, nullable=True)
    destination_recycler_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="SET NULL"), nullable=True, index=True)
    active_plan_id = Column(Uuid, nullable=True)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    generator_org = relationship("Organisation", foreign_keys=[generator_org_id])
    collector_org = relationship("Organisation", foreign_keys=[assigned_collector_org_id])
    recycler_org = relationship("Organisation", foreign_keys=[destination_recycler_org_id])
    material_category = relationship("MaterialCategory")
    events = relationship("BatchEvent", back_populates="batch", order_by="BatchEvent.id.asc()")
    pickup_records = relationship("PickupRecord", back_populates="batch")
    receipts = relationship("RecyclerReceipt", back_populates="batch")
    offers = relationship("CollectionOffer", back_populates="batch")


class BatchEvent(Base):
    __tablename__ = "batch_events"

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True, autoincrement=True)
    batch_id = Column(Uuid, ForeignKey("waste_batches.id", ondelete="CASCADE"), nullable=False, index=True)
    event_type = Column(String(64), nullable=False, index=True)
    from_status = Column(String(32), nullable=True)
    to_status = Column(String(32), nullable=True)
    actor_user_id = Column(Uuid, nullable=True)
    actor_org_id = Column(Uuid, nullable=True)
    payload = Column(JSON, default=dict, nullable=False)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    batch = relationship("WasteBatch", back_populates="events")
