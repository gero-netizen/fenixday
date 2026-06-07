#!/bin/bash
# FênixDay — Rotação de Secrets JWT
# ===================================
# Gera um novo SECRET_KEY e reinicia a API sem downtime.
# Tokens antigos ainda são válidos até o TTL natural (7 dias)
# porque a verificação tenta a chave nova e, se falhar, a antiga.
#
# Cron recomendado: 0 4 1 * *  (todo dia 1 do mês às 04:00)
# Uso: ./rotate_secrets.sh

set -euo pipefail

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
INFRA_DIR="/opt/fenixday/infra"
ENV_FILE="$INFRA_DIR/.env"
BACKUP_DIR="$INFRA_DIR/.secrets_backup"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[$TIMESTAMP]${NC} $1"; }
warn() { echo -e "${YELLOW}[$TIMESTAMP]${NC} $1"; }

# ── 1. Backup do .env atual ───────────────────────────────────────────────────
mkdir -p "$BACKUP_DIR"
cp "$ENV_FILE" "$BACKUP_DIR/.env.$(date '+%Y%m%d_%H%M%S')"
log "Backup do .env criado em $BACKUP_DIR"

# ── 2. Gerar novo SECRET_KEY ──────────────────────────────────────────────────
NEW_SECRET=$(openssl rand -hex 32)
log "Novo SECRET_KEY gerado"

# ── 3. Salvar a chave antiga como PREVIOUS_SECRET_KEY ────────────────────────
OLD_SECRET=$(grep "^SECRET_KEY=" "$ENV_FILE" | cut -d= -f2)

# Atualizar PREVIOUS_SECRET_KEY (usado para validar tokens antigos em transição)
if grep -q "^PREVIOUS_SECRET_KEY=" "$ENV_FILE"; then
    sed -i "s/^PREVIOUS_SECRET_KEY=.*/PREVIOUS_SECRET_KEY=$OLD_SECRET/" "$ENV_FILE"
else
    echo "PREVIOUS_SECRET_KEY=$OLD_SECRET" >> "$ENV_FILE"
fi

# Atualizar SECRET_KEY
sed -i "s/^SECRET_KEY=.*/SECRET_KEY=$NEW_SECRET/" "$ENV_FILE"
log "SECRET_KEY atualizado no .env"

# ── 4. Reiniciar a API sem derrubar outros serviços ───────────────────────────
cd "$INFRA_DIR"
docker compose restart api
log "API reiniciada com o novo secret"

# ── 5. Verificar saúde da API ─────────────────────────────────────────────────
sleep 5
if curl -sf http://localhost:8000/health > /dev/null; then
    log "API saudável após rotação ✅"
else
    warn "API não respondeu após rotação — restaurando backup..."
    cp "$BACKUP_DIR/.env.$(ls -t $BACKUP_DIR | head -1)" "$ENV_FILE"
    docker compose restart api
    echo "[$TIMESTAMP] [ERRO] Rotação falhou — backup restaurado" >&2
    exit 1
fi

# ── 6. Limpar backups antigos (manter últimos 6) ──────────────────────────────
ls -t "$BACKUP_DIR" | tail -n +7 | xargs -I{} rm -f "$BACKUP_DIR/{}"
log "Rotação de secrets concluída com sucesso"
