*** Settings ***
Documentation     Valida o esquema de autenticacao X-Api-Key:
...               - Reads anonimos continuam acessiveis (200)
...               - Writes sem header retornam 401
...               - Writes com header invalido retornam 401
...               - Writes com header valido seguem normalmente (201/204)

Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/telefones_api.resource
Variables   ../resources/variables/env.yaml

Suite Setup    Aguardar API Disponivel


*** Test Cases ***
Read anonimo continua acessivel
    [Documentation]    GET /api/telefones-uteis sem nenhum header de auth deve retornar 200.
    [Tags]    auth    smoke    e2e
    ${response}=    GET    ${API_URL}/api/telefones-uteis    expected_status=200
    Should Be True    isinstance($response.json(), list)


Write sem X-Api-Key retorna 401
    [Documentation]    POST sem header X-Api-Key deve ser rejeitado pelo middleware
    ...                de autenticacao antes mesmo de chegar no handler.
    [Tags]    auth    smoke    e2e

    ${body}=    Create Dictionary
    ...    nome=Sem Auth Test
    ...    categoria=${1}
    ...    telefone=000
    ...    ativo=${TRUE}
    ${headers}=    Headers Sem Api Key
    ${response}=    POST    ${API_URL}/api/telefones-uteis    json=${body}    headers=${headers}    expected_status=401


Write com X-Api-Key invalido retorna 401
    [Documentation]    POST com header X-Api-Key contendo valor incorreto tambem deve ser 401.
    ...                FixedTimeEquals no handler garante constant-time check; aqui so importa o status.
    [Tags]    auth    e2e

    ${body}=    Create Dictionary
    ...    nome=Chave Errada Test
    ...    categoria=${1}
    ...    telefone=000
    ...    ativo=${TRUE}
    ${headers}=    Create Dictionary
    ...    X-Api-Key=chave-totalmente-errada-1234
    ...    Content-Type=application/json
    ${response}=    POST    ${API_URL}/api/telefones-uteis    json=${body}    headers=${headers}    expected_status=401


Write com X-Api-Key valido segue normalmente
    [Documentation]    Confirma que com a chave correta o pipeline completa (201) e a entidade
    ...                pode ser lida em seguida e removida.
    [Tags]    auth    smoke    e2e

    ${suffix}=    Sufixo Aleatorio
    ${id}=    Criar Telefone Util    nome=Auth OK ${suffix}    categoria=1    telefone=190
    ${detalhe}=    Buscar Telefone Util    ${id}
    Should Be Equal As Strings    ${detalhe['nome']}    Auth OK ${suffix}
    Deletar Telefone Util    ${id}
