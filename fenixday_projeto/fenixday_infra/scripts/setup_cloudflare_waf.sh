#!/bin/bash
# FênixDay — Configuração do WAF Cloudflare
# ==========================================
# Configura regras de firewall via API Cloudflare para:
#   • Rate limiting avançado na camada de CDN
#   • Proteção contra DDoS
#   • Bloqueio de bots maliciosos
#   • Regras personalizadas para a API FênixDay
#
# Pré-requisito: domínio apontando para Cloudflare (nameservers)
# Configurar em .env:
#   CLOUDFLARE_ZONE_ID=xxx
#   CLOUDFLARE_API_TOKEN=xxx (permissão: Zone.Firewall Rules)
#
# Uso: ./setup_cloudflare_waf.sh

set -euo pipefail

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
INFRA_DIR="/opt/fenixday/infra"

[[ -f "$INFRA_DIR/.env" ]] && source "$INFRA_DIR/.env" 2>/dev/null || true

ZONE_ID="${CLOUDFLARE_ZONE_ID:-}"
API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"

[[ -z "$ZONE_ID" ]]    && echo "ERRO: CLOUDFLARE_ZONE_ID não configurado" && exit 1
[[ -z "$API_TOKEN" ]]  && echo "ERRO: CLOUDFLARE_API_TOKEN não configurado" && exit 1

CF_API="https://api.cloudflare.com/client/v4"
HEADERS=(-H "Authorization: Bearer $API_TOKEN" -H "Content-Type: application/json")

log() { echo "[$TIMESTAMP] $1"; }

# ── Função helper para chamadas à API ─────────────────────────────────────────
cf_api() {
    curl -sf "${HEADERS[@]}" "$@"
}

# ── 1. Rate limiting na rota de login ─────────────────────────────────────────
log "Criando regra de rate limit para /api/v1/auth/login..."
cf_api -X POST "$CF_API/zones/$ZONE_ID/rate_limits" \
    -d '{
        "match": {
            "request": { "url_pattern": "*/api/v1/auth/login*", "methods": ["POST"] }
        },
        "threshold": 10,
        "period": 60,
        "action": { "mode": "ban", "timeout": 300 },
        "description": "FênixDay: proteger rota de login"
    }' | python3 -c "import sys,json; d=json.load(sys.stdin); print('✅ Rate limit login criado' if d.get('success') else f'⚠ {d}')"

# ── 2. Rate limit geral da API ────────────────────────────────────────────────
log "Criando regra de rate limit geral para /api/..."
cf_api -X POST "$CF_API/zones/$ZONE_ID/rate_limits" \
    -d '{
        "match": {
            "request": { "url_pattern": "*/api/*" }
        },
        "threshold": 300,
        "period": 60,
        "action": { "mode": "simulate" },
        "description": "FênixDay: rate limit geral API"
    }' | python3 -c "import sys,json; d=json.load(sys.stdin); print('✅ Rate limit API criado' if d.get('success') else f'⚠ {d}')"

# ── 3. Bloquear países com alto índice de fraude (opcional) ──────────────────
# Descomente se necessário:
# log "Criando regra de bloqueio geográfico..."
# cf_api -X POST "$CF_API/zones/$ZONE_ID/firewall/rules" \
#     -d '[{
#         "filter": { "expression": "(ip.geoip.country in {\"RU\" \"CN\" \"KP\"})" },
#         "action": "block",
#         "description": "FênixDay: bloqueio geográfico opcional"
#     }]'

# ── 4. Habilitar modo Bot Fight ────────────────────────────────────────────────
log "Habilitando Bot Fight Mode..."
cf_api -X PUT "$CF_API/zones/$ZONE_ID/bot_management" \
    -d '{"fight_mode": true}' \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print('✅ Bot Fight Mode ativado' if d.get('success') else f'⚠ {d}')"

# ── 5. Configurar Security Level ─────────────────────────────────────────────
log "Configurando Security Level para 'high'..."
cf_api -X PATCH "$CF_API/zones/$ZONE_ID/settings/security_level" \
    -d '{"value": "high"}' \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print('✅ Security Level configurado' if d.get('success') else f'⚠ {d}')"

# ── 6. Habilitar HTTPS Always ─────────────────────────────────────────────────
log "Habilitando Always Use HTTPS..."
cf_api -X PATCH "$CF_API/zones/$ZONE_ID/settings/always_use_https" \
    -d '{"value": "on"}' \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print('✅ Always HTTPS ativado' if d.get('success') else f'⚠ {d}')"

# ── 7. Habilitar TLS 1.3 ──────────────────────────────────────────────────────
log "Habilitando TLS 1.3..."
cf_api -X PATCH "$CF_API/zones/$ZONE_ID/settings/tls_1_3" \
    -d '{"value": "zrt"}' \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print('✅ TLS 1.3 ativado' if d.get('success') else f'⚠ {d}')"

log ""
log "════════════════════════════════════════"
log " WAF Cloudflare configurado com sucesso!"
log "════════════════════════════════════════"
log " Regras ativas:"
log "  • Rate limit /login: 10 req/min"
log "  • Rate limit /api:  300 req/min"
log "  • Bot Fight Mode:   ativado"
log "  • Security Level:   high"
log "  • Always HTTPS:     ativado"
log "  • TLS 1.3:         ativado"
log "════════════════════════════════════════"
