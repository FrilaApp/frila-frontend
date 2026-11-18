# 02 — Tokens de Design e Material 3 (Android)

**Status:** Normativo · **Fonte:** o desenho do Fabrício (redesign de 11/2026): cores, tipografia, espaços, raios e
alturas do protótipo e do app de redesign dele. Código em `android/core/designsystem` (`tema/` e `componentes/`).

O design system do Android usa os MESMOS tokens e nomes do iOS (`FrilaCor`/`FrilaTipo`/`FrilaEspaco`/`FrilaRaio`), e
os põe nos papéis do Material 3 para os componentes do Material já nascerem no desenho. Código novo lê as cores por
`FrilaTema.cores` e o texto por `FrilaTipo`; `MaterialTheme.colorScheme`/`typography` continuam valendo e dão o mesmo
resultado.

As regras que os tokens carregam:

- **Uma cor, um significado.** Laranja (`acao`): "toque aqui para avançar", só no botão primário (no máximo um por
  tela) e no ícone da aba ativa. Amarelo: "deu certo, é seu". Roxo: "é agora". Tinta: texto, seleção e andamento.
- **Botão colorido leva texto BRANCO**, em negrito de 20sp. Nunca texto laranja, nunca texto escuro no botão laranja.
- **Problema não tem cor.** Não há vermelho, verde nem amarelo lavado: erro vem escrito em tinta, junto ao botão que
  o disparou (`MensagemJuntoAoBotao`) ou embaixo do campo.
- **Cápsula no que se toca** (botão, chip, busca); canto pequeno no que só informa (selo). Cartão sem sombra.
- **Poucos pesos:** a hierarquia vem da cor (tinta × tinta suave).

---

## 1. Cores → `ColorScheme`

| Token (`FrilaTema.cores`) | Claro | Escuro | Papel | `ColorScheme` (Material 3) |
|---|---|---|---|---|
| `fundo` | `#F9F6F4` | `#110F0E` | Fundo das telas e das folhas | `background`, `surfaceDim` |
| `superficie` | `#FFFFFF` | `#1D1B1A` | Cartões, campos, botão secundário | `surface`, `surfaceVariant`, `surfaceContainer*` |
| `tinta` | `#111111` | `#F4F1EF` | Texto, seleção, foco, andamento | `onBackground`, `onSurface`, `primary`, `secondary`, `tertiary`, `error`, `secondaryContainer` |
| `tintaSuave` | `#5A5A58` | `#A5A5A2` | Texto de apoio, ação discreta | `onSurfaceVariant` |
| `borda` | `#E5E3DD` | `#2F2E29` | Fio de cartão, divisória, botão secundário; fundo do botão desligado | `outlineVariant` |
| `bordaControle` | `#918F8A` | `#767470` | Contorno de campo | `outline` |
| `bordaNav` | `#EBE9E2` | `#282622` | Fio de cima do rodapé ancorado e da barra de abas | — |
| `superficiePressionada` | `#EFECEA` | `#2A2826` | Cartão, linha e secundário pressionados; bloco de aviso | `surfaceContainerHighest`, `primaryContainer`, `errorContainer` |
| `tintaPressionada` | `#2D2D2D` | `#CFCCCA` | Chip marcado, pressionado | — |
| `sobreTinta` | `#FFFFFF` | `#110F0E` | Texto sobre tinta (chip marcado, selo) | `onPrimary`, `onSecondaryContainer` |
| `acao` | `#F46700` | igual | Botão primário, ícone da aba ativa | — (nunca é `primary`) |
| `acaoPressionada` | `#DD5C00` | igual | Botão primário pressionado | — |
| `sobreAcao` | `#FFFFFF` | igual | Rótulo do botão primário | — |
| `destaqueAmarelo` / `sobreAmarelo` | `#FCEB36` / `#111111` | igual | Selos "Confirmado", "Você foi escolhida" | — |
| `destaqueRoxo` / `sobreRoxo` | `#9D47F5` / `#FFFFFF` | igual | Selo "Urgência" | — |

