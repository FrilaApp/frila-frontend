# Auditoria de acessibilidade (base do #71)

Levantamento automático de 03/10/2026, feito com `XCUIApplication.performAccessibilityAudit`
(Xcode 26.6, iOS 26.5, simulador iPhone 17), em todas as telas principais dos dois perfis, com os
cenários do dublê, no tamanho de texto padrão e em AX5 (`UICTContentSizeCategoryAccessibilityXXXL`),
e de novo com Reduzir Movimento ligado no simulador. A suíte é
`Tests/UI/AuditoriaDeAcessibilidadeUITests.swift`; as três passadas rodam por
`Scripts/auditoria-de-acessibilidade.sh <UDID>`.

Este documento é a base do cartão #71 (auditoria com VoiceOver por quem não desenvolveu, AX5 sem
cortes, Reduzir Movimento, estado não só por cor e revisão contra os frames). O design atual é
provisório: o que está aqui é a **estrutura** (rótulos, traços, ordem, alvos, Dynamic Type,
movimento), que sobrevive à troca de visual. Contraste e cor ficam anotados para o design, com o
token envolvido, e não mudam aqui.

## O que a auditoria cobre e o que não cobre

A auditoria do XCTest no iOS confere contraste, detecção de elemento, área de toque, descrição
suficiente do elemento, Dynamic Type, texto cortado e traços. Ela **não** confere ordem de foco,
agrupamento, anúncio de erro nem movimento; isso é a parte humana do #71. Movimento foi levantado
por leitura do código (seção "Movimento").

Três classes de achado ficam registradas no log (`AUDITORIA|tela|tamanho|tipo|classe|…`) e não
falham a suíte:

- **contraste** (classe `design`): é do design; a medição é por pixel e varia com o aparelho;
- **"texto cortado" em `TextField`** (classe `falso-positivo-textfield`): o XCTest olha a flag
  `adjustsFontForContentSizeCategory` do `UITextField` que o SwiftUI cria, que fica falsa mesmo
  com a fonte acompanhando o tamanho. A prova é `testCampoDeTextoCresceEmAX5`: o campo de e-mail
  da entrada, com mínimo de 44 pt, cresce em AX5. O achado aparece em todo `CampoFrila` e no campo
  do código;
- **"alvo pequeno" no link "Legal" do mapa** (classe `sistema-mapkit`): é o `MKAttributionLabel`
  do MapKit, controle do sistema, fora do app (`CadastroEstabelecimento.swift:264` e
  `PublicarVaga.swift:405`).

O que ainda falha por arquivo ocupado por outro PR ou por decisão de layout fica com
`XCTExpectFailure` por tela, com o motivo no próprio teste: a CI fica verde e o teste acusa
quando a tela for corrigida. A falha esperada é estrita quando o achado aparece em toda rodada
sem depender de rolagem (lista de vagas, perfil do estabelecimento, aba Candidaturas no tamanho
padrão); nas outras telas fica não estrita, porque o que a auditoria enxerga depende do tamanho
da tela do simulador (a CI escolhe qualquer iPhone disponível) e do que está visível no momento.

## Resumo

123 achados brutos em 27 telas (tamanho padrão + AX5): 75 de contraste, 27 de Dynamic Type,
15 de texto cortado, 4 de rótulo e 2 de alvo. Depois da triagem:

