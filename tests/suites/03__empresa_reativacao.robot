*** Settings ***
Documentation     Round-trip de soft delete + reativacao de Empresa. Valida o fluxo que
...               o painel admin usa na nova feature "painel de reativacao":
...                 1. Cria empresa (ativo=true por default)
...                 2. Filtra com ?ativo=true: aparece
...                 3. Filtra com ?ativo=false: NAO aparece
...                 4. DELETE -> ativo=false
...                 5. Filtra com ?ativo=true: NAO aparece
...                 6. Filtra com ?ativo=false: aparece
...                 7. Reativar via PUT com ativo=true
...                 8. Filtra com ?ativo=true: aparece de novo
...               Cobre tambem o efeito em GetEmpresaNeighbors: empresa Ativo=false nao
...               deve aparecer como vizinha.

Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/empresas_api.resource

Suite Setup    Aguardar API Disponivel


*** Test Cases ***
Empresa - soft delete + reativacao
    [Documentation]    Ciclo completo de soft delete e reativacao de uma empresa via PUT.
    [Tags]    empresas    reativacao    e2e

    ${suffix}=    Sufixo Aleatorio
    ${nome}=    Set Variable    Reativacao Test ${suffix}
    ${id}=    Criar Empresa    nome_fantasia=${nome}

    # Recem criada esta ativa
    ${detalhe}=    Buscar Empresa    ${id}
    Should Be Equal    ${detalhe['ativo']}    ${TRUE}

    # Aparece em ?ativo=true e nao em ?ativo=false
    ${ativas}=    Filtrar Empresas    nomeFantasia=${nome}    ativo=true
    ${ids_ativas}=    Evaluate    [e['id'] for e in $ativas]
    Should Contain    ${ids_ativas}    ${id}

    ${inativas}=    Filtrar Empresas    nomeFantasia=${nome}    ativo=false
    ${ids_inativas}=    Evaluate    [e['id'] for e in $inativas]
    Should Not Contain    ${ids_inativas}    ${id}

    # Soft delete: ativo=false
    Deletar Empresa    ${id}
    ${apos_delete}=    Buscar Empresa    ${id}
    Should Be Equal    ${apos_delete['ativo']}    ${FALSE}

    # Inverte na filtragem
    ${ativas_apos}=    Filtrar Empresas    nomeFantasia=${nome}    ativo=true
    ${ids_ativas_apos}=    Evaluate    [e['id'] for e in $ativas_apos]
    Should Not Contain    ${ids_ativas_apos}    ${id}

    ${inativas_apos}=    Filtrar Empresas    nomeFantasia=${nome}    ativo=false
    ${ids_inativas_apos}=    Evaluate    [e['id'] for e in $inativas_apos]
    Should Contain    ${ids_inativas_apos}    ${id}

    # Reativacao via PUT - simula o botao "Reativar" do painel admin
    Reativar Empresa    ${id}
    ${reativada}=    Buscar Empresa    ${id}
    Should Be Equal    ${reativada['ativo']}    ${TRUE}

    # Volta a aparecer no filtro de ativas
    ${ativas_final}=    Filtrar Empresas    nomeFantasia=${nome}    ativo=true
    ${ids_final}=    Evaluate    [e['id'] for e in $ativas_final]
    Should Contain    ${ids_final}    ${id}

    # Cleanup (deixa inativa - test isolation)
    Deletar Empresa    ${id}


Empresa inativa nao aparece como vizinha
    [Documentation]    Apos soft delete de uma empresa, ela nao deve mais ser retornada
    ...                como vizinha de outra empresa (EmpresaNeighborhoodService filtra
    ...                Ativo != false).
    [Tags]    empresas    reativacao    vizinhanca    e2e

    ${suffix}=    Sufixo Aleatorio
    ${id_base}=    Criar Empresa    nome_fantasia=Vizinha Base ${suffix}    latitude=-23.55052    longitude=-46.633308
    ${id_alvo}=    Criar Empresa    nome_fantasia=Vizinha Alvo ${suffix}    latitude=-23.55100    longitude=-46.633500

    # Antes do delete: aparece como vizinha
    ${antes}=    Buscar Vizinhos Empresa    ${id_base}    radius=5000    limit=20
    ${vizinhos_antes}=    Evaluate    [v['id'] for v in $antes['empresasProximas']]
    Should Contain    ${vizinhos_antes}    ${id_alvo}

    # Soft delete da alvo
    Deletar Empresa    ${id_alvo}

    # Depois: NAO aparece mais como vizinha
    ${depois}=    Buscar Vizinhos Empresa    ${id_base}    radius=5000    limit=20
    ${vizinhos_depois}=    Evaluate    [v['id'] for v in $depois['empresasProximas']]
    Should Not Contain    ${vizinhos_depois}    ${id_alvo}

    # Cleanup
    Deletar Empresa    ${id_base}
