"""
FênixDay — Router de Ordens do Grid (motor real)
Gerencia as ordens individuais (BUY/SELL) de cada grid.
O monitor no app usa estes endpoints para:
  - registrar ordens criadas na corretora
  - listar ordens abertas (para checar execução)
  - atualizar status (open -> filled) ao detectar execução
"""
from __future__ import annotations
import uuid
from datetime import datetime, timezone
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.routers.auth_v2 import get_current_user
from app.models.models import User
from app.models.grid_model import Grid
from app.models.grid_order_model import GridOrder

router = APIRouter(prefix='', tags=['grid_orders'])


# ── Schemas ───────────────────────────────────────────────────────────────────
class OrderCreate(BaseModel):
    exchange_order_id: Optional[str] = None
    nivel:     int
    side:      str          # 'BUY' ou 'SELL'
    price:     float
    qty:       float
    par_price: float
    status:    str = 'open'


class OrderResponse(BaseModel):
    id:                str
    grid_id:           str
    exchange_order_id: Optional[str]
    nivel:     int
    side:      str
    price:     float
    qty:       float
    status:    str
    par_price: float
    created_at: str
    updated_at: str

    @classmethod
    def from_orm(cls, o: GridOrder) -> 'OrderResponse':
        return cls(
            id=str(o.id), grid_id=str(o.grid_id),
            exchange_order_id=o.exchange_order_id, nivel=o.nivel,
            side=o.side, price=o.price, qty=o.qty, status=o.status,
            par_price=o.par_price,
            created_at=o.created_at.isoformat(),
            updated_at=o.updated_at.isoformat(),
        )


class OrderUpdate(BaseModel):
    status:            Optional[str] = None
    exchange_order_id: Optional[str] = None


# ── Helper: garante que o grid pertence ao usuário ────────────────────────────
async def _get_grid_or_404(grid_id: str, user: User, db: AsyncSession) -> Grid:
    try:
        gid = uuid.UUID(grid_id)
    except ValueError:
        raise HTTPException(status_code=400, detail='grid_id inválido')
    result = await db.execute(
        select(Grid).where(Grid.id == gid, Grid.user_id == user.id))
    grid = result.scalar_one_or_none()
    if not grid:
        raise HTTPException(status_code=404, detail='Grid não encontrado')
    return grid


# ── POST: registrar uma ou várias ordens de um grid ───────────────────────────
@router.post('/{grid_id}/orders', response_model=List[OrderResponse])
async def create_orders(
    grid_id: str,
    orders: List[OrderCreate],
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    grid = await _get_grid_or_404(grid_id, current_user, db)
    criadas = []
    for o in orders:
        order = GridOrder(
            id=uuid.uuid4(), grid_id=grid.id,
            exchange_order_id=o.exchange_order_id, nivel=o.nivel,
            side=o.side.upper(), price=o.price, qty=o.qty,
            status=o.status, par_price=o.par_price,
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        db.add(order)
        criadas.append(order)
    await db.commit()
    for o in criadas:
        await db.refresh(o)
    return [OrderResponse.from_orm(o) for o in criadas]


# ── GET: listar ordens de um grid (opcional filtrar por status) ───────────────
@router.get('/{grid_id}/orders', response_model=List[OrderResponse])
async def list_orders(
    grid_id: str,
    status: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    grid = await _get_grid_or_404(grid_id, current_user, db)
    query = select(GridOrder).where(GridOrder.grid_id == grid.id)
    if status:
        query = query.where(GridOrder.status == status)
    query = query.order_by(GridOrder.nivel)
    result = await db.execute(query)
    ordens = result.scalars().all()
    return [OrderResponse.from_orm(o) for o in ordens]


# ── PATCH: atualizar uma ordem (status open->filled, etc) ─────────────────────
@router.patch('/orders/{order_id}', response_model=OrderResponse)
async def update_order(
    order_id: str,
    upd: OrderUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        oid = uuid.UUID(order_id)
    except ValueError:
        raise HTTPException(status_code=400, detail='order_id inválido')
    # Busca a ordem garantindo que pertence a um grid do usuário
    result = await db.execute(
        select(GridOrder, Grid)
        .join(Grid, GridOrder.grid_id == Grid.id)
        .where(GridOrder.id == oid, Grid.user_id == current_user.id))
    row = result.first()
    if not row:
        raise HTTPException(status_code=404, detail='Ordem não encontrada')
    order = row[0]
    if upd.status is not None:
        order.status = upd.status
    if upd.exchange_order_id is not None:
        order.exchange_order_id = upd.exchange_order_id
    order.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(order)
    return OrderResponse.from_orm(order)


# ── DELETE: remover todas as ordens de um grid (limpeza) ──────────────────────
@router.delete('/{grid_id}/orders')
async def delete_orders(
    grid_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    grid = await _get_grid_or_404(grid_id, current_user, db)
    result = await db.execute(
        select(GridOrder).where(GridOrder.grid_id == grid.id))
    for o in result.scalars().all():
        await db.delete(o)
    await db.commit()
    return {'detail': 'Ordens removidas'}
