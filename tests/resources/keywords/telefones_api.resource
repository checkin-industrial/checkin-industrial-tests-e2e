*** Settings ***
Library     RequestsLibrary
Library     Collections
Resource    common.resource
Variables   ../variables/env.yaml


*** Keywords ***
Criar Telefone Util
    [Documentation]    Cria um telefone util. Retorna o id gerado.
    [Arguments]    ${nome}    ${categoria}=1    ${telefone}=193
    ${body}=    Create Dictionary
    ...    nome=${nome}
    ...    categoria=${categoria}
    ...    telefone=${telefone}
    ...    ativo=${TRUE}
    ${headers}=    Headers Com Api Key
    ${response}=    POST    ${API_URL}/api/telefones-uteis    json=${body}    headers=${headers}    expected_status=201
    ${id}=    Get From Dictionary    ${response.json()}    id
    RETURN    ${id}

Buscar Telefone Util
    [Arguments]    ${id}
    ${response}=    GET    ${API_URL}/api/telefones-uteis/${id}    expected_status=200
    RETURN    ${response.json()}

Listar Telefones Uteis
    ${response}=    GET    ${API_URL}/api/telefones-uteis    expected_status=200
    RETURN    ${response.json()}

Atualizar Telefone Util
    [Arguments]    ${id}    ${nome}    ${categoria}=1    ${telefone}=193
    ${body}=    Create Dictionary
    ...    nome=${nome}
    ...    categoria=${categoria}
    ...    telefone=${telefone}
    ...    ativo=${TRUE}
    ${headers}=    Headers Com Api Key
    PUT    ${API_URL}/api/telefones-uteis/${id}    json=${body}    headers=${headers}    expected_status=204

Deletar Telefone Util
    [Arguments]    ${id}
    ${headers}=    Headers Com Api Key
    DELETE    ${API_URL}/api/telefones-uteis/${id}    headers=${headers}    expected_status=204
