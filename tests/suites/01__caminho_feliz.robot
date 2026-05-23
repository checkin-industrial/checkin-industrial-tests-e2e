*** Settings ***
Documentation     Smoke E2E cobrindo as 3 features de CRUD da API: Telefones Uteis, Empresas
...               e Pontos Institucionais. Cria, le, filtra, busca vizinhanca e deleta — prova
...               que o pipeline ponta-a-ponta (Postgres + .NET 10 + EF Core + X-Api-Key + output
...               cache desligado) esta integro.

Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/empresas_api.resource
Resource    ../resources/keywords/pontos_api.resource
Resource    ../resources/keywords/telefones_api.resource

Suite Setup    Aguardar API Disponivel


*** Test Cases ***
Telefones Uteis - CRUD completo
    [Documentation]    Cria → busca por id → lista → atualiza → confirma update → deleta → confirma deletado.
    [Tags]    telefones    smoke    e2e

    ${suffix}=    Sufixo Aleatorio
    ${nome}=    Set Variable    Bombeiros E2E ${suffix}
    ${id}=    Criar Telefone Util    nome=${nome}    categoria=1    telefone=193

    ${detalhe}=    Buscar Telefone Util    ${id}
    Should Be Equal As Strings    ${detalhe['nome']}    ${nome}
    Should Be Equal As Strings    ${detalhe['telefone']}    193

    ${todos}=    Listar Telefones Uteis
    ${ids}=    Evaluate    [t['id'] for t in $todos]
    Should Contain    ${ids}    ${id}

    Atualizar Telefone Util    ${id}    nome=${nome} atualizado    categoria=1    telefone=193
    ${atualizado}=    Buscar Telefone Util    ${id}
    Should Be Equal As Strings    ${atualizado['nome']}    ${nome} atualizado

    # DELETE em Telefones eh soft delete (TelefoneUtilService.RemoverAsync seta Ativo=false).
    # Por isso o GET segue retornando 200 e o ativo vira false.
    Deletar Telefone Util    ${id}
    ${depois}=    Buscar Telefone Util    ${id}
    Should Be Equal    ${depois['ativo']}    ${FALSE}


Empresas - Criar, filtrar e buscar vizinhos
    [Documentation]    Cria duas empresas em coordenadas proximas e valida que a busca de vizinhos
    ...                retorna a segunda como vizinha da primeira. Cobre filter + neighbors + delete.
    [Tags]    empresas    smoke    e2e

    ${suffix}=    Sufixo Aleatorio
    ${nome_base}=    Set Variable    Empresa Base ${suffix}
    ${nome_vizinha}=    Set Variable    Empresa Vizinha ${suffix}

    ${id_base}=    Criar Empresa    nome_fantasia=${nome_base}    latitude=-23.55052    longitude=-46.633308
    ${id_vizinha}=    Criar Empresa    nome_fantasia=${nome_vizinha}    latitude=-23.55100    longitude=-46.633500

    ${filtradas}=    Filtrar Empresas    nomeFantasia=${nome_base}
    ${nomes_filtrados}=    Evaluate    [e['nomeFantasia'] for e in $filtradas]
    Should Contain    ${nomes_filtrados}    ${nome_base}

    ${vizinhanca}=    Buscar Vizinhos Empresa    ${id_base}    radius=5000    limit=20
    Should Be Equal As Strings    ${vizinhanca['empresaBase']['id']}    ${id_base}
    ${ids_vizinhos}=    Evaluate    [v['id'] for v in $vizinhanca['empresasProximas']]
    Should Contain    ${ids_vizinhos}    ${id_vizinha}

    Deletar Empresa    ${id_base}
    Deletar Empresa    ${id_vizinha}
    GET    ${API_URL}/api/empresas/${id_base}    expected_status=404


Pontos Institucionais - CRUD com filtro por tipo
    [Documentation]    Cria dois pontos de tipos diferentes, lista filtrando por tipo, deleta.
    [Tags]    pontos    smoke    e2e

    ${suffix}=    Sufixo Aleatorio
    ${nome_hotel}=    Set Variable    Hotel Teste ${suffix}
    ${nome_educacao}=    Set Variable    Escola Teste ${suffix}

    # 7 = Hotel, 1 = Educacao (TipoPontoInstitucional)
    ${id_hotel}=    Criar Ponto Institucional    nome=${nome_hotel}    tipo=7
    ${id_educacao}=    Criar Ponto Institucional    nome=${nome_educacao}    tipo=1

    ${apenas_hotel}=    Listar Pontos Institucionais    tipo=hotel
    ${nomes}=    Evaluate    [p['nome'] for p in $apenas_hotel]
    Should Contain    ${nomes}    ${nome_hotel}
    Should Not Contain    ${nomes}    ${nome_educacao}

    Deletar Ponto Institucional    ${id_hotel}
    Deletar Ponto Institucional    ${id_educacao}
