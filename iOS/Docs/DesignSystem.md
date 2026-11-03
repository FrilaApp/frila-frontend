# Design system iOS

O módulo `FrilaApresentacao` concentra tokens e componentes SwiftUI em `Sources/Apresentacao/DesignSystem/`.
Desde o Hi-Fi (Fase 2, 24/10/2026) o design system do app é o do FrilaLowPhase, numa camada só e sem prefixo:
os tipos da origem mantêm os nomes canônicos (`FrilaColor`, `FrilaTypography`, `FrilaGeometry`, `FrilaMotion`,
`FrilaShadow`, `FrilaButton`, `FrilaFilterChip`…) e os tokens antigos do app (`FrilaCor`, `FrilaTipo`,
`FrilaRaio`, `FrilaMovimento`) mantêm os nomes com os valores da origem. Os documentos de design do Fabrício
ficam em `Docs/Enxertos/FrilaLowPhase/` (`DESIGN.md`, `REGRAS-DE-DESIGN.md`, `design-system/`).

## Onde mora

- `DesignSystem/DesignTokens.swift`: `FrilaCor` (xcassets), `FrilaEspaco`, `FrilaRaio`, `FrilaMetrica`, `FrilaTipo`,
  `FontesFrila`, `FrilaMovimento`, `FrilaElevacao`, `FrilaMoney.spoken`, `cartaoFrila()`, `elevacaoFrila`, `vidroFrila`.
- `DesignSystem/Primitivas/`: a origem. `FrilaColor` (escala OKLCH da marca e funções `dynamic…(isDark:)`),
  `FrilaTypography` e `FrilaFormType` (papéis, `FrilaTypeSpec`, escala 11/13/15/18/22/26/32), `FrilaGeometry`
  (raios, alturas 32/44/52, espaços), `FrilaMotion` (molas), `FrilaShadow`, vidro, desfoque, esqueleto e a
  formatação de dinheiro (`FrilaMoney.total/rate/estimate`).
- `DesignSystem/Componentes/`: componentes da origem (`FrilaButton`, `FrilaFilterChip`, `FrilaStatusChip`,
  roletas, seções de formulário, prévia, toast…) e os do app em `Componentes.swift` (`BotaoPrimario`,
  `BotaoSecundario`, `CampoFrila`, `CampoCodigo`, `FiltroPill`, `SeloReputacao`, `AvisoFrila`, `CartaoVaga`,
  `RespostaSimNao`, `FolhaFrila`). `EstadosDeTela.swift` cobre carregando, vazio, erro, offline e pendente
  ([PadroesDeEstado.md](PadroesDeEstado.md)).
- `DesignSystem/Turnos/`: modelos e tokens de turno. `DesignSystem/Recursos/Estudio.xcstrings`: textos do Estúdio.
- `Resources/DesignSystem.xcassets`: 18 cores com variante clara/escura. `Resources/Fonts`: Bricolage Grotesque
  Regular, Medium, Bold e ExtraBold (OFL 1.1; `Docs/LicencasDeTerceiros.md` 4.1).
- `CatalogoDesignSystem` (Debug): paleta, tipografia, botões e chips do Estúdio, componentes do app, estados,
  folha e licenças.

## Tokens

