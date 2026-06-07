"""
FênixDay — API Principal (FastAPI)
Instancia o app, registra todos os routers e expõe /health.
"""

from __future__ import annotations

from contextlib import asynccontextmanager

import redis.asyncio as aioredis
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import settings
from app.database import engine, Base

# ── Routers ───────────────────────────────────────────────────────────────────
from app.routers.auth_v2       import router as auth_router
from app.routers.google_auth   import router as google_router
from app.routers.subscriptions_v2 import router as sub_router
from app.routers.lgpd.lgpd_router import router as lgpd_router
from app.routers.webhooks      import router as webhooks_router
from app.routers.admin         import router as admin_router


# ── Redis global ──────────────────────────────────────────────────────────────
redis_client: aioredis.Redis | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Inicialização e teardown da aplicação."""
    global redis_client

    # Conectar Redis
    redis_client = aioredis.from_url(
        settings.REDIS_URL,
        encoding='utf-8',
        decode_responses=True,
    )
    await redis_client.ping()

    # Guardar no state para os routers
    app.state.redis = redis_client

    yield

    # Cleanup
    await redis_client.aclose()
    await engine.dispose()


# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title='FênixDay API',
    description='Grid Trading Bot SaaS — Backend',
    version=settings.APP_VERSION,
    docs_url='/docs'     if not settings.IS_PRODUCTION else None,
    redoc_url='/redoc'   if not settings.IS_PRODUCTION else None,
    openapi_url='/openapi.json' if not settings.IS_PRODUCTION else None,
    lifespan=lifespan,
)

# ── CORS ──────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS.split(','),
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)

# ── Routers ───────────────────────────────────────────────────────────────────
PREFIX = '/api/v1'

app.include_router(auth_router,     prefix=f'{PREFIX}/auth',          tags=['Auth'])
app.include_router(google_router,   prefix=f'{PREFIX}/auth',          tags=['Auth'])
app.include_router(sub_router,      prefix=f'{PREFIX}/subscriptions', tags=['Subscriptions'])
app.include_router(lgpd_router,     prefix=f'{PREFIX}/lgpd',          tags=['LGPD'])
app.include_router(webhooks_router, prefix=f'{PREFIX}/webhooks',      tags=['Webhooks'])
app.include_router(admin_router,    prefix=f'{PREFIX}/admin',         tags=['Admin'])


# ── Health check ──────────────────────────────────────────────────────────────
@app.get('/health', tags=['Health'])
async def health():
    """Endpoint de saúde verificado pelo CI/CD e load balancer."""
    redis_ok = False
    try:
        if app.state.redis:
            await app.state.redis.ping()
            redis_ok = True
    except Exception:
        pass

    return JSONResponse({
        'status':  'ok',
        'version': settings.APP_VERSION,
        'env':     settings.APP_ENV,
        'redis':   'ok' if redis_ok else 'error',
    })


# ── Root ──────────────────────────────────────────────────────────────────────
@app.get('/', include_in_schema=False)
async def root():
    return {'message': 'FênixDay API', 'version': settings.APP_VERSION}
