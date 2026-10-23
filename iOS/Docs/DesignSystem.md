# Design system iOS

O módulo `FrilaApresentacao` concentra os tokens e componentes SwiftUI. Cores vivem em `DesignSystem.xcassets`, com variantes clara/escura; tipografia usa estilos semânticos do sistema para responder ao Dynamic Type.

## Tokens

- Espaçamento: 2, 4, 8, 12, 14, 16, 24 e 32 pt (`FrilaEspaco`).
- Raios: 8, 12, 16, 20 e 28 pt (`FrilaRaio`).
- Alvo interativo mínimo: 44 × 44 pt (`FrilaMetrica.alvoMinimo`).
- Cores (`FrilaCor`): primária, conteúdo sobre primária, fundo agrupado, superfície elevada, texto primário, texto secundário, sucesso, alerta, perigo, marca (terracota de acento), preenchimento de controle, divisória, borda de controle e puxador.
- Tipografia (`FrilaTipo`): estilos semânticos do sistema com Dynamic Type, além da fonte Bricolage Grotesque exclusiva para as perguntas de publicação de vaga.
- Movimento (`FrilaMovimento`): compressão tátil e molas com respeito estrito a Reduzir Movimento.
- Elevação e Sombras (`FrilaElevacao`): três camadas coordenadas (rim, key, ambient) e estilo zero-shadow nos cartões com fio de 1 pt.
- Moeda acessível (`FrilaMoney`): tradução fonética integral para VoiceOver.

