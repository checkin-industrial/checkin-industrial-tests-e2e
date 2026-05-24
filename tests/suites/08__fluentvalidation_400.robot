*** Settings ***
Documentation     Valida que o FluentValidation (api PR #17) rejeita payloads
...               invalidos com HTTP 400 ProblemDetails (RFC 7807). Cobre as
...               regras principais de Empresas, Pontos Institucionais e
...               Telefones Uteis (CNPJ malformado, CEP fora do padrao, range
...               de latitude/longitude, email invalido, campos obrigatorios
...               vazios).
...
...               Validators ficam em src/Features/<X>/DTO<X>CriarValidator.cs
...               e DTO<X>AtualizarValidator.cs. Aplicados via endpoint filter
...               ValidationFilter<T> registrado nos endpoints Create/Update.
...               Falha -> AppValidationException -> 400 via
...               ProblemDetailsMiddleware.

Library     RequestsLibrary
Library     Collections
Resource    ../resources/keywords/common.resource
Resource    ../resources/keywords/empresas_api.resource

Suite Setup    Aguardar API Disponivel


*** Variables ***
${EMPRESA_BASE_OK_LAT}      ${-23.55052}
${EMPRESA_BASE_OK_LNG}      ${-46.633308}


*** Keywords ***
Payload Empresa Valido
    [Documentation]    Body base com todos os campos validos. Tests sobrescrevem
    ...                campos individuais pra testar regras especificas.
    ${cnpj}=    Gerar CNPJ Valido
    ${body}=    Create Dictionary
    ...    cnpj=${cnpj}
    ...    razaoSocial=Empresa Validacao Teste LTDA
    ...    nomeFantasia=Validacao Teste
    ...    cnaePrincipal=4751201
    ...    setor=industria
    ...    porte=me
    ...    numeroFuncionarios=${5}
    ...    endereco=Rua Teste, 100
    ...    telefone=1133334444
    ...    cep=01310200
    ...    municipio=Sao Paulo
    ...    descricaoCnae=Comercio varejista
    ...    matrizOuFilial=matriz
    ...    latitude=${EMPRESA_BASE_OK_LAT}
    ...    longitude=${EMPRESA_BASE_OK_LNG}
    ...    situacaoCadastral=ativa
    RETURN    ${body}

POST Empresa Espera 400
    [Documentation]    Envia o payload e exige 400. Retorna a resposta ProblemDetails
    ...                pra que o test inspecione a mensagem.
    [Arguments]    ${body}
    ${headers}=    Headers Com Api Key
    ${response}=    POST    ${API_URL}/api/empresas    json=${body}    headers=${headers}    expected_status=400
    RETURN    ${response.json()}


*** Test Cases ***
Empresa - CNPJ com menos de 14 digitos retorna 400
    [Tags]    validacao    empresas    e2e

    ${body}=    Payload Empresa Valido
    Set To Dictionary    ${body}    cnpj=123
    ${problem}=    POST Empresa Espera 400    ${body}
    Should Contain    ${problem['detail']}    CNPJ


Empresa - CNPJ com letras retorna 400
    [Tags]    validacao    empresas    e2e

    ${body}=    Payload Empresa Valido
    Set To Dictionary    ${body}    cnpj=ABC45678000195
    ${problem}=    POST Empresa Espera 400    ${body}
    Should Contain    ${problem['detail']}    CNPJ


Empresa - CEP com formato invalido retorna 400
    [Tags]    validacao    empresas    e2e

    ${body}=    Payload Empresa Valido
    Set To Dictionary    ${body}    cep=01310-200
    ${problem}=    POST Empresa Espera 400    ${body}
    Should Contain    ${problem['detail']}    CEP


Empresa - Latitude fora de range retorna 400
    [Tags]    validacao    empresas    e2e

    ${body}=    Payload Empresa Valido
    Set To Dictionary    ${body}    latitude=${-95.0}
    ${problem}=    POST Empresa Espera 400    ${body}
    Should Contain    ${problem['detail']}    Latitude


Empresa - Longitude fora de range retorna 400
    [Tags]    validacao    empresas    e2e

    ${body}=    Payload Empresa Valido
    Set To Dictionary    ${body}    longitude=${200.0}
    ${problem}=    POST Empresa Espera 400    ${body}
    Should Contain    ${problem['detail']}    Longitude


Empresa - CNAE com letras retorna 400
    [Tags]    validacao    empresas    e2e

    ${body}=    Payload Empresa Valido
    Set To Dictionary    ${body}    cnaePrincipal=abc1234
    ${problem}=    POST Empresa Espera 400    ${body}
    Should Contain    ${problem['detail']}    CNAE


Empresa - Razao Social vazia retorna 400
    [Tags]    validacao    empresas    e2e

    ${body}=    Payload Empresa Valido
    Set To Dictionary    ${body}    razaoSocial=${EMPTY}
    ${problem}=    POST Empresa Espera 400    ${body}
    Should Contain    ${problem['detail']}    Razao social


Empresa - PUT com CNPJ malformado retorna 400
    [Documentation]    Validation filter aplica tanto em Create quanto Update.
    ...                Cria empresa valida primeiro, depois tenta atualizar com
    ...                CNPJ invalido.
    [Tags]    validacao    empresas    update    e2e

    ${suffix}=    Sufixo Aleatorio
    ${id}=    Criar Empresa    nome_fantasia=Update Validation ${suffix}

    ${body}=    Payload Empresa Valido
    Set To Dictionary    ${body}    cnpj=123    nomeFantasia=Atualizada
    ${headers}=    Headers Com Api Key
    ${response}=    PUT    ${API_URL}/api/empresas/${id}    json=${body}    headers=${headers}    expected_status=400
    ${problem}=    Set Variable    ${response.json()}
    Should Contain    ${problem['detail']}    CNPJ

    # Cleanup
    Deletar Empresa    ${id}


Ponto Institucional - Email invalido retorna 400
    [Tags]    validacao    pontos    e2e

    ${body}=    Create Dictionary
    ...    nome=Validacao Ponto
    ...    tipo=educacao
    ...    descricao=Teste de validacao
    ...    endereco=Rua Teste, 1
    ...    latitude=${-23.55052}
    ...    longitude=${-46.633308}
    ...    contatoEmail=isso-nao-eh-email
    ...    corMarcador=#0d9488
    ...    iconeMarcador=institucional
    ${headers}=    Headers Com Api Key
    ${response}=    POST    ${API_URL}/api/pontos-institucionais    json=${body}    headers=${headers}    expected_status=400
    ${problem}=    Set Variable    ${response.json()}
    Should Contain    ${problem['detail']}    Email


Ponto Institucional - Latitude fora de range retorna 400
    [Tags]    validacao    pontos    e2e

    ${body}=    Create Dictionary
    ...    nome=Validacao Ponto Lat
    ...    tipo=educacao
    ...    descricao=Teste
    ...    endereco=Rua Teste, 1
    ...    latitude=${200.0}
    ...    longitude=${-46.633308}
    ...    corMarcador=#0d9488
    ...    iconeMarcador=institucional
    ${headers}=    Headers Com Api Key
    ${response}=    POST    ${API_URL}/api/pontos-institucionais    json=${body}    headers=${headers}    expected_status=400
    ${problem}=    Set Variable    ${response.json()}
    Should Contain    ${problem['detail']}    Latitude


Telefone Util - Nome vazio retorna 400
    [Tags]    validacao    telefones    e2e

    ${body}=    Create Dictionary
    ...    nome=${EMPTY}
    ...    categoria=${1}
    ...    telefone=193
    ${headers}=    Headers Com Api Key
    ${response}=    POST    ${API_URL}/api/telefones-uteis    json=${body}    headers=${headers}    expected_status=400
    ${problem}=    Set Variable    ${response.json()}
    Should Contain    ${problem['detail']}    Nome


ProblemDetails - estrutura RFC 7807 nas respostas 400
    [Documentation]    Verifica que o body do 400 tem os campos minimos do
    ...                ProblemDetails: status, title, detail.
    [Tags]    validacao    rfc7807    e2e

    ${body}=    Payload Empresa Valido
    Set To Dictionary    ${body}    cnpj=invalido
    ${problem}=    POST Empresa Espera 400    ${body}
    Dictionary Should Contain Key    ${problem}    status
    Dictionary Should Contain Key    ${problem}    title
    Dictionary Should Contain Key    ${problem}    detail
    Should Be Equal As Integers    ${problem['status']}    ${400}
