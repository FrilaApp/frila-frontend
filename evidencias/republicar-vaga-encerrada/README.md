# Prova da republicação de vaga encerrada

Missão de 10/10/2026, cartão [RTmRTHbo](https://trello.com/c/RTmRTHbo), critério 4: "A partir de uma vaga encerrada, a vaga nova sai sem redigitar os campos copiados".

## Escopo e autorização

Nick Fury autorizou em 10/10 a ampliação somente de `iOS/Tests/Unitarios/RepublicarVagaViewModelTests.swift` para afirmar preservação de função, valor, local e instruções. A autorização está registrada no arquivo da missão em `.workers/missoes/2026-10-10-homem-aranha-prova-republicar-vaga-encerrada.md`. Produção, demais testes e contrato não foram alterados.

A prova roda no esquema `Frila-Local`, com `ApiClienteEmMemoria` no cenário `vaga-encerrada-contratante`. Não executa RPC remota nem comprova o comportamento do backend.

## Prova unitária

`preservaDadosDaVagaEncerradaSemRedigitar` exige uma origem encerrada cujo período já terminou. A fixture original tem `observacoes` nulas; o teste prepara uma origem com instruções preenchidas para detectar sua perda. Confirma pelo view model sem reinserir campos nem editar o período inicial.

Após a resposta, lê o detalhe da vaga criada e compara função, remuneração, local, região administrativa, coordenadas, observações, traje e responsável com a origem. Exige ID novo, estado publicado, período novo e uma única chamada de republicação referindo-se ao ID original.

Resultado executado: a suíte completa `RepublicarVagaViewModelTests` passou com 25 testes, 0 falhas e 0 testes pulados. Fontes: [resumo unitário](unit-resumo.json), [resultado da preservação](preservacao-resultado.json) e [trecho do log](unit-xcb-trecho.log).

## Prova de interface

`testRepublicarVagaEncerradaCaminhoFeliz` abre Minhas vagas no cenário de vaga encerrada, toca em Republicar, exige a tela e o cartão copiado, guarda a captura e confirma sem digitação. Após a confirmação, exige o fechamento da folha, o aviso de sucesso e uma seção de vagas ativas em Minhas vagas.

Resultado executado: 1 teste aprovado, 0 falhas e 0 testes pulados. Fonte: [ui-resumo.json](ui-resumo.json). Ambiente obtido do resultado: iPhone 17, simulador Homem-Aranha, iOS 26.5, build 23F77, UDID `85940BCB-553C-4145-8F8E-E83423D86431`.

A [captura republicar-vaga.png](republicar-vaga.png) foi extraída do anexo `republicar-vaga` do teste, antes de confirmar, e inspecionada visualmente. Mostra Garçom, R$ 120,00, CLS 405, Asa Sul, Brasília - DF, Plano Piloto e modo urgência. [Manifesto do anexo](manifest-ui.json) e [trecho do log](ui-xcb-trecho.log) preservam a origem e o resultado; a imagem não representa o estado posterior à confirmação.

SHA-256 da captura: `62578580df69401584039a3582cddc9e65eb1a21cce51b43e3592ea0a3929ba7`.

## Lacuna da apresentação

O cartão `cartao-dados-copiados-republicacao` mostra função, valor, local, região e modo. Não mostra instruções. Evidência por leitura: `iOS/Sources/Apresentacao/Fluxos/Contratante/RepublicarVaga.swift`, propriedade `cartaoDadosCopiados`, linhas 372 a 413. A preservação das instruções é verificada no detalhe da vaga criada pelo teste unitário, não pela imagem do cartão. A tela permanece como está, conforme autorização.

## Reprodução

Gerar o projeto com `xcodegen generate` dentro de `iOS/`. O esquema `Frila` citado na minuta da missão não existe nesta base; o esquema local é `Frila-Local`.

Todos os testes passam por `~/Documents/Projetos/Apps/.workers/vigia/xcb.sh homem-aranha -- xcodebuild test`, com `-project Frila.xcodeproj -scheme Frila-Local -destination 'platform=iOS Simulator,id=85940BCB-553C-4145-8F8E-E83423D86431'`, `-parallel-testing-enabled NO`, `-maximum-concurrent-test-simulator-destinations 1` e caminhos próprios de DerivedData e resultados.

Seleções usadas: `-only-testing:FrilaUITests/RepublicarVagaUITests/testRepublicarVagaEncerradaCaminhoFeliz` e `-only-testing:FrilaTests/RepublicarVagaViewModelTests`.

## CI remota

O teto da missão é zero execuções. O commit usa `[skip ci]` para impedir o disparo de `pull_request` provocado pelo arquivo de teste, conforme a [documentação do GitHub](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/skip-workflow-runs). CI remota não é evidência de aprovação desta missão.

## Limites da prova

A auditoria visual usa o anexo gerado pelo teste no simulador. QA manual pelo portal, Dynamic Type XXXL e suítes gerais do aplicativo não foram executados nesta prova focada nas seleções exigidas pela missão. Nenhum código SwiftUI foi alterado.

A primeira tentativa de `xcb.sh` terminou antes de executar testes porque `Frila.xcodeproj` não existia no worktree limpo. `xcodegen generate` resolveu o bloqueio; a execução seguinte do caminho feliz passou. A fila do simulador foi respeitada.

Bloqueios encontrados: 1, resolvido pela geração do projeto. Testes pulados dentro das seleções executadas: 0. CI remota e RPCs reais não foram executadas, conforme o teto e o escopo da missão.

## Evidências locais

Logs completos do `xcb.sh`, preservados também na pasta própria de evidências:

- UI: `.workers/vigia/logs-xcodebuild/homem-aranha-20261010-222342-65605.log`.
- Unitários: `.workers/vigia/logs-xcodebuild/homem-aranha-20261010-222600-74707.log`.
- Preparação sem projeto: `.workers/vigia/logs-xcodebuild/homem-aranha-20261010-222249-62846.log`.

Cópias completas locais: `/Users/cauecarneiro/Documents/Projetos/Apps/.workers/homem-aranha/evidencias/2026-10-10-republicar-vaga-encerrada/{ui,unit}-xcb-completo.log`. Os bundles de resultados e o DerivedData são removidos depois da extração, para devolver espaço em disco. A captura, o manifesto e os resumos permanecem neste PR.

## Minuta para o Trello

Após conferir as evidências deste PR, Nick Fury pode registrar:

> Critério 4 de US05 comprovado no iOS com o dublê local. A vaga encerrada abre a republicação com os dados copiados e a confirmação cria uma vaga ativa sem reinserção manual dos campos. O teste unitário adicional compara função, remuneração, localização e instruções da vaga nova com a original, incluindo instruções preenchidas. Captura e resultados anexados ao PR. Pendência de apresentação: instruções não aparecem no cartão copiado; não houve alteração de tela. Marcar o Critério 4 e mover RTmRTHbo para Concluído 🎉, mantendo registrada essa lacuna.
