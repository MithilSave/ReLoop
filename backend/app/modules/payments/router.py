"""Payments API router (simulated financial ledger)."""

import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import select, or_, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.permissions import require, AuthContext
from app.models.payments import Payment

router = APIRouter(prefix="/payments", tags=["payments"])


class MarkPaidInput(BaseModel):
    external_ref: str  # e.g. UPI transaction ref or bank reference


@router.get("")
async def list_payments(
    status_filter: Optional[str] = Query(None, alias="status"),
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Payment).order_by(desc(Payment.created_at))
    if not context.is_admin:
        stmt = stmt.where(
            or_(
                Payment.payer_org_id == context.org_id,
                Payment.payee_org_id == context.org_id,
            )
        )

    if status_filter:
        stmt = stmt.where(Payment.status == status_filter.upper())

    res = await db.execute(stmt)
    payments = res.scalars().all()
    return [{
        "id": p.id,
        "batch_id": p.batch_id,
        "payment_type": p.payment_type,
        "payer_org_id": p.payer_org_id,
        "payee_org_id": p.payee_org_id,
        "quantity_kg": p.quantity_kg,
        "rate": p.rate,
        "amount": p.amount,
        "status": p.status,
        "external_ref": p.external_ref,
        "created_at": p.created_at,
    } for p in payments]


@router.post("/{id}/mark-paid")
async def mark_payment_paid(
    id: uuid.UUID,
    req: MarkPaidInput,
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    p = await db.get(Payment, id)
    if not p:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Payment not found"}})
    if p.payer_org_id != context.org_id and not context.is_admin:
        raise HTTPException(status_code=403, detail={"error": {"code": "FORBIDDEN_ORG", "message": "Only payer org can mark paid"}})

    p.status = "PAID"
    p.external_ref = req.external_ref
    await db.commit()
    return {"status": "ok", "payment_status": "PAID", "external_ref": p.external_ref}
