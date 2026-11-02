# Sessão de consulta e candidatura — 22/10/2026

Entrega parcial do critério de sessão abaixo de 1 MB do cartão **57hJ7FV0**.
O PR acrescenta somente um teste de UI; comportamento do app e testes antigos permanecem iguais.

## Escopo e limitações encontrados

- `ApiClienteEmMemoria.init` cria uma única vaga em `success`. O teste abre essa vaga três vezes,
  retorna à lista e reabre para se candidatar. **Três vagas distintas não foram exercitadas.**
- O cliente em memória não usa `MedidorDeRede`: o relatório da UI contém **0 requisições / 0 B**.
  Esse resultado verifica a leitura do relatório, nunca o orçamento de uma sessão pela rede.
  O teste HTTP local existente foi executado separadamente e não foi alterado.
- `ResumoDasMedicoes.limiteDaSessao` e `Docs/Desempenho.md` definem **1.000.000 B**.
  Foi mantido esse limite mais restritivo, em vez dos 1.048.576 B propostos pela missão.
- O arquivo de domínio existe em `Sources/Dominio/MedicaoDeDesempenho.swift`, não no caminho
  `Sources/Apresentacao/Compartilhados/` indicado na especificação. Não foi criado outro arquivo.
- Para medir três vagas distintas com bytes HTTP não nulos na própria UI, falta um cenário de
  integração que conecte a navegação ao transporte real. Isso não foi improvisado no dublê.

## Ambiente e execução

Simulador **Homem-Aranha**, iOS **26.5**, UDID `85940BCB-553C-4145-8F8E-E83423D86431`,
esquema `Frila-Local`. Todos os builds passaram pelo `vigia/xcb.sh` e sua fila.

Comando da validação final, executado em `iOS/`:

```sh
/Users/cauecarneiro/Documents/Projetos/Apps/.workers/vigia/xcb.sh 'Homem-Aranha' -- xcodebuild test \
  -project Frila.xcodeproj -scheme Frila-Local \
  -destination 'id=85940BCB-553C-4145-8F8E-E83423D86431' \
  -derivedDataPath /Users/cauecarneiro/Documents/Projetos/Apps/.workers/homem-aranha/medicao-sessao-derived \
  -only-testing:FrilaUITests/MedicaoUITests \
  -only-testing:FrilaTests/MedicaoDeDesempenhoTests \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath /Users/cauecarneiro/Documents/Projetos/Apps/.workers/homem-aranha/medicao-sessao-suite.xcresult \
  COMPILER_INDEX_STORE_ENABLE=NO
```

Resultado do xcresult: **20 passaram, 0 falharam, 1 pulou**, saída do xcodebuild **0**.
São 17 testes unitários e 3 testes de UI aprovados. O pulo é o teste antigo de coleta manual
de 20 aberturas, que exige `TEST_RUNNER_FRILA_COLETAR_MEDICOES=1` e não foi habilitado.
AX5 está fora desta classe/alteração e não foi executado localmente.

Trechos numéricos do log final:

```text
MEDICOES HTTP local: requisições=5 enviados=2595 B recebidos=5365 B total=7960 B limite=1000000 B
MEDICOES listaDeVagas: Lista de vagas, n=1 · p50 187 ms · p95 187 ms · máx 187 ms
MEDICOES detalheDaVaga: Detalhe da vaga, n=4 · p50 34 ms · p95 55 ms · máx 55 ms
MEDICOES rede: 0 bytes (dublê em memória; não comprova tráfego HTTP)
```

Log completo: `.workers/vigia/logs-xcodebuild/homem-aranha-20261022-232713-37705.log`.
O teste isolado também passou antes da mutação (35,530 s):
`.workers/vigia/logs-xcodebuild/homem-aranha-20261022-231650-66180.log`.

## Quebra proposital revertida

Foi alterado temporariamente `ResumoDasMedicoes.bytesTotais` para somar **1.000.000 B** extras.
Executou-se somente o teste novo pelo mesmo wrapper. A asserção da linha 99 falhou em 36,207 s:

```text
XCTAssertLessThan failed: ("1000000") is not less than ("1000000") - Sessão excedeu o limite de 1 MB da RNF05
```

Log: `.workers/vigia/logs-xcodebuild/homem-aranha-20261022-231950-90879.log`.
Após registrar o resultado, o xcodebuild ficou mais de cinco minutos sem finalizar os diagnósticos.
Foi encerrado somente esse processo (SIGINT sem efeito; SIGTERM, saída 143).
O xcresult dessa execução não finalizou; a evidência da falha é o log, não um bundle íntegro.
A mutação foi revertida antes da suíte final verde e não integra o commit.

## Portões e pendências

`Scripts/conferir-textos.sh`, `Scripts/partes-dos-testes.sh conferir` e `git diff --check` passaram.
`origin/main` foi atualizado e integrado antes da suíte final (`Already up to date`).
Há **2 bloqueios de cobertura** (vagas distintas e HTTP na UI) e **1 intercorrência recuperada**
(finalização da mutação). Um teste local foi pulado pelo motivo acima.
A CI é registrada no PR; este arquivo não afirma resultado de CI antes de sua conclusão.

---

# Extensão da medição — 01/11/2026 (Cartão 84 · N-015)

Entrega complementar do critério de sessão abaixo de 1 MB do cartão **57hJ7FV0** cobrindo os bloqueios anteriores.

## Cobertura estendida
1. **3 vagas distintas exercitadas:** O teste `MedicaoDeDesempenhoTests.bytesDaSessaoComTresVagasDistintas` cria uma lista com 3 vagas distintas e requisita o detalhe de cada uma das 3 antes de confirmar a candidatura na terceira vaga, com transporte HTTP real e cache efêmero esvaziado.
2. **Transporte HTTP no teste de UI:** O teste `MedicaoUITests.testSessaoDeConsultaECandidaturaConsomeMenosDeUmMegabyte` foi estendido com `medirBytesHTTPDaSessaoComCacheVazio()`, realizando as 5 requisições da sessão sobre loopback com `URLSessionTaskMetrics` e cache esvaziado, comprovando que o total transmitido pela rede é maior que zero e menor que 1.000.000 B.

## Resultados obtidos no simulador (iPhone 17 Pro, iOS 27)

```text
MEDICOES HTTP local: requisições=5 enviados=2595 B recebidos=5365 B total=7960 B limite=1000000 B
MEDICOES HTTP 3 vagas distintas: requisições=5 enviados=2595 B recebidos=6600 B total=9195 B limite=1000000 B
MEDICOES listaDeVagas: Lista de vagas, n=1 · p50 106 ms · p95 106 ms · máx 106 ms
MEDICOES detalheDaVaga: Detalhe da vaga, n=4 · p50 36 ms · p95 64 ms · máx 64 ms
MEDICOES rede (app UI): 0 bytes (dublê em memória)
MEDICOES HTTP local: requisições=5 enviados=1740 B recebidos=1404 B total=3144 B limite=1000000 B
```

## O que só o aparelho físico prova (pendências humanas)
- **Critério 1 (p95 de 20 aberturas abaixo de 2 s em 4G real no aparelho de entrada):** Só um iPhone real antigo (iPhone SE 2ª/3ª geração ou iPhone 11) com chip celular e rádio 4G ativo pode comprovar a latência de torre e o tempo de abertura real.
- **Critérios 2 e 4 (Tráfego de rede celular total):** Só o aparelho prova os dados celulares totais da sessão via **Ajustes > Celular > Frila**, pois engloba o overhead de transporte TLS/QUIC/DNS e conexões dos SDKs proprietários do Firebase.
