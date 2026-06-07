# FênixDay — Grid Trading Bot com IA

SaaS de Grid Trading Bot para criptoativos Spot com Scanner de Inteligência Artificial.

## Stack

| Camada | Tecnologia |
|---|---|
| Frontend | Flutter 3.22 (Android / iOS / Windows / Web) |
| Backend | FastAPI + Python 3.12 |
| Banco local | SQLite via Drift |
| Banco servidor | PostgreSQL 16 |
| Cache | Redis 7 |
| Pagamentos | BTCPay Server |
| CDN/WAF | Cloudflare |
| CI/CD | GitHub Actions |

## Estrutura

```
fenixday/
├── fenixday_app/       Flutter app — todas as telas
├── fenixday_server/    Backend FastAPI — API, auth, licenças
├── fenixday_infra/     Docker Compose, Nginx, CI/CD, scripts
├── fenixday_scanner/   Scanner de IA — ADX, ATR, Bollinger, MM200
└── docs/               Documentação técnica e guia de deploy
```

## Deploy

Ver `docs/fenixday_guia_deploy.docx` para instruções completas.

## Segurança

As chaves de API das corretoras são armazenadas **exclusivamente** no dispositivo do usuário
via Android Keystore / iOS Keychain. Nunca são enviadas ao servidor.

## Licença

Proprietário — todos os direitos reservados.
