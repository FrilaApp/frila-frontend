# 🏛️ Especificação de Engenharia: Sistema, Laboratório e Acessibilidade (P3)

> **Documento Normativo de Implementação (Pacote P3):**
> Especificação técnica detalhada das superfícies do Sistema, do Laboratório e de seus metadados dinâmicos e acessibilidade no simulador Frila (iOS 26+ / macOS 14+).
> Em conformidade com `RULES.md`, `ORQUESTRACAO.md`, `MANIFESTO-PAGINAS.md` e a `SPEC.md` (§2, §5, §6, §7 e §8).

---

## 1. Escopo e Arquitetura do Pacote P3

O pacote P3 é responsável pela implementação das superfícies navegáveis dos ambientes **Sistema** e **Laboratório**, pela infraestrutura de contêiner compartilhada e pelo componente padronizado de metadados da casca:

1. **`CatalogMetadataView`:** Componente desacoplado de selos de fidelidade (`Baixa fidelidade`, `Média fidelidade`, `Alta fidelidade`), status de laboratório (`Em exploração`) e contagens. Construído com tipografia dinâmica, altura intrínseca (sem altura fixa), texto explícito e contraste $\ge 4.5:1$ nos temas Claro e Escuro. Não reutiliza nem altera `FrilaStatusChip`.
2. **`ShowcaseContainer`:** Casca compartilhada de visualização de páginas e experimentos, fornecendo cabeçalho estruturado, metadados, alternância de tema e ancoragem de canvas acromático.
3. **`SystemIndexView`:** Índice do Sistema estruturado como lista plana sem hierarquia intermediária de categorias, dividido visualmente em duas seções semânticas: **Fundamentos** (4 páginas) e **Componentes** (19 páginas). Total de 23 páginas únicas.
4. **`SystemPageView`:** Roteador exaustivo que mapeia cada uma das 23 páginas do Sistema para sua respectiva visualização demonstrada.
5. **`LaboratoryIndexView`:** Índice das 4 explorações ativas do Laboratório (`lab/role-picker`, `lab/experience`, `lab/studio`, `lab/shift-controls`), com selos dinâmicos `Em exploração` e mensagem de fallback quando vazio (`Nenhuma exploração ativa.`).

---

## 2. Garantia de Alcance em $\le 3$ Ativações

Conforme a SPEC §2 e §8, toda entrada registrada do catálogo é alcançável em no máximo 3 ativações a partir da raiz sem flags:

- **Na Hipótese 1 (H1: Índice em Lista):**
  - Ativação 1: Toque na entrada do ambiente no Índice Raiz (`Sistema` ou `Laboratório`).
  - Ativação 2: Toque na linha desejada dentro da lista plana do ambiente.
  - Resultado: Exibição da página ou experimento correspondente. Total: **2 ativações**.
- **Na Hipótese 2 (H2: Abas de Ambiente):**
  - Ativação 1: Toque na aba do ambiente (`Sistema` ou `Laboratório`).
  - Ativação 2: Toque na linha desejada na lista plana.
  - Resultado: Exibição da página ou experimento. Total: **1 a 2 ativações**.

---

## 3. Matriz das 23 Páginas do Sistema

### 3.1 Seção Visual: Fundamentos (4 páginas)
| # | ID / Rota | Título Canônico | Resumo |
|---|---|---|---|
| 1 | `system/typography` | Tipografia & Fundamentos | Escala modular Minor Third, upright sem itálico e os 7 degraus canônicos. |
| 2 | `system/colors` | Cores & Tokens | Sistema cromático OKLCH com âncora #EA5A36, parede de museu e pastéis. |
| 3 | `system/liquid-glass` | Liquid Glass | Camadas translúcidas do iOS 26+ com borda óptica especular de 2 tons. |
| 4 | `system/shadows` | Superfície & Sombras | Sistema Beautiful Shadows em 6 elevações coordenadas e anéis concêntricos. |

