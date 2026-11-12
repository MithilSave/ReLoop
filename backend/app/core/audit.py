"""Audit log helper with tamper-evident SHA-256 hash chaining."""

import hashlib
import json
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, Optional
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.audit import AuditLog


def compute_sha256(content: str) -> str:
    return hashlib.sha256(content.encode("utf-8")).hexdigest()


async def log_audit_event(
    db: AsyncSession,
    action: str,
    entity_type: str,
    entity_id: Optional[uuid.UUID] = None,
    actor_user_id: Optional[uuid.UUID] = None,
    actor_org_id: Optional[uuid.UUID] = None,
    before: Optional[Dict[str, Any]] = None,
    after: Optional[Dict[str, Any]] = None,
    ip: Optional[str] = None,
    request_id: Optional[str] = None,
) -> AuditLog:
    # Get latest audit log row for hash chaining
    stmt = select(AuditLog).order_by(desc(AuditLog.id)).limit(1)
    res = await db.execute(stmt)
    last_log = res.scalar_one_or_none()

    prev_hash = last_log.row_hash if last_log and last_log.row_hash else "0" * 64
    created_at = datetime.now(timezone.utc)

    # Compute row hash
    raw_str = (
        f"{prev_hash}|{actor_user_id}|{actor_org_id}|{action}|{entity_type}|{entity_id}|"
        f"{json.dumps(before, sort_keys=True) if before else ''}|"
        f"{json.dumps(after, sort_keys=True) if after else ''}|"
        f"{created_at.isoformat()}"
    )
    row_hash = compute_sha256(raw_str)

    log_entry = AuditLog(
        actor_user_id=actor_user_id,
        actor_org_id=actor_org_id,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        before=before,
        after=after,
        ip=ip,
        request_id=request_id,
        prev_hash=prev_hash,
        row_hash=row_hash,
        created_at=created_at,
    )
    db.add(log_entry)
    return log_entry
