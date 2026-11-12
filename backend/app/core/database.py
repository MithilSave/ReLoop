"""Async SQLAlchemy engine, session factory, and declarative Base with fallback."""

import logging
from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy import text

from app.core.config import settings

logger = logging.getLogger("reloop.database")

# Build initial engine
_engine_args = {
    "echo": False,
}
if "sqlite" in settings.DATABASE_URL:
    _engine_args["connect_args"] = {"check_same_thread": False}
else:
    _engine_args["pool_pre_ping"] = True

engine = create_async_engine(settings.DATABASE_URL, **_engine_args)
async_session = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    """Shared declarative base for all models."""
    pass


async def init_db() -> None:
    """Initialize database tables with automatic SQLite fallback."""
    global engine, async_session

    # Import all models to ensure they are registered with Base.metadata
    import app.models  # noqa: F401

    try:
        async with engine.begin() as conn:
            # Test query
            await conn.execute(text("SELECT 1"))
            await conn.run_sync(Base.metadata.create_all)
            logger.info("Database initialized successfully on %s", engine.url)
    except Exception as exc:
        if "sqlite" not in str(engine.url):
            logger.warning(
                "Primary database connection (%s) failed: %s. Falling back to SQLite async.",
                engine.url,
                exc,
            )
            fallback_url = "sqlite+aiosqlite:///./reloop.db"
            engine = create_async_engine(
                fallback_url,
                echo=False,
                connect_args={"check_same_thread": False},
            )
            async_session = async_sessionmaker(
                engine,
                class_=AsyncSession,
                expire_on_commit=False,
            )
            async with engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)
            logger.info("Database initialized successfully on fallback SQLite: %s", fallback_url)
        else:
            logger.error("Failed to initialize database: %s", exc)
            raise exc


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency – yields an async session."""
    async with async_session() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