### 3.2 Seção Visual: Componentes (19 páginas)
| # | ID / Rota | Título Canônico | Resumo |
|---|---|---|---|
| 5 | `system/search-capsule` | Search Capsule | Cápsula de busca interativa e Liquid Glass. |
| 6 | `system/segmented-control` | Segmented Control | Controle de 3 segmentos com ícones SF Symbols e texto. |
| 7 | `system/opportunity-card` | Opportunity Card | Cards de oportunidade clássico, framed, minimal, liquid e Hero Placard. |
| 8 | `system/budget-histogram` | Budget Histogram | Histograma de 13 barras com sliders de passo magnético. |
| 9 | `system/button` | Botões & Chips de Status | Pílulas Capsule 32/44/52pt e FrilaStatusChip. |
| 10 | `system/category-chip` | Category Chip | Chips em pastéis funcionais com ícones e estados. |
| 11 | `system/filter-chip` | Filter Chip & Dinâmicas de Bounce | Dinâmica tátil de press bounce, activation pop e pulse. |
| 12 | `system/proposal-bar` | Proposal Bar & Floating Dock | Barra de proposta fixa e floating dock desacoplado. |
| 13 | `system/creatorProfileHero` | Creator Profile Hero | Perfil monográfico com avatar 68x68, anel e badge. |
| 14 | `system/price-tag` | Price Tag & Money | Taxas horárias, valores fixos e estimativas totais. |
| 15 | `system/toast` | Toast de Notificação | Notificações transitórias com mola tátil e drag. |
| 16 | `system/feed-stagger` | Feed Stagger & Transição de Cartão | Cascata escalonada e transição contínua com namespace. |
| 17 | `system/opportunity-detail` | Opportunity Detail | Visualização completa da tela de oportunidade. |
| 18 | `system/skeletons` | Skeletons & Estados de Carga | Estados de carga com shimmer atenuado para acessibilidade. |
| 19 | `system/stat-card` | Stat Card | Métrica em destaque monumental e citação editorial com aspas curvas. |
| 20 | `system/flow-stepper` | Flow Stepper | Progresso sequencial com activeFocused, dots e pill. |
| 21 | `system/progressive-blur` | Progressive Blur | Desfoque progressivo com gradiente de opacidade. |
| 22 | `system/numbered-list` | Numbered List | Listas numeradas em estilos card e plain. |
| 23 | `system/editorial-tag` | Editorial Tag | Metadado editorial minimalPlacard, framedAccent e splitPill. |

---

## 4. Matriz das 4 Explorações do Laboratório

| # | ID / Rota | Título Oficial | Status | Resumo |
|---|---|---|---|---|
| 1 | `lab/role-picker` | Roletas Acopladas | `Em exploração` | Seleção em dois eixos ortogonais acoplados com atrito tátil e morphing. |
| 2 | `lab/experience` | Seletor de Experiência | `Em exploração` | Seletor ordinal de senioridade com expansão in-place, escolha por toque ou deslize e recolhimento imediato. |
| 3 | `lab/studio` | Studio Lab | `Em exploração` | Fluxo de criação de vagas com rascunhos, prévia e celebração. |
| 4 | `lab/shift-controls` | Controles de Turnos | `Em exploração` | Controles atômicos de horários, dias e steppers de vagas e remuneração. |

---

## 5. Diretrizes de Acessibilidade (A11y, SPEC §7)

1. **Selos (`CatalogMetadataView`):** Altura intrínseca que expande com Dynamic Type (`.frilaType(.microBold, dynamic: true)`), sem altura fixa nem `lineLimit(1)`.
2. **Área de Toque:** Todas as linhas navegáveis e controles interativos possuem área de toque efetiva $\ge 44 \times 44\text{pt}$ (G8) com `.frilaHitbox()`.
3. **VoiceOver:**
   - Linhas de catálogo lidas de forma combinada e coesa: `"Nome, Descrição, Selo"`.
   - Elementos decorativos (chevrons, ícones de fundo) ocultos com `.accessibilityHidden(true)`.
   - Cabeçalhos de seção marcados com `.accessibilityAddTraits(.isHeader)`.
4. **Contraste:** Todas as cores de primeiro e segundo plano respeitam taxa de contraste $\ge 4.5:1$ contra os fundos nos temas Claro e Escuro.
5. **Reduce Motion:** Animações respeitam `accessibilityReduceMotion` do ambiente.