- `primary` é a TINTA de propósito: seleção, foco, cursor, interruptor e texto de botão do Material ficam em tinta.
  O laranja só entra pelo `BotaoPrimario`, que o usa direto.
- `error` é a tinta: uma tela que ainda usa `colorScheme.error` já sai sem vermelho.
- `surfaceTint` é transparente e as superfícies de contêiner não levam o lilás padrão do Material.
- Modo OLED (RNF10): só o `fundo` vira preto puro (`#000000`); os cartões seguem em `superficie`.
- Com cores dinâmicas (Material You), `primary`, `onPrimary`, `error` e `onError` continuam do Frila.

## 2. Espaços (`FrilaEspacamento`)

| Token | Valor | Uso |
|---|---:|---|
| `junto` | 4dp | Linhas do mesmo dado; ícone do selo |
| `item` | 8dp | Ícone e texto; entre linhas de dado; mensagem e botão |
| `bloco` | 16dp | Padding de cartão; entre cartões; acima e abaixo da divisória |
| `grupo` | 24dp | Margem lateral da tela; do título ao cartão; entre blocos de um detalhe |
| `secao` | 32dp | Acima de seção e das ações discretas |
| `respiro` | 48dp | Acima do estado vazio |

Os nomes de antes (`fio` 2, `minimo` 4, `pequeno` 8, `compacto` 12, `faixa` 14, `medio` 16, `grande` 24, `enorme` 32)
continuam existindo para as telas que já os usam.

## 3. Raios (`FrilaRaios`) → `Shapes`

| Token | Valor | Uso | `Shapes` (Material 3) |
|---|---:|---|---|
| `selo` | 8dp | Selo de status | — |
| `interno` | 16dp | Campo, bloco de aviso, grupo de linhas, o que fica dentro de um cartão | `extraSmall` (campo, menu) |
| `cartao` | 24dp | Cartão, diálogo, topo de folha | `medium`, `large`, `extraLarge` |
| `cartaoDeVaga` | 36dp | Só o cartão de vaga com botão dentro (par concêntrico com o botão de raio 16) | — |
| cápsula | — | Botão, chip, busca | `small` (chip) |

Os nomes de antes apontam para os valores novos: `pequeno` = 8, `medio` = 16, `grande` = 24.

## 4. Tipografia (`FrilaTipo`) → `Typography`

Prodigy Sans 700 (OFL 1.1, a mesma do iOS; licença em `core/designsystem/src/main/res/raw`) só no título de tela e
no dinheiro principal. Fonte do sistema em todo o resto. Tudo em `sp`.

| Papel (`FrilaTipo`) | Fonte e peso | Tamanho / linha | `Typography` (Material 3) |
|---|---|---|---|
| `valorEmDestaque` | Prodigy 700 | 28 / 32 | `display*` |
| `tituloDaTela` | Prodigy 700 | 24 / 28 | `headline*`, `titleLarge` |
| `valorDoRodape` | Prodigy 700 | 20 / 24 | — |
| `rotuloDoPrimario` | sistema 700 | 20 / 24 | — |
| `fraseDoModo` | sistema 600 | 20 / 24 | — |
| `nome` | sistema 600 | 17 / 22 | `titleMedium` |
| `corpo` | sistema 400 | 16 / 22 | `bodyLarge` |
| `rotuloSecundario` | sistema 600 | 16 / 22 | `titleSmall`, `labelLarge` |
| `apoio` | sistema 400 | 15 / 20 | `bodyMedium` |
| `rotuloDeGrupo`, `selo` | sistema 600 | 15 / 20 | `labelMedium` |
| `chip` | sistema 500 | 15 / 20 | — |
| `legenda` | sistema 400 | 13 / 16 | `bodySmall`, `labelSmall` (500) |

## 5. Alturas (`FrilaMetricas`)

