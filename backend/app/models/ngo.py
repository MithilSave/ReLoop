"""NGO verification models."""

import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    JSON,
    String,
    Text,
    Uuid,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


def utcnow():
    return datetime.now(timezone.utc)


class NGOVerification(Base):
    __tablename__ = "ngo_verifications"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    batch_id = Column(Uuid, ForeignKey("waste_batches.id", ondelete="CASCADE"), nullable=False, index=True)
    ngo_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="RESTRICT"), nullable=False, index=True)
    reviewer_user_id = Column(Uuid, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    decision = Column(String(32), default="PENDING", nullable=False, index=True)  # PENDING, UNDER_REVIEW, VERIFIED, FLAGGED, REJECTED, REQUIRES_CORRECTION
    reviewed_record_versions = Column(JSON, default=dict, nullable=False)
    evidence_doc_ids = Column(JSON, default=list, nullable=False)
    comments = Column(Text, nullable=True)
    follow_up_required = Column(Text, nullable=True)
    supersedes_id = Column(Uuid, nullable=True)
    is_current = Column(Boolean, default=True, nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    batch = relationship("WasteBatch")
    ngo_org = relationship("Organisation")
    reviewer = relationship("User")