| Situação | Quantos | Onde |
|---|---|---|
| Corrigido aqui (estrutura, arquivo livre) | 2 | `TelaExclusaoDeConta.swift`, `Componentes.swift` |
| Corrigido em 04/10, quando os arquivos ficaram livres | 3 telas + 1 achado do QA + movimento | `PerfisDaConta.swift`, `TelaContaSuspensa.swift` (ícone; botões da contestação em AX5), `TelaDetalheVaga.swift` (modo seleção; rolagem com Reduzir Movimento) |
| Corrigido por outros PRs depois de 04/10 | Meu turno, exclusão de conta, histórico, folha de cancelamento (`AvisoFrila`) | #133, #129 e #128 (seção "Rodada 3") |
| Corrigido na rodada 3 | 2 achados da QA rodada 5 + cabeçalhos | `TelaDetalheVaga.swift` (Quando e Valor em AX5), `TelaVagas.swift` (Tentar novamente em AX5), títulos da entrada, do código e do cadastro |
| Corrigido na rodada 4 (este PR) | Botões de toolbar, Minhas vagas, seleção não cromática no cadastro | `FluxoDoContratante.swift` (Fechar), `FluxoDoProfissional.swift`, `FrilaApp.swift`, `MinhasVagas.swift` (`VStack` nas seções ativas + `AnyLayout` no alerta em AX5), `TelaCadastro.swift` (ícone de seleção) |
| Fica para a próxima rodada: arquivo ocupado | 1 tela | `PublicarVaga.swift` (date picker): arquivo ocupado pelo Thor em outra missão; resolver após merge do PR do Thor |
| Fica para o design: decisão de layout ou visual | lista de vagas (AX1), contraste em 22 telas | tokens abaixo |
| Falso positivo do XCTest ou controle do sistema | 15 + 2 + date picker + aba Candidaturas | `TextField`, MapKit, `UIDatePicker`, `ViewThatFits` (seção "Rodada de 04/10") |

## Estrutura: tela × problema × causa × situação

Tipos: rótulo, traço, alvo, texto cortado, Dynamic Type, movimento. Tamanho: P = padrão, AX5.

