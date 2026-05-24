*** Settings ***
Documentation     UI E2E: fluxo completo de gestao admin de empresas - editar
...               nome fantasia via modal de edicao, excluir (soft delete via
...               botao da linha), e reativar empresa inativa via filtro
...               "inativo" -> botao "Reativar".
...
...               Estrategia hibrida: cria empresa via API (estavel), manipula
...               via UI (cobre os fluxos do admin real). Validacao do efeito
...               combina via UI (botoes/labels visiveis) + via API REST
...               (status final no backend).

Library     Browser
Library     String
Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/ui.resource
Resource    ../resources/keywords/empresas_api.resource

Suite Setup    Aguardar API Disponivel
Test Teardown    Fechar Browser


*** Test Cases ***
Editar empresa via modal de edicao admin
    [Documentation]    Admin clica em Editar na linha da empresa, altera o
    ...                Nome Fantasia no modal e clica em "Salvar Alterações".
    ...                Modal fecha + tabela mostra o nome atualizado +
    ...                GET /api/empresas/{id} confirma a persistencia.
    [Tags]    ui    empresas    edit    e2e

    ${suffix}=    Sufixo Aleatorio
    ${nome_inicial}=    Set Variable    UI Edit Inicial ${suffix}
    ${nome_novo}=       Set Variable    UI Edit Atualizado ${suffix}
    ${id}=    Criar Empresa    nome_fantasia=${nome_inicial}

    Abrir Painel Pagina Inicial
    Logar Como Admin    tab_label=Empresas
    Wait For Elements State    text="Empresas Cadastradas"    visible    timeout=15s
    Wait For Elements State    text=${nome_inicial}    visible    timeout=10s

    # Click no Editar da linha - usa XPath ancorado no nome inicial pra
    # garantir que estamos na linha certa (evita pegar Editar de outra row).
    Click    xpath=//tr[td//strong[normalize-space()="${nome_inicial}"]]//button[normalize-space()="Editar"]
    Wait For Elements State    text="Editar Empresa"    visible    timeout=10s

    # Substitui o Nome Fantasia. Selector pelo label - input segue o label
    # textual no form. Limpa antes pra nao concatenar.
    ${input_locator}=    Set Variable    xpath=//label[contains(., "Nome Fantasia")]/input
    Fill Text    ${input_locator}    ${nome_novo}

    Click    css=button[type="submit"]

    # Modal fecha + lista re-renderiza com novo nome
    Wait For Elements State    text="Editar Empresa"    hidden    timeout=10s
    Wait For Elements State    text=${nome_novo}    visible    timeout=10s

    # Persistencia confirmada via API
    ${detalhe}=    Buscar Empresa    ${id}
    Should Be Equal As Strings    ${detalhe['nomeFantasia']}    ${nome_novo}

    # Cleanup
    Deletar Empresa    ${id}


Excluir empresa via UI: soft-delete confirmado por API
    [Documentation]    Admin clica em Excluir na linha; navegador mostra
    ...                window.confirm("Deseja realmente excluir...") que
    ...                aceitamos via Browser library; linha some do filtro
    ...                "ativo"; GET confirma Status=Inativo.
    [Tags]    ui    empresas    delete    e2e

    ${suffix}=    Sufixo Aleatorio
    ${nome}=    Set Variable    UI Delete ${suffix}
    ${id}=    Criar Empresa    nome_fantasia=${nome}

    Abrir Painel Pagina Inicial
    Logar Como Admin    tab_label=Empresas
    Wait For Elements State    text="Empresas Cadastradas"    visible    timeout=15s
    Wait For Elements State    text=${nome}    visible    timeout=10s

    # Browser library: pre-aceitar o proximo window.confirm que aparecer.
    # window.confirm e nativo - o handler nao pode esperar; tem que estar
    # armado ANTES do click. Promise rest configurada nao precisa await aqui.
    Handle Future Dialogs    action=accept

    Click    xpath=//tr[td//strong[normalize-space()="${nome}"]]//button[normalize-space()="Excluir"]

    # Filtro default "ativo": linha desaparece
    Wait For Elements State    text=${nome}    hidden    timeout=10s

    # Backend confirma soft-delete: status virou "inativo"
    ${detalhe}=    Buscar Empresa    ${id}
    Should Be Equal As Strings    ${detalhe['status']}    inativo


Reativar empresa inativa via UI: volta ao estado ativo
    [Documentation]    Empresa pre-soft-deletada via API aparece no filtro
    ...                "inativo"; admin clica "Reativar"; linha some de
    ...                "inativo" e reaparece em "ativo"; API confirma
    ...                Status=Ativo.
    [Tags]    ui    empresas    reativacao    e2e

    ${suffix}=    Sufixo Aleatorio
    ${nome}=    Set Variable    UI Reativar ${suffix}
    ${id}=    Criar Empresa    nome_fantasia=${nome}
    Deletar Empresa    ${id}

    Abrir Painel Pagina Inicial
    Logar Como Admin    tab_label=Empresas
    Wait For Elements State    text="Empresas Cadastradas"    visible    timeout=15s

    # Filtra inativos. Aguarda em 2 passos pra mitigar race entre mudanca de
    # statusFiltro -> useQuery refetch -> render:
    #   1. Espera pelo <strong> com o nome da empresa aparecer (confirma que
    #      a row da empresa entrou no DOM apos o refetch).
    #   2. Espera pelo botao Reativar dentro daquela row (confirma que a
    #      action_group renderizou).
    # Cada wait independente da uma janela de 15s, total margem >> tempo de
    # qualquer round-trip realistico do CI.
    Aplicar Filtro Status Admin    inativo
    Wait For Elements State    xpath=//strong[normalize-space()="${nome}"]    visible    timeout=15s
    ${reativar_btn}=    Set Variable    xpath=//tr[td//strong[normalize-space()="${nome}"]]//button[normalize-space()="Reativar"]
    Wait For Elements State    ${reativar_btn}    visible    timeout=15s

    Click    ${reativar_btn}

    # Sumiu do filtro inativo. Match no <strong> da row (e nao text=${nome})
    # porque a mensagem de sucesso "Empresa '<nome>' reativada com sucesso"
    # tambem contem o nome e Playwright `text=` faz substring match - o <p>
    # da mensagem nunca fica hidden, o wait nunca termina.
    Wait For Elements State    xpath=//strong[normalize-space()="${nome}"]    hidden    timeout=10s

    # Aparece no filtro ativo
    Aplicar Filtro Status Admin    ativo
    Wait For Elements State    xpath=//strong[normalize-space()="${nome}"]    visible    timeout=10s

    # API confirma status ativo
    ${detalhe}=    Buscar Empresa    ${id}
    Should Be Equal As Strings    ${detalhe['status']}    ativo

    # Cleanup
    Deletar Empresa    ${id}
