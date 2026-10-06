# FênixDay Spot — Inventário e Plano de Reconstrução

> Criado em 2026-10-06, após a perda do servidor no BattleHost (Secaucus, EUA):
> disco corrompido, máquina perdida por completo, **sem backup do banco**
> (confirmado pelo provedor). Este documento mapeia o que sobreviveu e como
> reerguer o serviço.
>
> **Boa notícia central:** quase tudo que importa é código e está no GitHub
> (`gero-netizen/fenixday`). Perdeu-se uma *instância*, não o produto. E existe
> um **Guia Completo de Deploy** (`docs/fenixday_guia_deploy.docx`) que
> documenta a montagem do zero — a reconstrução é seguir a receita, não
> redescobri-la.

---

## 1. Decisão

Reerguer o spot no **VPS brasileiro** (Feira de Santana, G7 Telecom) que já
roda o FênixDay Futures. Consolida os dois projetos numa máquina só e resolve
o bloqueio geográfico que o servidor dos EUA tinha (Bybit/Binance barram IP US).

**Fase 1 agora:** núcleo (banco + API + app + login). Leve, sobe rápido.
**Fase 2 depois:** BTCPay (Bitcoin Core + NBXplorer) — adiado, pagamentos não
são urgentes.

---

## 2. O que SOBREVIVEU (tudo no GitHub)

| Componente | Local no repo | Observação |
|---|---|---|
| App Flutter | `fenixday_app/` | Íntegro |
| Backend API (FastAPI) | `fenixday_server/app/` | models, schemas, database, main |
| **Migrations do banco** | `fenixday_server/alembic/` | `alembic upgrade head` recria tudo |
| Infra (compose, Nginx) | `fenixday_infra/` + `docker-compose-v2.yml` | Íntegro |
| Scanner | `fenixday_scanner/` | Íntegro |
| **Guia de deploy** | `docs/fenixday_guia_deploy.docx` | Passo a passo completo |
| Documentação técnica | `docs/fenixday_documentacao_tecnica_v2.docx` | Referência de arquitetura |
| Lista de segredos | `fenixday_server/.env.example` | Nomes das variáveis (sem valores) |

### Estrutura do banco (5 tabelas, recriadas pelo Alembic)
`users`, `licenses`, `subscriptions`, `payments`, `audit_logs`

---

## 3. O que SE PERDEU (precisa recriar)

### 3.1 Dados do banco — perdidos de vez
Contas de usuário, licenças, assinaturas, histórico de pagamentos, audit logs.

> **Mitigação:** as chaves de API das exchanges sempre ficaram **no dispositivo
> do usuário**, nunca no servidor. O dado mais sensível não se perdeu. Usuários
> recadastram conta e reconfiguram.

### 3.2 Segredos (`.env` — nunca estiveram no Git)
**Gerar novos:**
- `SECRET_KEY` → `openssl rand -hex 32`
- `POSTGRES_PASSWORD` → `openssl rand -base64 24`
- `REDIS_PASSWORD` → `openssl rand -base64 24`

**Recuperar das contas externas (Jeronimo tem acesso):**
- `GOOGLE_CLIENT_ID` → Google Cloud Console
- `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ZONE_ID` → conta Cloudflare

**Fase 2 (BTCPay):** `BTCPAY_API_KEY`, `BTCPAY_STORE_ID`, `BTCPAY_WEBHOOK_SECRET`

