# CLAUDE.md

Guia para Claude Code (claude.ai/code) ao trabalhar neste repo.

## Contexto do ecossistema

Este repo faz parte de **4 sob `c:/git/checkin-industrial/`**:

| Repo | Papel | Stack |
|---|---|---|
| `checkin-industrial-api` | Backend .NET 10 + EF Core + Postgres com 5 features (Empresas, Pontos, Telefones, Analytics, Geocoding) | .NET 10, Minimal APIs, VSA |
| `checkin-industrial-painel` | Widget React publico + telas admin protegidas por X-Api-Key | React 19, Vite 7, TanStack Query |
| `checkin-industrial-infra` | Infraestrutura (Railway + Postgres managed) | Terraform (futuro) |
| `checkin-industrial-tests-e2e` | **Este repo** — suite Robot Framework cobrindo API end-to-end via Docker Compose | Python 3.11, Robot Framework 7.2, Allure |

### Diferenca frente aos outros 3

- **Nao eh .NET nem JS**: este eh um projeto Python. Nao tente buildar com `dotnet` ou `npm`.
- **Depende do checkin-industrial-api como pasta irma**: o `docker-compose.e2e.yml` faz build
  do Dockerfile em `../../checkin-industrial-api`. CI checa out os dois repos como siblings.
- **Sem painel**: a suite atual eh API-only (REST). UI E2E (Browser library) e PR futuro.

## Comandos

```bash
# Setup
pip install -r requirements.txt

# Stack E2E (postgres + api)
docker compose -f docker-compose/docker-compose.e2e.yml up -d --wait --build

# Health da API
curl http://localhost:8080/health    # deve retornar "Healthy"

# Rodar a suite
robot --outputdir results tests/suites/

# Filtrar por tag
robot --include smoke --outputdir results tests/suites/

# Uma suite especifica
robot --outputdir results tests/suites/01__caminho_feliz.robot

# Com Allure (precisa allure CLI + Java)
robot --listener allure_robotframework:allure-results --outputdir results tests/suites/
allure serve allure-results

# Derrubar (com -v limpa volumes — DB reset)
docker compose -f docker-compose/docker-compose.e2e.yml down -v
```

## Estrutura

```text
checkin-industrial-tests-e2e/
├── .github/workflows/e2e-tests.yml
├── docker-compose/
│   ├── docker-compose.yml          # stack dev local (api + painel)
│   ├── docker-compose.e2e.yml      # stack E2E (api so, env de teste)
│   ├── nginx.conf
│   └── painel.Dockerfile
├── tests/
│   ├── resources/
│   │   ├── variables/env.yaml      # API_URL, API_KEY, timeouts
│   │   └── keywords/
│   │       ├── common.resource     # health probe, geradores, headers
│   │       ├── empresas_api.resource
│   │       ├── pontos_api.resource
│   │       └── telefones_api.resource
│   └── suites/
│       ├── 01__caminho_feliz.robot
│       └── 02__auth_api_key.robot
├── requirements.txt
└── README.md
```

## Convencoes

### 1. Um `.resource` por feature da API

Uma feature em `checkin-industrial-api/src/Features/<X>/` = um arquivo
`tests/resources/keywords/<x>_api.resource`. Cada arquivo expoe keywords como
`Criar <X>`, `Buscar <X>`, `Listar <X>s`, `Atualizar <X>`, `Deletar <X>`.

Keywords transversais (gerar CNPJ valido, headers com/sem X-Api-Key, polling no health,
sufixo aleatorio) ficam em `common.resource`.

### 2. Keywords em portugues (dominio)

Use portugues para keywords que descrevem o dominio: `Criar Empresa`, `Buscar Vizinhos Empresa`,
`Aguardar API Disponivel`. Use ingles apenas para primitivas tecnicas do Robot/RequestsLibrary:
`Create Dictionary`, `Get From Dictionary`, `Should Be Equal As Strings`.

### 3. Sufixo aleatorio em nomes

`Sufixo Aleatorio` retorna 8 hex chars. Use em todo nome de entidade criada para evitar
colisao entre execucoes (CNPJ ja eh gerado aleatorio sempre).

### 4. Cleanup inline

Cada test deleta o que cria. Sem `Suite Teardown` global — se um teste falha no meio,
o banco fica sujo, mas o `docker compose down -v` entre runs reseta tudo. Para isolar
mais, pode-se adicionar Suite Teardown que itera por sufixos conhecidos da suite.

### 5. Health probe como Suite Setup

Toda suite tem `Suite Setup    Aguardar API Disponivel`. Esse keyword faz polling no `/health`
ate retornar `Healthy`. O healthcheck do Compose so checa TCP (porta aberta); o `/health`
real exercita o DbContextCheck (DB connection healthy).

### 6. Sem inspecao de logs/queue

