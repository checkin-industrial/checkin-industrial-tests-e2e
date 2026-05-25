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

Multipart Files Para CSV
    [Documentation]    Monta o dict que o RequestsLibrary passa pro `files=` do
    ...                requests. Le o arquivo como bytes via Get Binary File e cria
    ...                a tupla (filename, content, mime) que o requests usa pra
    ...                gerar a parte multipart com o filename correto (a API valida
    ...                Path.GetExtension(file.FileName) — sem filename real, retorna
    ...                415 Unsupported Media Type).
    [Arguments]    ${file_path}
    ${content}=    Get Binary File    ${file_path}
    ${filename}=    Evaluate    __import__('os').path.basename(r'${file_path}')
    ${tuple}=    Evaluate    ($filename, $content, "text/csv")
    ${files}=    Create Dictionary    file=${tuple}
    RETURN    ${files}

Importar Empresas CSV
    [Documentation]    POST multipart de um arquivo CSV. Retorna o body JSON com
    ...                contadores (totalRecords, inserted, updated, skipped, errors).
    ...                IMPORTANTE: nao usa Headers Com Api Key porque o RequestsLibrary
    ...                precisa gerar o Content-Type multipart/form-data com boundary
    ...                automaticamente — passar Content-Type manualmente quebra o upload.
    [Arguments]    ${file_path}    ${expected_status}=200
    ${api_headers}=    Create Dictionary    X-Api-Key=${API_KEY}
    ${files}=    Multipart Files Para CSV    ${file_path}
    ${response}=    POST    ${API_URL}/api/import/empresas    files=${files}    headers=${api_headers}    expected_status=${expected_status}
    RETURN    ${response.json()}

Importar Pontos Institucionais CSV
    [Documentation]    Mesmo padrao de Importar Empresas CSV mas para pontos institucionais.
    [Arguments]    ${file_path}    ${expected_status}=200
    ${api_headers}=    Create Dictionary    X-Api-Key=${API_KEY}
    ${files}=    Multipart Files Para CSV    ${file_path}
    ${response}=    POST    ${API_URL}/api/import/pontos-institucionais    files=${files}    headers=${api_headers}    expected_status=${expected_status}
    RETURN    ${response.json()}
