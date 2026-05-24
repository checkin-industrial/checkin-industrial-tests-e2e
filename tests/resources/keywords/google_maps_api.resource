*** Settings ***
Library     RequestsLibrary
Library     Collections
Resource    common.resource
Variables   ../variables/env.yaml


*** Variables ***
# WireMock responde no host "wiremock" dentro da rede do compose, mas o Robot roda
# fora do compose e fala HTTP direto via porta publicada. Configuravel via env
# WIREMOCK_URL_EXTERNAL caso o port mapping mude no docker-compose.e2e.yml.
${WIREMOCK_URL}    %{WIREMOCK_URL_EXTERNAL=http://localhost:8089}


*** Keywords ***
Importar Empresas Via Google Maps
    [Documentation]    Dispara o endpoint admin de import. WireMock responde como
    ...                Google Places (mappings em tests/resources/fixtures/wiremock).
    [Arguments]    ${cep}    ${raio_metros}=800    ${tipo}=loja
    ${body}=    Create Dictionary
    ...    cep=${cep}
    ...    raioMetros=${{int($raio_metros)}}
    ...    tipo=${tipo}
    ${headers}=    Headers Com Api Key
    ${response}=    POST    ${API_URL}/api/empresas/import/google-maps    json=${body}    headers=${headers}    expected_status=200
    RETURN    ${response.json()}


Resetar WireMock
    [Documentation]    Limpa todas as requests gravadas pelo WireMock (mantem mappings).
    ...                Use em test setup pra garantir contadores limpos entre testes.
    DELETE    ${WIREMOCK_URL}/__admin/requests    expected_status=200


Contar Chamadas WireMock Para
    [Documentation]    Conta quantas requests bateram numa URL especifica desde o ultimo reset.
    ...                Util pra validar que o cliente realmente chamou o Google Places.
    [Arguments]    ${url_path}
    ${body}=    Create Dictionary    method=POST    urlPath=${url_path}
    ${response}=    POST    ${WIREMOCK_URL}/__admin/requests/count    json=${body}    expected_status=200
    ${count}=    Get From Dictionary    ${response.json()}    count
    RETURN    ${count}
