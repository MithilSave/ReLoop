"""Centralised application settings – reads from .env."""

from typing import List
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # ── App ───────────────────────────────────────────────
    APP_NAME: str = "ReLoop"
    DEBUG: bool = True
    CORS_ORIGINS: List[str] = [
        "http://localhost:5173",
        "http://localhost:3000",
        "http://127.0.0.1:5173",
        "http://127.0.0.1:3000",
        "*",
    ]

    # ── Database ──────────────────────────────────────────
    # Default to SQLite async for zero-config local operation.
    DATABASE_URL: str = "sqlite+aiosqlite:///./reloop.db"

    # ── JWT / Auth ────────────────────────────────────────
    JWT_SECRET: str = "reloop-super-secret-key-mumbai-pilot-2026"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 60 * 24  # 24 hours for pilot usability

    # ── S3 / MinIO ────────────────────────────────────────
    S3_ENDPOINT_URL: str = "http://localhost:9000"
    S3_ACCESS_KEY: str = "minioadmin"
    S3_SECRET_KEY: str = "minioadmin"
    S3_BUCKET_NAME: str = "reloop"


settings = Settings()
