# Enxerto FrilaLowPhase: estúdio de criação de vagas

Recorte do "Estúdio de Criação de Vagas" do FrilaLowPhase (Laboratório → Studio Lab), com a prévia e
a celebração, colocado no app com a estética da origem, isolado e removível. É matéria-prima para a
diluição do design system: não unifica com o tema atual (`Docs/DesignSystem.md`) nem o altera.

É outra peça que o enxerto de Publicar vaga (PR #493). Os documentos de design da origem (`DESIGN.md`,
`DESIGN-SOURCE-DOCUMENT.md`, `design-system/` com o `JOB_CREATION_FLOW_SPEC.md`) estão no README e
na pasta daquele PR, `Docs/Enxertos/FrilaLowPhase/`, e não são copiados de novo aqui.

## De onde veio

- Repositório `Frila/FrilaLowPhase`, `main` em `4badc63`.
- Tela: `Sources/FrilaDesignSystem/Components/FrilaJobCreationStudioView.swift` (estúdio, rascunho,
  prévia e celebração), com o que ela usa em `Components/`, `Primitives/` e `Shifts/`.
- Como a origem abre o estúdio: `DesignLab/Experiments/StudioExperimentView.swift`.

## O que foi copiado

Em `Sources/Apresentacao/Enxertos/FrilaLowPhase/Estudio/`, com o prefixo `FrilaLPE` em todos os tipos:

- `Components/`: o estúdio, as seções do formulário, roletas (coluna, física, perspectiva), seletor
  acoplado de categoria e função, seletores de turno, `FrilaFlowStepper`, campo que se expande,
  prévia (`OpportunityDetailView`, `OpportunityCard`, `PriceTag`, `StatCard`, `NumberedList`),
  botões, chip, toast e os modificadores de teclado e de toque fora.
- `Primitives/` e `Shifts/`: tokens de cor, tipografia, geometria, sombra, movimento, dinheiro,
  vidro, desfoque e esqueleto; modelos e tokens de turno.
- `Recursos/Fontes/`: Bricolage Grotesque Regular, Medium, Bold e ExtraBold, renomeadas para
  `FrilaLPE-…` e registradas só no processo. Regular e Bold são o mesmo arquivo das fontes do app
  (mesmo md5).
- `Recursos/FrilaLPEEstudio.xcstrings`: os textos da origem, numa tabela própria.
- `TelaEstudioFrilaLPE.swift` e `FormularioEstudioFrilaLPE.swift`: a entrada e a ponte com o
  `PublicarVagaViewModel`.

## O que mudou em relação à origem

O botão Publicar grava pelo `PublicarVagaViewModel` e pelo `ApiCliente` do app: mesmos campos, mesma
validação, mesma fila. Não há campo, regra nem endpoint novo.

1. Função: as roletas mostram `api.funcoes()`, agrupadas pela categoria do servidor, no lugar do
   catálogo fixo de 45 funções. Função digitada (a "personalizada") não existe no contrato: o
   estúdio a aceita, mas Publicar devolve o erro de função da validação.
2. Fora do envio, porque o contrato não tem: título, ofício, senioridade, tags, foto, protocolo,
   orçamento total e distância. Aparecem na prévia como na origem e ficam só no rascunho.
3. Valor: o app publica valor por turno. Com "Por hora", Publicar avisa e não envia. O valor por
   posição vira centavos (`valorTexto`).
4. Data e horários: lidos no fuso de Brasília. Fim igual ou antes do início vira o dia seguinte.
5. Cliente: fixo no nome do estabelecimento. Endereço inicial: o local da casa.
6. Prévia: sem reputação nem urgência fictícias, e o botão principal diz "Publicar vaga" (na origem,
   "Candidatar-me"). Celebração: sem a notificação de tela de bloqueio (fora do escopo) e sem dados
   de exemplo; tocar no aviso enviado faz o mesmo que "Ver Detalhes da Vaga".
7. Etapa Turno: "Quem recebe o profissional no local" também é obrigatório, como o
   `responsavel_local` na validação do app. A distância do local fica em
   `Shifts/FrilaLPEShiftDistance.swift`, fora do arquivo de modelos, por causa do guarda do US18.
8. Erro do servidor ou da validação: alerta "Não deu para publicar", com a mensagem do app. O botão
   fica desligado enquanto envia.
9. Código: `#Preview` removidos; animações passam por `FrilaMovimento.animacao` (Reduzir Movimento);
   textos com `bundle:`; ajustes de Swift 6 (`nonisolated`, `@MainActor`, catálogo sob trava).
10. Duplicação aceita: tokens, fontes e botões também existem no #493 (prefixo `FrilaLP`). O
    `GuardaTokensDesignTests` recebe a mesma mudança do #493 (aceitar `*DesignTokens.swift`). A
    diluição resolve.

