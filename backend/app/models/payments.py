"""Payment models (simulated financial ledger)."""

import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    Column,
    DateTime,
    Float,
    ForeignKey,
    String,
    Uuid,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


def utcnow():
    return datetime.now(timezone.utc)


class Payment(Base):
    __tablename__ = "payments"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    batch_id = Column(Uuid, ForeignKey("waste_batches.id", ondelete="SET NULL"), nullable=True, index=True)
    payment_type = Column(String(32), nullable=False, index=True)  # GENERATOR_PAYOUT, RECYCLER_PROCUREMENT, PLATFORM_FEE, NGO_FEE, EPR_SUBSCRIPTION
    payer_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="RESTRICT"), nullable=False, index=True)
    payee_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="RESTRICT"), nullable=True, index=True)
    quantity_kg = Column(Float, nullable=True)
    rate = Column(Float, nullable=True)
    amount = Column(Float, nullable=False)
    status = Column(String(32), default="PENDING", nullable=False, index=True)  # PENDING, PAID, FAILED, CANCELLED
    external_ref = Column(String(128), nullable=True)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    batch = relationship("WasteBatch")
    payer_org = relationship("Organisation", foreign_keys=[payer_org_id])
    payee_org = relationship("Organisation", foreign_keys=[payee_org_id])
