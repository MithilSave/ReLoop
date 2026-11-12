"""AI polymer classification API router.

The model itself is connected in `classifier.py`. When no model is connected this endpoint answers
503 AI_MODEL_NOT_CONFIGURED; it never returns a placeholder prediction.
"""

import base64
import binascii
import hashlib
import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.permissions import require, AuthContext
from app.models.audit import AIPrediction
from app.models.reference import MaterialCategory
from app.modules.ai import classifier

router = APIRouter(prefix="/ai", tags=["ai"])

MAX_IMAGE_BYTES = 8 * 1024 * 1024


class AIClassifyInput(BaseModel):
    # The photo itself, base64-encoded. Document storage is not connected yet, so the image is sent inline.
    image_base64: Optional[str] = Field(default=None, description="JPEG/PNG bytes, base64-encoded")
    # Optional link to the document record created for the same photo (its SHA-256 is stored there).
    document_id: Optional[uuid.UUID] = None
    sample_text: Optional[str] = None


class AIPredictionOut(BaseModel):
    prediction_id: uuid.UUID
    model_version: str
    predicted_code: str
    predicted_name: Optional[str]
    resin_code: Optional[int]
    confidence: float
    top_k: List[dict]
    low_confidence: bool
    needs_confirmation: bool
    image_sha256: str


class AIStatusOut(BaseModel):
    configured: bool
    model_version: str
    min_confidence: float
    message: str


def _err(code: int, err: str, message: str) -> HTTPException:
    return HTTPException(status_code=code, detail={"error": {"code": err, "message": message}})


@router.get("/status", response_model=AIStatusOut)
async def ai_status(context: AuthContext = Depends(require())):
    """Whether a polymer model is connected. The app uses this to show or explain the detection button."""
    try:
        classifier._get_model()
        return AIStatusOut(configured=True, model_version=classifier.MODEL_VERSION, min_confidence=classifier.LOW_CONFIDENCE, message="Polymer model connected")
    except classifier.ModelNotConfigured as e:
        return AIStatusOut(configured=False, model_version=classifier.MODEL_VERSION, min_confidence=classifier.LOW_CONFIDENCE, message=str(e))
    except Exception as e:  # model file present but failed to load
        return AIStatusOut(configured=False, model_version=classifier.MODEL_VERSION, min_confidence=classifier.LOW_CONFIDENCE, message=f"Model failed to load: {e}")


@router.post("/classify", response_model=AIPredictionOut, status_code=status.HTTP_200_OK)
async def classify_polymer(
    req: AIClassifyInput,
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    if not req.image_base64:
        raise _err(422, "IMAGE_REQUIRED", "Send the photo as image_base64.")
    try:
        image = base64.b64decode(req.image_base64.split(",")[-1], validate=True)
    except (binascii.Error, ValueError):
        raise _err(422, "IMAGE_INVALID", "image_base64 is not valid base64.")
    if not image:
        raise _err(422, "IMAGE_INVALID", "The image is empty.")
    if len(image) > MAX_IMAGE_BYTES:
        raise _err(413, "IMAGE_TOO_LARGE", "The image is larger than 8 MB.")

    try:
        ranked = classifier.classify(image)
    except classifier.ModelNotConfigured as e:
        raise _err(503, "AI_MODEL_NOT_CONFIGURED", f"AI polymer detection is not connected. {e}")
    except Exception as e:
        raise _err(500, "AI_MODEL_ERROR", f"The polymer model failed on this image: {e}")
    if not ranked:
        raise _err(500, "AI_MODEL_ERROR", "The polymer model returned no prediction.")

    mats = {m.code: m for m in (await db.execute(select(MaterialCategory))).scalars().all()}
    top_k = [
        {
            "code": code,
            "name": mats[code].name if code in mats else None,
            "resin_code": mats[code].resin_code if code in mats else None,
            "confidence": round(p, 4),
        }
        for code, p in ranked[:3]
    ]
    best = top_k[0]
    low = best["confidence"] < classifier.LOW_CONFIDENCE or best["code"] not in mats

    prediction = AIPrediction(
        document_id=req.document_id,
        model_version=classifier.MODEL_VERSION[:64],
        predicted_code=best["code"],
        confidence=best["confidence"],
        top_k=top_k,
    )
    db.add(prediction)
    await db.commit()
    await db.refresh(prediction)

    return AIPredictionOut(
        prediction_id=prediction.id,
        model_version=prediction.model_version,
        predicted_code=best["code"],
        predicted_name=best["name"],
        resin_code=best["resin_code"],
        confidence=best["confidence"],
        top_k=top_k,
        low_confidence=low,
        needs_confirmation=True,  # the generator always confirms the material before publishing
        image_sha256=hashlib.sha256(image).hexdigest(),
    )
