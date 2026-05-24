*** Settings ***
Library     RequestsLibrary
Library     Collections
Resource    common.resource
Variables   ../variables/env.yaml


*** Keywords ***
Criar Empresa
    [Documentation]    Cria uma empresa minima. Retorna o id gerado.
    ...                CNPJ valido por padrao para nao tropecar em validacoes futuras.
    [Arguments]    ${nome_fantasia}    ${cnpj}=${EMPTY}    ${latitude}=-23.55052    ${longitude}=-46.633308
    ${cnpj_final}=    Run Keyword If    '${cnpj}' == '${EMPTY}'    Gerar CNPJ Valido    ELSE    Set Variable    ${cnpj}
    ${body}=    Create Dictionary
    ...    cnpj=${cnpj_final}
    ...    razaoSocial=${nome_fantasia} LTDA
    ...    nomeFantasia=${nome_fantasia}
    ...    cnaePrincipal=4751201
    ...    setor=${1}
    ...    porte=${2}
    ...    numeroFuncionarios=${10}
    ...    endereco=Av Paulista, 1578
    ...    telefone=1133334444
    ...    cep=01310200
    ...    municipio=Sao Paulo
    ...    descricaoCnae=Comercio varejista de equipamentos de informatica
    ...    matrizOuFilial=${1}
    ...    latitude=${{float($latitude)}}
    ...    longitude=${{float($longitude)}}
    ...    situacaoCadastral=${1}
    ${headers}=    Headers Com Api Key
    ${response}=    POST    ${API_URL}/api/empresas    json=${body}    headers=${headers}    expected_status=201
    ${id}=    Get From Dictionary    ${response.json()}    id
    RETURN    ${id}

Buscar Empresa
    [Arguments]    ${id}
    ${response}=    GET    ${API_URL}/api/empresas/${id}    expected_status=200
    RETURN    ${response.json()}

Listar Empresas
    ${response}=    GET    ${API_URL}/api/empresas    expected_status=200
    RETURN    ${response.json()}

Filtrar Empresas
    [Documentation]    Aplica filtros opcionais (nomeFantasia, setor, porte, cnae, municipio, situacao).
    [Arguments]    &{filtros}
    ${response}=    GET    ${API_URL}/api/empresas/filter    params=${filtros}    expected_status=200
    RETURN    ${response.json()}

Buscar Vizinhos Empresa
    [Arguments]    ${id}    ${radius}=5000    ${limit}=20
    ${params}=    Create Dictionary    radius=${radius}    limit=${limit}
    ${response}=    GET    ${API_URL}/api/empresas/${id}/neighbors    params=${params}    expected_status=200
    RETURN    ${response.json()}

Deletar Empresa
    [Arguments]    ${id}
    ${headers}=    Headers Com Api Key
    DELETE    ${API_URL}/api/empresas/${id}    headers=${headers}    expected_status=204

Reativar Empresa
    [Documentation]    Reativa ou aprova uma empresa via PUT do payload completo com
    ...                `status="ativo"`. Funciona pra Inativo->Ativo (reativacao)
    ...                e AguardandoRevisao->Ativo (aprovacao pos-import).
    ...
    ...                Enums sao serializados pela API como string camelCase
    ...                (JsonStringEnumConverter). Reaproveitamos os valores do GET
    ...                direto no PUT - sem necessidade de int() casts.
    [Arguments]    ${id}
    ${empresa}=    Buscar Empresa    ${id}
    ${endereco}=   Set Variable    ${empresa.get('endereco', '') or empresa.get('Endereco', '')}
    ${cnpj_atual}=   Set Variable    ${empresa.get('cnpj', '')}
    ${body}=    Create Dictionary
    ...    cnpj=${cnpj_atual}
    ...    razaoSocial=${empresa['razaoSocial']}
    ...    nomeFantasia=${empresa['nomeFantasia']}
    ...    cnaePrincipal=${empresa['cnaePrincipal']}
    ...    setor=${empresa['setor']}
    ...    porte=${empresa['porte']}
    ...    numeroFuncionarios=${{int($empresa['numeroFuncionarios'])}}
    ...    endereco=${endereco}
    ...    telefone=${empresa.get('telefone', '')}
    ...    cep=${empresa.get('cep', '')}
    ...    municipio=${empresa['municipio']}
    ...    descricaoCnae=${empresa['descricaoCnae']}
    ...    matrizOuFilial=${empresa['matrizOuFilialCodigo']}
    ...    latitude=${{float($empresa['latitude'])}}
    ...    longitude=${{float($empresa['longitude'])}}
    ...    situacaoCadastral=${empresa['situacaoCadastral']}
    ...    status=ativo
    ${headers}=    Headers Com Api Key
    PUT    ${API_URL}/api/empresas/${id}    json=${body}    headers=${headers}    expected_status=204
