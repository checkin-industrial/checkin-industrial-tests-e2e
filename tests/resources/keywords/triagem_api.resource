*** Settings ***
Library     RequestsLibrary
Library     Collections
Resource    common.resource


*** Keywords ***
Listar Candidates Triagem
    [Documentation]    GET /api/import/candidates [?status=pendente|aprovado|rejeitado].
    ...                Sem status, retorna todos. Filtros casam contra QUALQUER destino.
    [Arguments]    ${status}=${EMPTY}
    ${headers}=    Headers Com Api Key
    ${url}=    Set Variable If    '${status}' == '${EMPTY}'
    ...    ${API_URL}/api/import/candidates
    ...    ${API_URL}/api/import/candidates?status=${status}
    ${response}=    GET    ${url}    headers=${headers}    expected_status=200
    RETURN    ${response.json()}

Buscar Candidate Triagem
    [Arguments]    ${id}
    ${headers}=    Headers Com Api Key
    ${response}=    GET    ${API_URL}/api/import/candidates/${id}    headers=${headers}    expected_status=200
    RETURN    ${response.json()}

Promover Candidate A Empresa
    [Documentation]    POST /promote-empresa. Body deve ser DTOEmpresaCriar completo
    ...                (CNPJ valido, CNAE 7 digitos, setor/porte enums, etc).
    ...                Retorna a Empresa criada.
    [Arguments]    ${candidate_id}    &{empresa_payload}
    ${headers}=    Headers Com Api Key
    ${response}=    POST    ${API_URL}/api/import/candidates/${candidate_id}/promote-empresa
    ...    json=${empresa_payload}    headers=${headers}    expected_status=201
    RETURN    ${response.json()}

Promover Candidate A Ponto
    [Documentation]    POST /promote-ponto. Body deve ser DTOPontoInstitucionalCriar
    ...                completo (tipo enum, descricao obrigatoria, etc).
    [Arguments]    ${candidate_id}    &{ponto_payload}
    ${headers}=    Headers Com Api Key
    ${response}=    POST    ${API_URL}/api/import/candidates/${candidate_id}/promote-ponto
    ...    json=${ponto_payload}    headers=${headers}    expected_status=201
    RETURN    ${response.json()}

Promover Candidate A Telefone
    [Documentation]    POST /promote-telefone. Body: nome, categoria (int 1-3), telefone.
    [Arguments]    ${candidate_id}    &{telefone_payload}
    ${headers}=    Headers Com Api Key
    ${response}=    POST    ${API_URL}/api/import/candidates/${candidate_id}/promote-telefone
    ...    json=${telefone_payload}    headers=${headers}    expected_status=201
    RETURN    ${response.json()}

Rejeitar Candidate
    [Documentation]    POST /reject?destino=empresa|ponto|telefone. Marca o destino como
    ...                Rejeitado (soft, audit-friendly).
    [Arguments]    ${candidate_id}    ${destino}    ${expected_status}=204
    ${headers}=    Headers Com Api Key
    POST    ${API_URL}/api/import/candidates/${candidate_id}/reject?destino=${destino}
    ...    headers=${headers}    expected_status=${expected_status}
