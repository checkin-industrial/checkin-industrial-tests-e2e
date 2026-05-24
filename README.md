# checkin-industrial-tests-e2e

Suíte **end-to-end** da API [Check-in Industrial](https://github.com/checkin-industrial/checkin-industrial-docs/wiki) usando **Robot Framework** + **Docker Compose**. Roda contra a stack real (Postgres + .NET 10).

[![E2E Tests](https://github.com/checkin-industrial/checkin-industrial-tests-e2e/actions/workflows/e2e-tests.yml/badge.svg)](https://github.com/checkin-industrial/checkin-industrial-tests-e2e/actions/workflows/e2e-tests.yml)

---

📖 **Documentação completa** no [Wiki](https://github.com/checkin-industrial/checkin-industrial-docs/wiki)
📄 **Apresentação comercial**: [PDF](https://github.com/checkin-industrial/checkin-industrial-docs/blob/main/Apresentacao_Comercial_Plataforma_Industrial.pdf)
📊 **Relatório Allure** (cross-runs): <https://checkin-industrial.github.io/checkin-industrial-tests-e2e/>

## O que é

Suite Robot Framework cobrindo CRUD das 3 features de negócio + auth API Key + soft delete + reativação + filtros. Puxa a imagem oficial `checkinindustrial/checkin-industrial-api:latest` do Docker Hub — sem build local em CI.

## Cobertura

| Suite | Cobre | Tags |
|---|---|---|
| `01__caminho_feliz` | CRUD Telefones, Empresas (criar + filter + neighbors) e Pontos (criar + filtrar por tipo) | `smoke` `e2e` |
| `02__auth_api_key` | Read anônimo 200, write sem chave 401, com chave inválida 401, com chave válida 201/204 | `auth` `smoke` `e2e` |
| `03__empresa_reativacao` | Round-trip de soft delete + reativação + vizinhança filtrada por Ativo | `reativacao` `e2e` |

Roadmap de novas suites em [Wiki — Melhorias Planejadas](https://github.com/checkin-industrial/checkin-industrial-docs/wiki/Melhorias-Planejadas).

## Stack

- **Python 3.11+**
- **Robot Framework 7.2**
- **robotframework-requests** (cliente HTTP)
- **allure-robotframework** (relatórios ricos com trend cross-runs)
- **Docker Compose v2**

## Pré-requisitos

- Docker 24+ com Docker Compose v2
- Python 3.11+
- Acesso ao Docker Hub (puxa `checkinindustrial/checkin-industrial-api:latest`)

Para testar contra **código local da API** (sem precisar publicar a tag), clone o repo `checkin-industrial-api` como pasta irmã e use `docker compose ... build api`.

## Início rápido

```bash
# Setup
pip install -r requirements.txt

# Sobe stack (Postgres + API) puxando :latest do Docker Hub
docker compose -f docker-compose/docker-compose.e2e.yml up -d --wait --pull always

# Roda a suite
robot --outputdir results tests/suites/

# Tear down
docker compose -f docker-compose/docker-compose.e2e.yml down -v
```

Report HTML em `results/report.html`.

### Filtros úteis

```bash
# Apenas smoke (caminho feliz + auth)
robot --include smoke --outputdir results tests/suites/

# Apenas testes de reativação
robot --include reativacao --outputdir results tests/suites/

# Uma suite específica
robot --outputdir results tests/suites/01__caminho_feliz.robot
```

## Allure (relatório rico, opcional)

Requer **Allure CLI** instalado (Java 8+):
- Windows: `scoop install allure`
- macOS: `brew install allure`
- Linux: [GitHub Releases](https://github.com/allure-framework/allure2/releases)

```bash
robot --listener allure_robotframework:allure-results --outputdir results tests/suites/
allure serve allure-results
```

Em CI, o report é publicado automaticamente no GitHub Pages a cada push em `main`.

## Estrutura

```text
checkin-industrial-tests-e2e/
├── docker-compose/
│   ├── docker-compose.yml          (stack dev local: api + painel)
│   └── docker-compose.e2e.yml      (stack E2E: api só, env de teste)
├── tests/
│   ├── resources/
│   │   ├── variables/env.yaml      (URLs, API_KEY, timeouts)
│   │   └── keywords/
│   │       ├── common.resource     (health probe, geradores, headers)
│   │       ├── empresas_api.resource
│   │       ├── pontos_api.resource
│   │       └── telefones_api.resource
│   └── suites/
│       ├── 01__caminho_feliz.robot
│       ├── 02__auth_api_key.robot
│       └── 03__empresa_reativacao.robot
├── .github/workflows/e2e-tests.yml
├── requirements.txt
└── CLAUDE.md                        (convenções Robot detalhadas)
```

Detalhes em [`CLAUDE.md`](CLAUDE.md).

## Configuração específica do ambiente E2E

`docker-compose.e2e.yml` define defaults diferentes do dev normal:

| Env var | Valor E2E | Por quê |
|---|---|---|
| `Auth__ApiKey` | chave fixa | Os keywords injetam em `X-Api-Key` |
| `OutputCache__ReadEndpointTtlSeconds` | `0` | Desliga cache de read; senão assertions pós-mutation veriam dados stale |
| `RateLimit__*PermitPerMinute` | `10000` | Defaults 60/300 baterieam 429 com suite inteira |
| `ASPNETCORE_ENVIRONMENT` | `Development` | Evita fail-fast de CORS sem origens config |

## CI

Workflow `.github/workflows/e2e-tests.yml`:

- Trigger: push em `main`/`feature/**`/`refactor/**`, PR em `main`, `workflow_dispatch`
- Puxa `:latest` da imagem oficial → sobe stack → roda Robot → gera Allure → publica em GitHub Pages (só em push para `main`)
- Robot tem `continue-on-error: true` para garantir geração do report mesmo em falha; o job é marcado `failure` ao final via step explícito

Detalhes em [Wiki — CI/CD](https://github.com/checkin-industrial/checkin-industrial-docs/wiki/Para-Devs-CI-CD).

## Convenções

Resumo:

- **1 `.resource` por feature da API** (`empresas_api`, `pontos_api`, `telefones_api`)
- **Keywords em português** quando descrevem domínio; inglês só pra primitivas técnicas
- **Sufixo aleatório em nomes** (`Sufixo Aleatorio`) pra evitar colisão entre runs
- **CNPJ válido** (`Gerar CNPJ Valido`) calcula dígitos verificadores
- **Cleanup inline** em cada teste; `docker compose down -v` reseta entre runs
- **Sem inspeção de logs/queues** — valida só via REST

Convenções completas + anti-patterns + troubleshooting em [`CLAUDE.md`](CLAUDE.md).

## Repositórios irmãos

| Repo | Papel |
|---|---|
| [`checkin-industrial-api`](https://github.com/checkin-industrial/checkin-industrial-api) | Backend testado |
| [`checkin-industrial-painel`](https://github.com/checkin-industrial/checkin-industrial-painel) | Frontend (UI E2E é PR futuro) |
| [`checkin-industrial-docs`](https://github.com/checkin-industrial/checkin-industrial-docs) | Wiki + apresentação |
