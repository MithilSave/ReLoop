"""ReLoop – FastAPI application factory."""

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.config import settings
from app.core.database import init_db

# Module routers
from app.modules.auth.router import router as auth_router
from app.modules.orgs.router import router as orgs_router, admin_router as admin_orgs_router
from app.modules.materials.router import router as materials_router
from app.modules.batches.router import router as batches_router
from app.modules.collections.router import router as collections_router
from app.modules.consignments.router import router as consignments_router
from app.modules.recycler.router import router as recycler_router
from app.modules.ngo.router import router as ngo_router
from app.modules.epr.router import router as epr_router
from app.modules.passport.router import router as passport_router
from app.modules.intelligence.router import router as intelligence_router
from app.modules.ai.router import router as ai_router
from app.modules.documents.router import router as documents_router
from app.modules.payments.router import router as payments_router
from app.modules.audit.router import router as audit_router
from app.modules.reports.router import router as reports_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: initialize database with automatic SQLite fallback
    await init_db()
    yield
    # Shutdown


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.APP_NAME,
        version="1.0.0",
        description="ReLoop Plastic Waste Marketplace & Traceability Platform API",
        lifespan=lifespan,
    )

    # ── CORS ──────────────────────────────────────────────
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # ── Exception handlers ────────────────────────────────
    @app.exception_handler(StarletteHTTPException)
    async def http_exception_handler(request, exc):
        if isinstance(exc.detail, dict) and "error" in exc.detail:
            return JSONResponse(status_code=exc.status_code, content=exc.detail)
        return JSONResponse(
            status_code=exc.status_code,
            content={"error": {"code": "HTTP_ERROR", "message": str(exc.detail)}},
        )

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(request, exc):
        return JSONResponse(
            status_code=422,
            content={
                "error": {
                    "code": "VALIDATION_ERROR",
                    "message": "Request validation failed",
                    "details": exc.errors(),
                }
            },
        )

    # ── Health ────────────────────────────────────────────
    @app.get("/health", tags=["health"])
    async def health():
        return {"status": "ok", "app": settings.APP_NAME, "version": "1.0.0"}

    # ── Mount routers under /api/v1 (source of truth) ─────
    api_v1_routers = [
        auth_router,
        orgs_router,
        admin_orgs_router,
        materials_router,
        batches_router,
        collections_router,
        consignments_router,
        recycler_router,
        ngo_router,
        epr_router,
        passport_router,
        intelligence_router,
        ai_router,
        documents_router,
        payments_router,
        audit_router,
        reports_router,
    ]

    for r in api_v1_routers:
        app.include_router(r, prefix="/api/v1")
        # Also mount on /api for convenience and backwards compatibility
        app.include_router(r, prefix="/api")

    return app


app = create_app()
