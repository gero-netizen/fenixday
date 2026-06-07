"""
FênixDay — Conexão assíncrona com PostgreSQL
SQLAlchemy + asyncpg + context manager para sessões.
"""

from __future__ import annotations

from contextlib import asynccontextmanager
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from app.config import settings


# ── Engine assíncrona ─────────────────────────────────────────────────────────

engine = create_async_engine(
    settings.DATABASE_URL,
    echo=not settings.IS_PRODUCTION,   # log SQL só em dev
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,                # reconecta automaticamente
    pool_recycle=3600,                 # recicla conexões a cada 1h
)

# ── Session factory ───────────────────────────────────────────────────────────

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)

# ── Base declarativa (todos os modelos herdam desta) ──────────────────────────

class Base(DeclarativeBase):
    pass


# ── Dependency do FastAPI ─────────────────────────────────────────────────────

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Dependency injection para os endpoints FastAPI.
    Uso:  async def endpoint(db: AsyncSession = Depends(get_db))
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


# ── Context manager para uso fora de endpoints ────────────────────────────────

@asynccontextmanager
async def get_db_context() -> AsyncGenerator[AsyncSession, None]:
    """
    Para uso em tarefas agendadas ou scripts.
    Uso:  async with get_db_context() as db: ...
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


# ── Criar/dropar tabelas (usado nos testes) ───────────────────────────────────

async def create_all_tables() -> None:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def drop_all_tables() -> None:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
