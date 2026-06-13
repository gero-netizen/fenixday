"""
FênixDay — Funções base de segurança JWT
"""
from datetime import datetime, timezone
from jose import JWTError, jwt
from app.config import settings


def decode_access_token(token: str) -> dict | None:
    """Decodifica e valida um JWT. Retorna o payload ou None se inválido."""
    for secret in [settings.SECRET_KEY, settings.PREVIOUS_SECRET_KEY]:
        if not secret:
            continue
        try:
            payload = jwt.decode(
                token,
                secret,
                algorithms=[settings.ALGORITHM],
            )
            return payload
        except JWTError:
            continue
    return None


def create_access_token(data: dict) -> str:
    """Cria um JWT com os dados fornecidos."""
    from datetime import timedelta
    import copy
    to_encode = copy.deepcopy(data)
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
    )
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