| Token | Valor | Uso |
|---|---:|---|
| `alvoMinimo` | 48dp | Alvo mínimo de toque. É o do Material 3 e o do desenho; nunca 44 |
| `alturaBotao`, `alturaCampo` | 48dp | Botão primário e secundário, campo, linha de lista |
| `alturaBotaoDePresenca` | 64dp | "MARCAR PRESENÇA" |
| `alturaChip` | 36dp | Chip (dentro de um alvo de 48) |
| `alturaSelo` | 28dp | Selo de status |
| `alturaCaixaDeCodigo` | 56dp | Caixa de dígito do código de acesso |

São mínimos: o texto cresce com o tamanho de fonte do sistema e o componente cresce junto.

## 6. Componentes (`componentes/`)

`BotaoPrimario`, `BotaoSecundario`, `LinkFrila`, `AcaoDiscreta`, `CartaoFrila`, `AvisoFrila`, `SeloDeStatus`,
`ChipFrila`, `CampoDeTexto`, `CampoDeBusca`, `CaixasDeCodigo`, `TituloDaTela`, `RotuloDeGrupo`, `FrilaGrupoDeLinhas`
com `FrilaLinhaDeOpcao`/`FrilaLinhaDeNavegacao`, `FrilaLinhaDeDado`, `FrilaDivisoria`, `LinhaDeEtapas`,
`FrilaBarraDeTopo`, `RodapeAncorado` com `MensagemJuntoAoBotao`, `EstadoVazio`, `EstadoErro`, `EstadoCarregando`,
`FrilaBottomSheet`, `FrilaSkeleton`. Cada um tem a regra de uso no comentário do próprio arquivo.

Movimento: quem anima respeita a redução de movimento do sistema (`animacoesAtivadas()` em `FrilaSkeleton.kt`).

## 7. Contraste WCAG 2.1 (medido; conferido em `FrilaCoresTest` e `MatrizContrasteWCAGTest`)

| Primeiro plano | Fundo | Claro | Escuro | Piso |
|---|---|---:|---:|---:|
| `tinta` | `fundo` | 17,55:1 | 17,00:1 | 4,5:1 |
| `tintaSuave` | `fundo` | 6,42:1 | 7,74:1 | 4,5:1 |
| `tintaSuave` | `superficie` | 6,91:1 | 6,95:1 | 4,5:1 |
| `tintaSuave` | `superficiePressionada` | 5,88:1 | 5,95:1 | 4,5:1 |
| `tintaSuave` | `borda` (botão desligado) | 5,39:1 | 5,51:1 | 4,5:1 |
| `sobreAcao` (branco) | `acao` | 3,09:1 | 3,09:1 | 3,0:1 (texto grande: 20sp em negrito) |
| `sobreAcao` (branco) | `acaoPressionada` | 3,75:1 | 3,75:1 | 3,0:1 |
| `sobreRoxo` | `destaqueRoxo` | 4,51:1 | 4,51:1 | 4,5:1 |
| `sobreAmarelo` | `destaqueAmarelo` | 15,35:1 | 15,35:1 | 4,5:1 |
| `bordaControle` | `fundo` | 3,00:1 | 4,10:1 | 3,0:1 (componente gráfico) |
| `tinta` (escuro) | preto do OLED | — | 18,68:1 | 7,0:1 |
| `tintaSuave` (escuro) | preto do OLED | — | 8,50:1 | 7,0:1 |

- Branco sobre o laranja só passa como texto grande: por isso o rótulo do primário é 20sp em negrito e o laranja
  nunca é cor de texto nem único sinal de estado.
- Alterar qualquer valor de `FrilaCores` exige rodar `./gradlew :core:designsystem:testDebugUnitTest` e atualizar
  esta tabela no mesmo PR.

As anotações de TalkBack, nós semânticos e ordem de foco das telas estão em
[`06-anotacoes-talkback-telas.md`](06-anotacoes-talkback-telas.md).
