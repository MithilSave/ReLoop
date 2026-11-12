"""Document and document link models."""

import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    BigInteger,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Uuid,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


def utcnow():
    return datetime.now(timezone.utc)


class Document(Base):
    __tablename__ = "documents"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    owner_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="RESTRICT"), nullable=False, index=True)
    storage_key = Column(String(512), nullable=False)
    mime_type = Column(String(128), default="image/jpeg", nullable=False)
    size_bytes = Column(BigInteger().with_variant(BigInteger, "sqlite"), default=0, nullable=False)
    sha256 = Column(String(64), nullable=True, index=True)
    doc_type = Column(String(64), nullable=False, index=True)  # PHOTO_LISTING, PHOTO_PICKUP, WEIGHBRIDGE_SLIP, etc.
    status = Column(String(32), default="UPLOADING", nullable=False)  # UPLOADING, READY
    uploaded_by_user_id = Column(Uuid, nullable=True)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    owner_org = relationship("Organisation")
    links = relationship("DocumentLink", back_populates="document", cascade="all, delete-orphan")


class DocumentLink(Base):
    __tablename__ = "document_links"

    document_id = Column(Uuid, ForeignKey("documents.id", ondelete="CASCADE"), primary_key=True)
    entity_type = Column(String(64), primary_key=True)  # waste_batch, pickup_record, etc.
    entity_id = Column(Uuid, primary_key=True)

    document = relationship("Document", back_populates="links")
