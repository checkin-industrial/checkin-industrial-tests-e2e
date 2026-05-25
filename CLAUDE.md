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
- **Painel + UI E2E**: ate a suite 04, eram so API tests (REST). A partir da 05
  (`05__ui_smoke.robot`), incluimos UI tests com Browser library / Playwright,
  rodando contra o painel buildado pelo `docker-compose.e2e.yml` (nginx em :8081).

## Comandos

```bash
# Setup
pip install -r requirements.txt
# rfbrowser baixa Chromium ~150MB local. Necessario uma unica vez.
rfbrowser init chromium

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

## Suites (estado atual)

A suite cresceu de 3 para 10 arquivos cobrindo API + UI E2E. Inventario:

| # | Arquivo | Cobertura | Tipo |
|---|---|---|---|
| 01 | `01__caminho_feliz.robot` | Smoke E2E CRUD: Telefones Uteis, Empresas (criar + filtrar + vizinhanca + delete) e Pontos Institucionais. Garante que o pipeline ponta-a-ponta esta integro. | API |
| 02 | `02__auth_api_key.robot` | Esquema X-Api-Key: read anonimo (200), write sem header (401), write com header invalido (401), write com header valido (201/204). | API |
| 03 | `03__empresa_reativacao.robot` | Ciclo soft-delete + reativacao de Empresa via Status enum (Ativo->Inativo->Ativo). Cobre tambem que empresa inativa nao aparece como vizinha. | API |
| 04 | `04__google_maps_import.robot` | Importacao via Google Places (mockada via WireMock): cria empresas com Status=AguardandoRevisao, dedup por GooglePlaceId em segundo import, aprovacao promove para Ativo, validacao de tipo nao suportado e raio acima do maximo. | API |
| 05 | `05__ui_smoke.robot` | UI smoke: painel publico carrega o mapa, painel de filtros abre, login admin destrava tela de Gestao Empresas. | UI (Browser) |
| 06 | `06__ui_empresa_lista_admin.robot` | UI: empresa criada via API aparece na lista admin; soft-delete via API esconde empresa do filtro "ativo" e mostra em "inativo". | UI (Browser) |
| 07 | `07__ui_google_maps_import.robot` | UI do fluxo Google Maps Import: form dispara busca e mostra resultados (tipo vazio); import com criados aparece em "Aguardando revisao" + botao "Ir para revisar" leva ao gestao. | UI (Browser) |
| 08 | `08__fluentvalidation_400.robot` | FluentValidation rejeita payloads invalidos com HTTP 400 ProblemDetails (RFC 7807): CNPJ malformado, CEP fora do padrao, lat/long fora de range, email invalido, campos obrigatorios vazios, etc. | API |
| 09 | `09__ui_crud_admin_completo.robot` | UI fluxo admin completo de Empresas: editar via modal, excluir (soft-delete via window.confirm), reativar empresa inativa pelo filtro "inativo" -> botao "Reativar". | UI (Browser) |
| 10 | `10__csv_import_export.robot` | Import/Export CSV de Empresas e Pontos Institucionais via endpoints admin-only `/api/import/{empresas,pontos-institucionais}/{exportar,exportar-ansi}` + POST. Cobre auth (401 sem X-Api-Key), import com fixtures dummy, export UTF-8 com BOM + ANSI sem BOM, cleanup inline. Regressao do bug do painel#43 (handler de export sem X-Api-Key). | API |

**Fixtures**: `tests/resources/fixtures/wiremock/mappings/*.json` (montados read-only no container)
e `tests/resources/fixtures/csv/*.csv` (dummy data lida pela suite 10 via `Get Binary File`
e tupla `(filename, bytes, mime)` no `files=` do RequestsLibrary — multipart precisa do
filename real porque a API valida `Path.GetExtension(file.FileName)`).
**Variables centralizadas**: `tests/resources/keywords/common.resource` (enums StatusEmpresa,
SetorEmpresa, PorteEmpresa, MatrizOuFilial, SituacaoCadastral) + `tests/resources/variables/env.yaml`
(URLs, API_KEY, timeouts UI).

## WireMock (Google Places)

A partir da suite `04__google_maps_import.robot`, o compose inclui um service `wiremock` que
simula a Google Places API. A API e configurada com `GoogleMaps__PlacesBaseUrl=http://wiremock:8080/v1/`
no `docker-compose.e2e.yml`, entao **nunca toca a API real do Google** (que cobra por chamada).

- Mappings: `tests/resources/fixtures/wiremock/mappings/*.json` (montados read-only no container).
- Cada arquivo descreve um request matcher + response JSON.
- Mappings disponiveis hoje:
  - `google-places-nearby-loja.json` - retorna 2 lugares para `includedTypes=["store"]` (usado pela suite 04 e cobre o dedup por GooglePlaceId no segundo import).
  - `google-places-nearby-farmacia-vazio.json` - retorna lista vazia para `includedTypes=["pharmacy"]` (suite 07 valida que o UI renderiza "Encontrados: 0" sem efeito colateral).
  - `google-places-nearby-supermercado.json` - retorna 1 lugar para `includedTypes=["supermarket"]` (suite 04 usa pra ter PlaceId distinto e exercitar o caminho de aprovacao).
  - `google-places-nearby-banco.json` - retorna 1 lugar "Banco UI Test Alfa" para `includedTypes=["bank"]` (suite 07 usa porque outros tipos ja tem PlaceIds gravados no banco por runs anteriores e o dedup impede criar novas — sem PlaceId fresco, `result.criados=0` e o botao "Ir para revisar" nao renderiza).
  - `google-places-nearby-sem-filtro.json` - matcher `absent=true` em `$.includedTypes` (a request sem o campo). Retorna 2 lugares de tipos distintos (restaurant + pharmacy) — exercita o caminho do slug "sem-filtro" da api#22.
- Sem matching = WireMock retorna 404 (util para testar caminhos de erro).
- Porta publica: `8089` (configuravel via `WIREMOCK_PORT`).
- Admin API do WireMock disponivel em `/__admin/` (reset de requests gravadas, contagem de chamadas, etc).
  Ver keyword `Resetar WireMock` em `google_maps_api.resource`.

Nominatim (geocodificacao de CEP) **continua sendo chamado real** pra simplificar (sem mock).
A regiao permitida (`GoogleMaps__AllowedRegion__*`) e configurada com bounds amplos no compose
pra aceitar qualquer CEP brasileiro.

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
