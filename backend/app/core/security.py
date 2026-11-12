"""JWT token helpers and Argon2 password hashing."""

import secrets
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional

from argon2 import PasswordHasher
from jose import JWTError, jwt

from app.core.config import settings

ph = PasswordHasher()


# ── Password hashing ─────────────────────────────────────

def hash_password(plain: str) -> str:
    return ph.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return ph.verify(hashed, plain)
    except Exception:
        return False


# ── JWT ───────────────────────────────────────────────────

def create_access_token(
    data: Dict[str, Any],
    expires_delta: Optional[timedelta] = None,
) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(minutes=settings.JWT_EXPIRE_MINUTES)
    )
    to_encode.update({"exp": expire, "type": "access"})
    return jwt.encode(to_encode, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(
    data: Dict[str, Any],
    expires_delta: Optional[timedelta] = None,
) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(days=30)
    )
    to_encode.update({"exp": expire, "type": "refresh", "jti": secrets.token_hex(16)})
    return jwt.encode(to_encode, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def decode_access_token(token: str) -> Dict[str, Any]:
    try:
        return jwt.decode(
            token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM]
        )
    except JWTError as err:
        raise ValueError(f"Invalid or expired token: {err}")
