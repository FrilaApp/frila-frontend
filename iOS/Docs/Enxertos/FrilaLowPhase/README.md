# Enxerto FrilaLowPhase: publicar vaga

Um recorte do fluxo "Nova vaga" do FrilaLowPhase, colocado no app com a estética da origem, isolado
e removível. Serve de matéria-prima para a diluição do design system. Não é para unificar com o
tema atual (`Docs/DesignSystem.md`), e nada daqui altera esse tema.

## De onde veio

- Repositório `Frila/FrilaLowPhase`, `main` em `4badc63`.
- Tela: `Sources/FrilaDesignSystem/Shifts/FrilaPublishShiftSheet.swift`, com o que ela usa em
  `Shifts/`, `Primitives/` e `Components/`.
- Spec: `design-system/JOB_CREATION_FLOW_SPEC.md`. Referência visual: os quadros de `prototipo-midfi/`.

## O que foi copiado

Código, em `Sources/Apresentacao/Enxertos/FrilaLowPhase/`, sempre com o prefixo `FrilaLP`:

- `Origem/`: tokens de cor, tipografia, forma, movimento e dinheiro; botão, chip, layout em fluxo,
  modificadores de teclado e de toque fora; modelos de turno (dia, relógio, janela), campos de
  formulário e o seletor de horário.
- `Recursos/Fontes/`: Bricolage Grotesque Regular, Medium, Bold e ExtraBold, com o mesmo arquivo da
  origem. A licença é a OFL, a mesma das fontes do app (`Resources/Fonts/BricolageGrotesque-OFL.txt`).
- `TelaPublicarVagaFrilaLP.swift`: a tela da origem (formulário, barra fixa com resumo e total,
  5 s de "Enviando" com Desfazer, descarte, sheets de Outra data e Trocar local).
- `FormularioPublicarVagaFrilaLP.swift`: converte o dia e a janela da origem em `inicio`/`fim` do
  `PublicarVagaViewModel` e traz os textos da barra.

Documentos, nesta pasta: `DESIGN.md`, `DESIGN-SOURCE-DOCUMENT.md`, `design-system/` inteiro
(com `tokens.json` e `tokens.css`), `REGRAS-DE-DESIGN.md` (trechos de `AGENTS.md` e `RULES.md`),
`orchestra/` (`PUBLICAR-CANVAS.md`, `FLUXO-VAGAS.md`) e `prototipo-midfi/` (quadros de Publicar,
PublicarCopia, PublicarRepublicar, RepetirVaga e TrocarLocal, com o `VERSAO.md`). O `support.js` do
MidFi não está versionado na origem, então os quadros abrem sem os estados alternativos.

## O que mudou em relação à origem

Dados: a tela grava pelo `PublicarVagaViewModel` e pelo `ApiCliente` do app, com os mesmos campos,
a mesma validação e a mesma fila. Não há campo, regra nem endpoint novo.

1. Função: vem de `vaga.funcoes`, a lista do servidor. O resumo diz "Garçom, 2 posições", e não
   "2 Garçons", porque o app não tem o plural da função.
2. Posições: de 1 a 200, a faixa que o view model aceita.
3. Local: o único endereço do estabelecimento. O sheet Trocar local mostra só esse endereço, porque
   o contrato não tem lista de locais.
4. Campo "Quem recebe o profissional no local": não existe na origem. Entrou porque o contrato
   exige `responsavelLocal`.
5. Modo da vaga e alerta de pouca antecedência: ficam no padrão do view model (a origem não os mostra).
6. O telefone do responsável, que a tela atual recebe, não é usado aqui.
7. As fontes `.system(size:)` da origem viraram fontes escaláveis, para passar no `conferir-textos.sh`.
   Todo texto novo está no `Localizable.xcstrings`.
8. Os previews da origem foram removidos. Toda animação passa por `FrilaMovimento.animacao(_:reduzir:)`,
   como o `conferir-movimento.sh` exige. Onde a origem já desligava a animação com Reduzir Movimento,
   o efeito é o mesmo. Em três lugares a origem não checava, e agora checa: a borda do campo em foco
   (`FrilaLPOutlinedField`) e as duas animações de teclado do `FrilaLPKeyboardObserver`.
9. Conhecido: com o teclado de hardware do simulador, a barra fixa não recolhe, e o último campo
   fica atrás dela. O campo com erro não ganha destaque; o erro aparece na barra.
10. Conhecido: três avisos de concorrência do Swift 6 no código copiado
    (`FrilaLPKeyboardDismissModifier`, `FrilaLPOutsideTapModifier`, `FrilaLPTimeField`). São avisos,
    não erros.
11. Dos modelos de turno da origem (`ShiftModels.swift`), só ficou o que a tela usa: relógio, janela,
    calendário e a escolha de dia. Função, local, histórico de recontratação, perfil e textos do feed
    saíram, porque são de outras telas e a menção a reputação quebraria o `ReputacaoSemMediaTests`.
12. Os tokens de cor e de fonte da origem ficam em `FrilaLPColorDesignTokens.swift` e
    `FrilaLPTypographyDesignTokens.swift`. O `GuardaTokensDesignTests` passou a aceitar qualquer
    `*DesignTokens.swift`, como o `conferir-textos.sh` já fazia.

## Como ligar

Só em DEBUG. Abra o app com o argumento `-FRILA_ENXERTO_LOWPHASE`; o "+" de Minhas vagas passa a
abrir esta tela. Sem o argumento, ou em Release, o app abre a `TelaPublicarVaga` de sempre. O ponto
de troca está em `Sources/Apresentacao/Fluxos/Contratante/PublicarVagaDaCasa.swift`.

```sh
xcrun simctl launch <udid> com.frila.org.app -FRILA_ENXERTO_LOWPHASE
```

## Como remover

1. Apague `Sources/Apresentacao/Enxertos/FrilaLowPhase/`, `Tests/Unitarios/PublicarVagaFrilaLPTests.swift`
   e esta pasta.
2. Em `PublicarVagaDaCasa.swift`, troque o bloco `#if DEBUG ... #endif` só pela `TelaPublicarVaga`.
3. Tire do `Localizable.xcstrings` as chaves que ficarem sem uso, que o `conferir-textos.sh` aponta.
4. Rode `Scripts/gerar-projeto.sh`.

## Testes

`Tests/Unitarios/PublicarVagaFrilaLPTests.swift`: estado inicial, dia e janela, posições e valor,
bloqueios, validação do app e publicação pelo `ApiClienteEmMemoria`.