### 3.3 Infraestrutura a refazer
- Apontamento do domínio (Cloudflare → novo IP do VPS BR)
- SSL (Cloudflare Origin Certificate — recomendado pelo guia — ou Let's Encrypt)
- WAF do Cloudflare (`scripts/setup_cloudflare_waf.sh` já automatiza)
- Usuário admin inicial (script, ver Guia de Deploy §3.3)

### 3.4 ⚠️ Corrigir na reconstrução: senhas em texto puro no Git
O `docker-compose-v2.yml` tem senhas hardcoded (`rpcpassword=FenixBTC2026!`,
`FenixDB2026!` no NBXplorer/Bitcoin). O servidor velho morreu, então elas não
servem mais. Ao reconstruir: gerar novas e mover TODAS para o `.env`.

### 3.5 ⚠️ Google OAuth e o keystore do app
O guia (§5.2 e §8.2) mostra que o OAuth do Android depende do **SHA-1 do
keystore de produção**. Se o keystore `.jks` de release ainda existir (guardado
fora do servidor), o app continua atualizável e o OAuth segue válido.
**Verificar urgente se o keystore de release foi preservado** — perdê-lo
significa não conseguir publicar updates do app com a mesma identidade.

---

## 4. Serviços do stack

| Serviço | Imagem | Fase |
|---|---|---|
| postgres | postgres:16-alpine | **1** |
| redis | redis:7-alpine | **1** |
| api | FastAPI (build local) | **1** |
| nginx | nginx:1.25-alpine | **1** |
| bitcoin | btcpayserver/bitcoin:26.0 (~10GB pruned) | 2 |
| nbxplorer | nbxplorer:2.5.0 | 2 |
| btcpay | btcpayserver:1.13.0 | 2 |

---

## 5. Plano de reconstrução

### Fase 1 — Núcleo (serviço no ar)
Segue o Guia de Deploy, adaptado para o VPS BR já existente e sem BTCPay:

1. Diretório isolado no VPS BR: `/opt/fenixday-spot` (separado de
   `/opt/fenixday-futures`).
2. `git clone` do repo no VPS.
3. Docker já deve estar instalável; conferir `docker --version`.
4. Criar `.env` com segredos NOVOS (SECRET_KEY, Postgres, Redis).
5. **Compose reduzido**: subir só `postgres + redis + api + nginx`
   (sem bitcoin/nbxplorer/btcpay). Provavelmente um
   `docker-compose-core.yml` derivado do v2.
6. `docker exec fenix_api alembic upgrade head` → cria as 5 tabelas.
7. Verificar: `curl localhost:8000/health` → `{"status":"ok",...}`.
8. Criar admin (Guia §3.3).
9. Google OAuth: ajustar/confirmar client e domínio (Guia §5).
10. Cloudflare: apontar domínio para o VPS BR, rodar WAF script (Guia §6).
11. SSL: Cloudflare Origin Certificate (Guia §7 opção A).
12. Validar ponta a ponta: login, cadastro, criar grid.
13. Comunicar usuários: falha de infra, refazer login/config (chaves no app
    deles seguem válidas).

### Fase 2 — Pagamentos (quando necessário)
bitcoin (sync ~10GB) + nbxplorer + btcpay; reconfigurar store/API key/webhook
(Guia §4).

---

## 6. ⚠️ Convivência com o FênixDay Futures (CRÍTICO)

O VPS BR **já roda `fenix-collector`** (systemd), acumulando dados para a
validação da estratégia de tendência. **Não derrubar nem prejudicar o coletor.**

- Fase 1 é leve (sem Bitcoin Core) → impacto pequeno.
- Fase 2 (Bitcoin Core sincronizando) é pesada em I/O → quando for, monitorar
  o coletor (`desyncs`, disco no NVMe) e sequenciar para não competir.
- Bancos, portas e diretórios separados dos futuros.
- Recursos do spot em containers Docker; o coletor roda direto no venv.

---

## 7. Checklist de acessos

- [x] Login GitHub (gero-netizen)
- [x] Root no VPS brasileiro
- [ ] Conta **Cloudflare** (domínio)
- [ ] **Google Cloud Console** (OAuth client)
- [ ] **Keystore de release `.jks`** do app + senhas — VERIFICAR SE EXISTE
- [ ] (Fase 2) Credenciais do BTCPay

---

## 8. Hardware do VPS BR (referência)
14 núcleos, 16 GB RAM. Disco sistema 223 GB (SSD) + NVMe 476 GB dedicado
(`/mnt/futures`, ext4). Folga de sobra para hospedar spot + futuros.
