"""AI polymer classification API router."""

import uuid
from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.permissions import require, AuthContext
from app.models.audit import AIPrediction
from app.models.documents import Document

router = APIRouter(prefix="/ai", tags=["ai"])


class AIClassifyInput(BaseModel):
    document_id: Optional[uuid.UUID] = None
    sample_text: Optional[str] = None


class AIPredictionOut(BaseModel):
    prediction_id: uuid.UUID
    predicted_code: str
    resin_code: int
    confidence: float
    top_k: List[dict]
    needs_confirmation: bool


@router.post("/classify", response_model=AIPredictionOut, status_code=status.HTTP_200_OK)
async def classify_polymer(
    req: AIClassifyInput,
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    # Simulated onnx / computer vision plastic RIC model
    # Top-k predictions
    top_k = [
        {"code": "PET", "name": "Polyethylene Terephthalate", "resin_code": 1, "confidence": 0.92},
        {"code": "HDPE", "name": "High-Density Polyethylene", "resin_code": 2, "confidence": 0.05},
        {"code": "PP", "name": "Polypropylene", "resin_code": 5, "confidence": 0.03},
    ]
    predicted = top_k[0]

    prediction = AIPrediction(
        document_id=req.document_id,
        model_version="yolo-plastic-v1.0",
        predicted_code=predicted["code"],
        confidence=predicted["confidence"],
        top_k=top_k,
    )
    db.add(prediction)
    await db.commit()
    await db.refresh(prediction)

    return AIPredictionOut(
        prediction_id=prediction.id,
        predicted_code=predicted["code"],
        resin_code=predicted["resin_code"],
        confidence=predicted["confidence"],
        top_k=top_k,
        needs_confirmation=predicted["confidence"] < 0.95,
    )