11. Hi-Fi, Fase 1 (24/10): o estúdio é o "Publicar vaga" do app, sem flag. O app entra por ganchos
    (`FrilaLPEStudioHostHooks`, em `FrilaLPEJobCreationStudioView.swift`) sem mexer no desenho da
    origem: avisos da fila, da pendência e de erro no topo do formulário; o modo da vaga
    (urgência/seleção, MS-RF01) no fim da etapa Turno, construído do zero no idioma da origem porque
    o FrilaLowPhase não tem seletor de modo (`ComplementosDoAppEstudioFrilaLPE.swift`); campos
    travados com publicação pendente; "Tentar novamente" e "Voltar" nos rótulos; botão do perfil do
    estabelecimento no primeiro acesso (sem X). Sem rede, Publicar devolve `.queued`: o estúdio não
    celebra e o aviso "A publicação continua" aparece. O rascunho inicial traz data e horários dos
    padrões do app (agora + 3 h, arredondado ao passo de 30 min da roleta), não em branco como na
    origem. Identificadores dos testes de UI (`publicar-vaga-botao`, `funcao-vaga-picker`,
    `categoria-vaga-picker`, `funcao-vaga-roleta`, `categoria-vaga-roleta`, `posicoes-vaga-menos`,
    `valor-vaga-campo`, `datepicker-*`, `modo-vaga-picker`, `mais-opcoes-botao`, `rateio-vaga-campo`,
    `observacoes-vaga-campo`, `alerta-vaga-picker`, `celebracao-concluir`…) nos controles equivalentes.
    A roleta (`FrilaLPEWheelColumn`) é um elemento ajustável único; o XCUITest não aciona a ação
    ajustável, mas toca uma linha da roleta aberta, que gira até ela e confirma
    (`testEscolherFuncaoNaRoletaDestravaAPublicacao`); os demais testes usam a função do roteiro
    (`-FRILA_CADASTRO_UI_TEST`).
12. "Mais opções" no fim da etapa Valor (`MaisOpcoesEstudioFrilaLPE`, gancho `sectionFooter`): rateio
    dos 10%, observações e alerta de vaga vazia (`participaRateio`, `observacoes`,
    `alertaAntecedenciaMinutos` do `PublicarVagaViewModel`), funções do Publicar vaga que o estúdio da
    origem não desenhou. O cartão-linha (título, apoio, chevron) é o do protótipo midfi da origem
    (`prototipo-midfi/Publicar.dc.html`), que lá abria a tela `MaisOpcoes.dc.html`; aqui abre no lugar,
    com as molas de disclosure da origem (`FrilaLPEMotion.disclosureExpand/Collapse`,
    `frilaLPEDisclosureDrop`). Dentro: linha Sim/Não do formulário (`FrilaLPEJobFormYesNoRow`), campo
    rotulado com apoio (`FrilaLPEJobFormLabeledField`) e o segmentado com 2, 3 e 6 horas antes. Mesmos
    identificadores do formulário antigo (`mais-opcoes-botao`, `observacoes-vaga-campo`,
    `alerta-vaga-picker`; o rateio ganhou `rateio-vaga-campo`). Abre sozinho quando a restauração traz
    esses campos preenchidos ou quando um erro deles aparece. O traje fica na etapa Turno, onde a origem
    o pôs ("Traje ou uniforme"), por isso o apoio do cartão não o cita. O telefone do responsável
    (RN10), que o formulário antigo mostrava só para leitura com o número da conta, não aparece: a
    prévia mantém o aviso da origem sobre telefone e WhatsApp. Modo da vaga e responsável no local
    entram pelos ganchos (itens 7 e 11).

## Como entra no app

`DestinoDePublicarVaga` (`Fluxos/Contratante/PublicarVagaDaCasa.swift`) e o fim do cadastro da casa
(`CadastroEstabelecimento.swift`) abrem `TelaEstudioFrilaLPE`. A `TelaPublicarVaga` antiga segue no
código até a fatia Contratante da Fase 3 do Hi-Fi; o enxerto #493 (`-FRILA_ENXERTO_LOWPHASE`) segue
só em DEBUG até a Fase 2.

## Como remover

1. Apague `Sources/Apresentacao/Enxertos/FrilaLowPhase/Estudio/`, esta pasta e
   `Tests/Unitarios/EstudioFrilaLPETests.swift`.
2. Em `PublicarVagaDaCasa.swift` e `CadastroEstabelecimento.swift`, volte a abrir a `TelaPublicarVaga`.
3. Rode `Scripts/gerar-projeto.sh`.

## Licença da fonte

Bricolage Grotesque usa a SIL Open Font License 1.1, a mesma das fontes do app
(`Resources/Fonts/BricolageGrotesque-OFL.txt`). Aviso: a OFL permite embutir no app, mas o arquivo
renomeado continua sob a OFL, e a licença precisa seguir junto se a fonte for distribuída à parte.
Ela não pode ser vendida sozinha.
