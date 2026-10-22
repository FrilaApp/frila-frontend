# 02 — Tokens de Design e Material 3 (Android v1.1)

**Status:** Normativo · **Fonte:** `iOS/Sources/Apresentacao/DesignTokens.swift` (MEDIDO, 326 linhas)

O design system do Android não reinventa tokens: ele mapeia, 1 a 1, os tokens já validados no
MidFi iOS (`FrilaCor`, `FrilaEspaco`, `FrilaRaio`, `FrilaTipo`, `FrilaMetrica`) para os sistemas
equivalentes do Material 3 Compose. Nome do token muda de convenção (PascalCase Swift →
camelCase Kotlin), valor e papel semântico não mudam.

---

## 1. `FrilaCor` → `ColorScheme`

Tema neutro: seleção ativa e botão principal em preenchimento escuro com texto claro; superfícies
brancas sobre fundo agrupado cinza; terracota da marca (`BrandAccent`, `#EA5A36`) só como acento,
nunca como fundo de tela ou de cartão — regra herdada do iOS e mantida sem exceção no Android.

| Token iOS (`FrilaCor`) | Papel | `ColorScheme` (Material 3) | Observação |
|---|---|---|---|
| `primaria` (`BrandPrimary`) | Seleção ativa, botão principal | `primary` | Quase preto no claro, quase branco no escuro |
| `sobrePrimaria` (`BrandOnPrimary`) | Texto/ícone sobre `primaria` | `onPrimary` | |
| `fundo` (`Surface`) | Fundo agrupado da tela | `background` | |
| `superficie` (`SurfaceElevated`) | Cartões, campos, linhas | `surface` | Branco com fio de 1dp, zero-shadow |
| `texto` (`TextPrimary`) | Texto principal | `onBackground` / `onSurface` | |
| `textoSecundario` (`TextSecondary`) | Texto de apoio | `onSurfaceVariant` | Contraste mínimo 4,8:1 sobre `fundo`, igual ao iOS |
| `sucesso` (`Success`) | Estado positivo | `tertiary` (custom scheme role) | Material 3 não tem slot "success" nativo; declarado como extensão do `ColorScheme` |
| `alerta` (`Warning`) | Estado de atenção | extensão custom `warning` / `onWarning` | |
| `perigo` (`Danger`) | Estado de erro | `error` | |
| `marca` (`BrandAccent`) | Acento pontual (ícone, destaque) | extensão custom `brandAccent` | Nunca mapeado para `primary`; uso como fundo de tela/cartão é falha de revisão de design |
| `controle` (`ControlFill`) | Preenchimento de controle/aviso neutro | `surfaceVariant` | |
| `divisoria` (`Hairline`) | Fio de cartões e divisórias (1pt) | `outlineVariant` | 1dp |
| `borda` (`ControlBorder`) | Contorno de chip inativo, botão outline, campo | `outline` | |
| `puxador` (`SheetGrabber`) | Puxador de bottom sheet | extensão custom `sheetHandle` | `ModalBottomSheet` do Compose usa `dragHandle` customizado com esse token |

Cada entrada acima que não tem slot nativo no `ColorScheme` do Material 3 é declarada como
propriedade de extensão em um `FrilaColorScheme` próprio (`data class` que envolve o
`ColorScheme` padrão), nunca sobrescrevendo um slot existente para um papel diferente do dele —
por exemplo, `sucesso` **não** deve ser forçado dentro de `tertiary` se isso colidir com um uso já
planejado de `tertiary` noutra tela; nesse caso, a extensão custom é obrigatória também para
`sucesso`.

Claro e escuro seguem o mesmo princípio do iOS: os valores vêm de recursos `colors.xml` /
`colors-night.xml` com o mesmo nome semântico, nunca de lógica condicional em Kotlin no ponto de
uso.

## 2. `FrilaEspaco` → espaçamento Compose

Sem equivalente nativo de "espaçamento" no Material 3 (que define apenas `Shapes` e
`Typography`); o Android replica `FrilaEspaco` como `object` de constantes `Dp`, usado
diretamente em `Modifier.padding`/`Arrangement.spacedBy`:

| Token iOS | Valor (pt → dp, 1:1) | Uso |
|---|---:|---|
| `fio` | 2dp | Entre título e subtítulo de um mesmo bloco |
| `minimo` | 4dp | |
| `pequeno` | 8dp | |
| `compacto` | 12dp | Entre cartões de lista e dentro de grupos |
| `faixa` | 14dp | Entre faixas de um cartão (cabeçalho, linhas, divisória) |
| `medio` | 16dp | |
| `grande` | 24dp | |
| `enorme` | 32dp | |

Conversão pt→dp é 1:1 porque ambas as plataformas usam unidade de densidade independente
(points no iOS, dp no Android) com a mesma base conceitual de 160 "pixels por polegada" de
referência.

## 3. `FrilaRaio` → `Shapes`

| Token iOS | Valor | `Shapes` (Material 3) | Uso |
|---|---:|---|---|
| `pequeno` | 8dp | `extraSmall` | |
| `medio` | 12dp | `small` | |
| `aviso` | 16dp | `medium` | Avisos e blocos de informação |
| `grande` | 20dp | `large` | Cartões agrupados (`radiusGroupedCard`) |
| `folha` | 28dp | `extraLarge` | Topo de bottom sheets |

```kotlin
val FrilaShapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(16.dp),
    large = RoundedCornerShape(20.dp),
    extraLarge = RoundedCornerShape(28.dp),
)
```

Cartões usam zero-shadow com fio de 1dp (`divisoria`/`outlineVariant`), replicando
`cartaoFrila()` do iOS: `Modifier.background(superficie, FrilaShapes.large).border(1.dp,
divisoria, FrilaShapes.large)`.

