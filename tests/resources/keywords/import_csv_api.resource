*** Settings ***
Library     RequestsLibrary
Library     Collections
Library     OperatingSystem
Resource    common.resource


*** Keywords ***
Exportar Empresas CSV
    [Documentation]    Faz GET no endpoint admin de export e retorna o objeto Response.
    ...                Endpoint exige X-Api-Key (api#21 RequireAuthorization).
    ...                Variante: ${ansi}=${TRUE} usa /exportar-ansi (Windows-1252 / Excel legacy).
    [Arguments]    ${ansi}=${FALSE}
    ${path}=    Set Variable If    ${ansi}    /api/import/empresas/exportar-ansi    /api/import/empresas/exportar
    ${headers}=    Headers Com Api Key
    ${response}=    GET    ${API_URL}${path}    headers=${headers}    expected_status=200
    RETURN    ${response}

Exportar Pontos Institucionais CSV
    [Documentation]    Mesmo padrao de Exportar Empresas CSV mas para pontos institucionais.
    [Arguments]    ${ansi}=${FALSE}
    ${path}=    Set Variable If    ${ansi}    /api/import/pontos-institucionais/exportar-ansi    /api/import/pontos-institucionais/exportar
    ${headers}=    Headers Com Api Key
    ${response}=    GET    ${API_URL}${path}    headers=${headers}    expected_status=200
    RETURN    ${response}

Importar Empresas CSV
    [Documentation]    POST multipart de um arquivo CSV. Retorna o body JSON com
    ...                contadores (totalRecords, inserted, updated, skipped, errors).
    ...                Atencao: nao usa Headers Com Api Key (Content-Type=application/json),
    ...                pois multipart precisa setar boundary automaticamente.
    [Arguments]    ${file_path}    ${expected_status}=200
    ${api_headers}=    Create Dictionary    X-Api-Key=${API_KEY}
    ${file_handle}=    Get File    ${file_path}
    ${files}=    Create Dictionary    file=${file_handle}
    ${response}=    POST    ${API_URL}/api/import/empresas    files=${files}    headers=${api_headers}    expected_status=${expected_status}
    RETURN    ${response.json()}

Importar Pontos Institucionais CSV
    [Documentation]    Mesmo padrao de Importar Empresas CSV mas para pontos institucionais.
    [Arguments]    ${file_path}    ${expected_status}=200
    ${api_headers}=    Create Dictionary    X-Api-Key=${API_KEY}
    ${file_handle}=    Get File    ${file_path}
    ${files}=    Create Dictionary    file=${file_handle}
    ${response}=    POST    ${API_URL}/api/import/pontos-institucionais    files=${files}    headers=${api_headers}    expected_status=${expected_status}
    RETURN    ${response.json()}
