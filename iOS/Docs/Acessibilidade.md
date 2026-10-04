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
| Corrigido em 04/10, quando os arquivos ficaram livres | 2 telas + 1 achado do QA | `PerfisDaConta.swift`, `TelaContaSuspensa.swift` (ícone; botões da contestação em AX5) |
| Fica para depois: arquivo ocupado por PR aberto | 5 telas | `FluxoDoProfissional`, `FluxoDoContratante`, `TelaMeuTurno`, `TelaDetalheVaga`, `PublicarVaga` |
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
| Vagas (lista) | P, AX5 | Dynamic Type | função, valor, estabelecimento, horário, local, inclusos, reputação e "vagas abertas" do cartão não acompanham a fonte | `TelaVagas.swift:108`: `.dynamicTypeSize(...accessibility1)` no cartão; `TelaVagas.swift:172`: o mesmo nas pílulas de filtro. Decisão de layout do #139, para o cartão caber na tela em AX5 (`AcessibilidadeDoProfissionalUITests` mede isso) | fica para o design: a alta fidelidade do #15 decide o cartão; a suíte registra com falha esperada estrita |
| Vagas (lista) | P, AX5 | Dynamic Type | botão "Catálogo" da barra não acompanha a fonte | `FluxoDoProfissional.swift` (item de toolbar, Debug): item de barra não escala por desenho do sistema; o caminho é `accessibilityShowsLargeContentViewer()` | fica: arquivo ocupado (#97); só existe em Debug |
| Perfil do estabelecimento | P, AX5 | Dynamic Type | botão "Fechar" da barra não acompanha a fonte | `FluxoDoContratante.swift:116` e `:136`: item de toolbar da folha; mesmo caso acima | fica: arquivo ocupado (#73) |
| Candidaturas (aba) | P | Dynamic Type | "Garçom" e "R$ 120,00" (função e valor do cartão) "não mudam de tamanho" | `CandidaturaEmSelecao.swift:535`: `ViewThatFits` com duas cópias de função/valor; no padrão vale o `HStack`, em AX5 o `VStack`, e o XCTest não acha o mesmo elemento ao variar a fonte. Inferência: falso positivo do `ViewThatFits`; o texto escala (a passada AX5 não aponta) | **falso positivo, confirmado em 04/10** (seção "Rodada de 04/10"); falha esperada estrita no tamanho padrão |
| Candidaturas (aba) | AX5 | texto cortado | elemento sem identificação | `CandidaturaEmSelecao.swift:533-568` (cartão); não encontrado qual texto (a auditoria não devolveu o elemento) | **provável falso positivo (04/10)**: aparece só com o `ViewThatFits` e a captura não mostra corte (seção "Rodada de 04/10"); falha esperada não estrita em AX5 |
| Publicar vaga | AX5 | Dynamic Type | `_UIDatePickerCompactTimeLabel` e `UILabel` do date picker | `PublicarVaga.swift:571-586`: `DatePicker` compacto do sistema não escala | fica: controle do sistema e arquivo ocupado (#73, #103); o caminho é `.datePickerStyle(.wheel)` ou `.graphical` nos tamanhos de acessibilidade |
| Detalhe da vaga (seleção) | P | texto cortado | "o estabelecimento escolhe entre os candidatos" | `TelaDetalheVaga.swift:214` (`TextosDoProfissional.Detalhe.selecaoDetalhe`) numa linha que não quebra | fica: arquivo ocupado (#97) |
| Meu turno | P | texto cortado | "· quem recebe: Marina" | `TelaMeuTurno.swift:71`: texto num `HStack` ao lado do atalho de mapas, sem quebra | fica: arquivo ocupado (#92, #93, #103) |
| Cadastro do estabelecimento, Publicar vaga | P | alvo | link "Legal" do mapa menor que 44 pt | `MKAttributionLabel` do MapKit (`CadastroEstabelecimento.swift:264`, `PublicarVaga.swift:405`) | sistema: não há API para o app |
| Entrada, Código, Cadastro, Funções e horários, Cadastro do estabelecimento, Publicar vaga (mais opções) | P, AX5 | texto cortado | "Text of this UITextField may be clipped" | `Componentes.swift` (`CampoFrila`) e `TelaCodigo.swift`: flag do `UITextField` que o SwiftUI não expõe | falso positivo do XCTest; prova em `testCampoDeTextoCresceEmAX5` |

Telas sem achado estrutural (só contraste, ou nada): detalhe da vaga, candidatura confirmada,
vaga preenchida, vaga encerrada, conflito de horário, candidatura com conta suspensa, Meus turnos,
avaliação, Funções e horários, Minhas vagas (painel, encerradas, presença a confirmar, turno em
atraso), detalhe da vaga do contratante (com e sem contato), perfil público, republicar vaga,
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
   (`PerfisDaConta.swift:179`) e no perfil do estabelecimento saem na `secondaryLabel` do iOS
   (≈ 3,3:1 sobre branco), e não em `TextSecondary` (`#4A5259`, 7,55:1). Apontados: telefone,
   e-mail, funções, "2 horários cadastrados", "Administrador", "Restaurante ou bar". Arquivo
   ocupado; a correção é trocar para o token.
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
ícone de check (`TelaVagas.swift:164`), os cartões de perfil do cadastro e as respostas Sim/Não
mudam fundo e borda e têm valor "Selecionado" no VoiceOver (`TelaCadastro.swift:214`,
`Componentes.swift:318`); os avisos mudam ícone por tom (`Componentes.swift:216`). Visualmente,
cartão de perfil e pílula do perfil só mudam cor e espessura da borda: fica para o design decidir
uma marca não cromática.

## Movimento

O app quase não anima. Única animação explícita: `TelaDetalheVaga.swift:60`, `withAnimation` ao
rolar até os avisos; não consulta `accessibilityReduceMotion`. Fica: arquivo ocupado (#97). Os
`ProgressView` são o indicador do sistema, que já respeita a preferência. A passada da suíte com
Reduzir Movimento ligado (03/10) não trouxe achado novo: o conjunto foi o mesmo da passada sem a
preferência, menos dois apontamentos que dependem do que estava visível no momento (o texto
cortado do modo seleção no detalhe da vaga e um contraste em AX5 na exclusão de conta).

## Fora da auditoria automática (para a parte humana do #71)

- Ordem de foco e agrupamento do VoiceOver: não medidos aqui.
- Anúncio de erro: `AvisoFrila` não anuncia ao aparecer; o campo com erro não é associado ao
  aviso (`TelaEntrada.swift:48`, `TelaCadastro.swift:163`). As telas de resultado anunciam o
  título (`TelasDaCandidatura.swift:139`).
- Cabeçalhos: os títulos da entrada ("Frila", "Digite o código", "Como você vai usar o Frila?")
  não têm o traço `isHeader`; os de perfil e das seções da aba Candidaturas têm.

## Como rodar

A suíte é **opcional**: na suíte normal e na CI ela é pulada com `XCTSkip`, porque são 29 casos
que abrem o app e auditam duas vezes, e o passo de testes da CI já leva de 42 a 53 dos 70 minutos
do job. Ela só roda com `FRILA_AUDITORIA_DE_ACESSIBILIDADE=1` no ambiente do test runner, que o
`xcodebuild` recebe com o prefixo `TEST_RUNNER_`. Medida no simulador iPhone 17 (03/10, três
passadas): 533 s, 512 s e 513 s só de testes, fora a compilação, ou seja, cerca de 9 minutos.

```sh
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