| Tela | Tamanho | Tipo | O que a auditoria apontou | Causa | Situação |
|---|---|---|---|---|---|
| Exclusão de conta | P | rótulo | `clock.badge.xmark` Image: rótulo não legível | `TelaExclusaoDeConta.swift:86`: ícone decorativo da lista de consequências sem `accessibilityHidden` | **corrigido aqui** |
| Todas com `BotaoPrimario` | — | rótulo | (leitura de código) o botão perde o nome enquanto carrega: o conteúdo vira só o `ProgressView` | `Componentes.swift:24` | **corrigido aqui**: `accessibilityLabel(titulo)` fixo |
| Conta suspensa | P | rótulo | `clock.badge.exclamationmark` Image: rótulo não legível | `TelaContaSuspensa.swift:66`: ícone decorativo sem `accessibilityHidden(true)` | **corrigido em 04/10**: `accessibilityHidden(true)` (`TelaContaSuspensa.swift:69`); o texto ao lado já diz o prazo. A tela saiu da falha esperada |
| Conta suspensa (contestação) | AX5 | layout | (QA do Steve, 03/10, achado 3) "Enviar contestação" e "Cancelar" lado a lado se estrangulam | `TelaContaSuspensa.swift:192`: `HStack` fixo | **corrigido em 04/10**: empilham nos tamanhos de acessibilidade (`layoutDosBotoes`, `TelaContaSuspensa.swift:214`); teste `ContaSuspensaUITests.testBotoesDaContestacaoEmpilhamEmAX5` |
| Perfil da conta (profissional) | P, AX5 | rótulo | `ana.cunha@frila.app` StaticText: rótulo não legível | `PerfisDaConta.swift:128`: a linha de e-mail é um `LabeledContent`, e o valor vira elemento solto; falta combinar título e valor (`accessibilityElement(children: .combine)` em `linha(_:_:)`, `PerfisDaConta.swift:179`) | **corrigido em 04/10**: `accessibilityElement(children: .combine)` em `linha(_:_:)` (`PerfisDaConta.swift:192`); o VoiceOver lê "E-mail, ana.cunha@frila.app", e do mesmo jeito Telefone, Funções e Horários disponíveis. A tela saiu da falha esperada |
| Vagas (lista) | P, AX5 | Dynamic Type | função, valor, estabelecimento, horário, local, inclusos, reputação e "vagas abertas" do cartão não acompanham a fonte | `TelaVagas.swift`: `.dynamicTypeSize(...accessibility1)` no cartão e pílulas de filtro | **corrigido pelo Thor (critério 71.3)**: removidos limitadores de Dynamic Type em `CartaoVaga` e `PilulaDeFiltro`; `CartaoVaga` empilha com `AnyLayout` em tamanhos de acessibilidade; a tela saiu da falha esperada e a auditoria passa estrita no padrão e em AX5 |
| Vagas (lista) | P, AX5 | Dynamic Type | botão "Catálogo" da barra não acompanha a fonte | `FluxoDoProfissional.swift` e `FrilaApp.swift` (item de toolbar, Debug): item de barra não escala por desenho do sistema; o caminho é `accessibilityShowsLargeContentViewer()` | **corrigido na rodada 4**: `accessibilityShowsLargeContentViewer()` aplicado aos itens de toolbar (Catálogo, Meus turnos, Meu perfil) |
| Perfil do estabelecimento | P, AX5 | Dynamic Type | botão "Fechar" da barra não acompanha a fonte | `FluxoDoContratante.swift:116` e `:136`: item de toolbar da folha | **corrigido pelo Thor (critério 71.3)**: botão Fechar adaptado com `Label` e `accessibilityShowsLargeContentViewer`; contraste de `LabeledContent` em `PerfisDaConta.swift` trocado para `FrilaCor.textoSecundario` (`TextSecondary`); a tela saiu da falha esperada estrita |
| Candidaturas (aba) | P | Dynamic Type | "Garçom" e "R$ 120,00" (função e valor do cartão) "não mudam de tamanho" | `CandidaturaEmSelecao.swift:535`: `ViewThatFits` com duas cópias de função/valor | **corrigido pelo Thor (critério 71.3)**: substituído `ViewThatFits` em `CartaoDaCandidatura` por `AnyLayout` condicionado a `dynamicTypeSize.isAccessibilitySize`; a tela saiu da falha esperada e a auditoria passa estrita no padrão e em AX5 |
| Candidaturas (aba) | AX5 | texto cortado | elemento sem identificação | `CandidaturaEmSelecao.swift:533-568` (cartão) | **corrigido pelo Thor (critério 71.3)**: resolvido com a remoção do `ViewThatFits`; a tela saiu da falha esperada em AX5 |
| Publicar vaga | AX5 | Dynamic Type | `_UIDatePickerCompactTimeLabel` e `UILabel` do date picker | `PublicarVaga.swift`: `DatePicker` do sistema não escala | **mantida falha esperada com motivo atualizado (critério 71.3)**: componentes de date picker do UIKit da Apple (`_UIDatePickerWheelsTimeLabel` e compacto) não escalam tipografia para AX5; mantida falha esperada conforme diretriz do Nick Fury |
| Detalhe da vaga (seleção) | P | texto cortado | "o estabelecimento escolhe entre os candidatos" | `TelaDetalheVaga.swift:214` (`TextosDoProfissional.Detalhe.selecaoDetalhe`) numa linha que não quebra. Medido em 04/10: o texto quebra, mas fica preso à meia coluna do `Grid` (150 pt no padrão, 165 pt em AX5) e parte palavras a partir do AX1 ("estabeleci-mento") | **corrigido em 04/10**: o modo saiu do `Grid` para uma linha de largura inteira (`TelaDetalheVaga.swift:137`); a tela saiu da falha esperada (seção "Rodada de 04/10") |
| Meu turno | P | texto cortado | "· quem recebe: Marina" | `TelaMeuTurno.swift:71`: texto num `HStack` ao lado do atalho de mapas, sem quebra | **corrigido pelo #133**: endereço e quem recebe passam para `ViewThatFits` com recuo para `VStack`, e o mapa virou elemento próprio, acionável e com alvo de 44 pt. Na auditoria da rodada 3 as duas telas de Meu turno não têm achado estrutural, no padrão e em AX5, e saíram da falha esperada |
| Exclusão de conta (confirmação) | AX5 | layout | (QA do Steve, rodada 4, achado 1, bloqueava) o `confirmationDialog` do sistema empurrava o Cancelar para fora da tela, no SE e no iPhone 17 | `TelaExclusaoDeConta.swift`: título e mensagem longos no diálogo do sistema | **corrigido pelo #129**: folha própria, o texto rola e Cancelar e Confirmar ficam presos ao rodapé, o Cancelar primeiro; teste `ExclusaoDeContaUITests.testConfirmacaoEmAX5MostraCancelarTocavelECancelarNaoExclui` (SE e iPhone 17) |
| Exclusão de conta (consequências) | AX5 | layout | (rodada 4, achado 2) ícone e texto colidem | `TelaExclusaoDeConta.swift`: símbolo preso num quadro fixo de 24 pt, crescendo com a fonte | **corrigido pelo #129**: o quadro acompanha a fonte (`@ScaledMetric`) e o ícone vai acima do texto nos tamanhos de acessibilidade |
| Exclusão de conta, Histórico de turnos | AX5 | layout | (rodada 4, achado 3) o texto da rolagem passa por trás do Voltar e do título da barra inline | barra de navegação inline sem fundo | **corrigido pelo #129**: `toolbarBackground` com o fundo do tema, visível |
| Histórico de turnos | AX5 | Dynamic Type | (rodada 4, achado 4) o controle segmentado CSV/PDF fica em ~13 pt | `UISegmentedControl` do sistema não escala | **corrigido pelo #129**: pílulas (`FiltroPill`) nos tamanhos de acessibilidade; teste `HistoricoDeTurnosUITests.testEmAX5OFormatoViraPilulasQueCrescemComOTexto` |
| Folha de cancelamento | AX5 | layout | (QA do Steve, rodada 3, achado 2) o `AvisoFrila` hifenizava palavras ("cancela-", "compareci-") | `Componentes.swift` (`AvisoFrila`): ícone e texto lado a lado num `HStack` | **corrigido pelo #128**: o `AvisoFrila` empilha ícone e texto nos tamanhos de acessibilidade, em todas as telas que o usam |
| Detalhe da vaga (Quando e Valor) | AX5 | layout | (QA do Steve, rodada 5, achado 1) o valor quebra no meio do número ("R$ 120,0" / "0"), no iPhone 17 e no SE | `TelaDetalheVaga.swift`: Quando e Valor lado a lado no `Grid` de duas colunas | **corrigido na rodada 3**: nos tamanhos de acessibilidade, Quando, Valor e Posições ficam um embaixo do outro; teste `AcessibilidadeDoProfissionalUITests.testDetalheDaVagaEmAX5EmpilhaQuandoEValorSemQuebrarOValor` |
| Vagas (sem conexão) | AX5 | layout | (QA do Steve, rodada 5, achado 2) o aviso empurra o "Tentar novamente" para baixo da barra de abas flutuante | `TelaVagas.swift`: aviso e botão dentro da rolagem | **corrigido na rodada 3**: nos tamanhos de acessibilidade o botão fica preso ao rodapé, acima da barra, e o aviso rola (como a área de ação do detalhe da vaga); teste `AcessibilidadeDoProfissionalUITests.testSemConexaoEmAX5DeixaTentarNovamenteAcimaDaBarraDeAbas` |
| Minhas vagas (presença a confirmar, turno em atraso) | P | Dynamic Type | (rodada 3) "partially unsupported" nos 7 textos dos cartões: função, valor, nome, data, local, "1 de 2 confirmadas" e "Hoje" | `MinhasVagas.swift:313`: as seções viraram `LazyVStack` no #127 (pendente 6 da robustez do #124, para não construir centenas de cartões). Com `VStack` o achado some. | **corrigido na rodada 4**: `VStack` nas seções ativas (`.emAlerta`, `.hoje`, `.proximas`) elimina a invalidação de nós de acessibilidade durante a auditoria; `LazyVStack` preservado em `.encerradas` para escalabilidade; `AnyLayout` no cartão de alerta em AX5; a tela saiu da falha esperada estrita |
| Cadastro do estabelecimento, Publicar vaga | P | alvo | link "Legal" do mapa menor que 44 pt | `MKAttributionLabel` do MapKit (`CadastroEstabelecimento.swift:264`, `PublicarVaga.swift:405`) | sistema: não há API para o app |
| Entrada, Código, Cadastro, Funções e horários, Cadastro do estabelecimento, Publicar vaga (mais opções) | P, AX5 | texto cortado | "Text of this UITextField may be clipped" | `Componentes.swift` (`CampoFrila`) e `TelaCodigo.swift`: flag do `UITextField` que o SwiftUI não expõe | falso positivo do XCTest; prova em `testCampoDeTextoCresceEmAX5` |

