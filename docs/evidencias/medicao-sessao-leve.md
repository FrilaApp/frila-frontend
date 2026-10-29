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
