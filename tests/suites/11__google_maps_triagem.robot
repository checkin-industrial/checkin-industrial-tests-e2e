*** Settings ***
Documentation     Cobertura E2E do pipeline de triagem de imports Google Maps (api#25).
...
...               Fluxo: import via Google Maps cria CANDIDATES (nao Empresas).
...               Admin promove individualmente cada candidato pra Empresa/Ponto/
...               Telefone (ou rejeita por destino). Os 3 destinos sao independentes.
...
...               Pre-requisitos:
...                 - api com a feature de candidates merged (api#25)
...                 - WireMock mappings (google-places-nearby-loja.json) — retorna 2 lugares

Library     RequestsLibrary
Library     Collections
Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/empresas_api.resource
Resource    ../resources/keywords/google_maps_api.resource
Resource    ../resources/keywords/triagem_api.resource

Suite Setup    Aguardar API Disponivel
Test Setup     Resetar WireMock


*** Variables ***
${CEP_BAURU}    17012000


*** Test Cases ***
Triagem - Import cria candidates pendentes em todos os destinos
    [Documentation]    Import via Google Maps com tipo=loja deve criar candidates
    ...                com EmpresaStatus/PontoStatus/TelefoneStatus = Pendente.
    ...                Empresas/Pontos/Telefones nao sao criados direto.
    [Tags]    triagem    google-maps    e2e

    ${resultado}=    Importar Empresas Via Google Maps    cep=${CEP_BAURU}    tipo=loja
    Should Be Equal As Integers    ${resultado['encontrados']}    ${2}
    Should Be True    ${resultado['candidatesCriados'] + $resultado['candidatesAtualizados']} >= ${1}

    # Cada item retornado tem candidateId (nao mais empresaId)
    FOR    ${item}    IN    @{resultado['itens']}
        Should Not Be Empty    ${item['candidateId']}
    END

    # Candidates aparecem na lista de triagem
    ${candidates}=    Listar Candidates Triagem    status=pendente
    Should Be True    len($candidates) >= ${1}

    # Cleanup: rejeita os 3 destinos pra todos os candidates dessa rodada
    FOR    ${c}    IN    @{candidates}
        Continue For Loop If    '${c['nome']}' != 'Loja E2E Alfa' and '${c['nome']}' != 'Loja E2E Beta'
        Rejeitar Candidate    ${c['id']}    empresa    expected_status=ANY
        Rejeitar Candidate    ${c['id']}    ponto       expected_status=ANY
        Rejeitar Candidate    ${c['id']}    telefone    expected_status=ANY
    END


Triagem - Promover candidate a Empresa cria empresa + marca decidido
    [Documentation]    Promotion cria Empresa Ativo (nao AguardandoRevisao) e
    ...                atualiza candidate.empresaStatus=Aprovado + empresaId.
    [Tags]    triagem    promotion    empresa    e2e

    ${resultado}=    Importar Empresas Via Google Maps    cep=${CEP_BAURU}    tipo=loja
    ${candidate_id}=    Evaluate    next(i['candidateId'] for i in $resultado['itens'])

    ${cnpj}=    Gerar CNPJ Valido
    ${empresa_payload}=    Create Dictionary
    ...    cnpj=${cnpj}
    ...    razaoSocial=Loja Triada LTDA
    ...    nomeFantasia=Loja Triada
    ...    cnaePrincipal=4751201
    ...    setor=comercio
    ...    porte=me
    ...    numeroFuncionarios=${5}
    ...    endereco=Av Comercio, 100
    ...    telefone=1433330000
    ...    cep=17012000
    ...    municipio=Bauru
    ...    descricaoCnae=Comercio varejista
    ...    matrizOuFilial=matriz
    ...    latitude=${-22.31470}
    ...    longitude=${-49.06060}
    ...    situacaoCadastral=ativa

    ${empresa}=    Promover Candidate A Empresa    ${candidate_id}    &{empresa_payload}
    Should Not Be Empty    ${empresa['id']}

    # Candidate marcado como Aprovado/empresaId, demais destinos continuam pendentes
    ${atualizado}=    Buscar Candidate Triagem    ${candidate_id}
    Should Be Equal As Strings    ${atualizado['empresaStatus']}    aprovado
    Should Be Equal As Strings    ${atualizado['empresaId']}    ${empresa['id']}
    Should Be Equal As Strings    ${atualizado['pontoStatus']}    pendente
    Should Be Equal As Strings    ${atualizado['telefoneStatus']}    pendente

    # Cleanup
    Deletar Empresa    ${empresa['id']}
    Rejeitar Candidate    ${candidate_id}    ponto       expected_status=ANY
    Rejeitar Candidate    ${candidate_id}    telefone    expected_status=ANY


Triagem - Mesmo candidate pode virar Empresa E Ponto simultaneamente
    [Documentation]    Validation do design: decisoes por destino sao INDEPENDENTES.
    ...                Mesmo candidato pode ser Empresa + Ponto + (rejeitado como Telefone).
    [Tags]    triagem    promotion    multi-destino    e2e

    ${resultado}=    Importar Empresas Via Google Maps    cep=${CEP_BAURU}    tipo=loja
    ${candidate_id}=    Evaluate    next(i['candidateId'] for i in $resultado['itens'])

    # Promove a Empresa
    ${cnpj}=    Gerar CNPJ Valido
    ${empresa_payload}=    Create Dictionary
    ...    cnpj=${cnpj}    razaoSocial=Multi Destino LTDA    nomeFantasia=Multi Destino
    ...    cnaePrincipal=4751201    setor=comercio    porte=me    numeroFuncionarios=${5}
    ...    endereco=Rua Teste, 100    telefone=1433331111    cep=17012000
    ...    municipio=Bauru    descricaoCnae=Comercio varejista    matrizOuFilial=matriz
    ...    latitude=${-22.314}    longitude=${-49.060}    situacaoCadastral=ativa
    ${empresa}=    Promover Candidate A Empresa    ${candidate_id}    &{empresa_payload}

    # Promove o mesmo candidate a Ponto
    ${ponto_payload}=    Create Dictionary
    ...    nome=Multi Destino    tipo=comercio    descricao=Loja teste multi-destino
    ...    endereco=Rua Teste, 100    latitude=${-22.314}    longitude=${-49.060}
    ...    contatoEmail=teste@example.com    corMarcador=#0d9488    iconeMarcador=institucional
    ${ponto}=    Promover Candidate A Ponto    ${candidate_id}    &{ponto_payload}

    # Rejeita como Telefone
    Rejeitar Candidate    ${candidate_id}    telefone

    # Confirma os 3 estados independentes no candidate
    ${atualizado}=    Buscar Candidate Triagem    ${candidate_id}
    Should Be Equal As Strings    ${atualizado['empresaStatus']}    aprovado
    Should Be Equal As Strings    ${atualizado['pontoStatus']}    aprovado
    Should Be Equal As Strings    ${atualizado['telefoneStatus']}    rejeitado

    # Cleanup
    Deletar Empresa    ${empresa['id']}
    ${headers}=    Headers Com Api Key
    DELETE    ${API_URL}/api/pontos-institucionais/${ponto['id']}    headers=${headers}    expected_status=204


Triagem - Re-decidir destino ja decidido retorna 409
    [Documentation]    Decisoes sao terminais. Pra desfazer, admin deleta a entidade-fim.
    [Tags]    triagem    promotion    conflict    e2e

    ${resultado}=    Importar Empresas Via Google Maps    cep=${CEP_BAURU}    tipo=loja
    ${candidate_id}=    Evaluate    next(i['candidateId'] for i in $resultado['itens'])

    # Primeira rejeicao OK
    Rejeitar Candidate    ${candidate_id}    empresa

    # Segunda rejeicao no mesmo destino → 409
    Rejeitar Candidate    ${candidate_id}    empresa    expected_status=409

    # Cleanup
    Rejeitar Candidate    ${candidate_id}    ponto       expected_status=ANY
    Rejeitar Candidate    ${candidate_id}    telefone    expected_status=ANY


Triagem - Filtro status=aprovado retorna candidates com algum destino aprovado
    [Documentation]    Filtro casa contra QUALQUER um dos 3 destinos. Util pra UI
    ...                "mostrar quem ja teve alguma decisao positiva".
    [Tags]    triagem    listing    e2e

    ${resultado}=    Importar Empresas Via Google Maps    cep=${CEP_BAURU}    tipo=loja
    ${candidate_id}=    Evaluate    next(i['candidateId'] for i in $resultado['itens'])

    # Promove a Empresa pra criar um "aprovado"
    ${cnpj}=    Gerar CNPJ Valido
    ${empresa_payload}=    Create Dictionary
    ...    cnpj=${cnpj}    razaoSocial=Filtro Test LTDA    nomeFantasia=Filtro Test
    ...    cnaePrincipal=4751201    setor=comercio    porte=me    numeroFuncionarios=${5}
    ...    endereco=Rua Teste, 100    telefone=1433332222    cep=17012000
    ...    municipio=Bauru    descricaoCnae=Comercio varejista    matrizOuFilial=matriz
    ...    latitude=${-22.314}    longitude=${-49.060}    situacaoCadastral=ativa
    ${empresa}=    Promover Candidate A Empresa    ${candidate_id}    &{empresa_payload}

    # Filtro aprovado deve incluir nosso candidate
    ${aprovados}=    Listar Candidates Triagem    status=aprovado
    ${ids}=    Evaluate    [c['id'] for c in $aprovados]
    Should Contain    ${ids}    ${candidate_id}

    # Cleanup
    Deletar Empresa    ${empresa['id']}
    Rejeitar Candidate    ${candidate_id}    ponto       expected_status=ANY
    Rejeitar Candidate    ${candidate_id}    telefone    expected_status=ANY