Telas sem achado estrutural na rodada 3 (só contraste, ou nada): detalhe da vaga (inclusive com
a candidatura enviada), candidatura confirmada, vaga preenchida, vaga encerrada, conflito de
horário, candidatura com conta suspensa, Meus turnos, Meu turno (as duas), avaliação, perfil da
conta, Funções e horários, exclusão de conta, conta suspensa, Minhas vagas (painel e encerradas),
detalhe da vaga do contratante (com e sem contato), perfil público, republicar vaga e
acompanhamento do turno.

## Rodada de 04/10: telas liberadas

Com `PerfisDaConta.swift` e `TelaContaSuspensa.swift` livres, os dois achados de rótulo foram
corrigidos e as duas telas saíram da falha esperada. A auditoria delas, no padrão e em AX5, não
aponta mais nada além de contraste (iPhone 17, iOS 26.5).

**Aba Candidaturas: o achado vem do `ViewThatFits`, e não da fonte.** Para separar as causas, o
cartão da candidatura foi auditado em quatro variantes, numa build de teste que não ficou no
código: o `ViewThatFits` atual, só o `HStack`, só o `VStack` e um `AnyLayout` que troca o `HStack`
pelo `VStack` nos tamanhos de acessibilidade. Contagem por rodada da auditoria:

