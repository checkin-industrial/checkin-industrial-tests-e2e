*** Settings ***
Documentation     Round-trip de soft delete + reativacao de Empresa via Status enum.
...               Valida o fluxo que o painel admin usa no botao "Reativar":
...                 1. Cria empresa (Status=Ativo default)
...                 2. Filtra ?status=ativo: aparece
...                 3. Filtra ?status=inativo: NAO aparece
...                 4. DELETE -> Status=Inativo
...                 5. Filtra ?status=ativo: NAO aparece
...                 6. Filtra ?status=inativo: aparece
...                 7. Reativar via PUT com status=1 (Ativo)
...                 8. Filtra ?status=ativo: aparece de novo
...               Cobre tambem o efeito em GetEmpresaNeighbors: empresa Status=Inativo
...               nao deve aparecer como vizinha.

Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/empresas_api.resource

Suite Setup    Aguardar API Disponivel


*** Variables ***
${STATUS_ATIVO}                ${{int(1)}}
${STATUS_INATIVO}              ${{int(2)}}
${STATUS_AGUARDANDO_REVISAO}   ${{int(3)}}


*** Test Cases ***
Empresa - soft delete + reativacao
    [Documentation]    Ciclo completo de soft delete e reativacao de uma empresa via PUT.
    [Tags]    empresas    reativacao    e2e

    ${suffix}=    Sufixo Aleatorio
    ${nome}=    Set Variable    Reativacao Test ${suffix}
    ${id}=    Criar Empresa    nome_fantasia=${nome}

    # Recem criada esta com Status=Ativo (1)
    ${detalhe}=    Buscar Empresa    ${id}
    Should Be Equal As Integers    ${detalhe['status']}    ${STATUS_ATIVO}

    # Aparece em ?status=ativo e nao em ?status=inativo
    ${ativas}=    Filtrar Empresas    nomeFantasia=${nome}    status=ativo
    ${ids_ativas}=    Evaluate    [e['id'] for e in $ativas]
    Should Contain    ${ids_ativas}    ${id}

    ${inativas}=    Filtrar Empresas    nomeFantasia=${nome}    status=inativo
    ${ids_inativas}=    Evaluate    [e['id'] for e in $inativas]
    Should Not Contain    ${ids_inativas}    ${id}

    # Soft delete: Status=Inativo (2)
    Deletar Empresa    ${id}
    ${apos_delete}=    Buscar Empresa    ${id}
    Should Be Equal As Integers    ${apos_delete['status']}    ${STATUS_INATIVO}

    # Inverte na filtragem
    ${ativas_apos}=    Filtrar Empresas    nomeFantasia=${nome}    status=ativo
    ${ids_ativas_apos}=    Evaluate    [e['id'] for e in $ativas_apos]
    Should Not Contain    ${ids_ativas_apos}    ${id}

    ${inativas_apos}=    Filtrar Empresas    nomeFantasia=${nome}    status=inativo
    ${ids_inativas_apos}=    Evaluate    [e['id'] for e in $inativas_apos]
    Should Contain    ${ids_inativas_apos}    ${id}

    # Reativacao via PUT - simula o botao "Reativar" do painel admin
    Reativar Empresa    ${id}
    ${reativada}=    Buscar Empresa    ${id}
    Should Be Equal As Integers    ${reativada['status']}    ${STATUS_ATIVO}

    # Volta a aparecer no filtro de ativas
    ${ativas_final}=    Filtrar Empresas    nomeFantasia=${nome}    status=ativo
    ${ids_final}=    Evaluate    [e['id'] for e in $ativas_final]
    Should Contain    ${ids_final}    ${id}

    # Cleanup (deixa inativa - test isolation)
    Deletar Empresa    ${id}


Empresa inativa nao aparece como vizinha
    [Documentation]    Apos soft delete de uma empresa, ela nao deve mais ser retornada
    ...                como vizinha de outra empresa (EmpresaNeighborhoodService filtra
    ...                Status == Ativo).
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
