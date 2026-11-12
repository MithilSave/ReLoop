"""Audit and Anomalies API router."""

import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.permissions import require, AuthContext
from app.models.audit import AnomalyFlag, AuditLog

router = APIRouter(tags=["audit"])


class ResolveAnomalyInput(BaseModel):
    status: str = "RESOLVED"  # RESOLVED, ACKNOWLEDGED, DISMISSED
    note: Optional[str] = None


@router.get("/anomalies")
async def list_anomalies(
    status_filter: Optional[str] = Query(None, alias="status"),
    severity: Optional[str] = Query(None),
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(AnomalyFlag).order_by(desc(AnomalyFlag.created_at))
    if status_filter:
        stmt = stmt.where(AnomalyFlag.status == status_filter.upper())
    if severity:
        stmt = stmt.where(AnomalyFlag.severity == severity.upper())

    res = await db.execute(stmt)
    flags = res.scalars().all()
    return [{
        "id": f.id,
        "rule_code": f.rule_code,
        "severity": f.severity,
        "batch_id": f.batch_id,
        "entity_type": f.entity_type,
        "entity_id": f.entity_id,
        "details": f.details,
        "status": f.status,
        "resolved_by_user_id": f.resolved_by_user_id,
        "resolution_note": f.resolution_note,
        "created_at": f.created_at,
    } for f in flags]


@router.post("/anomalies/{id}/resolve")
async def resolve_anomaly(
    id: uuid.UUID,
    req: ResolveAnomalyInput,
    context: AuthContext = Depends(require("NGO", "OWNER", "ADMIN")),
    db: AsyncSession = Depends(get_db),
):
    flag = await db.get(AnomalyFlag, id)
    if not flag:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Anomaly flag not found"}})

    flag.status = req.status.upper()
    flag.resolution_note = req.note
    flag.resolved_by_user_id = context.user_id
    await db.commit()
    return {"status": "ok", "flag_status": flag.status, "resolution_note": flag.resolution_note}


@router.get("/audit/logs")
async def list_audit_logs(
    entity_type: Optional[str] = Query(None),
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(AuditLog).order_by(desc(AuditLog.id)).limit(100)
    if entity_type:
        stmt = stmt.where(AuditLog.entity_type == entity_type)

    res = await db.execute(stmt)
    logs = res.scalars().all()
    return [{
        "id": l.id,
        "actor_user_id": l.actor_user_id,
        "actor_org_id": l.actor_org_id,
        "action": l.action,
        "entity_type": l.entity_type,
        "entity_id": l.entity_id,
        "before": l.before,
        "after": l.after,
        "prev_hash": l.prev_hash,
        "row_hash": l.row_hash,
        "created_at": l.created_at,
    } for l in logs]