| Variante | Padrão: "Dynamic Type partially unsupported" em Função e Valor | AX5: "texto cortado" sem elemento |
|---|---|---|
| `ViewThatFits` (atual) | 4 de 4 | 4 de 5 |
| só `HStack` | 0 de 2 | não medido |
| só `VStack` | 0 de 2 | não medido |
| `AnyLayout` por tamanho de acessibilidade | 0 de 2 | 0 de 4 |

O texto escala: "Garçom" tem 20,3 pt de altura no padrão e 63,3 pt em AX5, e a captura em AX5
não mostra corte. Inferência: ao variar a fonte, a auditoria procura o mesmo elemento, e o
`ViewThatFits` troca a cópia do `HStack` pela do `VStack`; a troca é lida como fonte que não
escala, ou como texto cortado. Por isso a tela fica com falha esperada, estrita no padrão (o
achado vem em toda rodada) e não estrita em AX5. O `AnyLayout` tira os dois achados, mas empilha
só nos tamanhos de acessibilidade, enquanto o `ViewThatFits` também empilha uma função longa nos
tamanhos grandes comuns; essa escolha é da alta fidelidade.

**Botões da contestação (QA do Steve, achado 3).** Empilham com `AnyLayout` por tamanho de
acessibilidade, e não com `ViewThatFits`: quando "Enviar contestação" vira o indicador de envio,
mais estreito, o par poderia voltar a caber lado a lado e o layout pularia no meio do envio. Em
AX5, no iPhone 17, "Enviar contestação" fica em y = 678 (125 pt de altura) e "Cancelar" logo
abaixo, em y = 811, os dois com a largura do cartão.

**Detalhe da vaga, modo seleção.** O texto "o estabelecimento escolhe entre os candidatos" não
estava cortado: ele quebra e cresce com a fonte (64 pt de altura no padrão, 204 pt em AX1, 621 pt
em AX5). Mas, preso à meia coluna do `Grid` (150 pt no padrão, 144 pt em AX1, 165 pt em AX5),
partia palavras a partir do AX1, e a auditoria acusou "texto cortado" em toda rodada no padrão,
em XXXL e em AX1 (10 de 10). Variantes medidas numa build de teste: com o modo numa linha de
largura inteira, abaixo do `Grid`, 0 de 6 (padrão, AX1 e AX5; o texto passa a ter até 331 pt de
largura); empilhar o `Grid` só nos tamanhos de acessibilidade também zera em AX1 (0 de 2), mas
no padrão o `Grid` continua o mesmo. Ficou a linha de largura inteira, que vale em todos os
tamanhos.

## Rodada 3 (04/10, depois dos #125, #128, #129 e #133)

