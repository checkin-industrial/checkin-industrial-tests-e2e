*** Settings ***
Documentation     Importacao de empresas via Google Places API (mockada via WireMock).
...               Stack roda com GoogleMaps__PlacesBaseUrl apontando para o container
...               wiremock; mappings em tests/resources/fixtures/wiremock/mappings/
...               sao montados read-only e definem respostas pre-cadastradas para o
...               endpoint /v1/places:searchNearby do Google.
...
...               Pre-requisito: API com pipeline de candidates (api#25). Imports
...               criam GoogleMapsImportCandidate pendentes — NAO criam Empresas
...               direto. Suite 11 cobre o fluxo de triagem (promote/reject por
...               destino) e suite 04 foca no contrato basico do endpoint de import
...               (response shape, dedup por GooglePlaceId, validacoes 400).

Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/empresas_api.resource
Resource    ../resources/keywords/google_maps_api.resource
Resource    ../resources/keywords/triagem_api.resource

Suite Setup    Aguardar API Disponivel
Test Setup     Resetar WireMock


*** Variables ***
# CEP de Bauru/SP - resolve via Nominatim (real, nao mockado) para
# coordenadas dentro da AllowedRegion ampla configurada no compose.
${CEP_BAURU}                    17012000


*** Test Cases ***
Import Google Maps - cria candidates pendentes (nao Empresas)
    [Documentation]    Dispara import com tipo=loja (mapping retorna 2 lugares).
    ...                Confirma que o response trafega contadores de candidates
    ...                e que NENHUMA empresa foi criada direto (vs fluxo antigo).
    [Tags]    google-maps    import    e2e

    ${resultado}=    Importar Empresas Via Google Maps    cep=${CEP_BAURU}    tipo=loja
    Should Be Equal As Integers    ${resultado['encontrados']}    ${2}
    Should Be True    ${resultado['candidatesCriados'] + $resultado['candidatesAtualizados']} >= ${1}

    # WireMock recebeu a chamada do client da API (proof of mock-not-real)
    ${chamadas}=    Contar Chamadas WireMock Para    /v1/places:searchNearby
    Should Be True    ${chamadas} >= ${1}

    # Itens tem candidateId (nao mais empresaId)
    FOR    ${item}    IN    @{resultado['itens']}
        Should Not Be Empty    ${item['candidateId']}
    END

    # Candidates aparecem como Pendente em todos os 3 destinos
    ${candidate_ids}=    Evaluate    [i['candidateId'] for i in $resultado['itens']]
    FOR    ${id}    IN    @{candidate_ids}
        ${c}=    Buscar Candidate Triagem    ${id}
        Should Be Equal As Strings    ${c['empresaStatus']}    pendente
        Should Be Equal As Strings    ${c['pontoStatus']}    pendente
        Should Be Equal As Strings    ${c['telefoneStatus']}    pendente
    END

    # Cleanup: rejeita pra nao deixar lixo entre runs
    FOR    ${id}    IN    @{candidate_ids}
        Rejeitar Candidate    ${id}    empresa    expected_status=ANY
        Rejeitar Candidate    ${id}    ponto       expected_status=ANY
        Rejeitar Candidate    ${id}    telefone    expected_status=ANY
    END


Import Google Maps - dedup por GooglePlaceId em segundo import
    [Documentation]    Dois imports consecutivos com o mesmo mapping nao devem criar
    ...                candidates duplicados. O segundo enriquece campos vazios ou
    ...                ignora se ja tudo preenchido.
    [Tags]    google-maps    import    dedup    e2e

    ${primeiro}=    Importar Empresas Via Google Maps    cep=${CEP_BAURU}    tipo=loja
    ${ids_primeiro}=    Evaluate    [i['candidateId'] for i in $primeiro['itens']]

    Resetar WireMock

    ${segundo}=    Importar Empresas Via Google Maps    cep=${CEP_BAURU}    tipo=loja
    # Segundo import: 0 novos criados, todos batem via GooglePlaceId
    Should Be Equal As Integers    ${segundo['candidatesCriados']}    ${0}
    Should Be True    ${segundo['candidatesAtualizados']} + ${segundo['candidatesIgnorados']} >= ${1}

    # Cleanup
    FOR    ${id}    IN    @{ids_primeiro}
        Rejeitar Candidate    ${id}    empresa    expected_status=ANY
        Rejeitar Candidate    ${id}    ponto       expected_status=ANY
        Rejeitar Candidate    ${id}    telefone    expected_status=ANY
    END


Import Google Maps - tipo sem-filtro omite includedTypes na request
    [Documentation]    Slug "sem-filtro" deve fazer a API enviar request ao Google
    ...                Places SEM o campo includedTypes. WireMock tem mapping
    ...                que casa absent=true em $.includedTypes — retorna 2 lugares
    ...                de tipos distintos.
    [Tags]    google-maps    import    sem-filtro    e2e

    ${resultado}=    Importar Empresas Via Google Maps    cep=${CEP_BAURU}    tipo=sem-filtro
    Should Be Equal As Integers    ${resultado['encontrados']}    ${2}
    Should Be True    ${resultado['candidatesCriados'] + $resultado['candidatesAtualizados']} >= ${1}

    # WireMock recebeu a chamada (proof of mapping absent=true matched)
    ${chamadas}=    Contar Chamadas WireMock Para    /v1/places:searchNearby
    Should Be True    ${chamadas} >= ${1}

    # Cleanup
    ${candidate_ids}=    Evaluate    [i['candidateId'] for i in $resultado['itens']]
    FOR    ${id}    IN    @{candidate_ids}
        Rejeitar Candidate    ${id}    empresa    expected_status=ANY
        Rejeitar Candidate    ${id}    ponto       expected_status=ANY
        Rejeitar Candidate    ${id}    telefone    expected_status=ANY
    END


Import Google Maps - tipo nao suportado retorna 400
    [Documentation]    Tipo desconhecido (nao mapeado em GooglePlaceTypeMapping)
    ...                deve retornar 400 com mensagem de ValidationException.
    [Tags]    google-maps    import    e2e

    ${body}=    Create Dictionary
    ...    cep=${CEP_BAURU}
    ...    raioMetros=${{int(800)}}
    ...    tipo=tipo-inexistente-xyz
    ${headers}=    Headers Com Api Key
    POST    ${API_URL}/api/empresas/import/google-maps    json=${body}    headers=${headers}    expected_status=400


Import Google Maps - raio acima do maximo retorna 400
    [Documentation]    MaxRaioMetros=10000 no compose. Request com raio 15000 deve
    ...                ser rejeitado antes mesmo de bater no WireMock.
    [Tags]    google-maps    import    e2e

    ${body}=    Create Dictionary
    ...    cep=${CEP_BAURU}
    ...    raioMetros=${{int(15000)}}
    ...    tipo=loja
    ${headers}=    Headers Com Api Key
    POST    ${API_URL}/api/empresas/import/google-maps    json=${body}    headers=${headers}    expected_status=400

    # Nem chegou ao WireMock
    ${chamadas}=    Contar Chamadas WireMock Para    /v1/places:searchNearby
    Should Be Equal As Integers    ${chamadas}    ${0}
