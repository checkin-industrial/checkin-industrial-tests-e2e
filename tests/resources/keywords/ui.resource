*** Settings ***
Documentation     Keywords compartilhadas pelas suites de UI E2E (Browser library).
...               Para suites API-level, ver common.resource + *_api.resource.

Library     Browser
Library     OperatingSystem
Variables   ../variables/env.yaml


*** Keywords ***
Abrir Painel Pagina Inicial
    [Documentation]    Abre o painel publico (mapa) em browser headless e aguarda
    ...                o titulo "Mapa Industrial" aparecer. Usar como primeiro
    ...                step de cada test UI.
    New Browser    chromium    headless=True
    New Context    viewport={'width': 1280, 'height': 800}    locale=pt-BR
    New Page    ${PAINEL_URL}
    # Aguarda o React montar - title "Check-in Industrial" indica que o JS
    # rodou e o app-shell renderizou. Margem de 30s pra startup do CI.
    Wait For Elements State    text="Mapa Industrial"    visible    timeout=${UI_LONG_TIMEOUT}


Logar Como Admin
    [Documentation]    Clica em Gestao no menu, abre LoginModal e injeta a
    ...                API_KEY do env. Apos sucesso, navega pra tela de Gestao
    ...                que foi solicitada (default: Gestao Empresas).
    [Arguments]    ${tab_label}=Empresas
    Click    text="Gestão"
    # Submenu abre - clica no tab solicitado (que dispara LoginModal porque eh admin).
    # role[name=...] e a sintaxe Playwright para combinar role com accessible name.
    Click    role=menuitem[name="${tab_label}"]
    # LoginModal: digita a key e submete
    Fill Text    css=input[type="password"]    ${API_KEY}
    Click    css=button[type="submit"]
    # Espera o modal fechar (key correta -> entra)
    Wait For Elements State    css=input[type="password"]    hidden    timeout=${UI_SHORT_TIMEOUT}


Fechar Browser
    [Documentation]    Teardown padrao - usar como Test Teardown. Se o test
    ...                falhou, captura screenshot full-page antes de fechar.
    ...                Salva em ${OUTPUT_DIR}/browser/screenshot/* e vira
    ...                artifact do CI no upload-artifact (results/).
    Run Keyword If Test Failed    Take Screenshot    fullPage=True
    Close Browser    ALL


Aplicar Filtro Status Admin
    [Documentation]    Na tela Gestao Empresas, troca o dropdown de status para
    ...                o valor solicitado e dispara o refetch do useQuery do
    ...                container. Valores aceitos: ativo, inativo,
    ...                aguardando-revisao, todos.
    ...
    ...                Workaround consciente: o painel ainda nao expoe um sinal
    ...                determinstico de "tabela recarregada" (ex: atributo
    ...                data-loading="false" no <table>). Sinais aparentes nao
    ...                funcionam:
    ...                  - .map-loading-spinner so renderiza quando empresas
    ...                    esta vazio (refetch com dados anteriores no cache
    ...                    do TanStack Query nao mostra spinner);
    ...                  - select.value sincroniza no DOM antes do retorno
    ...                    do Select Options By, entao polling nele e no-op.
    ...                O sleep de 400ms cobre o gap entre dispatch do
    ...                onChange e re-render apos o refetch. A sincronizacao
    ...                de fato fica por conta do `Wait For Elements State`
    ...                que o caller faz logo apos para o conteudo esperado
    ...                (linha visivel/oculta). Remover assim que o painel
    ...                ganhar um sinal proprio (painel#TODO).
    [Arguments]    ${status_value}
    Select Options By    css=select[aria-label="Filtro de status"]    value    ${status_value}
    Sleep    400ms
