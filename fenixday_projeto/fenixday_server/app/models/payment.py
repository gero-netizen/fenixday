"""
FênixDay — Re-exporta o modelo Payment do models.py central.
Mantido por compatibilidade com imports existentes.
"""

from app.models.models import Payment, PaymentStatus  # noqa: F401
