# Runbook de Deploy - Producao

Procedimento operacional para promover uma nova versao do checkin-industrial
para o ambiente de producao. Cobre as duas imagens coordenadas (API + painel),
migrations, health checks, rollback e cenarios comuns de falha.

> Para gerencia e rotacao das credenciais citadas aqui (`Auth__ApiKey`,
> `GoogleMaps__ApiKey`, `DOCKERHUB_TOKEN`), ver
> [./secrets-management.md](./secrets-management.md).

## Visao geral

O ambiente de producao roda **duas imagens Docker** coordenadas:

| Imagem | Origem | Pipeline | Endpoint observavel |
|---|---|---|---|
| `checkinindustrial/checkin-industrial-api` | repo [`checkin-industrial-api`](https://github.com/checkin-industrial/checkin-industrial-api) | `.github/workflows/publish-docker.yml` (push em `main`) | `GET /health` retorna `Healthy` |
| Bundle React do `checkin-industrial-painel` (servido por nginx) | repo [`checkin-industrial-painel`](https://github.com/checkin-industrial/checkin-industrial-painel) | build do host (Railway / outro) a partir do `npm run build` | nginx serve `/` (sem health endpoint dedicado) |

O painel e um **widget estatico**: o build (`dist/`) e servido por nginx
sem backend proprio. Toda escrita protegida passa pelo header `X-Api-Key`
contra a API, que valida `Auth__ApiKey`.

Coordenacao entre os dois e feita por **tags de imagem**: o operador define
qual tag da API esta em prod e qual revisao do painel foi publicada. Hoje
ambos sao taggeados como `latest` por default (TODO: migrar para semver).

## Pre-requisitos

### Ferramentas locais (operador)

- Acesso ao host de prod (Railway / VPS) com permissao de definir env vars
  e reiniciar servicos.
- `docker` CLI (caso o deploy seja manual via compose).
- Acesso aos secrets atuais de prod (ver [secrets-management.md](./secrets-management.md)).

### Env vars obrigatorias na API (`checkin-industrial-api`)

Tabela canonica vive em [`checkin-industrial-api/src/CLAUDE.md`](https://github.com/checkin-industrial/checkin-industrial-api/blob/main/src/CLAUDE.md#configuracao-em-produção)
- ler de la em caso de duvida. Resumo do que deve estar setado **antes** de
subir uma replica de prod:

| Env var | Notas |
|---|---|
| `ConnectionStrings__DefaultConnectionTurismo` | String de conexao do Postgres gerenciado. `Server=...;Port=5432;Database=...;User Id=...;Password=...;` |
| `Auth__ApiKey` | Chave admin (`X-Api-Key`). **Em prod, vazio aborta o startup.** Ver [secrets-management.md](./secrets-management.md). |
| `Cors__AllowedOrigins__0` | Origem do painel publico (ex: `https://painel.senailp.com.br`). **Array vazio aborta o startup em prod.** |
| `Cors__AllowedOrigins__1` | (Opcional) origens extras (ex: domain de staging, admin separado). Incrementar indice. |
| `GoogleMaps__ApiKey` | Google Places API key (ver [secrets-management.md](./secrets-management.md)). |
| `GoogleMaps__PlacesBaseUrl` | Default `https://places.googleapis.com/v1/`. So override em ambiente de teste/wiremock. |
| `GoogleMaps__AllowedRegion__LatMin` | Bound sul da regiao permitida (recomendado: ajustar pra municipio/regiao real). |
| `GoogleMaps__AllowedRegion__LatMax` | Bound norte. |
| `GoogleMaps__AllowedRegion__LngMin` | Bound oeste. |
| `GoogleMaps__AllowedRegion__LngMax` | Bound leste. |
| `GoogleMaps__MaxRaioMetros` | Raio maximo (default 1000m em prod). |
| `ASPNETCORE_ENVIRONMENT` | `Production`. |
| `UPLOADS_ROOT` | Path do volume persistente de uploads (ex: `/uploads`). |
| `PORT` | `8080` (default). |
| `Migrations__SkipOnStartup` | `true` em replicas; ver secao [Migrations](#migrations). |
| `RateLimit__AnonymousPermitPerMinute` | Default 60 (suficiente para widget publico). |
| `RateLimit__AuthenticatedPermitPerMinute` | Default 300. |
| `OutputCache__ReadEndpointTtlSeconds` | Default 60 (so abaixar em casos pontuais). |

### Env vars do painel (build-time)

| Env var | Notas |
|---|---|
| `VITE_API_BASE` | URL absoluta da API em prod (ex: `https://api.senailp.com.br/turismoindustrial_api`). Aplicado em build time - rebuild necessario se mudar. |

> A antiga `VITE_API_KEY` foi removida - a chave admin nao vai mais no bundle.
> Cada admin digita a chave no `LoginModal` (ver `checkin-industrial-painel/CLAUDE.md` -> "Auth admin").

## Checklist - Deploy normal (API)

Use este fluxo para promover uma nova versao da API que **nao quebra contrato**
com o painel atualmente publicado.

- [ ] CI em `main` do `checkin-industrial-api` verde (lint + tests + build).
- [ ] Workflow `publish-docker.yml` publicou a nova tag no Docker Hub
      (`checkinindustrial/checkin-industrial-api:<tag>`).
- [ ] Anotar a tag anterior (rollback) em algum lugar visivel (Slack do squad).
- [ ] **Aplicar migrations** com `--migrate-only` apontando pro DB de prod
      (ver [Migrations](#migrations) abaixo). Conferir exit 0.
- [ ] Atualizar `image_tag` da(s) replica(s) da API para a nova tag (Railway
      service config / `docker-compose` no host).
- [ ] Garantir que cada replica tem `Migrations__SkipOnStartup=true`.
- [ ] Restart das replicas (rolling se possivel).
- [ ] **Smoke test:** `curl https://<api-prod>/health` -> deve retornar
      `Healthy` em todas as replicas.
- [ ] Smoke do painel: abrir a URL publica, conferir mapa carregando
      (faz GET em `/api/empresas`).
- [ ] Smoke admin: logar no `LoginModal` com a `Auth__ApiKey` atual e
      executar 1 leitura admin (lista de empresas).

## Checklist - Deploy normal (painel)

- [ ] CI em `main` do `checkin-industrial-painel` verde (lint + typecheck + test + build).
- [ ] Build de prod gerado com `VITE_API_BASE` apontando pra URL real da API.
- [ ] `dist/` deploy-ado no host estatico (Railway/CDN).
- [ ] Smoke: acessar URL publica, conferir versao no bundle (hash do JS no
      DevTools muda).
- [ ] Smoke admin: `LoginModal` aceita a chave, abre tela de gestao sem 401.

## Checklist - Deploy coordenado (API + painel juntos)

Quando o mesmo PR muda contrato (DTO, query param novo, schema). O painel
construido pra versao N+1 da API quebra contra N, e vice-versa - **ordem
importa**.

- [ ] PR da **API** merge primeiro em `main`.
- [ ] Aguardar `publish-docker.yml` terminar e publicar a nova imagem.
- [ ] Verificar tag publicada em https://hub.docker.com/r/checkinindustrial/checkin-industrial-api/tags.
- [ ] **Apos confirmar imagem no Hub**, mergir PR do painel.
- [ ] Aplicar [Deploy normal (API)](#checklist---deploy-normal-api) e em
      seguida [Deploy normal (painel)](#checklist---deploy-normal-painel).

> A inversao (painel primeiro) tipicamente causa 400/404 ate a API subir.
> Em caso de janela apertada, valeria considerar feature flag no painel
> pra esconder o que ainda nao esta no backend - mas isso e debito tecnico
> futuro.

## Migrations

A API roda `db.Database.Migrate()` no startup por default. Em prod
multi-instancia, isso vira race condition. Procedimento correto:

- [ ] **Step de deploy dedicado:** rodar `dotnet AppTurismoIndustrial.Api.dll --migrate-only`
      apontando pro DB de prod. Aplica migrations e sai com exit 0 (ou nao-zero
      em falha).
- [ ] Confirmar exit code antes de prosseguir. Logs devem mostrar `Applied migration: <name>`
      ou `No migrations to apply`.
- [ ] **Em todas as replicas**: setar `Migrations__SkipOnStartup=true` (referencia:
      [PR #19 da API](https://github.com/checkin-industrial/checkin-industrial-api/pull/19)).
- [ ] So entao subir / restartar as replicas.

Em dev / single-instance, o default e suficiente. So vale a pena montar este
fluxo quando ha 2+ replicas concorrentes em prod.

## Health checks

| Servico | Endpoint | Esperado | Quem chama |
|---|---|---|---|
| API | `GET /health` | `200` + body `Healthy` (string) quando DB acessivel; `503` caso contrario | Docker / Railway / k8s probes; smoke pos-deploy |
| Painel | nginx servindo `GET /` | `200` com HTML do bundle | smoke manual; CDN/load balancer probe |

O painel **nao** tem endpoint de health dedicado (e widget estatico). Use o
proprio `/` como liveness; readiness pode ser confirmado por uma requisicao
JS (mapa carrega = bundle ok + API alcancavel).

## Rollback

Imagem Docker da API e imutavel por tag. Para reverter:

- [ ] Identificar a tag anterior (snapshot deveria estar em Slack ou
      no historico do Railway service).
- [ ] Atualizar `image_tag` das replicas para a tag anterior.
- [ ] Restart das replicas.
- [ ] Smoke: `GET /health` + chamada admin.

> Atencao: se o deploy revertido tinha aplicado migrations, **o rollback do
> codigo nao reverte o schema** automaticamente. EF Core migrations sao
> aditivas na maioria dos casos (drop de coluna usado e raro), entao
> tipicamente o rollback funciona. Em casos com drop/rename, considerar
> rollback de schema explicito ou seguir adiante com hotfix.

**TODO:** Migrar para tags semver (`v1.2.3`) em vez de `latest` - facilita
rollback e auditoria. Hoje a unica forma de "fixar versao" e congelar o
digest da imagem (`@sha256:...`).

## Observabilidade

- Logs: `docker logs <container>` (ou painel do Railway).
- Logs estruturados via `ILogger<T>` na API, categoria por feature/service.
- Sem APM / OpenTelemetry hoje (escopo de widget). Considerar Sentry/OTel
  futuro se a base de empresas crescer.
- Health: `GET /health` como probe principal.

## Cenarios comuns de falha

### API nao sobe / containers reiniciando em loop

1. **Logs:** `docker logs <container-api>` - procurar `InvalidOperationException`
   ou `Application startup exception`.
2. Causas frequentes:
   - `Auth__ApiKey` nao setado em `Production`. **A API faz fail-fast** com
     erro `Auth:ApiKey is required in Production`.
   - `Cors__AllowedOrigins__0` ausente. Mesma classe de fail-fast.
   - String de conexao invalida -> erro do Npgsql em vez de fail-fast.

### CORS bloqueando o painel (`Access-Control-Allow-Origin` no console do browser)

- Conferir `Cors__AllowedOrigins__<i>` na API. Precisa incluir o **scheme**
  (`https://painel.senailp.com.br`, nao `painel.senailp.com.br`).
- Cada origem distinta = indice separado: `__0`, `__1`, ...
- Restart da API obrigatorio apos mudar.

### DB connection falha (`/health` retorna 503)

- Conferir `ConnectionStrings__DefaultConnectionTurismo` - sintaxe Npgsql
  (`Server=...;Port=...;Database=...;User Id=...;Password=...;`).
- Conferir que o Postgres gerenciado esta UP no Railway / provider.
- Testar a string fora da app (psql / dbeaver) com as mesmas credenciais.

### 401 em writes do admin com chave correta

- Conferir que `Auth__ApiKey` em prod bate com a chave que o admin digitou
  no `LoginModal`. Apos rotacao (ver [secrets-management.md](./secrets-management.md)),
  todos os admins precisam digitar a nova chave.
- Apos atualizar a env var, **restart da API** e obrigatorio (a chave e
  cacheada em memoria pelo `ApiKeyAuthenticationHandler`).

### 429 inesperado em prod (rate limit)

- Defaults: 60/min anonimo, 300/min autenticado. Para o widget publico isso
  cobre uso normal. Se um cliente integra a API direto, considerar:
  - Subir `RateLimit__AnonymousPermitPerMinute` temporariamente.
  - Dar API key pra esse cliente (vai pro bucket de autenticado).
