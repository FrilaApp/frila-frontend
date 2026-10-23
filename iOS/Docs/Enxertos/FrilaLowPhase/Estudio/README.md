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
6. Prévia: sem reputação nem urgência fictícias. Celebração: sem a notificação de tela de bloqueio
   (fora do escopo) e sem dados de exemplo.
7. Erro do servidor ou da validação: alerta "Não deu para publicar", com a mensagem do app. O botão
   fica desligado enquanto envia.
8. Código: `#Preview` removidos; animações passam por `FrilaMovimento.animacao` (Reduzir Movimento);
   textos com `bundle:`; ajustes de Swift 6 (`nonisolated`, `@MainActor`, catálogo sob trava).
9. Duplicação aceita: tokens, fontes e botões também existem no #493 (prefixo `FrilaLP`). O
   `GuardaTokensDesignTests` recebe a mesma mudança do #493 (aceitar `*DesignTokens.swift`). A
   diluição resolve.

## Como ligar

Só em DEBUG. Lance o app com o argumento `-FRILA_ENXERTO_LOWPHASE_ESTUDIO` e abra "Publicar vaga":
o `DestinoDePublicarVaga` (`Fluxos/Contratante/PublicarVagaDaCasa.swift`) mostra o estúdio no lugar
da `TelaPublicarVaga`. Sem o argumento, e em Release, o fluxo atual fica igual.

## Como remover

1. Apague `Sources/Apresentacao/Enxertos/FrilaLowPhase/Estudio/`, esta pasta e
   `Tests/Unitarios/EstudioFrilaLPETests.swift`.
2. Em `PublicarVagaDaCasa.swift`, tire o bloco `#if DEBUG … #else` e deixe só a `TelaPublicarVaga`.
3. Rode `Scripts/gerar-projeto.sh`.

## Licença da fonte

Bricolage Grotesque usa a SIL Open Font License 1.1, a mesma das fontes do app
(`Resources/Fonts/BricolageGrotesque-OFL.txt`). Aviso: a OFL permite embutir no app, mas o arquivo
renomeado continua sob a OFL, e a licença precisa seguir junto se a fonte for distribuída à parte.
Ela não pode ser vendida sozinha.
