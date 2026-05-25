# Gerenciamento de Secrets

Catalogo dos secrets do ecossistema checkin-industrial, como gera-los e como
rotaciona-los com seguranca.

> Para o procedimento de deploy onde estes secrets sao consumidos, ver
> [./deploy-prod.md](./deploy-prod.md).

## Secrets do ecossistema

| Secret | Onde mora | Quem usa | Impacto se vazar |
|---|---|---|---|
| `Auth__ApiKey` | Env var da API em prod (Railway/host) | API (header `X-Api-Key` em writes) | Atacante consegue criar/editar/deletar empresas, pontos, telefones via API publica |
| `GoogleMaps__ApiKey` | Env var da API em prod | API (chamadas server-side para Google Places) | Conta de billing do GCP cobrada por terceiros; quota esgotada |
| `DOCKERHUB_TOKEN` | GitHub Secrets do repo `checkin-industrial-api` | Workflow `publish-docker.yml` (push de imagem) | Atacante publica imagem maliciosa com a tag `latest` -> infecta proximo deploy |
| `PAINEL_REF` | GitHub **vars** do repo `checkin-industrial-tests-e2e` | Workflow `e2e-tests.yml` (checkout do painel pra build do compose) | Nao e segredo (e uma `var`, nao um `secret`) - mas se redirecionado pra fork malicioso, CI publica relatorio Allure de codigo nao autorizado |
| `ConnectionStrings__DefaultConnectionTurismo` | Env var da API em prod | API (Npgsql) | Acesso total ao DB de prod (read + write + drop) |

> A separacao do GitHub entre **Secrets** (criptografados, nao visiveis em
> logs) e **Vars** (visiveis, sem mascaramento) e intencional. `PAINEL_REF`
> e ref de branch, nao credencial - por isso vive em `vars.`.

## `Auth__ApiKey` (API)

Chave admin que protege todos os endpoints de escrita da API
(POST/PUT/DELETE/Upload/Import/Export/Geocode). Validada pelo
`ApiKeyAuthenticationHandler` no header `X-Api-Key`.

### Como gerar

Opcao 1 - Linux / Mac / Git Bash (CSPRNG nativo):

```bash
openssl rand -hex 32
```

Opcao 2 - Windows PowerShell, forma criptograficamente segura (recomendado):

```powershell
[Convert]::ToHexString([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLower()
```

Opcao 3 - Windows PowerShell, forma rapida (NAO criptograficamente segura,
apenas pra ambientes dev/teste):

```powershell
[Convert]::ToHexString((1..32 | %{Get-Random -Maximum 256})).ToLower()
```

> `Get-Random` usa um PRNG seedeado por tempo - previsivel sob ataque.
> Para qualquer chave que vai pra producao, use a opcao 1 ou 2.

### Como rotacionar

- [ ] **1. Gerar nova chave** (ver acima) e guardar temporariamente em
      gerenciador de senha (1Password / Bitwarden / similar).
- [ ] **2. Comunicar a nova chave fora-de-banda** para cada admin que usa o
      painel (Slack DM, e-mail criptografado). **Nao envie por canal
      publico.** Cada admin precisa digitar a nova chave no `LoginModal`
      proximo login (a antiga deixa de funcionar apos passo 5).
- [ ] **3. Atualizar env var** `Auth__ApiKey` no host de prod
      (Railway service config / `docker-compose` env / vault). A chave **nao
      deve** ser commitada em nenhum repo.
- [ ] **4. Restart da API** (ver [deploy-prod.md](./deploy-prod.md) - secao
      "Cenarios comuns de falha" -> "401 em writes do admin"). A chave e
      cacheada em memoria; sem restart, a antiga continua valida.
- [ ] **5. Testar com a nova chave**: chamar 1 endpoint protegido
      (ex: `DELETE /api/empresas/<guid-impossivel>` deve retornar 404, nao
      401 - 401 indicaria chave errada).
- [ ] **6. Revogar a chave antiga**: removida do step 3 acima ja a invalida.
      Apagar a chave antiga do gerenciador de senha apos 24h (janela pra
      casos de admin viajando que precise voltar).

### Cadencia sugerida

- **Trimestral** em rotina (calendario).
- **Imediata** em qualquer suspeita de vazamento (commit acidental,
  screenshot, ex-funcionario com acesso, etc.).

### `.env.example` do `docker-compose/`

O arquivo [`docker-compose/.env.example`](../docker-compose/.env.example) lista
defaults **apenas pra dev local**. O valor `Auth__ApiKey` nao esta la (ainda
e injetado direto no `docker-compose.e2e.yml` via `E2E_API_KEY`, default
`e2e-api-key-checkin-industrial-2026`).

**Em producao**, `Auth__ApiKey` DEVE:

- Vir de gerenciador de secrets (Railway env vars, vault, etc.), nunca de
  arquivo commitado.
- Ser rotacionada na cadencia acima.
- Ser distinta da chave de dev (nunca usar `e2e-api-key-checkin-industrial-2026`
  em prod).

## `GoogleMaps__ApiKey` (API)

Chave do Google Cloud Platform para chamar a Places API (server-side; nunca
exposta ao browser).

### Como criar

1. Console GCP -> APIs & Services -> Credentials -> Create Credentials -> API key.
2. **Restringir a chave** (Application restrictions):
   - **Recomendado:** "IP addresses" - listar IPs estaticos do(s) host(s) que
     rodam a API (Railway tem IPs egress documentados; em VPS proprio, IP fixo).
   - Alternativa pra dev: "None" temporariamente, mas **nunca** deixar None
     em prod.
