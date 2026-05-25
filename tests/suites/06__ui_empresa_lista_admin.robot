*** Settings ***
Documentation     UI E2E: valida que a tela de Gestao Empresas reflete o estado
...               do backend - empresas criadas via API aparecem na lista,
...               soft-delete muda a visibilidade conforme o filtro de status.
...
...               Estrategia: cria via API (mais robusto que preencher form via
...               UI - selectors de form complexos sao fonte de flakiness).
...               UI so renderiza e nos so verificamos efeito visual.

Library     Browser
Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/ui.resource
Resource    ../resources/keywords/empresas_api.resource

Suite Setup    Aguardar API Disponivel
Test Teardown    Fechar Browser


*** Test Cases ***
Empresa criada via API aparece na lista admin
    [Documentation]    Cria empresa via API REST, abre tela Gestao Empresas
    ...                logado como admin, e confirma que o nome fantasia
    ...                aparece na tabela. Cleanup ao final.
    [Tags]    ui    empresas    e2e

    ${suffix}=    Sufixo Aleatorio
    ${nome}=    Set Variable    UI Test Empresa ${suffix}
    ${id}=    Criar Empresa    nome_fantasia=${nome}

    Abrir Painel Pagina Inicial
    Logar Como Admin    tab_label=Empresas
    Wait For Elements State    text="Empresas Cadastradas"    visible    timeout=${UI_DEFAULT_TIMEOUT}

    # Empresa nova esta com Status=Ativo (default) - filtro "ativo" do dropdown
    # ja vem selecionado. Nome fantasia aparece na coluna "Nome Fantasia".
    Wait For Elements State    text=${nome}    visible    timeout=${UI_SHORT_TIMEOUT}

    # Cleanup
    Deletar Empresa    ${id}


Soft-delete via API esconde empresa do filtro "ativo" e mostra em "inativo"
    [Documentation]    Cria empresa, soft-deleta via API, e valida via UI:
    ...                filtro "ativo" NAO mostra a empresa; filtro "inativo" mostra.
    ...                Cobre o caminho que o admin usa pra revisar empresas
    ...                arquivadas e potencialmente reativar.
    [Tags]    ui    empresas    soft-delete    e2e

    ${suffix}=    Sufixo Aleatorio
    ${nome}=    Set Variable    UI Soft Delete ${suffix}
    ${id}=    Criar Empresa    nome_fantasia=${nome}
    Deletar Empresa    ${id}

    Abrir Painel Pagina Inicial
    Logar Como Admin    tab_label=Empresas
    Wait For Elements State    text="Empresas Cadastradas"    visible    timeout=${UI_DEFAULT_TIMEOUT}

    # Filtro default "ativo" NAO deve listar a empresa soft-deletada
    Wait For Elements State    text=${nome}    hidden    timeout=${UI_SHORT_TIMEOUT}

    # Troca pra filtro "inativo" - deve aparecer
    Aplicar Filtro Status Admin    ${FILTRO_STATUS_INATIVO}
    Wait For Elements State    text=${nome}    visible    timeout=${UI_SHORT_TIMEOUT}