A suite valida apenas **efeito observavel via REST**. Nao inspeciona logs da API nem queries
diretas ao Postgres. Se um teste precisa verificar estado intermediario, expoe via endpoint.

## Por que o `docker-compose.e2e.yml` muda env vars

| Var | Por que difere do default | Sintoma se nao mudar |
|---|---|---|
| `Auth__ApiKey` | Chave fixa que os keywords usam | Writes sem auth (em dev) ou todos os writes 401 (em prod) |
| `OutputCache__ReadEndpointTtlSeconds=0` | Default 60s mascararia mutacoes em assertions imediatas | Testes flaky/intermitentes em assertions pos-POST |
| `RateLimit__*PermitPerMinute=10000` | Defaults 60/300 muito baixos pra suite | 429 randomico depois de varios testes |
| `ASPNETCORE_ENVIRONMENT=Development` | Evita fail-fast de CORS sem origens config | API nao sobe (`InvalidOperationException` em Program.cs:101) |

## Padroes BDD (Gherkin)

A suite **nao** usa Gherkin explicito (`Given`/`When`/`Then` em portugues como em mecanica-hermes)
porque os fluxos sao curtos (CRUD simples vs. SAGA multi-etapa). Se um suite futura precisar de
fluxo longo (ex: importacao CSV → assercao de dados → exportacao), considere voltar ao estilo
Gherkin do mecanica-hermes.

## CI

Workflow `.github/workflows/e2e-tests.yml`:

- Trigger: push em `main`/`feature/**`/`refactor/**`, PR contra `main`, `workflow_dispatch`.
- Faz checkout de DOIS repos: este + `checkin-industrial-api` (ref configuravel via
  `vars.API_REF`, default `main`).
- Sobe `docker-compose.e2e.yml`, roda `robot tests/suites/`, gera Allure via CLI direta,
  publica em GitHub Pages **so em push para main**.
- Robot tem `continue-on-error: true` para garantir geracao do Allure mesmo em falha;
  o job e marcado como failure ao final por step explicito que le `steps.robot.outcome`.

GitHub Pages precisa estar **ativado manualmente** (Settings → Pages → Source: GitHub Actions ou
gh-pages branch) para o publish funcionar.

### Cross-repo checkout

O step "Checkout API repo" usa o `GITHUB_TOKEN` default. Em orgs com Actions restritas isso pode
falhar com 403. Solucao: criar um fine-grained PAT com `contents:read` no repo da API e usar como
`token: ${{ secrets.API_REPO_TOKEN }}` no checkout.

## Roadmap (suites futuras)

Ordem sugerida, do mais simples ao mais complexo:

1. **03__cnpj_duplicado**: POST empresa → POST de novo com mesmo CNPJ → 409.
2. **04__heatmap_analytics**: cria N empresas em coordenadas variadas → GET `/api/analytics/heatmap`
   → verifica pontos retornados.
3. **05__upload_imagem**: POST multipart em `/api/pontos-institucionais/upload-imagem` → confirma
   URL retornada acessivel via `GET {URL}` (testa o servidor estatico `/uploads/...`).
4. **06__importacao_empresas_csv**: POST CSV → confirma empresas criadas → GET `/exportar` retorna o
   mesmo conteudo.
5. **07__geocoding**: POST `/api/empresas/geocode` com endereco → confirma lat/long no response
   (com WireMock para Nominatim caso queira evitar dependencia externa).

A partir da suite 4 vale considerar **fixtures** (`tests/resources/fixtures/`) e talvez **WireMock**
para mockar o Nominatim (parecido com o WireMock do MP no mecanica-hermes).

## Anti-patterns que evitar

- ❌ **Hardcoded IDs** entre testes. Sempre crie a entidade no setup do test e use o id retornado.
- ❌ **`Sleep    5s`** para "esperar consistencia". Use `Wait Until Keyword Succeeds` com polling.
- ❌ **Compartilhar suite variables entre tests**. Cada test deve ser independente
  (test isolation > convenience).
- ❌ **Tocar diretamente no banco** ou ler logs internos. Valide so via API publica.
- ❌ **Test que depende de ordem de execucao**. Robot roda em ordem por default, mas dependencia
  implicita quebra cherry-picking de tests via tag.

## Troubleshooting

- **`compose up` trava na API**: confira se o postgres ficou healthy (`docker compose ps`).
  Se sim, o startup do .NET pode estar rodando migrations — aguarde ate 30s no primeiro run.
- **401 inesperado em write**: confira que `Auth__ApiKey` no compose bate com `API_KEY` em
  `tests/resources/variables/env.yaml`.
- **Assertion pos-POST falha aleatoriamente**: provavel cache de read. Confirme
  `OutputCache__ReadEndpointTtlSeconds=0`.
- **429 no meio da suite**: rate limit. Confira `RateLimit__*PermitPerMinute=10000`.
- **CI falha em "Checkout API repo"**: cross-repo permission. Veja secao "Cross-repo checkout".