3. **Restringir as APIs** (API restrictions): selecionar apenas:
   - Places API (New) - usado pelo `GoogleMaps__PlacesBaseUrl`.
4. Habilitar billing alerts no GCP project (ex: alerta em 50% / 80% / 100%
   do budget mensal esperado).

### Como rotacionar

- [ ] Criar segunda chave no mesmo GCP project com as mesmas restricoes.
- [ ] Atualizar env var `GoogleMaps__ApiKey` no host de prod.
- [ ] Restart da API.
- [ ] Smoke test: chamar `POST /api/empresas/geocode` com um endereco real
      e conferir lat/long no response.
- [ ] **Deletar** a chave antiga no Console GCP (nao apenas desabilitar -
      delecao e auditavel).

### Como monitorar uso

- GCP Console -> APIs & Services -> Dashboard -> filtrar por API key.
- Configurar **quota** mensal alinhada ao orcamento (ex: 10k reqs/mes).
- Alerta de billing ja mencionado acima.
- Se a quota e atingida, a API recebe `RESOURCE_EXHAUSTED` do Google e os
  endpoints de geocoding falham - cliente vera erro 5xx. Importante ter
  alerta antes do limite duro.

## `DOCKERHUB_TOKEN` (CI da API)

Personal Access Token do Docker Hub com permissao **Read + Write** no
repositorio `checkinindustrial/checkin-industrial-api`. Usado pelo workflow
[`publish-docker.yml`](https://github.com/checkin-industrial/checkin-industrial-api/blob/main/.github/workflows/publish-docker.yml).

### Como gerar

1. Login em https://hub.docker.com.
2. Account Settings -> Security -> New Access Token.
3. Description: `gh-actions-checkin-industrial-api`.
4. Permissions: **Read & Write** (nao precisa Delete).
5. Copiar o token (so visivel uma vez).

### Como configurar no repo

- GitHub repo `checkin-industrial-api` -> Settings -> Secrets and variables
  -> Actions:
  - **Secret** `DOCKERHUB_TOKEN` = o token gerado.
  - **Variable** `DOCKERHUB_USERNAME` = login do Hub.
  - **Variable** `DOCKERHUB_NAMESPACE` = namespace (geralmente igual ao
    username).

### Como rotacionar

- [ ] Criar novo token no Docker Hub com a mesma permissao.
- [ ] Atualizar o secret `DOCKERHUB_TOKEN` no GitHub repo.
- [ ] Rodar workflow `publish-docker.yml` manualmente (workflow_dispatch) ou
      empurrar um commit em `main` para verificar que ainda publica.
- [ ] Revogar o token antigo em Docker Hub -> Account Settings -> Security.

### Cadencia sugerida

- Anual (tokens do Hub nao expiram por default - boa pratica de rotacao).
- Imediata se houve mudanca no time (offboarding de quem criou o token).

## `PAINEL_REF` (CI do tests-e2e)

**GitHub Variable** (nao secret) do repo `checkin-industrial-tests-e2e`. Define
qual ref do `checkin-industrial-painel` o workflow `e2e-tests.yml` faz
checkout pra incluir no build do `docker-compose.e2e.yml`.

### Configuracao normal

- Default ausente -> workflow usa `'main'` (ver linha 49 de `e2e-tests.yml`).
- Override em casos de teste cross-repo: setar `PAINEL_REF` = nome da branch
  (ex: `feat/nova-tela`) temporariamente, rodar a suite, apagar a var depois.

### Riscos

Nao e credencial, mas se setada pra apontar pra fork malicioso, o CI builda e
testa codigo nao autorizado, e o relatorio Allure publicado pode conter
dados sensiveis. Como mitigacao:

- Manter `PAINEL_REF` apenas durante o teste; remover apos uso.
- Idealmente restringir quem pode modificar variables (Settings -> Actions
  -> proteger variables a maintainers).

## `ConnectionStrings__DefaultConnectionTurismo`

String de conexao do Postgres gerenciado em prod. Forma:

```
Server=<host>;Port=5432;Database=<db>;User Id=<user>;Password=<senha>;
```

### Como rotacionar (mudanca de senha)

- [ ] No painel do provider Postgres (Railway managed / outro), gerar nova
      senha pro user de aplicacao.
- [ ] Atualizar env var `ConnectionStrings__DefaultConnectionTurismo` no
      host de prod com a nova senha.
- [ ] Restart da API (ver [deploy-prod.md](./deploy-prod.md)).
- [ ] `GET /health` deve voltar `Healthy` em todas as replicas.
- [ ] Revogar a senha antiga (se o provider mantiver historico).

### Boas praticas

- Usuario dedicado pra app (nao usar `postgres` superuser em prod).
- Permissoes minimas (DDL via migrations -> precisa de CREATE/ALTER/DROP,
  ok, mas nao precisa de SUPERUSER).
- Habilitar SSL/TLS no provider (Npgsql aceita `SSL Mode=Require` na
  connection string).

## Checklist anual de seguranca

- [ ] Rotacionar `Auth__ApiKey` (trimestral; este e o checkpoint anual).
- [ ] Rotacionar `DOCKERHUB_TOKEN`.
- [ ] Auditar lista de admins com a chave atual; revogar acessos de quem
      saiu do projeto.
- [ ] Conferir quota e billing alerts no GCP project.
- [ ] Conferir IP allowlist da `GoogleMaps__ApiKey` (host pode ter mudado IP).
- [ ] Revisar quem tem acesso ao GitHub Secrets dos repos.
