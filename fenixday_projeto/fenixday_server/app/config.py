"""
FênixDay — Configuração centralizada via Pydantic Settings
Lê as variáveis do arquivo .env automaticamente.
"""

from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file='.env',
        env_file_encoding='utf-8',
        case_sensitive=False,
    )

    # ── JWT ──────────────────────────────────────────────────────────────────
    SECRET_KEY:          str  = 'insecure-change-me'
    PREVIOUS_SECRET_KEY: str  = ''
    ALGORITHM:           str  = 'HS256'
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10_080   # 7 dias

    # ── Banco de dados ────────────────────────────────────────────────────────
    POSTGRES_HOST:     str = 'postgres'
    POSTGRES_PORT:     int = 5432
    POSTGRES_DB:       str = 'fenixday'
    POSTGRES_USER:     str = 'fenixday'
    POSTGRES_PASSWORD: str = 'changeme'

    @property
    def DATABASE_URL(self) -> str:
        return (
            f'postgresql+asyncpg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}'
            f'@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}'
        )

    @property
    def DATABASE_URL_SYNC(self) -> str:
        """URL síncrona para as migrations do Alembic."""
        return (
            f'postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}'
            f'@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}'
        )

    # ── Redis ─────────────────────────────────────────────────────────────────
    REDIS_HOST:     str = 'redis'
    REDIS_PORT:     int = 6379
    REDIS_PASSWORD: str = ''

    @property
    def REDIS_URL(self) -> str:
        if self.REDIS_PASSWORD:
            return f'redis://:{self.REDIS_PASSWORD}@{self.REDIS_HOST}:{self.REDIS_PORT}/0'
        return f'redis://{self.REDIS_HOST}:{self.REDIS_PORT}/0'

    # ── BTCPay ────────────────────────────────────────────────────────────────
    BTCPAY_SERVER_URL:    str = ''
    BTCPAY_API_KEY:       str = ''
    BTCPAY_STORE_ID:      str = ''
    BTCPAY_WEBHOOK_SECRET: str = ''

    # ── Google OAuth2 ─────────────────────────────────────────────────────────
    GOOGLE_CLIENT_ID: str = ''

    # ── Cloudflare ────────────────────────────────────────────────────────────
    CLOUDFLARE_ZONE_ID:   str = ''
    CLOUDFLARE_API_TOKEN: str = ''

    # ── App ───────────────────────────────────────────────────────────────────
    APP_ENV:      str = 'production'   # production | development
    APP_VERSION:  str = '2.0.0'
    CORS_ORIGINS: str = '*'

    @property
    def IS_PRODUCTION(self) -> bool:
        return self.APP_ENV == 'production'


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
