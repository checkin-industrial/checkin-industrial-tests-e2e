*** Settings ***
Library     RequestsLibrary
Library     Collections
Resource    common.resource
Variables   ../variables/env.yaml


*** Keywords ***
Criar Ponto Institucional
    [Documentation]    Cria um ponto institucional minimo. Retorna o id gerado.
    [Arguments]    ${nome}    ${tipo}=1    ${latitude}=-23.55052    ${longitude}=-46.633308
    ${body}=    Create Dictionary
    ...    nome=${nome}
    ...    tipo=${tipo}
    ...    descricao=Ponto criado pela suite E2E
    ...    endereco=Av Paulista, 1000
    ...    latitude=${latitude}
    ...    longitude=${longitude}
    ...    ativo=${TRUE}
    ${headers}=    Headers Com Api Key
    ${response}=    POST    ${API_URL}/api/pontos-institucionais    json=${body}    headers=${headers}    expected_status=201
    ${id}=    Get From Dictionary    ${response.json()}    id
    RETURN    ${id}

Buscar Ponto Institucional
    [Arguments]    ${id}
    ${response}=    GET    ${API_URL}/api/pontos-institucionais/${id}    expected_status=200
    RETURN    ${response.json()}

Listar Pontos Institucionais
    [Arguments]    &{filtros}
    ${response}=    GET    ${API_URL}/api/pontos-institucionais    params=${filtros}    expected_status=200
    RETURN    ${response.json()}

Deletar Ponto Institucional
    [Arguments]    ${id}
    ${headers}=    Headers Com Api Key
    DELETE    ${API_URL}/api/pontos-institucionais/${id}    headers=${headers}    expected_status=204
