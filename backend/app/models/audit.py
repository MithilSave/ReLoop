"""Audit log, Anomaly flags, and AI predictions."""

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
    String,
    Text,
    Uuid,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


def utcnow():
    return datetime.now(timezone.utc)


class AnomalyFlag(Base):
    __tablename__ = "anomaly_flags"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    rule_code = Column(String(64), nullable=False, index=True)
    severity = Column(String(16), default="WARN", nullable=False)  # INFO, WARN, HIGH
    batch_id = Column(Uuid, ForeignKey("waste_batches.id", ondelete="SET NULL"), nullable=True, index=True)
    entity_type = Column(String(64), nullable=False)
    entity_id = Column(Uuid, nullable=False)
    details = Column(JSON, default=dict, nullable=False)
    status = Column(String(32), default="OPEN", nullable=False, index=True)  # OPEN, ACKNOWLEDGED, RESOLVED, DISMISSED
    resolved_by_user_id = Column(Uuid, nullable=True)
    resolution_note = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    batch = relationship("WasteBatch")


class AIPrediction(Base):
    __tablename__ = "ai_predictions"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    document_id = Column(Uuid, ForeignKey("documents.id", ondelete="SET NULL"), nullable=True)
    model_version = Column(String(64), default="yolo-plastic-v1.0", nullable=False)
    predicted_code = Column(String(32), nullable=False)  # PET, HDPE, etc.
    confidence = Column(Float, nullable=False)
    top_k = Column(JSON, default=list, nullable=False)
    user_confirmed_code = Column(String(32), nullable=True)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True, autoincrement=True)
    actor_user_id = Column(Uuid, nullable=True)
    actor_org_id = Column(Uuid, nullable=True)
    action = Column(String(64), nullable=False, index=True)
    entity_type = Column(String(64), nullable=False, index=True)
    entity_id = Column(Uuid, nullable=True, index=True)
    before = Column(JSON, nullable=True)
    after = Column(JSON, nullable=True)
    ip = Column(String(64), nullable=True)
    request_id = Column(String(64), nullable=True)
    prev_hash = Column(String(64), nullable=True)
    row_hash = Column(String(64), nullable=True)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)
