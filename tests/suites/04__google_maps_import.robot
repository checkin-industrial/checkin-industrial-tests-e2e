*** Settings ***
Documentation     Importacao de empresas via Google Places API (mockada via WireMock).
...               Stack roda com GoogleMaps__PlacesBaseUrl apontando para o container
...               wiremock; mappings em tests/resources/fixtures/wiremock/mappings/
...               sao montados read-only e definem respostas pre-cadastradas para o
...               endpoint /v1/places:searchNearby do Google.
...
...               Pre-requisito: API deve ter o refactor StatusEmpresa enum (api#15)
...               + feature GoogleMapsImport (api#13). Imports criam empresas com
...               Status=AguardandoRevisao (3).

Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/empresas_api.resource
Resource    ../resources/keywords/google_maps_api.resource

Suite Setup    Aguardar API Disponivel
Test Setup     Resetar WireMock


*** Variables ***
# CEP de Bauru/SP - resolve via Nominatim (real, nao mockado) para
# coordenadas dentro da AllowedRegion ampla configurada no compose.
# Constantes de StatusEmpresa vem de common.resource.
${CEP_BAURU}                    17012000


*** Test Cases ***
Import Google Maps - cria empresas com Status AguardandoRevisao
    [Documentation]    Dispara import com tipo=loja (mapping retorna 2 lugares),
    ...                valida que ambas foram criadas com Status=AguardandoRevisao,
    ...                e que aparecem no filtro ?status=aguardando-revisao.
    [Tags]    google-maps    import    e2e

    ${resultado}=    Importar Empresas Via Google Maps    cep=${CEP_BAURU}    tipo=loja
    Should Be Equal As Integers    ${resultado['encontrados']}    ${2}
    Should Be True    ${resultado['criados']} >= ${1}

    # WireMock recebeu a chamada do client da API (proof of mock-not-real)
    ${chamadas}=    Contar Chamadas WireMock Para    /v1/places:searchNearby
    Should Be True    ${chamadas} >= ${1}

    # Cada empresa criada tem Status=AguardandoRevisao (3)
    FOR    ${item}    IN    @{resultado['itens']}
        Continue For Loop If    '${item['acao']}' != 'criado'
        ${empresa}=    Buscar Empresa    ${item['empresaId']}
        Should Be Equal As Strings    ${empresa['status']}    ${STATUS_AGUARDANDO_REVISAO}
    END

    # Filtro do painel: aparecem em "aguardando revisao"
    ${pendentes}=    Filtrar Empresas    status=${FILTRO_STATUS_AGUARDANDO_REVISAO}
    Should Be True    len($pendentes) >= ${1}

    # NAO aparecem no mapa publico (filtra status=ativo)
    ${ativas}=    Filtrar Empresas    status=${FILTRO_STATUS_ATIVO}
    ${ids_pendentes}=    Evaluate    [i['empresaId'] for i in $resultado['itens'] if i['acao'] == 'criado']
    ${ids_ativas}=    Evaluate    [e['id'] for e in $ativas]
    FOR    ${id}    IN    @{ids_pendentes}
        Should Not Contain    ${ids_ativas}    ${id}
    END

    # Cleanup
    FOR    ${id}    IN    @{ids_pendentes}
        Deletar Empresa    ${id}
    END


Import Google Maps - dedup por GooglePlaceId em segundo import
    [Documentation]    Dois imports consecutivos com o mesmo mapping nao devem criar
    ...                duplicatas. O segundo enriquece campos vazios ou ignora se ja
    ...                tudo preenchido. Empresas continuam com Status=AguardandoRevisao.
    [Tags]    google-maps    import    dedup    e2e

    ${primeiro}=    Importar Empresas Via Google Maps    cep=${CEP_BAURU}    tipo=loja
    ${criados_1}=    Set Variable    ${primeiro['criados']}
    ${ids_pendentes}=    Evaluate    [i['empresaId'] for i in $primeiro['itens'] if i['acao'] == 'criado']

    Resetar WireMock

    ${segundo}=    Importar Empresas Via Google Maps    cep=${CEP_BAURU}    tipo=loja
    # Segundo import: 0 criadas, todas re-batem via GooglePlaceId
    Should Be Equal As Integers    ${segundo['criados']}    ${0}
    Should Be True    ${segundo['atualizados']} + ${segundo['ignorados']} >= ${1}

    # Cleanup
    FOR    ${id}    IN    @{ids_pendentes}
        Deletar Empresa    ${id}
    END


Import Google Maps - aprovacao promove para Status Ativo
    [Documentation]    Empresa criada via import (Status=AguardandoRevisao) deve poder
    ...                ser aprovada via PUT com status=1 (Ativo). Apos aprovada, passa
    ...                a aparecer no filtro ?status=ativo (mapa publico).
    ...
    ...                Usa tipo=supermercado pra ter GooglePlaceId distinto dos testes
    ...                anteriores (tipo=loja). Sem isso, o dedup do backend (re-import
    ...                de empresas ja existentes vira "atualizado"/"ignorado", nao
    ...                "criado") deixa o teste sem candidata fresca pra aprovar.
    [Tags]    google-maps    import    aprovacao    e2e

    ${resultado}=    Importar Empresas Via Google Maps    cep=${CEP_BAURU}    tipo=supermercado
    ${id_pendente}=    Evaluate    next(i['empresaId'] for i in $resultado['itens'] if i['acao'] == 'criado')

    # Estado inicial: AguardandoRevisao
    ${antes}=    Buscar Empresa    ${id_pendente}
    Should Be Equal As Strings    ${antes['status']}    ${STATUS_AGUARDANDO_REVISAO}

    # Admin aprova (mesma keyword usada pra reativar; envia status="ativo")
    Reativar Empresa    ${id_pendente}

    # Agora aparece no filtro publico (status=ativo)
    ${depois}=    Buscar Empresa    ${id_pendente}
    Should Be Equal As Strings    ${depois['status']}    ${STATUS_ATIVO}

    ${ativas}=    Filtrar Empresas    status=${FILTRO_STATUS_ATIVO}
    ${ids_ativas}=    Evaluate    [e['id'] for e in $ativas]
    Should Contain    ${ids_ativas}    ${id_pendente}

    # Cleanup (todas inclusive a aprovada)
    FOR    ${item}    IN    @{resultado['itens']}
        Continue For Loop If    '${item['acao']}' != 'criado'
        Deletar Empresa    ${item['empresaId']}
    END


Import Google Maps - tipo sem-filtro omite includedTypes na request
    [Documentation]    Slug "sem-filtro" deve fazer a API enviar request ao Google
    ...                Places SEM o campo includedTypes (Places API New retorna
    ...                400 se enviarmos includedTypes vazio). WireMock tem mapping
    ...                que casa absent=true em $.includedTypes — retorna 2 lugares
    ...                de tipos distintos.
    [Tags]    google-maps    import    sem-filtro    e2e

    ${resultado}=    Importar Empresas Via Google Maps    cep=${CEP_BAURU}    tipo=sem-filtro
    Should Be Equal As Integers    ${resultado['encontrados']}    ${2}
    Should Be True    ${resultado['criados']} >= ${1}

    # WireMock recebeu a chamada (proof of mapping absent=true matched)
    ${chamadas}=    Contar Chamadas WireMock Para    /v1/places:searchNearby
    Should Be True    ${chamadas} >= ${1}

    # Cleanup
    ${ids_criados}=    Evaluate    [i['empresaId'] for i in $resultado['itens'] if i['acao'] == 'criado']
    FOR    ${id}    IN    @{ids_criados}
        Deletar Empresa    ${id}
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
