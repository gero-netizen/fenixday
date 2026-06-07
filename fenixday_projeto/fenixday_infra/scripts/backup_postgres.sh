#!/bin/bash
# FênixDay — Backup Automático do PostgreSQL
# ===========================================
# Faz dump do banco, comprime e envia para armazenamento remoto.
# Mantém os últimos 30 backups diários e 12 mensais.
#
# Pré-requisitos:
#   - rclone configurado (rclone config) com remote "b2" ou "s3"
#   - ou AWS CLI configurado para S3
#
# Cron diário: 0 2 * * * /opt/fenixday/scripts/backup_postgres.sh
# Uso: ./backup_postgres.sh [--monthly]

set -euo pipefail

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
DATE=$(date '+%Y-%m-%d')
INFRA_DIR="/opt/fenixday/infra"
BACKUP_DIR="/tmp/fenixday_backups"
LOG_FILE="/var/log/fenixday_backup.log"

# Configurações — ajustar conforme ambiente
POSTGRES_CONTAINER="fenix_postgres"
DB_NAME="${POSTGRES_DB:-fenixday}"
DB_USER="${POSTGRES_USER:-fenix}"
REMOTE_PATH="b2:fenixday-backups"   # rclone remote:bucket
RETENTION_DAILY=30
RETENTION_MONTHLY=12

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"; }
err()  { echo "[$TIMESTAMP] [ERRO] $1" | tee -a "$LOG_FILE" >&2; }

mkdir -p "$BACKUP_DIR"

# ── 1. Carregar variáveis de ambiente ─────────────────────────────────────────
if [[ -f "$INFRA_DIR/.env" ]]; then
    source "$INFRA_DIR/.env" 2>/dev/null || true
fi

# ── 2. Fazer o dump ───────────────────────────────────────────────────────────
DUMP_FILE="$BACKUP_DIR/fenixday_${TIMESTAMP}.sql.gz"

log "Iniciando backup do banco $DB_NAME..."

docker exec "$POSTGRES_CONTAINER" \
    pg_dump -U "$DB_USER" "$DB_NAME" \
    | gzip -9 > "$DUMP_FILE"

SIZE=$(du -sh "$DUMP_FILE" | cut -f1)
log "Dump criado: $DUMP_FILE ($SIZE)"

# ── 3. Verificar integridade ──────────────────────────────────────────────────
if ! gzip -t "$DUMP_FILE" 2>/dev/null; then
    err "Arquivo corrompido — backup abortado"
    rm -f "$DUMP_FILE"
    exit 1
fi
log "Integridade verificada ✅"

# ── 4. Enviar para armazenamento remoto ───────────────────────────────────────
if command -v rclone > /dev/null 2>&1; then
    log "Enviando para $REMOTE_PATH/daily/..."
    rclone copy "$DUMP_FILE" "$REMOTE_PATH/daily/" \
        --log-level INFO 2>> "$LOG_FILE"
    log "Upload concluído ✅"

    # Backup mensal (executar no dia 1 ou com --monthly)
    if [[ "${1:-}" == "--monthly" ]] || [[ "$(date '+%d')" == "01" ]]; then
        MONTHLY_NAME="fenixday_monthly_$(date '+%Y-%m').sql.gz"
        rclone copy "$DUMP_FILE" "$REMOTE_PATH/monthly/$MONTHLY_NAME" \
            2>> "$LOG_FILE"
        log "Backup mensal criado: $MONTHLY_NAME"
    fi
else
    warn "rclone não encontrado — backup salvo apenas localmente em $DUMP_FILE"
    warn "Instale com: curl https://rclone.org/install.sh | sudo bash"
fi

# ── 5. Limpar backups locais antigos ──────────────────────────────────────────
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +7 -delete
log "Arquivos locais antigos removidos"

# ── 6. Limpar backups remotos antigos ─────────────────────────────────────────
if command -v rclone > /dev/null 2>&1; then
    # Manter apenas os últimos N backups diários
    DAILY_COUNT=$(rclone ls "$REMOTE_PATH/daily/" 2>/dev/null | wc -l)
    if [[ $DAILY_COUNT -gt $RETENTION_DAILY ]]; then
        EXCESS=$((DAILY_COUNT - RETENTION_DAILY))
        log "Removendo $EXCESS backups diários antigos..."
        rclone ls "$REMOTE_PATH/daily/" 2>/dev/null \
            | sort \
            | head -n "$EXCESS" \
            | awk '{print $2}' \
            | while read -r f; do
                rclone delete "$REMOTE_PATH/daily/$f" 2>/dev/null || true
              done
    fi

    # Manter apenas os últimos N backups mensais
    MONTHLY_COUNT=$(rclone ls "$REMOTE_PATH/monthly/" 2>/dev/null | wc -l)
    if [[ $MONTHLY_COUNT -gt $RETENTION_MONTHLY ]]; then
        EXCESS=$((MONTHLY_COUNT - RETENTION_MONTHLY))
        rclone ls "$REMOTE_PATH/monthly/" 2>/dev/null \
            | sort \
            | head -n "$EXCESS" \
            | awk '{print $2}' \
            | while read -r f; do
                rclone delete "$REMOTE_PATH/monthly/$f" 2>/dev/null || true
              done
        log "Backups mensais antigos removidos"
    fi
fi

# ── 7. Relatório final ────────────────────────────────────────────────────────
log "================================================"
log "Backup concluído com sucesso!"
log "  Arquivo: $(basename $DUMP_FILE)"
log "  Tamanho: $SIZE"
log "  Destino: $REMOTE_PATH/daily/"
log "================================================"

# Limpar arquivo temporário
rm -f "$DUMP_FILE"

warn() { echo "[$TIMESTAMP] [AVISO] $1" | tee -a "$LOG_FILE"; }
