*** Settings ***
Documentation     UI E2E smoke tests cobrindo fluxos visuais que escapariam do
...               smoke Vitest do painel (mudancas de CSS, deep-link admin,
...               modais de auth). Roda contra o painel servido por nginx no
...               docker-compose.e2e.yml e a API real.
...
...               Browser library headless (Chromium). Para debug local, basta
...               trocar headless=False no New Browser de ui.resource.

Library     Browser
Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/ui.resource
Resource    ../resources/keywords/empresas_api.resource

Suite Setup    Aguardar API Disponivel
Test Teardown    Fechar Browser


*** Test Cases ***
Painel publico - mapa carrega com titulo correto
    [Documentation]    Smoke basico: abre o painel anonimo, garante que o app
    ...                React monta e o mapa esta visivel com o titulo do menu.
    [Tags]    ui    smoke    e2e

    Abrir Painel Pagina Inicial
    # Validacoes minimas: titulo no menu + um botao conhecido (Telefones Uteis)
    Get Text    text="Mapa Industrial"    ==    Mapa Industrial
    Wait For Elements State    text="Telefones Úteis"    visible    timeout=${UI_SHORT_TIMEOUT}


Painel publico - filtros aparecem ao abrir painel de filtros
    [Documentation]    Click no toggle de filtros da legenda do mapa abre o
    ...                painel lateral "Filtros" com input de busca e caixa
    ...                "Empresas".
    [Tags]    ui    smoke    filtros    e2e

    Abrir Painel Pagina Inicial
    # O toggle de filtros e um botao com aria-label "Abrir Painel de Filtros"
    Click    css=button[aria-label="Abrir Painel de Filtros"]
    Wait For Elements State    text="Filtros"    visible    timeout=5s
    # Caixa de Empresas dentro do painel
    Wait For Elements State    text="Empresas"    visible    timeout=5s


Login admin - chave correta destrava tela de Gestao Empresas
    [Documentation]    Usuario anonimo tenta abrir "Empresas" no submenu de
    ...                Gestao - LoginModal aparece. Apos preencher API_KEY do
    ...                env, modal fecha e a tela de Gestao renderiza com o
    ...                titulo "Empresas Cadastradas".
    [Tags]    ui    smoke    auth    e2e

    Abrir Painel Pagina Inicial
    Logar Como Admin    tab_label=Empresas
    # Confirma que aterrissou na ManagementScreen
    Wait For Elements State    text="Empresas Cadastradas"    visible    timeout=${UI_DEFAULT_TIMEOUT}
    Wait For Elements State    text="Nova Empresa"    visible    timeout=${UI_SHORT_TIMEOUT}
