"""Documents upload and management API router."""

import hashlib
import uuid
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.permissions import require, AuthContext
from app.models.documents import Document

router = APIRouter(prefix="/documents", tags=["documents"])


class UploadUrlRequest(BaseModel):
    doc_type: str  # PHOTO_LISTING, WEIGHBRIDGE_SLIP, etc.
    mime_type: str = "image/jpeg"
    size_bytes: int = 1024


class CompleteUploadRequest(BaseModel):
    sha256: Optional[str] = None


@router.post("/upload-url", status_code=status.HTTP_201_CREATED)
async def get_upload_url(
    req: UploadUrlRequest,
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    doc_id = uuid.uuid4()
    storage_key = f"uploads/{context.org_id}/{doc_id}"

    doc = Document(
        id=doc_id,
        owner_org_id=context.org_id,
        storage_key=storage_key,
        mime_type=req.mime_type,
        size_bytes=req.size_bytes,
        doc_type=req.doc_type,
        status="UPLOADING",
        uploaded_by_user_id=context.user_id,
    )
    db.add(doc)
    await db.commit()

    return {
        "document_id": doc.id,
        "upload_url": f"https://reloop-storage.local/{storage_key}?token=mock_presigned_upload",
        "storage_key": storage_key,
    }


@router.post("/{id}/complete")
async def complete_document_upload(
    id: uuid.UUID,
    req: CompleteUploadRequest,
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    doc = await db.get(Document, id)
    if not doc:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Document not found"}})

    doc.status = "READY"
    doc.sha256 = req.sha256 or hashlib.sha256(str(id).encode()).hexdigest()
    await db.commit()
    return {"status": "ok", "document_id": doc.id, "document_status": "READY", "sha256": doc.sha256}


@router.get("/{id}/download-url")
async def get_download_url(
    id: uuid.UUID,
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    doc = await db.get(Document, id)
    if not doc:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Document not found"}})

    return {
        "document_id": doc.id,
        "download_url": f"https://reloop-storage.local/{doc.storage_key}?token=mock_presigned_download",
        "mime_type": doc.mime_type,
        "doc_type": doc.doc_type,
    }
