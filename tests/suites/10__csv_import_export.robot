*** Settings ***
Documentation     Cobertura E2E para os endpoints CSV de Empresas e Pontos
...               Institucionais. Todos os 6 endpoints sao admin-only
...               (RequireAuthorization em Importacao{Empresas,PontosInstitucionais}Module.cs).
...
...               Cenarios:
...                 - Import: upload de CSV valido -> totalRecords/inserted/updated/skipped/errors
...                 - Export UTF-8: GET retorna text/csv + Content-Disposition + BOM
...                 - Export ANSI: GET retorna text/csv (Windows-1252)
...                 - Auth: GET sem X-Api-Key retorna 401
...
...               Bug corrigido pelo painel#43: handleExportCsv usava fetch direto
...               sem X-Api-Key e quebrava em prod. A suite mantem cobertura de
...               regressao no contrato da API (validacao do header obrigatorio).

Library     RequestsLibrary
Library     Collections
Library     OperatingSystem
Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/empresas_api.resource
Resource    ../resources/keywords/import_csv_api.resource

Suite Setup    Aguardar API Disponivel


*** Variables ***
${EMPRESAS_CSV_FIXTURE}    ${CURDIR}/../resources/fixtures/csv/empresas-import-sample.csv
${PONTOS_CSV_FIXTURE}      ${CURDIR}/../resources/fixtures/csv/pontos-import-sample.csv


*** Test Cases ***
Empresas - Import CSV com 2 linhas validas
    [Documentation]    Upload de CSV com 2 empresas valids. Espera totalRecords=2
    ...                e inserted=2 (banco zerado entre runs) ou updated=2 (re-run).
    [Tags]    csv    empresas    e2e

    ${result}=    Importar Empresas CSV    ${EMPRESAS_CSV_FIXTURE}
    Should Be Equal As Integers    ${result['totalRecords']}    ${2}
    ${processados}=    Evaluate    ${result['inserted']} + ${result['updated']}
    Should Be Equal As Integers    ${processados}    ${2}
    Should Be Equal As Integers    ${result['skipped']}    ${0}
    Length Should Be    ${result['errors']}    ${0}

    # Cleanup: deleta as 2 empresas pra evitar lixo entre runs
    ${response}=    GET    ${API_URL}/api/empresas/filter?status=todos    expected_status=200
    ${empresas}=    Set Variable    ${response.json()}
    FOR    ${empresa}    IN    @{empresas}
        Continue For Loop If    'CSV Teste' not in $empresa.get('nomeFantasia', '')
        Deletar Empresa    ${empresa['id']}
    END


Empresas - Export CSV UTF-8 retorna text/csv com Content-Disposition
    [Documentation]    GET /api/import/empresas/exportar com X-Api-Key:
    ...                Content-Type text/csv, header Content-Disposition presente,
    ...                body comeca com BOM (UTF-8) seguido do header CSV.
    [Tags]    csv    empresas    e2e

    ${response}=    Exportar Empresas CSV    ansi=${FALSE}
    Should Contain    ${response.headers['Content-Type']}    text/csv
    Should Contain    ${response.headers['Content-Disposition']}    .csv
    # CSV UTF-8 BOM (EF BB BF) -> string comeca com ﻿ em python
    Should Start With    ${response.text}    ﻿CNPJ


Empresas - Export CSV ANSI retorna text/csv sem BOM
    [Documentation]    Variante Windows-1252: mesmo content-type mas sem BOM.
    [Tags]    csv    empresas    e2e

    ${response}=    Exportar Empresas CSV    ansi=${TRUE}
    Should Contain    ${response.headers['Content-Type']}    text/csv
    Should Contain    ${response.headers['Content-Disposition']}    .csv
    # ANSI nao tem BOM -> primeiro char eh o "C" do header CNPJ
    Should Start With    ${response.text}    CNPJ


Empresas - Export CSV sem X-Api-Key retorna 401
    [Documentation]    Bug que motivou painel#43: o handler usava fetch direto
    ...                sem header. Aqui validamos o contrato: sem X-Api-Key, 401.
    [Tags]    csv    empresas    auth    e2e

    GET    ${API_URL}/api/import/empresas/exportar    expected_status=401


Empresas - Import CSV sem X-Api-Key retorna 401
    [Documentation]    Equivalente do anterior pro endpoint de POST.
    [Tags]    csv    empresas    auth    e2e

    ${file_handle}=    Get File    ${EMPRESAS_CSV_FIXTURE}
    ${files}=    Create Dictionary    file=${file_handle}
    POST    ${API_URL}/api/import/empresas    files=${files}    expected_status=401


Pontos Institucionais - Import CSV com 2 linhas validas
    [Documentation]    Upload com 2 pontos institucionais. Banco zerado entre runs
    ...                tipicamente -> 2 inserted; em re-run vira updated (dedup
    ...                por nome+endereco+tipo conforme ImportPontosInstitucionais.cs).
    [Tags]    csv    pontos    e2e

    ${result}=    Importar Pontos Institucionais CSV    ${PONTOS_CSV_FIXTURE}
    Should Be Equal As Integers    ${result['totalRecords']}    ${2}
    ${processados}=    Evaluate    ${result['inserted']} + ${result['updated']}
    Should Be Equal As Integers    ${processados}    ${2}
    Should Be Equal As Integers    ${result['skipped']}    ${0}
    Length Should Be    ${result['errors']}    ${0}

    # Cleanup: deleta os 2 pontos via API normal (soft delete -> Ativo=false)
    ${response}=    GET    ${API_URL}/api/pontos-institucionais    expected_status=200
    ${pontos}=    Set Variable    ${response.json()}
    ${headers}=    Headers Com Api Key
    FOR    ${ponto}    IN    @{pontos}
        Continue For Loop If    'CSV Teste' not in $ponto.get('nome', '')
        DELETE    ${API_URL}/api/pontos-institucionais/${ponto['id']}    headers=${headers}    expected_status=204
    END


Pontos Institucionais - Export CSV UTF-8 retorna text/csv com BOM
    [Documentation]    Equivalente do export de Empresas. Header esperado: Id;Nome;...
    [Tags]    csv    pontos    e2e

    ${response}=    Exportar Pontos Institucionais CSV    ansi=${FALSE}
    Should Contain    ${response.headers['Content-Type']}    text/csv
    Should Contain    ${response.headers['Content-Disposition']}    .csv
    Should Start With    ${response.text}    ﻿Id


Pontos Institucionais - Export CSV sem X-Api-Key retorna 401
    [Documentation]    Mesma validacao de contrato auth-required.
    [Tags]    csv    pontos    auth    e2e

    GET    ${API_URL}/api/import/pontos-institucionais/exportar    expected_status=401