## 4. `FrilaTipo` → `Typography`

iOS usa Dynamic Type com SF Pro para a maior parte da UI, e a fonte display **Bricolage
Grotesque** só no formulário de publicar vaga (`pergunta`, `respostaEscolhida`,
`contextoDaResposta`) — números e dinheiro ficam sempre na fonte do sistema, nunca em Bricolage.
Essa regra é normativa e vale igual no Android.

| Token iOS | Papel | `Typography` (Material 3) | Fonte |
|---|---|---|---|
| `tituloGrande` | Título de tela principal | `displaySmall` | Sistema (Roboto/variável do dispositivo) |
| `secao` | Cabeçalho de seção ("Abertas", "Seus dados") | `titleLarge` | Sistema |
| `subtituloDaTela` | | `titleMedium` | Sistema |
| `rotuloDoCampo` | | `titleSmall` | Sistema |
| `valorDoCampo` | | `bodyLarge` | Sistema |
| `chip` | | `labelLarge` (peso semibold) | Sistema |
| `tituloDoCartao` | | `titleSmall` (peso semibold) | Sistema |
| `corpo` | | `bodyLarge` | Sistema |
| `meta` | | `bodyMedium` | Sistema |
| `nota` | | `bodySmall` | Sistema |
| `resumo` | | `titleSmall` | Sistema |
| `preco` | | `titleMedium` (bold) | Sistema — número, nunca Bricolage |
| `tituloDeEstado` | | `titleMedium` (peso semibold) | Sistema |
| `tituloDaFolha` | | `titleMedium` (peso semibold) | Sistema |
| `botao` | | `titleSmall` | Sistema |
| `pergunta` | Pergunta do formulário de publicar vaga | extensão custom `pergunta` (26sp, Bold) | **Bricolage Grotesque Bold** |
| `respostaEscolhida` | Resposta escolhida no formulário | extensão custom `respostaEscolhida` (17sp, Bold) | **Bricolage Grotesque Bold** |
| `contextoDaResposta` | Contexto da resposta | extensão custom `contextoDaResposta` (17sp, Regular) | **Bricolage Grotesque Regular** |
| `microRotulo` | Microrrótulo em caixa alta | extensão custom `microRotulo` (peso semibold) | Sistema, `letterSpacing` 0.8sp equivalente ao `.tracking(0.8)` do iOS |

Fontes Bricolage (`BricolageGrotesque-Regular.ttf`, `BricolageGrotesque-Bold.ttf`) são
empacotadas em `:core:designsystem/src/main/res/font/` e referenciadas via `FontFamily` do
Compose — sem fallback silencioso: se o arquivo não resolver, o build falha (ao contrário do iOS,
que cai na fonte do sistema via `guard`); essa é uma divergência deliberada porque Android
empacota a fonte no APK, não depende de registro em runtime.

Escala de texto respeita `fontScale` do sistema (equivalente a Dynamic Type) em todos os tokens
de sistema; tokens Bricolage usam `TextUnit` com `.sp` e participam igualmente da escala —
nenhum texto do app usa `.dp` para tamanho de fonte.

## 5. `FrilaMetrica` → alvo de toque e métricas de componente

| Token iOS | Valor | Uso | Regra Material 3 equivalente |
|---|---:|---|---|
| `alvoMinimo` | 44pt | Alvo mínimo de toque | Android usa **48dp** como alvo mínimo (guideline Material 3 / acessibilidade Android), não 44 — ver nota abaixo |
| `larguraMaximaDeLeitura` | 680pt | Largura máxima de bloco de leitura | 680dp, mantido igual |
| `alturaDoCampo` | 52pt | Campos e botões grandes | 52dp, mantido igual |
| `alturaDoChip` | 32pt | Altura visual do chip de filtro (toque permanece no alvo mínimo) | 32dp visual, hit box expandida até 48dp |
| `circuloDeEstado` | 72pt | Círculo de estados vazios/erro | 72dp, mantido igual |

> **Alvo mínimo de toque: 48dp, não 44dp.** O token iOS `alvoMinimo` vale 44pt porque é a
> diretriz da HIG da Apple. A diretriz equivalente do Android/Material 3 é **48dp**. O Android
> **não** replica o valor numérico 44 — replica o *papel* do token (garantir área de toque
> acessível) usando o mínimo correto da própria plataforma. Todo componente tocável de
> `:core:designsystem` (botão, chip, ícone de ação) declara `Modifier.sizeIn(minWidth = 48.dp,
> minHeight = 48.dp)` como piso, mesmo quando o conteúdo visual é menor (caso do chip, visual de
> 32dp com hit box de 48dp).

## 6. Movimento e elevação

`FrilaMovimento` (spring stiffness/damping) e `FrilaElevacao` (três camadas rim/key/ambient) não
têm tradução direta em Material 3 puro — Compose usa `animateDpAsState`/`Spring` com os mesmos
parâmetros numéricos (`stiffness = 350f, dampingRatio = ...`) e `Modifier.shadow` com múltiplas
camadas compostas manualmente, replicando os valores de opacidade/raio/offset do iOS por tema
(claro/escuro) linha a linha. Redução de movimento do sistema (`Settings.Global.ANIMATOR_DURATION_SCALE
== 0f` ou a preferência de acessibilidade equivalente) desliga a transição exatamente como
`FrilaMovimento.animacao(reduzir:)` faz no iOS — retorna `tween(durationMillis = 0)` em vez de
`null`, já que `AnimationSpec` do Compose não aceita ausência de animação, mas o efeito prático
(sem deslocamento) é o mesmo.
