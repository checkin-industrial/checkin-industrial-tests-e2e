*** Settings ***
Library     RequestsLibrary
Library     Collections
Library     DateTime
Library     String
Library     OperatingSystem
Variables   ../variables/env.yaml


*** Keywords ***
Aguardar API Disponivel
    [Documentation]    Polling no /health ate o DbContextCheck retornar Healthy.
    ...                Roda como Suite Setup para garantir que a API + Postgres
    ...                estao prontos antes de qualquer teste executar.
    Wait Until Keyword Succeeds    ${ASYNC_TIMEOUT}s    ${POLL_INTERVAL}s
    ...    Health Endpoint Esta Saudavel

Health Endpoint Esta Saudavel
    ${response}=    GET    ${API_URL}/health    expected_status=200
    Should Be Equal As Strings    ${response.text}    Healthy

Headers Com Api Key
    [Documentation]    Retorna dict com X-Api-Key e Content-Type pre-preenchidos.
    ...                Use em endpoints de escrita (Create/Update/Delete/Upload).
    ${headers}=    Create Dictionary
    ...    X-Api-Key=${API_KEY}
    ...    Content-Type=application/json
    RETURN    ${headers}

Headers Sem Api Key
    [Documentation]    Headers apenas com Content-Type. Use para testar 401 em writes.
    ${headers}=    Create Dictionary    Content-Type=application/json
    RETURN    ${headers}

Gerar CNPJ Valido
    [Documentation]    Gera CNPJ aleatorio com digitos verificadores validos pelo algoritmo da
    ...                Receita Federal. CnpjValidator.IsValid roda hoje so na importacao CSV,
    ...                mas geramos certo para ficar preparado caso validacao expanda para Create.
    ${digits}=    Evaluate    [__import__('random').randint(0, 9) for _ in range(12)]
    ${pesos1}=    Evaluate    [5,4,3,2,9,8,7,6,5,4,3,2]
    ${s1}=        Evaluate    sum(a*b for a, b in zip($digits, $pesos1))
    ${r1}=        Evaluate    $s1 % 11
    ${d1}=        Evaluate    0 if $r1 < 2 else 11 - $r1
    ${doze}=      Evaluate    $digits + [$d1]
    ${pesos2}=    Evaluate    [6,5,4,3,2,9,8,7,6,5,4,3,2]
    ${s2}=        Evaluate    sum(a*b for a, b in zip($doze, $pesos2))
    ${r2}=        Evaluate    $s2 % 11
    ${d2}=        Evaluate    0 if $r2 < 2 else 11 - $r2
    ${final}=     Evaluate    $doze + [$d2]
    ${cnpj}=      Evaluate    ''.join(str(d) for d in $final)
    RETURN    ${cnpj}

Sufixo Aleatorio
    [Documentation]    Sufixo curto (8 chars hex) para garantir nomes unicos por execucao.
    ${suffix}=    Evaluate    __import__('uuid').uuid4().hex[:8]
    RETURN    ${suffix}
