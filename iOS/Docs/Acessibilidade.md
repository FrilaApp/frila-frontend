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

Inventário e checklist sistemático das 43 telas da v1.0 do Frila avaliadas contra os 9 critérios de acessibilidade (estrutura, Dynamic Type, alvos, contraste, movimento, estado e VoiceOver), totalizando 387 células:

| Situação da célula | Quantidade | Percentual | Detalhamento |
|---|---|---|---|
| **ok** | 219 | 56,59% | Requisitos atendidos e comprovados por testes automatizados (`AuditoriaDeAcessibilidadeUITests.swift`) ou leitura de código |
| **falta** | 87 | 22,48% | 43 em VoiceOver em aparelho (100% das telas sem teste físico com pessoa com deficiência visual); 28 por ausência de teste de auditoria automática nas 14 telas fora da suíte (padrão e AX5); 14 por ausência de auditoria de contraste nas 14 telas; 2 em cabeçalhos (`isHeader`) nas telas de Suporte e Atualização |
| **não se aplica** | 81 | 20,93% | 40 em Reduzir Movimento (telas estáticas sem animação); 33 em estado só por cor (telas sem seleção de estado por cor); 8 nas 2 folhas nativas do sistema iOS |
| **Total** | **387** | **100,00%** | **Soma de verificação exata:** 219 (ok) + 87 (falta) + 81 (não se aplica) = 387 células |

O critério 71.1 permanece aberto: o checklist sistemático das 43 telas está preenchido, mas resta criar um cartão de correção por tela para as pendências identificadas.

