# checkin-industrial — Testes E2E

Suite end-to-end da API checkin-industrial usando **Robot Framework** + **Docker Compose**.
Roda contra a stack real (Postgres + API .NET 10) com `Auth__ApiKey` injetada via env var.

## Cobertura atual (PR1)

| Suite | Cobre | Tags |
|---|---|---|
| `01__caminho_feliz` | CRUD completo de Telefones Uteis, Empresas (criar + filtrar + vizinhanca) e Pontos Institucionais (criar + filtrar por tipo) | `smoke` `e2e` |
| `02__auth_api_key` | Read anonimo 200, write sem chave 401, write com chave invalida 401, write com chave valida 201 | `auth` `smoke` `e2e` |

Suites adicionais (CNPJ duplicado, importacao CSV, heatmap analytics, upload de imagem, geocoding)
ficam para PRs subsequentes — esta primeira leva existe pra provar a infra ponta-a-ponta.

## Pre-requisitos

- Docker 24+ com Docker Compose v2
- Python 3.11+
- Acesso ao Docker Hub (puxa `checkinindustrial/checkin-industrial-api:latest`
  automaticamente — a tag eh publicada pelo workflow `publish-docker.yml`
  do repo `checkin-industrial-api` em cada push pra `main`).

Para **testar contra codigo local** (sem precisar publicar a tag), clone o repo
da API como pasta irma e use o fallback `build:` do compose:

```
c:/git/checkin-industrial/
├── checkin-industrial-api/        (codigo local para build)
└── checkin-industrial-tests-e2e/  (este repo)
```

E rode `docker compose ... build api` antes do `up`.

## Inicio rapido

### 1. Instalar dependencias Python

```bash
pip install -r requirements.txt
```

### 2. Subir Postgres + API (pull da imagem publicada)

```bash
docker compose -f docker-compose/docker-compose.e2e.yml up -d --wait --pull always
```

> `--pull always` garante que a `:latest` no Docker Hub seja re-puxada
> evitando cache stale. `--wait` aguarda healthchecks.

### Alternativa: testar contra codigo local da API

```bash
docker compose -f docker-compose/docker-compose.e2e.yml build api
docker compose -f docker-compose/docker-compose.e2e.yml up -d --wait
```

### 3. Executar a suite

```bash
# Tudo
robot --outputdir results tests/suites/

# So smoke
robot --include smoke --outputdir results tests/suites/

# Uma suite especifica
robot --outputdir results tests/suites/01__caminho_feliz.robot
```

O report HTML padrao do Robot fica em `results/report.html`.

### 4. Derrubar

```bash
docker compose -f docker-compose/docker-compose.e2e.yml down -v
```

## Allure (relatorio rico, opcional)

