# Estabilização do encerramento (terminate) em AvaliacaoUITests

Auditoria e correção por Doutor Estranho (Diagnóstico, CI e Regressão).

## Causa da instabilidade (em uma linha)

**Causa:** Falha intermitente na finalização do processo do app no teste `testPerguntaSimNaoEmOrdemComRotuloValorESelecao` (`Failed to terminate com.frila.org.app:52216: Failed to terminate com.frila.org.app:0`, run CI 38199224104), provocada pelo encerramento abrupto do método após interação de UI e dump da árvore de acessibilidade (`app.debugDescription`) sem aguardar a quiescência (idle) do app antes da emissão do comando `terminate()`.

## Evidência observada e inferências

- **Evidência observada:**
  - Na run da CI `38199224104` (job "Parte 2: interface e builds de Release"):
    ```text
    ##[error]    testPerguntaSimNaoEmOrdemComRotuloValorESelecao, Failed to terminate com.frila.org.app:52216: Failed to terminate com.frila.org.app:0
    ##[error]Process completed with exit code 65.
    ```
  - O teste realiza dois toques seguidos (`sim.tap()`, `nao.tap()`), faz dump completo da hierarquia de acessibilidade com `XCTAttachment(string: app.debugDescription)` e finaliza o método sem qualquer espera de estabilização.
  - Ao iniciar o próximo teste (`testRespostaGuardadaFicaSelecionadaSemPermitirTroca`), a chamada `app.launch()` tenta encerrar a instância anterior pendente via `testmanagerd`. Sob carga pesada de CPU na máquina de CI macOS, o processo do app ainda processando eventos assíncronos não respondia a tempo, falhando com timeout de encerramento atribuído ao teste anterior.

- **Inferência:**
  - Adicionar encerramento limpo com espera explícita por estado estável em primeiro plano (`app.wait(for: .runningForeground, timeout: Espera.aparecer)`) em bloco `defer { ... app.terminate() }` assegura que a fila de eventos do app atinja idle e o processo seja terminado ordenadamente antes da transição para os testes subsequentes da suíte.

## Correção mínima aplicada

Em `iOS/Tests/UI/AvaliacaoUITests.swift`:
- No método `testPerguntaSimNaoEmOrdemComRotuloValorESelecao`, foi adicionado bloco `defer`:
  ```swift
  defer {
      _ = app.wait(for: .runningForeground, timeout: Espera.aparecer)
      app.terminate()
  }
  ```
- Nenhuma alteração foi realizada nos outros testes da classe.
- Zero uso de `sleep` fixo.

## Três execuções consecutivas aprovadas

Executadas via `.workers/vigia/xcb.sh "Doutor Estranho"` no esquema `Frila-Local`:
- **Ambiente:** iPhone 17 (simulador Doutor Estranho, UDID `4E344DE6-2366-42CA-84BB-46C474E6789E`), iOS 26.5 (build 23F77).
- **Resultados:**
  1. Execução 1: Aprovado (7 testes da suíte `AvaliacaoUITests` aprovados em 54.120 s) ([resumo](execucao-1-resumo.json), log `doutor-estranho-20261012-035708-97968.log`)
  2. Execução 2: Aprovado (7 testes da suíte `AvaliacaoUITests` aprovados em 53.858 s) ([resumo](execucao-2-resumo.json), log `doutor-estranho-20261012-035822-98983.log`)
  3. Execução 3: Aprovado (7 testes da suíte `AvaliacaoUITests` aprovados em 53.890 s) ([resumo](execucao-3-resumo.json), log `doutor-estranho-20261012-035926-99768.log`)