- Cor (`FrilaCor` ↔ `FrilaColor`): cada token do xcassets é o mesmo RGB de uma função da origem;
  `ParidadeDeCoresDesignTests` prova a igualdade. `fundo` = `dynamicCanvas` (#FFFFFF / #111111);
  `superficie` = `dynamicFormCardSurface` (#FAFAFA / #171717); `superficieDoCampo` = `dynamicFormFieldSurface`;
  `controle` = `dynamicInputBg`; `texto` = `dynamicTextPrimary` (#1B1A18 / #F5F4F0);
  `textoSecundario` = `dynamicFormTextMuted` (#6B6B6B / #A3A3A3); `primaria` = `dynamicTextInk`
  (#090908 / #FFFFFF) com `sobrePrimaria` = `dynamicCanvas`; `selecao` = `primarySelection` (#C9470F) com
  `sobreSelecao` branco; `marca` = `dynamicBrandAccent` (#EA5A36 / #F26643); `sucesso` = `dynamicVerified`;
  `alerta` = `dynamicWarningText`; `perigo` = `dynamicError`; `divisoria` = `dynamicHairline`;
  `borda` = `dynamicBorder`; `bordaDoCampo` = `dynamicFormFieldBorder`; `puxador` decorativo.
- Espaçamento (`FrilaEspaco`): 2, 4, 8, 12, 14, 16, 24 e 32 pt (`FrilaGeometry.space…`).
- Raios (`FrilaRaio` ↔ `FrilaGeometry`): 8 aninhado, 14 campo (`entrada`), 16 cartão e aviso (`cartao`),
  24 folha. Botões, chips e pílulas são sempre `Capsule` (G6), com 32/44/52 pt de altura.
- Alvo interativo mínimo: 44 × 44 pt (`FrilaMetrica.alvoMinimo`, `FrilaGeometry.hitboxMinimum`).
- Tipografia (`FrilaTipo` ↔ `FrilaTypography`/`FrilaFormType`): SF Pro pelos estilos semânticos, com Dynamic Type.
  Bricolage Grotesque só nas perguntas e respostas dos formulários (`pergunta`, `respostaEscolhida`,
  `contextoDaResposta`); valores monetários em Jost 600 pelo `FrilaPriceTag` (LOG-016); demais números em SF Pro. Rótulo do botão
  grande: SF Pro Bold 18 (`botao`); padrão e chips: Semibold 15 (`botaoPadrao`).
- Movimento (`FrilaMovimento` ↔ `FrilaMotion`): compressão 0,96 (botão) e 0,94 (chip), molas 350/25 e 380/24;
  tudo passa por `FrilaMovimento.animacao(_:reduzir:)` (Reduzir Movimento).
- Elevação (`FrilaElevacao`): zero-shadow nos cartões com fio de 1 pt; três camadas (rim, key, ambient) em
  folhas e docas.
- Moeda: `FrilaMoney.spoken` para VoiceOver; `FrilaMoney.total/rate/estimate` para o visual (pt-BR fixo).

## Regras herdadas da origem

`Docs/Enxertos/FrilaLowPhase/REGRAS-DE-DESIGN.md`: zero emojis na UI (G3), pílulas 100% redondas (G6), alvo
mínimo 44 pt (G8), nenhum texto solto como botão (M1), controle expandido fecha com toque fora (M20).

## Decisões da Fase 2

- Botão principal e pílula neutra ativa continuam na tinta (`.ink` da origem), não na terracota viva: o rótulo
  em 15 pt sobre #EA5A36 fica em 3,5:1, abaixo do AA para texto normal. A terracota viva é acento e botão de
  destaque do Estúdio (texto grande, 18 pt bold). Filtro ativo e escolha confirmada usam a terracota de seleção
  (#C9470F, 4,8:1 com branco).
- `TextSecondary` é o `dynamicFormTextMuted` (#6B6B6B), não o `dynamicTextMuted` (#767571, 4,4:1 sobre o cartão).

> A especificação exaustiva de cada token gerada de `DesignTokens.swift` (cartão Trello `iUIipiiN`) está em
> [GuiaDoFabricio.md (Seção 5.1.1)](GuiaDoFabricio.md#511-tabela-canônica-de-todos-os-tokens-do-app-designtokensswift--cartão-iuiipiin).

---

## Tabela canônica de contraste WCAG 2.1 AA

Valores calculados pela fórmula do W3C (1.4.3 texto, 1.4.11 componentes) a partir de `DesignSystem.xcassets`,
na Fase 2 do Hi-Fi (24/10/2026). `ContrasteDesignTokensTests` recalcula a cada execução.

| Par (frente sobre fundo) | Uso | Requisito | Claro | Situação | Escuro | Situação |
|---|---|---|:---:|:---:|:---:|:---:|
| `TextPrimary` sobre `Surface` | Títulos e textos sobre a tela | Texto normal (≥ 4,5:1) | 17,39:1 | Aprovado | 17,16:1 | Aprovado |
| `TextPrimary` sobre `SurfaceElevated` | Títulos de cartões e folhas | Texto normal (≥ 4,5:1) | 16,66:1 | Aprovado | 16,29:1 | Aprovado |
| `TextPrimary` sobre `ControlFill` | Texto em `AvisoFrila` e pílulas neutras | Texto normal (≥ 4,5:1) | 15,51:1 | Aprovado | 14,45:1 | Aprovado |
| `TextPrimary` sobre `FieldSurface` | Valor digitado nos campos | Texto normal (≥ 4,5:1) | 15,95:1 | Aprovado | 15,48:1 | Aprovado |
| `TextSecondary` sobre `Surface` | Apoio e metadados sobre a tela | Texto normal (≥ 4,5:1) | 5,33:1 | Aprovado | 7,49:1 | Aprovado |
| `TextSecondary` sobre `SurfaceElevated` | Apoio em cartões, placeholders | Texto normal (≥ 4,5:1) | 5,11:1 | Aprovado | 7,11:1 | Aprovado |
| `TextSecondary` sobre `ControlFill` | Metadados em chips neutros | Texto normal (≥ 4,5:1) | 4,75:1 | Aprovado | 6,31:1 | Aprovado |
| `TextSecondary` sobre `FieldSurface` | Placeholder e apoio nos campos | Texto normal (≥ 4,5:1) | 4,89:1 | Aprovado | 6,76:1 | Aprovado |
| `BrandOnPrimary` sobre `BrandPrimary` | Rótulo do `BotaoPrimario` | Texto normal (≥ 4,5:1) | 19,92:1 | Aprovado | 18,88:1 | Aprovado |
| `BrandOnPrimary` sobre `Danger` | Exclusão definitiva de conta | Texto normal (≥ 4,5:1) | 5,06:1 | Aprovado | 6,83:1 | Aprovado |
| `BrandPrimary` sobre `Surface` | Ações de texto sobre a tela | Texto normal (≥ 4,5:1) | 19,92:1 | Aprovado | 18,88:1 | Aprovado |
| `BrandPrimary` sobre `SurfaceElevated` | Ações dentro de cartões | Texto normal (≥ 4,5:1) | 19,09:1 | Aprovado | 17,93:1 | Aprovado |
| `BrandOnSelection` sobre `BrandSelection` | `FiltroPill` ativa, `RespostaSimNao` escolhida | Texto normal (≥ 4,5:1) | 4,78:1 | Aprovado | 4,78:1 | Aprovado |
| `Success` sobre `Surface` | Confirmações sobre a tela | Texto normal (≥ 4,5:1) | 5,48:1 | Aprovado | 10,84:1 | Aprovado |
| `Success` sobre `SurfaceElevated` | Selos de reputação em cartões | Texto normal (≥ 4,5:1) | 5,25:1 | Aprovado | 10,29:1 | Aprovado |
| `Warning` sobre `Surface` | Pendências sobre a tela | Texto normal (≥ 4,5:1) | 5,27:1 | Aprovado | 11,31:1 | Aprovado |
| `Warning` sobre `SurfaceElevated` | Avisos em cartões | Texto normal (≥ 4,5:1) | 5,05:1 | Aprovado | 10,74:1 | Aprovado |
| `Danger` sobre `Surface` | Erros sobre a tela | Texto normal (≥ 4,5:1) | 5,06:1 | Aprovado | 6,83:1 | Aprovado |
| `Danger` sobre `SurfaceElevated` | `capsulaDestrutiva`, erros de campo | Texto normal (≥ 4,5:1) | 4,85:1 | Aprovado | 6,48:1 | Aprovado |
| `BrandAccent` sobre `Surface` | Ícone e marca terracota | Componente / ícone (≥ 3,0:1) | 3,49:1 | Aprovado | 6,08:1 | Aprovado |
| `BrandAccent` sobre `SurfaceElevated` | Acento em cartões | Componente / ícone (≥ 3,0:1) | 3,35:1 | Aprovado | 5,77:1 | Aprovado |
| `BrandOnPrimary` sobre `BrandAccent` | Glifo sobre pílula terracota (`SearchCapsule`, botão `.primary` do Estúdio) | Componente / ícone (≥ 3,0:1) | 3,49:1 | Aprovado | 6,08:1 | Aprovado |
| `FieldBorder` sobre `Surface` | Fio do campo sobre a tela | Componente / ícone (≥ 3,0:1) | 3,36:1 | Aprovado | 3,49:1 | Aprovado |
| `FieldBorder` sobre `SurfaceElevated` | Fio do campo em cartões | Componente / ícone (≥ 3,0:1) | 3,22:1 | Aprovado | 3,31:1 | Aprovado |
| `FieldBorder` sobre `FieldSurface` | Fio contra o preenchimento do campo | Componente / ícone (≥ 3,0:1) | 3,08:1 | Aprovado | 3,15:1 | Aprovado |
| `BrandSelection` sobre `Surface` | Pílula ativa sobre a tela | Componente / ícone (≥ 3,0:1) | 4,78:1 | Aprovado | 3,95:1 | Aprovado |
| `BrandSelection` sobre `SurfaceElevated` | Pílula ativa em cartões | Componente / ícone (≥ 3,0:1) | 4,58:1 | Aprovado | 3,75:1 | Aprovado |
| `SheetGrabber` sobre `SurfaceElevated` | Puxador das folhas | Decorativo (isento, 1.4.11) | 1,48:1 | Isento | 1,99:1 | Isento |

### Exceções e restrições

1. **`BrandAccent` (`FrilaCor.marca`, #EA5A36)**: 3,49:1 sobre `Surface` no claro. Aprovado para ícone, componente
   e texto grande; reprovado para texto corrido. O teste `guardaDeExcecoesERestricoesDeDesign` registra os dois lados.
2. **`SheetGrabber` (`FrilaCor.puxador`)**: decorativo, `.accessibilityHidden(true)` em `FolhaFrila`; isento (1.4.11).
3. **`ControlBorder` e `Hairline`**: fios de 1 pt de cartões e chips inativos, sem exigência de 3:1 porque não
   delimitam sozinhos um controle (o campo usa `FieldBorder`, que passa).

### Cobertura por teste

- `ContrasteDesignTokensTests`: 18 tokens, pares de texto ≥ 4,5:1, componentes ≥ 3,0:1, exceções documentadas.
- `ParidadeDeCoresDesignTests`: cada token do xcassets igual à função correspondente do `FrilaColor`.
- `GuardaTokensDesignTests`: literal de cor ou fonte só em arquivos `*DesignTokens.swift`.