> A especificação exaustiva de cada token, valores, tipos e regras de uso geradas de `DesignTokens.swift` (atendimento ao cartão Trello `iUIipiiN`) está catalogada em [GuiaDoFabricio.md (Seção 5.1.1)](GuiaDoFabricio.md#511-tabela-canônica-de-todos-os-tokens-do-app-designtokensswift--cartão-iuiipiin).

## Componentes iniciais

Botões primário/secundário, campo comum, código de acesso, pill de filtro, cartão de vaga, selo de reputação, aviso, folha e avaliação sim/não. Estados reutilizáveis cobrem carregando, vazio, erro com retry, offline e envio pendente (detalhados em [PadroesDeEstado.md](PadroesDeEstado.md)).

`CatalogoDesignSystem` é a referência executável em Debug e inclui preview com Dynamic Type de acessibilidade.

---

## Tabela Canônica de Contraste WCAG 2.1 AA

Em conformidade com as diretrizes de acessibilidade **WCAG 2.1 (Critério 1.4.3 para contraste de texto e 1.4.11 para contraste de elementos de interface e componentes gráficos)**, todas as combinações semânticas de cor do tema MidFi (claro e escuro) de `Resources/DesignSystem.xcassets` são matematicamente auditadas e protegidas por testes unitários de regressão (`ContrasteDesignTokensTests.swift`).

### Regras de Corte WCAG AA
- **Texto Normal** (< 18 pt regular ou < 14 pt negrito): razão mínima de **4,5:1**.
- **Texto Grande** (≥ 18 pt regular ou ≥ 14 pt negrito), **Componente de UI ou Ícone Essencial**: razão mínima de **3,0:1**.
- **Elementos Decorativos e Controles Desabilitados**: isentos pela norma WCAG 1.4.3 e 1.4.11.

### Fórmula Canônica W3C
Para cada canal $C \in \{R, G, B\}$ em sRGB normalizado $[0, 1]$:
$$C_{\text{linear}} = \begin{cases} \frac{C}{12.92}, & \text{se } C \le 0.04045 \\ \left(\frac{C + 0.055}{1.055}\right)^{2.4}, & \text{se } C > 0.04045 \end{cases}$$
Luminância relativa:
$$L = 0.2126 \times R_{\text{linear}} + 0.7152 \times G_{\text{linear}} + 0.0722 \times B_{\text{linear}}$$
Razão de contraste entre duas cores com luminâncias $L_1$ e $L_2$ ($L_1 \ge L_2$):
$$\text{Razão} = \frac{L_1 + 0.05}{L_2 + 0.05} : 1$$

---

### Tabela Formal de Combinações Semânticas

| Par de Tokens (Frente / Fundo) | Uso / Contexto no Frila | Requisito WCAG | Modo Claro (Razão) | Situação Claro | Modo Escuro (Razão) | Situação Escuro | Observações e Diretrizes de Design |
|---|---|---|:---:|:---:|:---:|:---:|---|
| `TextPrimary` sobre `Surface` | Títulos e cabeçalhos sobre fundo agrupado | Texto normal (≥ 4,5:1) | 16,84:1 | **Aprovado** | 17,90:1 | **Aprovado** | Fundo da tela (`#F2F2F0` claro / `#0B0B0A` escuro) |
| `TextPrimary` sobre `SurfaceElevated` | Títulos de cartões, campos e folhas modais | Texto normal (≥ 4,5:1) | 18,88:1 | **Aprovado** | 15,50:1 | **Aprovado** | Cartões elevados (`#FFFFFF` claro / `#1C1C1A` escuro) |
| `TextPrimary` sobre `ControlFill` | Mensagens textuais em `AvisoFrila` e chips | Texto normal (≥ 4,5:1) | 15,26:1 | **Aprovado** | 12,85:1 | **Aprovado** | Preenchimento neutro (`#E8E7E3` claro / `#2C2B28` escuro) |
| `TextSecondary` sobre `Surface` | Subtítulos e metadados sobre o fundo | Texto normal (≥ 4,5:1) | 6,06:1 | **Aprovado** | 7,69:1 | **Aprovado** | Texto de apoio (`#5C5B57` claro / `#A3A29C` escuro) |
| `TextSecondary` sobre `SurfaceElevated` | Metadados de cartão, notas e placeholders | Texto normal (≥ 4,5:1) | 6,79:1 | **Aprovado** | 6,66:1 | **Aprovado** | Em cartões, listas e campos de formulário |
| `TextSecondary` sobre `ControlFill` | Metadados em tags e controles neutros | Texto normal (≥ 4,5:1) | 5,49:1 | **Aprovado** | 5,52:1 | **Aprovado** | Chips inativos e badges |
| `BrandOnPrimary` sobre `BrandPrimary` | Rótulo do `BotaoPrimario` e seleção ativa | Texto normal (≥ 4,5:1) | 18,88:1 | **Aprovado** | 17,16:1 | **Aprovado** | Botão principal (`#111110` claro / `#F5F4F0` escuro) |
| `BrandOnPrimary` sobre `Danger` | Rótulo de exclusão definitiva de conta | Texto normal (≥ 4,5:1) | 5,39:1 | **Aprovado** | 6,70:1 | **Aprovado** | Ação destrutiva confirmada em `TelaExclusaoDeConta` |
| `BrandPrimary` sobre `Surface` | Ações de texto e contornos sobre o fundo | Texto normal (≥ 4,5:1) | 16,84:1 | **Aprovado** | 17,90:1 | **Aprovado** | Links e botões de contorno |
| `BrandPrimary` sobre `SurfaceElevated` | Botões secundários de contorno em cartões | Texto normal (≥ 4,5:1) | 18,88:1 | **Aprovado** | 15,50:1 | **Aprovado** | Ações dentro de cartões e folhas |
| `Success` sobre `Surface` | Status e confirmações sobre o fundo | Texto normal / Ícone (≥ 4,5:1) | 4,90:1 | **Aprovado** | 11,31:1 | **Aprovado** | `#007A33` claro / `#4ADE80` escuro |
| `Success` sobre `SurfaceElevated` | Selos de reputação e presença confirmada | Texto normal / Ícone (≥ 4,5:1) | 5,49:1 | **Aprovado** | 9,80:1 | **Aprovado** | Selos em cartões de vaga e turno |
| `Warning` sobre `Surface` | Advertências e turno aguardando sobre fundo | Texto normal / Ícone (≥ 4,5:1) | 4,70:1 | **Aprovado** | 11,79:1 | **Aprovado** | `#9E5C00` claro / `#FBBF24` escuro (ajustado no MidFi) |
| `Warning` sobre `SurfaceElevated` | Avisos de fila offline ou prazos em cartões | Texto normal / Ícone (≥ 4,5:1) | 5,26:1 | **Aprovado** | 10,22:1 | **Aprovado** | Avisos em cartões de turno |
| `Danger` sobre `Surface` | Mensagens de erro e cancelamento sobre fundo | Texto normal / Ícone (≥ 4,5:1) | 4,80:1 | **Aprovado** | 6,98:1 | **Aprovado** | `#D70015` claro / `#FF6961` escuro |
| `Danger` sobre `SurfaceElevated` | Rótulo e contorno do botão destrutivo | Texto normal / Comp. (≥ 4,5:1) | 5,39:1 | **Aprovado** | 6,05:1 | **Aprovado** | `capsulaDestrutiva` e erros em campos |
| `BrandAccent` sobre `Surface` | Ícone e marca terracota pontual (#EA5A36) | Ícone / Componente (≥ 3,0:1) | 3,11:1 | **Aprovado (3:1)** | 6,34:1 | **Aprovado** | Acento de marca. Reprovado se usado como texto normal (< 4,5:1). |
| `BrandAccent` sobre `SurfaceElevated` | Destaque gráfico e ícone de marca em cartão | Ícone / Componente (≥ 3,0:1) | 3,49:1 | **Aprovado (3:1)** | 5,49:1 | **Aprovado** | Acento de marca. Reprovado se usado como texto normal (< 4,5:1). |
| `BrandOnPrimary` sobre `BrandAccent` | Glifo/ícone claro sobre pílula terracota | Ícone / Componente (≥ 3,0:1) | 3,49:1 | **Aprovado (3:1)** | 6,08:1 | **Aprovado** | Em `SearchCapsule`. Reprovado se usado como texto normal (< 4,5:1). |
| `SheetGrabber` sobre `SurfaceElevated` | Puxador visual central de folhas modais | Decorativo (isento WCAG 1.4.11) | 1,54:1 | **Isento** | 1,89:1 | **Isento** | Possui `.accessibilityHidden(true)`; fechamento nativo por toque/botão. |

---

### Exceções, Restrições e Pares Reprovados para Texto Corrido

1. **Terracota da Marca (`BrandAccent` / `FrilaCor.marca` - `#EA5A36`):**
   - **Comportamento matemático:** No tema claro, apresenta contraste de **3,11:1** sobre `Surface` e **3,49:1** sobre `SurfaceElevated`.
   - **Conformidade:** **Aprovado** para componentes gráficos, ícones e texto grande (WCAG 1.4.11 / 1.4.3 ≥ 3,0:1). **Reprovado** se utilizado para texto corrido normal (< 4,5:1).
   - **Diretriz normativa (`DesignTokens.swift`):** "A terracota da marca (`marca`) fica só como acento, nunca como fundo de tela ou de cartão." É proibido o uso de `FrilaCor.marca` como cor de corpo de texto no tema claro. Em `FrilaEditorialTag`, qualquer customização deve utilizar texto grande ou alto contraste.

2. **Puxador de Folha Modal (`SheetGrabber` / `FrilaCor.puxador`):**
   - **Comportamento matemático:** 1,54:1 no claro e 1,89:1 no escuro sobre `SurfaceElevated`.
   - **Conformidade:** **Isento** conforme WCAG 1.4.11 (elementos puramente decorativos). O componente SwiftUI (`Componentes.swift:660`) aplica expressamente `.accessibilityHidden(true)` e as folhas contam com gesto de arrasto nativo e botão "Fechar" com alvo de toque de 44 pt e foco acessível.

3. **Evolução do Token `Warning` (`FrilaCor.alerta`):**
   - No Sprint 1 (paleta preliminar anterior ao MidFi), `Warning` possuía valor `#B57005` (3,78:1 sobre Surface, falhando para texto normal).
   - Com a aplicação da identidade MidFi do Fabrício (`commit fd06f002`), o token foi redefinido para `#9E5C00` (sRGB `0.620, 0.361, 0.000` no claro), atingindo **4,70:1** sobre `Surface` e **5,26:1** sobre `SurfaceElevated`, passando com folga o critério AA (≥ 4,5:1) sem necessidade de alterações manuais adicionais.

---

### Cobertura por Teste Automatizado de Regressão
A suíte unitária `ContrasteDesignTokensTests.swift` (`iOS/Tests/Unitarios/ContrasteDesignTokensTests.swift`) carrega dinamicamente os valores de `DesignSystem.xcassets`, calcula a luminância e garante que:
- Nenhum par normativo de texto regrida abaixo de 4,5:1.
- Nenhum componente ou ícone essencial regrida abaixo de 3,0:1.
- As restrições de uso do `BrandAccent` permaneçam estritamente documentadas e testadas.
