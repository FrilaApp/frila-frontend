# Estabilização do teste de erro do servidor em Exportar Meus Dados

Missão de 11/10/2026, cartão [nUpPFCpM](https://trello.com/c/nUpPFCpM) (S2 · Backend + iOS · Exportar meus dados US25 / #219).

## Causa da instabilidade (em uma linha)

**Causa:** Falha intermitente em CI (ex.: run 38168644182) com `Botão exportar dados deve existir no perfil` após toque em `abrir-meu-perfil`, decorrente de falta de sincronização com a barra `Vagas no DF` e ausência de espera pela transição para a tela `Meu perfil` (inferência: sob carga ou cold start na CI, o toque no link da toolbar ocorria antes da barra estar interativa ou o carregamento assíncrono do perfil ainda exibia estado de carregamento sem o botão).

## Evidência observada e inferências

- **Evidência observada:**
  - No log da CI 38168644182 (job "Parte 2: interface e builds de Release"):
    `testExportarMeusDadosErroServidorMostraAvisoDeErro, XCTAssertTrue failed - Botão exportar dados deve existir no perfil`
    `Failed to tap "perfil-exportar-dados" Button: No matches found for Elements matching predicate '"perfil-exportar-dados" IN identifiers' from input {(`
  - O teste era executado primeiro na suíte `ExportarDadosUITests` (ordem alfabética).
  - O código original não aguardava a navegação inicial para `Vagas no DF` e, imediatamente após `botaoPerfil.tap()`, esperava `perfil-exportar-dados` sem aguardar `app.navigationBars["Meu perfil"]` nem garantir que o botão estivesse tocável (`isHittable`).
- **Inferência:**
  - Em ambientes sob carga ou durante inicialização fria, o toque na barra de ferramentas pode não disparar a transição de navegação se a árvore ainda não concluiu layout.
  - Além disso, a tela `TelaMeuPerfilProfissional` inicia exibindo `EstadoCarregando()` enquanto `model.carregar()` roda assincronamente via `.task`. O elemento `ItemExportarDados` só entra na hierarquia quando `model.conta` e `model.perfil` são preenchidos.
  - Sem sincronizar a presença de `navigationBars["Meu perfil"]` e retentar o toque caso a navegação não tenha iniciado, o teste esgotava o timeout procurando o botão enquanto a tela ainda estava no feed inicial ou transicionando.

## Correção mínima aplicada

Em `iOS/Tests/UI/ExportarDadosUITests.swift`:
1. Aguardar `app.navigationBars["Vagas no DF"]` antes de acionar `abrir-meu-perfil`.
2. Após tocar em `abrir-meu-perfil`, verificar a transição para `app.navigationBars["Meu perfil"]`, com repetição do toque se a navegação não tiver ocorrido em 3 segundos.
3. Aguardar `app.navigationBars["Meu perfil"]` com `Espera.aparecer`.
4. Rolar com `app.swipeUp()` se o botão `perfil-exportar-dados` não estiver imediatamente tocável (`isHittable`).

## Cinco execuções consecutivas aprovadas

Executadas via `.workers/vigia/xcb.sh "Thor"` no esquema `Frila-Local`:
- **Ambiente:** iPhone 17 (simulador Thor, UDID `CEF93014-23BF-4F01-B535-6C1777ED08C9`), iOS 26.5 (build 23F77).
- **Resultados:**
  1. Execução 1: Aprovado em 11.362 s ([resumo](execucao-1-resumo.json), log `thor-20261012-001947-88518.log`)
  2. Execução 2: Aprovado em 11.078 s ([resumo](execucao-2-resumo.json), log `thor-20261012-002023-89563.log`)
  3. Execução 3: Aprovado em 10.557 s ([resumo](execucao-3-resumo.json), log `thor-20261012-002053-90269.log`)
  4. Execução 4: Aprovado em 10.685 s ([resumo](execucao-4-resumo.json), log `thor-20261012-002132-91200.log`)
  5. Execução 5 (suíte completa `ExportarDadosUITests`): 4 testes aprovados em 36.188 s ([resumo](execucao-5-resumo.json), log `thor-20261012-002201-91826.log`)

## Captura gerada

- Arquivo: `evidencias/exportar-dados-estavel/perfil-profissional-exportar-erro-servidor.png`
- SHA-256: `5869232dad6edc96111123a799b033c7012d1f84e9bc856426cd525355718c21`
- Anexo: Extraído do `xcresult-5.xcresult` pelo `xcresulttool export attachments`.