Pre-requisito: **Allure CLI** instalado (Java 8+).
- Windows: `scoop install allure`
- macOS: `brew install allure`
- Linux: baixe do [GitHub Releases](https://github.com/allure-framework/allure2/releases)

```bash
robot --listener allure_robotframework:allure-results \
      --outputdir results \
      tests/suites/

allure serve allure-results
```

## Configuracao do ambiente

O `docker-compose.e2e.yml` define defaults que diferem do dev normal:

| Env var | Valor E2E | Por que |
|---|---|---|
| `Auth__ApiKey` | `e2e-api-key-checkin-industrial-2026` | Chave fixa que os keywords injetam em X-Api-Key |
| `OutputCache__ReadEndpointTtlSeconds` | `0` | Desliga cache de read; assercoes pos-mutation veriam dados stale com TTL=60s default |
| `RateLimit__AnonymousPermitPerMinute` | `10000` | Suite inteira sob 60/min default bateria 429 |
| `RateLimit__AuthenticatedPermitPerMinute` | `10000` | Idem |
| `ASPNETCORE_ENVIRONMENT` | `Development` | Evita o fail-fast de CORS em prod; CORS permanece aberto |

Override possivel via `E2E_API_KEY`, `POSTGRES_*`, `API_PORT`, `POSTGRES_PORT` no env.

## Estrutura

```text
checkin-industrial-tests-e2e/
├── .github/workflows/e2e-tests.yml   # CI: sobe stack + roda Robot + publica Allure
├── docker-compose/
│   ├── docker-compose.yml            # stack dev local (postgres + api + painel)
│   ├── docker-compose.e2e.yml        # stack E2E (postgres + api so, com env de teste)
│   ├── nginx.conf
│   └── painel.Dockerfile
├── tests/
│   ├── resources/
│   │   ├── variables/env.yaml        # URLs, API_KEY, timeouts
│   │   └── keywords/
│   │       ├── common.resource       # health probe, geradores, headers helpers
│   │       ├── empresas_api.resource
│   │       ├── pontos_api.resource
│   │       └── telefones_api.resource
│   └── suites/
│       ├── 01__caminho_feliz.robot
│       └── 02__auth_api_key.robot
├── requirements.txt
└── README.md
```

## CI

Workflow `.github/workflows/e2e-tests.yml`:

- Roda em push (`main`, `feature/**`, `refactor/**`), PR contra `main` e `workflow_dispatch`.
- Puxa `checkinindustrial/checkin-industrial-api:${API_IMAGE_TAG}` do Docker Hub (default
  `:latest`). A tag eh configuravel via variavel de repo `API_IMAGE_TAG` para fixar uma
  versao especifica (ex: `sha-abc1234`) em builds determinasticos.
- Sobe Docker Compose, roda `robot tests/suites/`, gera Allure via CLI direta, publica em
  GitHub Pages **so em push para main**.
- Robot roda com `continue-on-error: true` para garantir geracao do Allure mesmo em falha;
  o job e marcado como failure ao final via step explicito.

### Pre-requisito: imagem da API publicada

A imagem da API precisa estar disponivel em `checkinindustrial/checkin-industrial-api` no
Docker Hub. O workflow `publish-docker.yml` no repo `checkin-industrial-api` publica
automaticamente em todo push para `main` e em tags `v*.*.*`.

Para configurar o publish-docker.yml no repo da API:

1. Criar um **access token** no Docker Hub (NAO usar a senha de login):
   - Login em <https://hub.docker.com> → Account Settings → Security → New Access Token
   - Description: `github-actions-checkin-industrial-api`
   - Permissions: **Read, Write, Delete** (Delete eh opcional, mas necessario se quiser
     limpar tags antigas via workflow no futuro)

2. Adicionar secrets/vars no repo `checkin-industrial-api` (Settings → Secrets and variables → Actions):

   | Tipo | Nome | Valor |
   |---|---|---|
   | Variable | `DOCKERHUB_USERNAME` | username do Docker Hub (ex: `checkinindustrial`) |
   | Secret | `DOCKERHUB_TOKEN` | o access token gerado no passo 1 |
   | Variable | `DOCKERHUB_NAMESPACE` | (opcional) namespace se diferente do username |
   | Variable | `IMAGE_NAME` | (opcional) nome do repo no Docker Hub. Default `checkin-industrial-api` |

3. Apos o primeiro push em main, conferir que a tag apareceu em
   <https://hub.docker.com/r/checkinindustrial/checkin-industrial-api/tags>.

## Convencoes

- **Resources por feature**: um `.resource` por feature da API (`empresas_api`, `pontos_api`,
  `telefones_api`). Keywords transversais (geradores, polling, headers) ficam em `common.resource`.
- **Keywords em portugues** quando descrevem dominio (`Criar Empresa`, `Buscar Vizinhos Empresa`);
  em ingles apenas para primitivas tecnicas (`Create Dictionary`, `Set To Dictionary`).
- **Sufixo aleatorio por execucao** (`Sufixo Aleatorio`) em nomes para evitar colisao entre runs.
- **Cleanup inline no test**: o smoke deleta tudo que criou. Sem `Suite Teardown` global por
  enquanto — banco eh re-criado a cada `docker compose up` quando se passa `down -v`.
- **CNPJ valido**: `Gerar CNPJ Valido` calcula digitos verificadores. Hoje o Create da API
  so valida `\d{14}` (regex), mas o gerador valido nos blinda caso a validacao expanda.

## Troubleshooting

- **`docker compose up` trava em healthcheck da api**: a build do Dockerfile pode estar
  demorando (publish do .NET). Verifique `docker compose logs api`.
- **Robot reporta "Connection refused"**: a API ainda nao subiu. `--wait` deveria evitar
  isso; se persistir, confirme que o probe TCP esta passando (`docker compose ps`).
- **401 inesperado**: confira que `Auth__ApiKey` no compose bate com `API_KEY` em
  `tests/resources/variables/env.yaml`.
- **Output cache mascarando mutacao**: confirme `OutputCache__ReadEndpointTtlSeconds=0` no
  compose. Default da API eh 60s.

## Maturidade dos sistemas testados

- **checkin-industrial-api**: .NET 10, Vertical Slice Architecture, Auth API Key, Rate
  Limiting, Output Caching, Response Compression, Health Checks, CORS configuravel,
  CI/Dependabot. Tres features estaveis com sub-features (Importacao em Empresas e
  PontosInstitucionais).
- **checkin-industrial-painel**: React 19 + Vite 7, TanStack Query em todas as features
  de CRUD, ESLint 0 warnings, auth via LoginModal. **Nao testado neste primeiro PR** —
  testes de UI viriam num PR futuro usando Browser Library do Robot, depois que a infra
  API-only estiver provada.
