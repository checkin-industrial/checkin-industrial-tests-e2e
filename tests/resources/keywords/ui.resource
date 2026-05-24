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
    Wait For Elements State    text="Mapa Industrial"    visible    timeout=30s


Logar Como Admin
    [Documentation]    Clica em Gestao no menu, abre LoginModal e injeta a
    ...                API_KEY do env. Apos sucesso, navega pra tela de Gestao
    ...                que foi solicitada (default: Gestao Empresas).
    [Arguments]    ${tab_label}=Empresas
    Click    text="Gestão"
    # Submenu abre - clica no tab solicitado (que dispara LoginModal porque eh admin)
    Click    role=menuitem and text="${tab_label}"
    # LoginModal: digita a key e submete
    Fill Text    css=input[type="password"]    ${API_KEY}
    Click    css=button[type="submit"]
    # Espera o modal fechar (key correta -> entra)
    Wait For Elements State    css=input[type="password"]    hidden    timeout=10s


Fechar Browser
    [Documentation]    Teardown padrao - usar como Test Teardown (ou Suite
    ...                Teardown se reusar o context entre tests).
    Close Browser    ALL