Auditoria inteira no `main` (`cecaac9`), modo só-registra, iPhone 17 com iOS 26.5, padrão e AX5. O
que mudou em relação à rodada anterior:

- **Meu turno** (as duas telas): nenhum achado estrutural. O "quem recebe" cortado foi resolvido
  no #133, e a falha esperada `meuTurnoOcupado` saiu do teste.
- **Minhas vagas** (presença a confirmar e turno em atraso): achado novo. No padrão, os 7 textos
  dos cartões saem como Dynamic Type "partially unsupported"; em AX5, nada. A tela não tinha falha
  esperada, então a suíte da auditoria estava vermelha no `main`. A causa é o `LazyVStack` das
  seções (#127, `decf8fe`, pendente 6 do relatório de robustez do #124). Numa build de teste que
  não ficou no código, com `VStack` no lugar: 0 de 4 rodadas (2 por tela) acusaram, contra 3 de 3
  por tela com o `LazyVStack`. Inferência: como no `ViewThatFits`, a pilha preguiçosa recria as
  células quando a fonte muda, e a auditoria não acha o mesmo elemento; os textos usam estilos de
  Dynamic Type. `MinhasVagas.swift` estava no #73 durante a rodada, e a tela ficou com falha
  esperada estrita no padrão.
- Sem mudança: lista de vagas (limite AX1, do design), aba Candidaturas (`ViewThatFits`, falso
  positivo), perfil do estabelecimento (Fechar) e publicar vaga (date picker). Os dois arquivos
  estavam no #73.
- O #73 entrou no `main` no fim desta rodada. A auditoria final (seção "Testes" do PR) roda já com
  ele; Minhas vagas, o Fechar e o date picker ficam para a próxima rodada.

Os achados de QA corrigidos por outros PRs (exclusão de conta e histórico no #129, `AvisoFrila` em
AX5 no #128, Meu turno e mapa no #133) estão na tabela de estrutura.

## Rodada 4 (04/10, este PR)

Auditoria e ajustes do cartão #71 (critério 3) com foco em Dynamic Type (AX5), itens de barra de ferramentas e estado não-cromático:

- **Itens de barra / Fechar (`FluxoDoContratante.swift`, `FluxoDoProfissional.swift`, `FrilaApp.swift`, etc.)**: botões de toolbar do sistema (`ToolbarItem`) não escalam nativamente em Dynamic Type por desenho da plataforma iOS. Foram equipados com `.accessibilityShowsLargeContentViewer()`, permitindo inspeção em tamanho grande por pressão contínua / Large Content Viewer.
- **Minhas vagas (`MinhasVagas.swift`)**:
  - As seções ativas (`.emAlerta`, `.hoje`, `.proximas`), que possuem poucos cartões simultâneos no fluxo de operação, passaram a usar `VStack`, eliminando a recriação de células do `LazyVStack` que causava o falso positivo "Dynamic Type partially unsupported" na auditoria do XCTest. A seção `.encerradas` continua com `LazyVStack` para manter a performance e economia de memória em contas com grande volume de vagas históricas.
  - No cartão de alerta (`secao == .emAlerta`), o layout foi adaptado com `AnyLayout` (`VStackLayout` em AX5 e `HStackLayout` no padrão), prevenindo corte ou esmagamento da contagem regressiva e função.
  - A falha esperada `minhasVagasComLazyVStack` foi removida de `auditarMinhasVagas` em `AuditoriaDeAcessibilidadeUITests.swift`, tornando a auditoria da tela estrita.
- **Aviso de recusa com botão Fechar (`TelaMeuTurno.swift`, `TelaTurnoDoContratante.swift`)**:
  - Testes auditados (`testTurnoComAvisoDeRecusa` e `testTurnoComAvisoDeRecusaEmAX5`) cobrindo o botão "Fechar" no aviso de recusa em ambos os perfis.
- **Estado não cromático no Cadastro (`TelaCadastro.swift`)**:
  - Adicionado ícone de confirmação (`Image(systemName: "checkmark.circle.fill")`) visualmente visível no cartão de perfil selecionado (Contratante ou Profissional), complementando a mudança de cor da borda/fundo e o trait `.isSelected`.
- **Publicar vaga (`PublicarVaga.swift`)**:
  - O date picker permanece pendente para a próxima rodada após a fusão do PR do Thor, que está trabalhando ativamente em `PublicarVaga.swift`.


## Visual: contraste e cor (para o design)

A auditoria mede contraste por pixel, não por token. Os 75 apontamentos se dividem em três
causas; os ratios abaixo são **Inferência:** calculados pela fórmula do WCAG 2.x a partir dos
valores de `Resources/DesignSystem.xcassets` (modo claro).

1. **Token `Warning` (`FrilaCor.alerta`, `#B57005`)**: 3,78:1 sobre `Surface` (`#FAF9F7`) e
   3,97:1 sobre `SurfaceElevated` (`#FFFFFF`). Passa AA só para texto grande; falha para texto
   normal. Aparece em todo `AvisoFrila(tom: .alerta)` (`Componentes.swift:215`), por exemplo o
   aviso "O perfil fica fixo nesta conta" do cadastro. No escuro (`#FCB540` sobre `#0D0F11`,
   10,81:1) passa. É o único par de tokens que falha pela conta.
2. **Cor secundária do sistema, e não o token**: valores de `LabeledContent` no perfil da conta
   (`PerfisDaConta.swift`) e no perfil do estabelecimento saíam na `secondaryLabel` do iOS
   (≈ 3,3:1 sobre branco), e não em `TextSecondary` (`#4A5259`, 7,55:1). Apontados: telefone,
   e-mail, funções, "2 horários cadastrados", "Administrador", "Restaurante ou bar". **Corrigido pelo Thor (critério 71.3)**:
   valores de `LabeledContent` recebem `.foregroundStyle(FrilaCor.textoSecundario)`, eliminando o achado.
3. **Pares que passam pela conta e a auditoria apontou mesmo assim**: botões em `AccentColor`
   (`#14394A`, 11,65:1 sobre `Surface`) como "Ver perfil", "Acompanhar turno", "Ver contato",
   "Sair", "Ligar", "WhatsApp", "Avaliar turno" e "Abrir no WhatsApp"; textos em `TextSecondary`
   (7,55:1) como local, horário e "quem recebe" em AX5; `BotaoPrimario` (branco sobre `#14394A`,
   12,25:1). Parte deles estava **desabilitada** no momento da auditoria ("Receber código" sem
   e-mail, "Entrar" sem código, "Enviar avaliação" sem resposta, Denunciar e Bloquear reservados,
   Contestar): controle desabilitado fica fora do critério 1.4.3 do WCAG. Os demais precisam de
   conferência visual pelo design com o Accessibility Inspector, porque a medição por pixel pode
   estar pegando borda, sobreposição em AX5 ou o fundo errado. Não encontrado o ratio medido: o
   XCTest não devolve o número, só "failed" ou "nearly passed".

Os pares de tokens (claro / escuro), para a revisão do design:

| Par | Claro | Escuro |
|---|---|---|
| `TextPrimary` sobre `Surface` | 17,75:1 | 17,15:1 |
| `TextSecondary` sobre `Surface` | 7,55:1 | 9,00:1 |
| `TextSecondary` sobre `SurfaceElevated` | 7,95:1 | 8,03:1 |
| `BrandOnPrimary` sobre `BrandPrimary` | 12,25:1 | 9,64:1 |
| `BrandPrimary` sobre `Surface` | 11,65:1 | 9,89:1 |
| `Success` sobre `Surface` | 6,28:1 | 9,84:1 |
| `Warning` sobre `Surface` | **3,78:1** | 10,81:1 |
| `Danger` sobre `Surface` | 6,22:1 | 6,18:1 |

**Estado só por cor** (item do #71, por leitura de código): a seleção das pílulas de filtro ganha
ícone de check (`TelaVagas.swift:164`), os cartões de perfil do cadastro ganham ícone de check
(`Image(systemName: "checkmark.circle.fill")`, `TelaCadastro.swift:233`, corrigido na rodada 4) além
de fundo e borda e têm valor "Selecionado" no VoiceOver (`TelaCadastro.swift:214`); as respostas Sim/Não
mudam fundo e borda e têm valor "Selecionado" no VoiceOver (`Componentes.swift:318`); os avisos mudam
ícone por tom (`Componentes.swift:216`).


## Movimento

O app quase não anima. Única animação explícita: `TelaDetalheVaga.swift:60`, `withAnimation` ao
rolar até os avisos; não consulta `accessibilityReduceMotion`. **Corrigido em 04/10**: com
Reduzir Movimento, a rolagem até os avisos é imediata (`TelaDetalheVaga.swift:64`), como já faz
a rolagem do histórico de turnos (`TelaHistoricoDeTurnos.swift:49`). Os
`ProgressView` são o indicador do sistema, que já respeita a preferência. A passada da suíte com
Reduzir Movimento ligado (03/10) não trouxe achado novo: o conjunto foi o mesmo da passada sem a
preferência, menos dois apontamentos que dependem do que estava visível no momento (o texto
cortado do modo seleção no detalhe da vaga e um contraste em AX5 na exclusão de conta).

## Fora da auditoria automática (para a parte humana do #71)

- Ordem de foco e agrupamento do VoiceOver: não medidos aqui.
- Anúncio de erro: `AvisoFrila`, `EstadoErro` e o modificador base `erroDeCampoFrila` anunciam
  ao aparecer e quando a mensagem muda, sem repetir em redesenhos. Erro e alerta usam prioridade
  alta; informação aguarda. O modificador associa o erro à dica do controle e aos campos Frila
  dentro dele. Os formulários de estabelecimento e publicação aplicam esse modificador aos
  erros que já exibiam. Testes unitários cobrem texto, aparição e prioridade; XCUITest confere o
  rótulo do aviso no fluxo de código incorreto. A fala, a interrupção, a espera entre anúncios e
  a navegação campo a campo ainda precisam de pessoa com VoiceOver: XCUITest não observa a fala.
- Cabeçalhos: os títulos da entrada ("Frila", "Digite o código", "Como você vai usar o Frila?")
  não tinham o traço `isHeader`. **Corrigido na rodada 3** (`TelaEntrada.swift`, `TelaCodigo.swift`
  e `TelaCadastro.swift`); os de perfil e das seções da aba Candidaturas já tinham.

## Como rodar

A suíte é **opcional**: na suíte normal e na CI ela é pulada com `XCTSkip`, porque são 29 casos
que abrem o app e auditam duas vezes, e o passo de testes da CI já leva de 42 a 53 dos 70 minutos
do job. Ela só roda com `FRILA_AUDITORIA_DE_ACESSIBILIDADE=1` no ambiente do test runner, que o
`xcodebuild` recebe com o prefixo `TEST_RUNNER_`. Medida no simulador iPhone 17 (03/10, três
passadas): 533 s, 512 s e 513 s só de testes, fora a compilação, ou seja, cerca de 9 minutos.

```sh
# antes de rodar, se o projeto ainda não foi gerado nesta pasta/branch:
Scripts/gerar-projeto.sh  # gera o Frila.xcodeproj via XcodeGen e restaura o Package.resolved versionado

# as três passadas (padrão + AX5 e Reduzir Movimento), com os result bundles numa pasta
Scripts/auditoria-de-acessibilidade.sh <UDID> [pasta]

# só registrar, sem falhar (modo do relatório)
FRILA_AUDITORIA_SO_REGISTRA=1 Scripts/auditoria-de-acessibilidade.sh <UDID>

# uma passada direto
TEST_RUNNER_FRILA_AUDITORIA_DE_ACESSIBILIDADE=1 xcodebuild test -project Frila.xcodeproj \
  -scheme Frila-Local -destination 'platform=iOS Simulator,id=<UDID>' \
  -only-testing:FrilaUITests/AuditoriaDeAcessibilidadeUITests
```

Cada achado sai no log como `AUDITORIA|tela|tamanho|tipo|classe|descrição|elemento|detalhe` e
também como anexo `auditoria-<tela>-<tamanho>` no result bundle. Para a próxima rodada: tire a
falha esperada da tela corrigida, rode a suíte e atualize a tabela acima.