### Triagem da auditoria automática (rodadas de 03 e 04/10)

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
| Vagas (lista) | P, AX5 | Dynamic Type | função, valor, estabelecimento, horário, local, inclusos, reputação e "vagas abertas" do cartão não acompanham a fonte além de AX1 | `TelaVagas.swift`: `.dynamicTypeSize(...accessibility1)` no botão do cartão | pílulas corrigidas para AX5; cartão segue limitado a AX1 por decisão de layout do design (#139), pois sem o limite atinge 957 pt de altura em AX5 (excedendo a tela de 874 pt); mantida falha esperada estrita |
| Vagas (lista) | P, AX5 | Dynamic Type | botão "Catálogo" da barra não acompanha a fonte | `FluxoDoProfissional.swift` e `FrilaApp.swift` (item de toolbar, Debug): item de barra não escala por desenho do sistema; o caminho é `accessibilityShowsLargeContentViewer()` | **corrigido na rodada 4**: `accessibilityShowsLargeContentViewer()` aplicado aos itens de toolbar (Catálogo, Meus turnos, Meu perfil) |
| Perfil do estabelecimento | P, AX5 | Dynamic Type | botão "Fechar" da barra não acompanha a fonte | `FluxoDoContratante.swift:116` e `:136`: item de toolbar da folha | **corrigido pelo Thor**: botão Fechar adaptado com `Label` e `accessibilityShowsLargeContentViewer`; contraste de `LabeledContent` em `PerfisDaConta.swift` trocado para `FrilaCor.textoSecundario` (`TextSecondary`); a tela saiu da falha esperada estrita |
| Candidaturas (aba) | P | Dynamic Type | "Garçom" e "R$ 120,00" (função e valor do cartão) "não mudam de tamanho" | `CandidaturaEmSelecao.swift:535`: `ViewThatFits` com duas cópias de função/valor | **corrigido pelo Thor**: `CartaoDaCandidatura` usa `VStack` em acessibilidade e `ViewThatFits` original nos demais tamanhos; a tela saiu da falha esperada e a auditoria passa estrita no padrão e em AX5 |
| Candidaturas (aba) | AX5 | texto cortado | elemento sem identificação | `CandidaturaEmSelecao.swift:533-568` (cartão) | **corrigido pelo Thor**: com `VStack` em acessibilidade a tela saiu da falha esperada em AX5 |
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

## Checklist das 43 telas × 9 critérios (71.1)

Checklist sistemático das 43 telas da v1.0 na ordem exata do inventário aceito, avaliando as 9 colunas de critérios. Cada célula contém **ok** + prova (`arquivo:linha` ou teste), **falta** + o que falta, ou **não se aplica** + justificativa.
A coluna "VoiceOver em aparelho" registra sempre **falta: pessoa com VoiceOver** (nenhum teste em aparelho físico realizado).

| Tela | Auditoria automática no padrão | No AX5 | Rótulos e dicas do VoiceOver no código | Títulos com traço de cabeçalho | Alvos de toque de 44 pt | Contraste | Reduzir Movimento | Estado não comunicado só por cor | VoiceOver em aparelho |
|---|---|---|---|---|---|---|---|---|---|
| Entrada ("Frila") | ok: AuditoriaDeAcessibilidadeUITests.swift:173 (`testEntradaCodigoECadastro`) | ok: AuditoriaDeAcessibilidadeUITests.swift:174 (`testEntradaCodigoECadastroEmAX5`) | ok: AuditoriaDeAcessibilidadeUITests.swift:173 (coberto pela auditoria) | ok: TelaEntrada.swift:22 (`isHeader` no título "Frila") | ok: AuditoriaDeAcessibilidadeUITests.swift:173 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:173 (auditado; Acessibilidade.md:180) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Código de verificação ("Digite o código") | ok: AuditoriaDeAcessibilidadeUITests.swift:173 (`testEntradaCodigoECadastro`) | ok: AuditoriaDeAcessibilidadeUITests.swift:174 (`testEntradaCodigoECadastroEmAX5`) | ok: TelaCodigo.swift:93 (`accessibilityHint` "Digite os seis números...") | ok: TelaCodigo.swift:45 (`isHeader` no título "Digite o código") | ok: AuditoriaDeAcessibilidadeUITests.swift:173 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:173 (auditado; Acessibilidade.md:180) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Cadastro ("Como você vai usar o Frila?") | ok: AuditoriaDeAcessibilidadeUITests.swift:173 (`testEntradaCodigoECadastro`) | ok: AuditoriaDeAcessibilidadeUITests.swift:174 (`testEntradaCodigoECadastroEmAX5`) | ok: TelaCadastro.swift:214 (valor "Selecionado" nos cartões) | ok: TelaCadastro.swift:44 (`isHeader` no título "Como você vai usar o Frila?") | ok: AuditoriaDeAcessibilidadeUITests.swift:173 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:173 (auditado; token Warning 3,78:1 em Acessibilidade.md:186) | não se aplica: tela sem animação | ok: TelaCadastro.swift:233 (ícone `checkmark.circle.fill` e `.isSelected`) | falta: pessoa com VoiceOver |
| Vagas no DF (Lista de vagas) | ok: AuditoriaDeAcessibilidadeUITests.swift:203 (`testListaDetalheECandidatura`) | ok: AuditoriaDeAcessibilidadeUITests.swift:204 (`testListaDetalheECandidaturaEmAX5`) | ok: TelaVagas.swift:120 (`accessibilityHint("Abre o detalhe da vaga")`) | ok: AuditoriaDeAcessibilidadeUITests.swift:190 (navigationTitle "Vagas no DF") | ok: AuditoriaDeAcessibilidadeUITests.swift:203 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:203 (auditado; Acessibilidade.md:180) | não se aplica: tela sem animação | ok: TelaVagas.swift:164 (ícone de check nas pílulas de filtro ativas) | falta: pessoa com VoiceOver |
| Detalhe da vaga | ok: AuditoriaDeAcessibilidadeUITests.swift:203 (`testListaDetalheECandidatura`) | ok: AuditoriaDeAcessibilidadeUITests.swift:204 (`testListaDetalheECandidaturaEmAX5`) | ok: AuditoriaDeAcessibilidadeUITests.swift:203 (coberto pela auditoria) | ok: TelaDetalheVaga.swift:121,152 (`isHeader` na função e requisitos) | ok: AuditoriaDeAcessibilidadeUITests.swift:203 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:203 (auditado; Acessibilidade.md:89) | ok: TelaDetalheVaga.swift:64 (consulta `UIAccessibility.isReduceMotionEnabled`) | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Turno confirmado! (Resultado de candidatura) | ok: AuditoriaDeAcessibilidadeUITests.swift:203 (`testListaDetalheECandidatura`) | ok: AuditoriaDeAcessibilidadeUITests.swift:204 (`testListaDetalheECandidaturaEmAX5`) | ok: TelasDaCandidatura.swift:139 (anúncio sonoro do título) | ok: TelasDaCandidatura.swift:265,280 (`isHeader` em título e detalhes) | ok: AuditoriaDeAcessibilidadeUITests.swift:203 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:203 (auditado; Acessibilidade.md:89) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Vaga preenchida (Resultado de candidatura) | ok: AuditoriaDeAcessibilidadeUITests.swift:221 (`testResultadosDaCandidatura`) | ok: AuditoriaDeAcessibilidadeUITests.swift:222 (`testResultadosDaCandidaturaEmAX5`) | ok: AuditoriaDeAcessibilidadeUITests.swift:221 (coberto pela auditoria) | ok: TelasDaCandidatura.swift:232 (`isHeader` no título do resultado) | ok: AuditoriaDeAcessibilidadeUITests.swift:221 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:221 (auditado; Acessibilidade.md:89) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Vaga encerrada (Resultado de candidatura) | ok: AuditoriaDeAcessibilidadeUITests.swift:221 (`testResultadosDaCandidatura`) | ok: AuditoriaDeAcessibilidadeUITests.swift:222 (`testResultadosDaCandidaturaEmAX5`) | ok: AuditoriaDeAcessibilidadeUITests.swift:221 (coberto pela auditoria) | ok: TelasDaCandidatura.swift:232 (`isHeader` no título do resultado) | ok: AuditoriaDeAcessibilidadeUITests.swift:221 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:221 (auditado; Acessibilidade.md:89) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Conflito de horário (Resultado de candidatura) | ok: AuditoriaDeAcessibilidadeUITests.swift:221 (`testResultadosDaCandidatura`) | ok: AuditoriaDeAcessibilidadeUITests.swift:222 (`testResultadosDaCandidaturaEmAX5`) | ok: AuditoriaDeAcessibilidadeUITests.swift:221 (coberto pela auditoria) | ok: TelasDaCandidatura.swift:232 (`isHeader` no título do resultado) | ok: AuditoriaDeAcessibilidadeUITests.swift:221 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:221 (auditado; Acessibilidade.md:89) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Conta suspensa (Resultado de candidatura) | ok: AuditoriaDeAcessibilidadeUITests.swift:221 (`testResultadosDaCandidatura`) | ok: AuditoriaDeAcessibilidadeUITests.swift:222 (`testResultadosDaCandidaturaEmAX5`) | ok: AuditoriaDeAcessibilidadeUITests.swift:221 (coberto pela auditoria) | ok: TelasDaCandidatura.swift:232 (`isHeader` no título do resultado) | ok: AuditoriaDeAcessibilidadeUITests.swift:221 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:221 (auditado; Acessibilidade.md:89) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Candidaturas (Aba Candidaturas) | ok: AuditoriaDeAcessibilidadeUITests.swift:241 (`testCandidaturasEmSelecao`) | ok: AuditoriaDeAcessibilidadeUITests.swift:242 (`testCandidaturasEmSelecaoEmAX5`) | ok: CandidaturaEmSelecao.swift:236,500 (`accessibilityHint` de ação e estado) | ok: CandidaturaEmSelecao.swift:266,492 (`isHeader` nas seções) | ok: AuditoriaDeAcessibilidadeUITests.swift:241 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:241 (auditado; Acessibilidade.md:180) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Meus turnos (Aba Meus turnos) | ok: AuditoriaDeAcessibilidadeUITests.swift:265 (`testMeusTurnosMeuTurnoEAvaliacao`) | ok: AuditoriaDeAcessibilidadeUITests.swift:266 (`testMeusTurnosMeuTurnoEAvaliacaoEmAX5`) | ok: TelaMeusTurnos.swift:93 (`accessibilityHint("Abre o detalhe do turno")`) | ok: AuditoriaDeAcessibilidadeUITests.swift:252 (navigationTitle "Meus turnos") | ok: AuditoriaDeAcessibilidadeUITests.swift:265 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:265 (auditado; Acessibilidade.md:89) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Meu turno | ok: AuditoriaDeAcessibilidadeUITests.swift:265 (`testMeusTurnosMeuTurnoEAvaliacao`) | ok: AuditoriaDeAcessibilidadeUITests.swift:266 (`testMeusTurnosMeuTurnoEAvaliacaoEmAX5`) | ok: TelaMeuTurno.swift:101,176,235 (`accessibilityHint` em ajuda, mapa e WhatsApp) | ok: TelaMeuTurno.swift:133,191,212,259 (`isHeader` nos blocos da tela) | ok: AuditoriaDeAcessibilidadeUITests.swift:265 (mapa e botões 44 pt via #133) | ok: AuditoriaDeAcessibilidadeUITests.swift:265 (auditado; Acessibilidade.md:89) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Avaliação do turno | ok: AuditoriaDeAcessibilidadeUITests.swift:265 (`testMeusTurnosMeuTurnoEAvaliacao`) | ok: AuditoriaDeAcessibilidadeUITests.swift:266 (`testMeusTurnosMeuTurnoEAvaliacaoEmAX5`) | ok: AuditoriaDeAcessibilidadeUITests.swift:265 (coberto pela auditoria) | ok: TelaAvaliacao.swift:59 (`isHeader` no título) | ok: AuditoriaDeAcessibilidadeUITests.swift:265 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:265 (auditado; Acessibilidade.md:89) | não se aplica: tela sem animação | ok: Componentes.swift:318 (respostas com valor "Selecionado") | falta: pessoa com VoiceOver |
| Meu perfil | ok: AuditoriaDeAcessibilidadeUITests.swift:329 (`testPerfilEExclusaoDeConta`) | ok: AuditoriaDeAcessibilidadeUITests.swift:330 (`testPerfilEExclusaoDeContaEmAX5`) | ok: PerfisDaConta.swift:192 (children: .combine em `linha(_:_:)`, Acessibilidade.md:69) | ok: PerfisDaConta.swift:125 (`isHeader` no nome do perfil) | ok: AuditoriaDeAcessibilidadeUITests.swift:329 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:329 (auditado; secondaryLabel em Acessibilidade.md:191) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Funções e horários | ok: AuditoriaDeAcessibilidadeUITests.swift:329 (`testPerfilEExclusaoDeConta`) | ok: AuditoriaDeAcessibilidadeUITests.swift:330 (`testPerfilEExclusaoDeContaEmAX5`) | ok: AuditoriaDeAcessibilidadeUITests.swift:329 (coberto pela auditoria) | ok: TelaPerfilProfissional.swift:91 (`isHeader` nas seções) | ok: AuditoriaDeAcessibilidadeUITests.swift:329 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:329 (auditado; Acessibilidade.md:89) | não se aplica: tela sem animação | ok: Componentes.swift:138,150 (FiltroPill com checkmark e .isSelected) | falta: pessoa com VoiceOver |
| Exclusão de conta | ok: AuditoriaDeAcessibilidadeUITests.swift:329 (`testPerfilEExclusaoDeConta`) | ok: AuditoriaDeAcessibilidadeUITests.swift:330 (`testPerfilEExclusaoDeContaEmAX5`) | ok: TelaExclusaoDeConta.swift:128 (ícone decorativo com `accessibilityHidden(true)`, Acessibilidade.md:65) | ok: AuditoriaDeAcessibilidadeUITests.swift:326 (navigationTitle inline) | ok: AuditoriaDeAcessibilidadeUITests.swift:329 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:329 (auditado; Acessibilidade.md:89) | não se aplica: tela sem animação | ok: TelaExclusaoDeConta.swift:199 (Toggle nativo) | falta: pessoa com VoiceOver |
| Conta suspensa | ok: AuditoriaDeAcessibilidadeUITests.swift:338 (`testContaSuspensa`) | ok: AuditoriaDeAcessibilidadeUITests.swift:339 (`testContaSuspensaEmAX5`) | ok: TelaContaSuspensa.swift:69 (ícone com `accessibilityHidden(true)`, Acessibilidade.md:67) | ok: AuditoriaDeAcessibilidadeUITests.swift:335 (título auditado) | ok: AuditoriaDeAcessibilidadeUITests.swift:338 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:338 (auditado; Acessibilidade.md:89) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Cadastro do estabelecimento | ok: AuditoriaDeAcessibilidadeUITests.swift:362 (`testCadastroDoEstabelecimentoEPublicarVaga`) | ok: AuditoriaDeAcessibilidadeUITests.swift:363 (`testCadastroDoEstabelecimentoEPublicarVagaEmAX5`) | ok: CadastroEstabelecimento.swift:240,257,318 (`accessibilityHint` nos controles) | ok: AuditoriaDeAcessibilidadeUITests.swift:351 (título auditado) | ok: AuditoriaDeAcessibilidadeUITests.swift:362 (alvos do app >= 44 pt; link Legal do MapKit do sistema, Acessibilidade.md:86) | ok: AuditoriaDeAcessibilidadeUITests.swift:362 (auditado; Acessibilidade.md:180) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Publicar vaga | ok: AuditoriaDeAcessibilidadeUITests.swift:362 (`testCadastroDoEstabelecimentoEPublicarVaga`) | ok: AuditoriaDeAcessibilidadeUITests.swift:363 (`testCadastroDoEstabelecimentoEPublicarVagaEmAX5`) | ok: AuditoriaDeAcessibilidadeUITests.swift:362 (coberto pela auditoria) | ok: AuditoriaDeAcessibilidadeUITests.swift:349 (navigationTitle e seções) | ok: AuditoriaDeAcessibilidadeUITests.swift:362 (alvos do app >= 44 pt; link Legal do MapKit do sistema, Acessibilidade.md:86) | ok: AuditoriaDeAcessibilidadeUITests.swift:362 (auditado; Acessibilidade.md:180) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Minhas vagas | ok: AuditoriaDeAcessibilidadeUITests.swift:383 (`testMinhasVagasDetalheEPerfilPublico`) | ok: AuditoriaDeAcessibilidadeUITests.swift:384 (`testMinhasVagasDetalheEPerfilPublicoEmAX5`) | ok: MinhasVagas.swift:383 (`accessibilityHint` "Ver detalhes da vaga") | ok: MinhasVagas.swift:271,378 (`isHeader` nas seções do painel) | ok: AuditoriaDeAcessibilidadeUITests.swift:383 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:383 (auditado; Acessibilidade.md:89) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Detalhe da vaga do contratante | ok: AuditoriaDeAcessibilidadeUITests.swift:383 (`testMinhasVagasDetalheEPerfilPublico`) | ok: AuditoriaDeAcessibilidadeUITests.swift:384 (`testMinhasVagasDetalheEPerfilPublicoEmAX5`) | ok: AuditoriaDeAcessibilidadeUITests.swift:383 (coberto pela auditoria) | ok: MinhasVagas.swift:548,584 (`isHeader` na função e posições) | ok: AuditoriaDeAcessibilidadeUITests.swift:383 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:383 (auditado; Acessibilidade.md:89) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Republicar vaga | ok: AuditoriaDeAcessibilidadeUITests.swift:397 (`testRepublicarVaga`) | ok: AuditoriaDeAcessibilidadeUITests.swift:398 (`testRepublicarVagaEmAX5`) | ok: AuditoriaDeAcessibilidadeUITests.swift:397 (coberto pela auditoria) | ok: RepublicarVaga.swift:364,420 (`isHeader` nas seções) | ok: AuditoriaDeAcessibilidadeUITests.swift:397 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:397 (auditado; Acessibilidade.md:89) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Acompanhamento do turno | ok: AuditoriaDeAcessibilidadeUITests.swift:414 (`testAcompanhamentoDoTurno`) | ok: AuditoriaDeAcessibilidadeUITests.swift:415 (`testAcompanhamentoDoTurnoEmAX5`) | ok: TelaTurnoDoContratante.swift:225 (`accessibilityHint(dicaAjudaTurno)`) | ok: TelaTurnoDoContratante.swift:161,184,237,481 (`isHeader` nas seções) | ok: AuditoriaDeAcessibilidadeUITests.swift:414 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:414 (auditado; Acessibilidade.md:89) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Perfil do estabelecimento | ok: AuditoriaDeAcessibilidadeUITests.swift:436 (`testPerfilDoEstabelecimento`) | ok: AuditoriaDeAcessibilidadeUITests.swift:437 (`testPerfilDoEstabelecimentoEmAX5`) | ok: FluxoDoContratante.swift:116 (`accessibilityShowsLargeContentViewer()`, Acessibilidade.md:72) | ok: PerfisDaConta.swift:258 (`isHeader` no nome do estabelecimento) | ok: AuditoriaDeAcessibilidadeUITests.swift:436 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:436 (auditado; secondaryLabel em Acessibilidade.md:191) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Perfil público | ok: AuditoriaDeAcessibilidadeUITests.swift:383 (`testMinhasVagasDetalheEPerfilPublico`) | ok: AuditoriaDeAcessibilidadeUITests.swift:384 (`testMinhasVagasDetalheEPerfilPublicoEmAX5`) | ok: AuditoriaDeAcessibilidadeUITests.swift:383 (coberto pela auditoria) | ok: AcoesDeSeguranca.swift:197 (`isHeader` no nome do perfil público) | ok: AuditoriaDeAcessibilidadeUITests.swift:383 (alvos >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:383 (auditado; Acessibilidade.md:89) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Publicar vaga: erro ao ler casa | ok: AuditoriaDeAcessibilidadeUITests.swift:466 (`testPublicarVagaErroAoLerCasa`) | ok: AuditoriaDeAcessibilidadeUITests.swift:467 (`testPublicarVagaErroAoLerCasaEmAX5`) | ok: AuditoriaDeAcessibilidadeUITests.swift:466 (coberto pela auditoria) | ok: AuditoriaDeAcessibilidadeUITests.swift:463 (título de erro auditado) | ok: AuditoriaDeAcessibilidadeUITests.swift:466 (BotaoSecundario >= 44 pt) | ok: AuditoriaDeAcessibilidadeUITests.swift:466 (auditado; Acessibilidade.md:180) | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Folha de cancelamento | falta: sem teste de auditoria automática | falta: sem teste de auditoria automática em AX5 | ok: FolhaDeCancelamento.swift:42,132 (recolher teclado com rótulo, ícone com `accessibilityHidden`) | ok: FolhaDeCancelamento.swift:58 (`isHeader` no motivo) | ok: FolhaDeCancelamento.swift:80,138,172 (minHeight 44 pt) | falta: sem auditoria de contraste | não se aplica: tela sem animação | ok: FolhaDeCancelamento.swift:130,142 (ícone preenchido e `.isSelected`) | falta: pessoa com VoiceOver |
| Histórico de turnos | ok: AuditoriaDeAcessibilidadeUITests.swift:357 (`testHistoricoDeTurnos`) | ok: AuditoriaDeAcessibilidadeUITests.swift:358 (`testHistoricoDeTurnosEmAX5`) | ok: TelaHistoricoDeTurnos.swift:35,130 (`accessibilityHint(dicaExportar)`, FiltroPill com valor de acessibilidade) | ok: TelaHistoricoDeTurnos.swift:81,157 (`isHeader` em período e formato) | ok: TelaHistoricoDeTurnos.swift:144,178 (minHeight 44 pt em pílulas, picker e botões) | falta: sem auditoria de contraste | ok: TelaHistoricoDeTurnos.swift:50 (checa `accessibilityReduceMotion` antes da rolagem) | ok: Componentes.swift:138,150 (FiltroPill com checkmark e `.isSelected`) | falta: pessoa com VoiceOver |
| Confirmação de exclusão de conta | ok: AuditoriaDeAcessibilidadeUITests.swift:389 (`testConfirmacaoDeExclusaoDeConta`) | ok: AuditoriaDeAcessibilidadeUITests.swift:390 (`testConfirmacaoDeExclusaoDeContaEmAX5`) | ok: TelaExclusaoDeConta.swift:62,71 (botões nomeados semanticamente) | ok: TelaExclusaoDeConta.swift:53 (`isHeader` no título do diálogo) | ok: TelaExclusaoDeConta.swift:74 (minHeight 44 pt) | falta: sem auditoria de contraste | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Por que recebo vagas | ok: AuditoriaDeAcessibilidadeUITests.swift:406 (`testPorQueReceboVagas`) | ok: AuditoriaDeAcessibilidadeUITests.swift:407 (`testPorQueReceboVagasEmAX5`) | ok: TelaPorQueReceboVagas.swift:102,160 (cartões com children: .combine, prompt e label no TextField) | ok: TelaPorQueReceboVagas.swift:97,127 (`isHeader` nos cartões de critérios e contestação) | ok: TelaPorQueReceboVagas.swift:180,185 (botões com minHeight >= 44 pt) | falta: sem auditoria de contraste | não se aplica: tela sem animação | ok: TelaPorQueReceboVagas.swift:174,207 (contagem numérica em texto e checkmark em Label) | falta: pessoa com VoiceOver |
| Equipe de confiança | ok: AuditoriaDeAcessibilidadeUITests.swift:575 (`testEquipeDeConfianca`) | ok: AuditoriaDeAcessibilidadeUITests.swift:576 (`testEquipeDeConfiancaEmAX5`) | ok: TelaEquipeDeConfianca.swift:96 (`accessibilityLabel` explícito no botão remover com nome) | ok: TelaEquipeDeConfianca.swift:87 (`isHeader` no nome do membro) | ok: TelaEquipeDeConfianca.swift:129,138 (minHeight 44 pt) | falta: sem auditoria de contraste | não se aplica: tela sem animação | ok: TelaEquipeDeConfianca.swift:125 (`checkmark.seal` em Label no status "Na equipe") | falta: pessoa com VoiceOver |
| Folha de suporte no turno | falta: sem teste de auditoria automática | falta: sem teste de auditoria automática em AX5 | ok: FolhaSuporteTurno.swift:112,270,276 (rótulo em motivo, dicas de envio e cópia) | falta: subtítulos de seção sem isHeader em FolhaSuporteTurno.swift:84,178,202 | ok: FolhaSuporteTurno.swift:108,143,158 (minHeight 44 pt) | falta: sem auditoria de contraste | ok: FolhaSuporteTurno.swift:91 (checa `accessibilityReduceMotion` antes de animar) | ok: FolhaSuporteTurno.swift:100,114 (ícone preenchido e `.isSelected`) | falta: pessoa com VoiceOver |
| Folha de denúncia | falta: sem teste de auditoria automática | falta: sem teste de auditoria automática em AX5 | ok: AcoesDeSeguranca.swift:80,87,161 (children: .combine em protocolo/prazo, recolher teclado com rótulo) | ok: AcoesDeSeguranca.swift:74 (`isHeader` no título do desfecho) | ok: AcoesDeSeguranca.swift:128,135 (minHeight 44 pt) | falta: sem auditoria de contraste | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Ajuda do perfil | ok: AuditoriaDeAcessibilidadeUITests.swift:423 (`testAjudaDoPerfil`) | ok: AuditoriaDeAcessibilidadeUITests.swift:424 (`testAjudaDoPerfilEmAX5`) | ok: PerfisDaConta.swift:369,370,403 (rótulo e dica em suporte, termos e privacidade com traço .isLink) | ok: PerfisDaConta.swift:433 (navigationTitle inline) | ok: PerfisDaConta.swift:366,400,416,428,442 (minHeight 44 pt) | falta: sem auditoria de contraste | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Licenças de código aberto | ok: AuditoriaDeAcessibilidadeUITests.swift:452 (`testLicencasEDetalhe`) | ok: AuditoriaDeAcessibilidadeUITests.swift:453 (`testLicencasEDetalheEmAX5`) | ok: TelaLicencas.swift:64 (`accessibilityHint(dicaAbrir)`) | ok: TelaLicencas.swift:75 (navigationTitle inline) | ok: TelaLicencas.swift:90 (minHeight 44 pt) | falta: sem auditoria de contraste | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Detalhe da licença | ok: AuditoriaDeAcessibilidadeUITests.swift:452 (`testLicencasEDetalhe`) | ok: AuditoriaDeAcessibilidadeUITests.swift:453 (`testLicencasEDetalheEmAX5`) | ok: TelaLicencas.swift:137 (children: .combine em campo) | ok: TelaLicencas.swift:118 (`isHeader` em avisos do pacote) | ok: TelaLicencas.swift:107 (minHeight 44 pt no link) | falta: sem auditoria de contraste | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Explicação de notificações push | falta: sem teste de auditoria automática | falta: sem teste de auditoria automática em AX5 | ok: TelasDaPermissaoDePush.swift:24,42,47 (ícone hidden, botões nomeados) | ok: TelasDaPermissaoDePush.swift:27 (`isHeader` no título principal) | ok: TelasDaPermissaoDePush.swift:42,47 (botões >= 44 pt) | falta: sem auditoria de contraste | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Vaga indisponível (Aviso Push) | falta: sem teste de auditoria automática | falta: sem teste de auditoria automática em AX5 | ok: DestinosDoAviso.swift:141,144 (children: .combine em título/mensagem, botão voltar) | ok: DestinosDoAviso.swift:137 (`isHeader` no título da mensagem) | ok: DestinosDoAviso.swift:144 (BotaoSecundario >= 44 pt) | falta: sem auditoria de contraste | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Turno do aviso não encontrado (Push) | falta: sem teste de auditoria automática | falta: sem teste de auditoria automática em AX5 | ok: DestinosDoAviso.swift:251,253 (children: .combine em título/mensagem, botão ver turnos) | ok: DestinosDoAviso.swift:247 (`isHeader` no título da mensagem) | ok: DestinosDoAviso.swift:253 (BotaoSecundario >= 44 pt) | falta: sem auditoria de contraste | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Atualização obrigatória | falta: sem teste de auditoria automática | falta: sem teste de auditoria automática em AX5 | ok: AtualizacaoObrigatoria.swift:88,91 (ícone hidden, botão nomeado) | falta: título sem isHeader em AtualizacaoObrigatoria.swift:89 | ok: AtualizacaoObrigatoria.swift:91 (BotaoPrimario >= 44 pt) | falta: sem auditoria de contraste | não se aplica: tela sem animação | não se aplica: tela sem seleção de estado por cor | falta: pessoa com VoiceOver |
| Compartilhamento / exportação de dados | não se aplica: folha nativa do sistema iOS (Acessibilidade.md:32) | não se aplica: folha nativa do sistema iOS (Acessibilidade.md:32) | ok: ItemExportarDados.swift:60,61 (rótulo e dica no botão que abre a folha) | não se aplica: folha nativa do sistema iOS | ok: ItemExportarDados.swift:55 (minHeight 44 pt no botão do app que abre) | não se aplica: folha nativa do sistema iOS | não se aplica: folha nativa do sistema iOS | não se aplica: folha nativa do sistema iOS | falta: pessoa com VoiceOver |
| Compositor de e-mail nativo | não se aplica: folha nativa do sistema iOS (Acessibilidade.md:32) | não se aplica: folha nativa do sistema iOS (Acessibilidade.md:32) | ok: FolhaSuporteTurno.swift:270 (dica no botão que abre o compositor) | não se aplica: folha nativa do sistema iOS | ok: FolhaSuporteTurno.swift:256 (BotaoPrimario >= 44 pt no botão do app que abre) | não se aplica: folha nativa do sistema iOS | não se aplica: folha nativa do sistema iOS | não se aplica: folha nativa do sistema iOS | falta: pessoa com VoiceOver |

### Folhas nativas do sistema iOS

1. **Compartilhamento / exportação de dados (`ItemExportarDados.swift:5`, `FolhaCompartilhamento`)**
   - **Natureza:** Folha nativa do iOS (`UIActivityViewController`). Conforme documentado em `Acessibilidade.md:32`, controles e folhas do sistema ficam fora do escopo de auditoria do app por serem componentes do sistema operacional.
   - **Controle do app:** O app controla o botão que dispara a apresentação da folha em `ItemExportarDados.swift:39-57` (identificador dinâmico, rótulo `TextosExportarDados.titulo`, dica `TextosExportarDados.dicaAcessibilidade` na linha 61 e área de toque `minHeight: FrilaMetrica.alvoMinimo` na linha 55) e em `TelaHistoricoDeTurnos.swift:31-36` (`BotaoPrimario` com `accessibilityHint(dicaExportar)`).
2. **Compositor de e-mail nativo (`CompositorDeEmail.swift:7`, `CompositorDeEmailNativo`)**
   - **Natureza:** Folha nativa do iOS (`MFMailComposeViewController`). Requer conta de e-mail ativa no sistema operacional (`MFMailComposeViewController.canSendMail()`). Fica fora do escopo de auditoria do app por ser componente do sistema operacional.
   - **Controle do app:** O app controla o botão que aciona o compositor em `FolhaSuporteTurno.swift:256-271` (`BotaoPrimario` com `accessibilityIdentifier("botao-enviar-email-suporte")`, dica `TextosDoSuporte.dicaEnviarEmail` na linha 270 e altura mínima de 44 pt), além do tratamento de fallback com cópia para a área de transferência caso o envio nativo falhe ou não esteja disponível.

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
