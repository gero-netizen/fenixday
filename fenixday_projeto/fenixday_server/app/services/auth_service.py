from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from passlib.context import CryptContext
from app.models.models import User, License, LicenseStatus, Subscription
import uuid

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)

async def register_user(db: AsyncSession, email: str, password: str) -> User:
    user = User(
        id=uuid.uuid4(),
        email=email,
        hashed_password=hash_password(password),
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )
    db.add(user)
    db.add(License(id=uuid.uuid4(), user_id=user.id, status=LicenseStatus.PENDING, created_at=datetime.now(timezone.utc)))
    db.add(Subscription(id=uuid.uuid4(), user_id=user.id, current_tier='exempt', created_at=datetime.now(timezone.utc), updated_at=datetime.now(timezone.utc)))
    await db.flush()
    return user

async def authenticate_user(db: AsyncSession, email: str, password: str) -> User | None:
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if not user or not user.hashed_password:
        return None
    return user if verify_password(password, user.hashed_password) else None
