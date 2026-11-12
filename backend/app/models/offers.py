"""Collection offer and Recycler offer models."""

import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    SmallInteger,
    String,
    Text,
    Uuid,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


def utcnow():
    return datetime.now(timezone.utc)


class CollectionOffer(Base):
    __tablename__ = "collection_offers"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    batch_id = Column(Uuid, ForeignKey("waste_batches.id", ondelete="CASCADE"), nullable=False, index=True)
    collector_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="CASCADE"), nullable=False, index=True)
    generator_rate_per_kg = Column(Float, nullable=False)
    proposed_pickup_at = Column(DateTime(timezone=True), nullable=False)
    status = Column(String(32), default="OPEN", nullable=False, index=True)  # OPEN, ACCEPTED, DECLINED, EXPIRED, WITHDRAWN
    expires_at = Column(DateTime(timezone=True), nullable=False)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    batch = relationship("WasteBatch", back_populates="offers")
    collector_org = relationship("Organisation")


class RecyclerOffer(Base):
    __tablename__ = "recycler_offers"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    recycler_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="CASCADE"), nullable=False, index=True)
    material_category_id = Column(SmallInteger, ForeignKey("material_categories.id", ondelete="RESTRICT"), nullable=False, index=True)
    price_per_kg = Column(Float, nullable=False)
    min_kg = Column(Float, default=100.0, nullable=False)
    quality_spec = Column(Text, nullable=True)
    max_contamination_pct = Column(Float, default=5.0, nullable=False)
    valid_from = Column(DateTime(timezone=True), default=utcnow, nullable=False)
    valid_to = Column(DateTime(timezone=True), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    recycler_org = relationship("Organisation")
    material_category = relationship("MaterialCategory")
