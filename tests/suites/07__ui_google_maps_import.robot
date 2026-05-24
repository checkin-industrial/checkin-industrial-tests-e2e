*** Settings ***
Documentation     UI E2E do fluxo Google Maps Import. Preenche o form via
...               browser, submete e valida que o resultado renderiza + as
...               empresas aparecem como "Aguardando revisao" na tela de
...               Gestao Empresas.
...
...               WireMock no compose responde como Google Places (ver suite
...               04 pra setup) - tipo "farmacia" devolve lista vazia, "loja"
...               devolve 2 lugares com PlaceIds estaveis.

Library     Browser
Library     Collections
Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/ui.resource
Resource    ../resources/keywords/google_maps_api.resource
Resource    ../resources/keywords/empresas_api.resource

Suite Setup    Aguardar API Disponivel
Test Setup    Resetar WireMock
Test Teardown    Fechar Browser


*** Variables ***
${CEP_BAURU}    17012000


*** Test Cases ***
Form de import dispara busca e mostra resultados
    [Documentation]    Login admin -> tela Importar do Google Maps -> preenche
    ...                CEP + raio + tipo "farmacia" -> submit -> deve mostrar
    ...                contador "Encontrados: 0" porque o mapping da farmacia
    ...                devolve vazio (sem efeito colateral no banco).
    [Tags]    ui    google-maps    import    e2e

    Abrir Painel Pagina Inicial
    Logar Como Admin    tab_label=Importar do Google Maps
    Wait For Elements State    text="Importar Empresas do Google Maps"    visible    timeout=15s

    # CEP input - placeholder "17012000" como dica
    Fill Text    css=input[placeholder="17012000"]    ${CEP_BAURU}
    # Tipo: farmacia (WireMock retorna array vazio - sem criar nada no banco)
    Select Options By    css=select    value    farmacia
    # Submit
    Click    css=button[type="submit"]

    # Resultado renderiza com header "Resultado da importação".
    # Conteudo exato (counts) e validado pela suite 04 via API - aqui so
    # confirmamos que a UI renderizou o bloco de resultados.
    Wait For Elements State    text="Resultado da importação"    visible    timeout=15s


Import com criados aparece em "Aguardando revisao" na Gestao Empresas
    [Documentation]    Login admin -> importar tipo "loja" -> WireMock devolve
    ...                2 lugares -> ambos sao criados com Status=AguardandoRevisao
    ...                -> clica em "Ir para revisar" -> redireciona pra Gestao
    ...                Empresas -> filtra aguardando-revisao -> verifica que
    ...                as empresas criadas aparecem.
    [Tags]    ui    google-maps    import    aprovacao    e2e

    Abrir Painel Pagina Inicial
    Logar Como Admin    tab_label=Importar do Google Maps
    Wait For Elements State    text="Importar Empresas do Google Maps"    visible    timeout=15s

    Fill Text    css=input[placeholder="17012000"]    ${CEP_BAURU}
    Select Options By    css=select    value    loja
    Click    css=button[type="submit"]

    Wait For Elements State    text="Resultado da importação"    visible    timeout=15s
    # "Ir para revisar" so aparece se result.criados > 0
    Wait For Elements State    text="Ir para revisar empresas aguardando aprovação"    visible    timeout=5s
    Click    text="Ir para revisar empresas aguardando aprovação"

    # Aterrissa em Gestao Empresas
    Wait For Elements State    text="Empresas Cadastradas"    visible    timeout=15s
    # Aplica filtro pra ver so AguardandoRevisao
    Aplicar Filtro Status Admin    aguardando-revisao
    # Mapping retorna "Loja E2E Alfa" e "Loja E2E Beta" - confere o primeiro
    Wait For Elements State    text="Loja E2E Alfa"    visible    timeout=10s

    # Cleanup: pega ids das empresas com GooglePlaceId conhecido e deleta
    ${ativas}=    Filtrar Empresas    nomeFantasia=Loja E2E    status=aguardando-revisao
    FOR    ${empresa}    IN    @{ativas}
        Deletar Empresa    ${empresa['id']}
    END
