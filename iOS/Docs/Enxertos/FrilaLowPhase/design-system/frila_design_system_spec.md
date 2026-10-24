# Frila Design System & UI Specification: The "Gallery-Marketplace" Synthesis
**Product:** Frila (FindJob and Opportunities Marketplace for Freelancers)  
**Roles & Contributors:** Product Designer, Worker 1 (Airbnb Specialist), Worker 2 (Artsy Specialist), Orchestrator  
**Brand Color Anchor:** `#EA5A36` (Governed by OKLCH: `oklch(0.651 0.186 35.1)`)  
**Methodology:** Refero Design System Empirical Extraction & Semantic Merge  


> **Governing rules (Onda 1 — override anything below):** Swiss is the default paradigm · no italic or oblique anywhere (titles are upright) · figures in SF Pro with proportional digits, tabular only for animated or column values · money via `FrilaMoney` (USD, `en_US`: `$140/hr`, `$33,600`) displayed with `FrilaPriceTag` · no emoji or text glyphs as icons in badges/chips/pills — SF Symbols only. Source of truth: `DESIGN.md` and `Sources/FrilaDesignSystem/Primitives/`. In ASCII mockups, `(shield)`, `(hourglass)` etc. mark an SF Symbol slot (`checkmark.shield.fill`, `hourglass`).
---

## 1. Executive Summary & Design Thesis

Current freelance platforms (Upwork, Fiverr, Freelancer.com) suffer from severe design entropy: cheap 5-star ratings, yellow badge spam, bargain-bin countdown timers, inconsistent font hierarchies, and noisy elevated drop-shadows that degrade high-value creative and technical talent.

**Frila** establishes a radically new standard: the **Gallery-Marketplace Synthesis**.
By forking and merging the proven, empirical mechanics of **Airbnb** (App ID: 2) and **Artsy** (App ID: 218) extracted via Refero, Frila unites:
1. **The Soul of Artsy (Prestige, Dignity & Framing):** Museum-wall achromatic white canvas (`#FFFFFF`), zero gratuitous card drop-shadows, 1px crisp architectural dividers, museum placard metadata conventions (Creator in bold, Project upright in a lighter weight — italic is forbidden), uppercase micro-labels with wide tracking (`SCOPE`, `BUDGET`, `TIMELINE`), and verified historical track records instead of cheap star ratings.
2. **The Engine of Airbnb (Discovery, Frictionless Conversion & Transparence):** Floating sticky 999px search capsules with 3-part progressive disclosure (*What $\rightarrow$ How $\rightarrow$ Budget*), horizontal category scrollers, interactive budget distribution histogram with dual drag-handles, real-time result counters (`Show 42 Opportunities`), and sticky bottom proposal action bars.
3. **The Frila Brand Anchor (`#EA5A36` in OKLCH):** A vibrant, warm persimmon/vermilion orange-red governed by modern perceptual color spaces (OKLCH). It acts as the focused energetic pulse for high-intent commitments, active pill tabs, and escrow trust indicators—never as noisy wallpaper.

---

## 2. Synthesis & Mutual Evaluation Matrix

| Architectural Dimension | Airbnb (Worker 1 Findings) | Artsy (Worker 2 Findings) | Frila Synthesis Decision | Source Role & Rule |
| :--- | :--- | :--- | :--- | :--- |
| **Canvas & Surfaces** | Soft off-white, light gray sections, rounded container cards | Pure white gallery drywall (`#FFFFFF`), stark `#000000` text, flat `#F0F0F0` input fills | **Pure Gallery White (`#FFFFFF`)** with subtle `#FBFBFA` surfaces. No wallpaper tints. | Artsy primary rule: Creative work and opportunities provide 100% of the chromatic energy. |
| **Elevation & Shadows** | Floating search pill `0 4px 14px rgba(0,0,0,0.08)`, minimal card shadows | **0 box-shadows** across all cards and feeds. Completely flat. | **Zero shadows on cards.** Cards defined by negative space and hairline `1px #E5E5E3` borders. Search pill retains subtle Airbnb ambient elevation. | Artsy framing + Airbnb floating utility. |
| **Typography Hierarchy** | Uniform Bold Sans (Airbnb Cereal/SF Pro), strikethrough prices, heavy badges | High contrast: Bold Display Sans, **Italicized Artwork Titles**, Uppercase Micro-Labels (`WIDTH`, `MEDIUM`) | **The Placard Convention**: Client/Creator in Bold Sans, Opportunity Title upright in Medium Sans (`Design System Refactor, 2026`), specs in uppercase micro-labels. | Artsy curatorial cataloguing convention. |
| **Search & Discovery** | Floating 999px pill (`Where · When · Who`), horizontal category scroller | Light gray input field, curated 2-column editorial collections | **Floating 3-Part Pill Capsule**: Taps open modal (*What $\rightarrow$ How $\rightarrow$ Budget*). Category scroller with active indicator. | Airbnb conversion engine. |
| **Filtering Mechanism** | Price histogram with dual draggable circular handles, dynamic CTA count | Multi-facet vertical filter stack, dual range inputs, color swatches | **Dual-Handle Budget Histogram Sheet** with real-time dynamic CTA (`Show 38 Opportunities`). | Airbnb marketplace mechanics. |
| **Pricing & Compensation** | Bold rate + transparent breakdown modal (fees, taxes, totals) | Stark bold tabular figures (`£5,900`), zero discounts, firm valuation | **Dignified All-in Compensation**: Bold proportional SF Pro figures via `FrilaPriceTag` (`$140/hr` or `$18,500 Fixed`) + transparent escrow guarantee badge. | Artsy dignity + Airbnb fee transparency. |
| **Freelancer Profiles** | Host reviews, badge seals ("Superhost", "14 years on Airbnb") | **3-Pillar Taxonomy**: `Artworks` (Works), `Auction Results` (Track Record), `About` (Bio) | **Anti-Gig Profile**: `Selected Works` (Visual Showcase), `Verified Track Record` (Past contracts & brackets), `Biography` (Pedigree monograph). Categorized by subject without AI-sloped numbers. | Artsy artist pedigree model. |
| **Bottom Action Bar** | Sticky bottom sheet: Rate summary on left + "Reserve" pill on right | Stark black full-width pill `Contact Gallery` | **Sticky Proposal Bar**: Budget & timeline calculation on left + `#EA5A36` high-intent pill `Submit Proposal` on right. | Airbnb sticky bar architecture + Artsy stark commitment. |

---

## 3. Color Architecture & OKLCH Token Specification

The Frila brand color `#EA5A36` is anchored at coordinates:
$$\mathbf{L = 0.6510, \quad C = 0.1856, \quad h = 35.10^\circ}$$

### 3.1 Primary Brand Scale (OKLCH)
Strictly reserved for **primary CTAs, active selection pills, focus states, and key interactive highlights**. Never to be used as a full-screen wallpaper.

```
primary-50:  oklch(0.970 0.020 35.1) -> #FFF1EC  [Subtle active chip background]
primary-100: oklch(0.930 0.050 35.1) -> #FFDDD2  [Hover surface for interactive chips]
primary-200: oklch(0.850 0.100 35.1) -> #FFB6A1  [Hairline focus accent / outline]
primary-300: oklch(0.760 0.150 35.1) -> #FF8B6D  [Secondary illustration line]
primary-400: oklch(0.680 0.180 35.1) -> #F26643  [Hover state for primary button]
primary-500: oklch(0.651 0.186 35.1) -> #EA5A36  [BRAND ANCHOR: Primary CTA / Active Tab]
primary-600: oklch(0.540 0.180 35.1) -> #C03710  [Pressed state for primary button]
primary-700: oklch(0.460 0.160 35.1) -> #9D2701  [Accessible link text on light gray]
primary-800: oklch(0.380 0.130 35.1) -> #781D03  [Deep brand mark]
primary-900: oklch(0.290 0.090 35.1) -> #4F1506  [Dark tone highlight]
primary-950: oklch(0.200 0.060 35.1) -> #2C0903  [Deepest brand shade]
```

### 3.2 Achromatic & Neutral Scale (Gallery Wall System)
```
canvas:         oklch(1.000 0.000 0)    -> #FFFFFF  [Pure White Gallery Wall]
surface-subtle: oklch(0.985 0.003 40.0) -> #FBFBFA  [Card Container Surface]
input-bg:       oklch(0.960 0.005 40.0) -> #F2F2F0  [Search & Input Fields]
hairline:       oklch(0.910 0.005 40.0) -> #E5E5E3  [1px Crisp Architectural Divider]
border-control: oklch(0.820 0.008 40.0) -> #CECECB  [Outlined Buttons & Steppers]
text-muted:     oklch(0.520 0.012 40.0) -> #767571  [Metadata, Studio Attribution]
text-primary:   oklch(0.180 0.012 40.0) -> #1B1A18  [Body Text & Headlines]
text-ink:       oklch(0.100 0.008 40.0) -> #090908  [Stark Solid Pill CTA alternative]
```

### 3.3 Semantic Accents
```
escrow-verified: oklch(0.620 0.160 145.0) -> #008A3B [Emerald: 100% Escrow Funded, Verified Payment]
warning-expiring: oklch(0.650 0.150 75.0)  -> #C97A00 [Amber: Closing in 24h, 1 spot open]
```

---

## 4. Component Architecture & Blueprints

### Component A: The Frila Opportunity Card (Feed Unit)
Synthesizes Airbnb's 4:3 media presentation with Artsy's museum placard metadata hierarchy.

```
┌──────────────────────────────────────────────────────────┐
│  [(sparkles) Staff Pick]                   [(heart) Save]│
│                                                          │
│             PROJECT / SCOPE PREVIEW (16:10)              │
│                                                          │
│                      ● ○ ○ ○ ○                            │
├──────────────────────────────────────────────────────────┤
│  ACME CORP / LABS                             [Bold Sans]│
│  NextGen AI Assistant Design System, 2026     [Medium 500]│
│  Remote · Contract (3-6 mo) · Senior Level               │
│                                                          │
│  [Figma]  [Design Tokens]  [SwiftUI]          [Chips]    │
│                                                          │
│  $120–$150/hr  ·  Est. $35,000                [SF Pro]   │
│  (shield) 100% Escrow Funded                  [Green]    │
└──────────────────────────────────────────────────────────┘
```
- **Proportion:** 16:10 media carousel with 5 bottom-centered dots.
- **Corner Radius:** `14px` border radius with clean clipping.
- **Elevation:** `0px` shadow. Separated by `24px` vertical spacing and hairline `1px #E5E5E3` divider.
- **Placard Metadata:** 
  - Line 1: Client/Company Name (Bold Sans 15pt, `#1B1A18`).
  - Line 2: Opportunity Scope (upright Medium Sans 18pt, `#1B1A18`).
  - Line 3: Location, Duration, Seniority (Regular Sans 13pt, `#767571`).
  - Line 4: Tech Stack Chips (Pill capsules, `#F2F2F0` background, 12pt sans).
  - Line 5: `FrilaPriceTag` compensation (proportional SF Pro) + Verified Escrow chip with SF Symbol (`#008A3B`).

---

### Component B: Sticky Search Capsule & 3-Step Sheet
Forked from Airbnb's progressive discovery pattern.

```
┌──────────────────────────────────────────────────────────────┐
│  🔍  Staff Product Designer · Remote · $100k+      [ ⚙️ 2 ]   │
└──────────────────────────────────────────────────────────────┘
```
- **Default State:** Floating capsule (`height: 52px`, `radius: 9999px`, background: `#FFFFFF`, border: `1px solid #E5E5E3`, shadow: `0 4px 14px rgba(0,0,0,0.08)`).
- **Expansion (Tap):** Triggers full-screen modal with 3 stacked modular inputs:
  1. **What**: Role title, domain (Design, Engineering, AI, Growth).
  2. **How**: Contract type (`Retainer`, `Sprint`, `Hourly`, `Fixed Project`).
  3. **Budget**: Dual-slider histogram sheet.
- **Action Footer:** "Clear All" text button on left, high-intent `#EA5A36` pill button on right (`Show 47 Opportunities`).

---

### Component C: Budget Histogram & Dual-Handle Filter Sheet
Forked from Airbnb Flow #6389 (Screens `1e00ab54`, `265957bc`).

```
  OPPORTUNITY DENSITY (HOURLY / PROJECT)
       ▃ ▅ █ ▇ ▆ ▅ ▃ ▂
  ───●─────────────────●───   [Dual Circular Handles]
   Min Rate           Max Rate
  [$ 85 / hr]       [$ 160 / hr]

  [ Clear all ]               [ Show 38 Opportunities (#EA5A36) ]
```
- **Histogram Bars:** Rendered in subtle neutral `#E5E5E3` with active range highlighted in brand `#EA5A36` or high-contrast ink.
- **Handles:** 28px circular white pills with crisp `1px solid #CECECB` and subtle grab shadow.
- **Live Feedback:** Primary button updates dynamically with matching candidate count.

---

### Component D: Sticky Proposal Action Bar (Opportunity Detail)
Forked from Airbnb Flow #6399 (Screen `60143210`) with Artsy stark button styling.

```
┌──────────────────────────────────────────────────────────────┐
│  $140 / hr  (Est. $22,400 total)   ┌───────────────────────┐ │
│  (hourglass) Closes in 2 days       │   Submit Proposal     │ │
│                                    └───────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```
- **Position:** Fixed to bottom viewport with backdrop blur (`rgba(255, 255, 255, 0.92)`).
- **Border Top:** 1px hairline `#E5E5E3`.
- **Left Column:** Prominent bold rate (`FrilaPriceTag`, proportional SF Pro) + urgency metadata (`13pt regular #767571`).
- **Right Column:** Primary CTA Button (`height: 48px`, `radius: 9999px`, background: `#EA5A36`, text: `#FFFFFF`, font-weight: `600`).

---

### Component E: Freelancer Creator Profile (The 3 Pillars)
Forked from Artsy Flow #7603 & #7619 (Screens `4a9a4084`, `820e6a78`).

```
┌──────────────────────────────────────────────────────────────┐
│  [← Back]                                           [Share]  │
│                                                              │
│                         ( 80x80 )                            │
│                      [Avatar Photo]                          │
│                                                              │
│                    MARCUS BENNETT                   [Bold 26]│
│         Staff Design Technologist · Madrid, ES      [Meta 14]│
│                                                              │
│  ┌──────────────────┐  ┌──────────────────┐                  │
│  │   Invite to Job  │  │     Follow       │                  │
│  │    (#EA5A36)     │  │  (1px Outline)   │                  │
│  └──────────────────┘  └──────────────────┘                  │
├──────────────────────────────────────────────────────────────┤
│   SELECTED WORKS   │   TRACK RECORD   │   BIOGRAPHY          │
├──────────────────────────────────────────────────────────────┤
│  [2-Column Masonry Grid of Case Studies / Systems]           │
│  *Design System Alpha, 2025*                                 │
│  Vercel Labs · Verified Scope Delivered                      │
└──────────────────────────────────────────────────────────────┘
```
- **Replaces:** Cheap 5-star ratings and hourly wage stickers.
- **Pillar 1: Selected Works**: Full visual portfolio in clean 2-column gallery grid.
- **Pillar 2: Track Record**: Verifiable historical record of past completed contracts, client names, project scope brackets, and on-time delivery guarantees.
- **Pillar 3: Biography**: Formal third-person professional statement, speaking engagements, publications, open-source repositories, and recognized honors.

---

## 5. Design Decision Ledger

| Decision | Source Reference | Source Rule / Role | Why It Was Chosen |
| :--- | :--- | :--- | :--- |
| **Achromatic Canvas (`#FFFFFF`)** | Artsy App ID 218 (`7359672b`) | Canvas must be pure white gallery drywall; work supplies the color. | Prevents the marketplace from feeling like an e-commerce bargain store; elevates freelance work into prized craft. |
| **Zero Drop-Shadows on Cards** | Artsy App ID 218 (`f7b4edda`) | Zero drop-shadows; separation achieved via negative space & 1px borders. | Shadows create UI sludge and dated skeuomorphism; flat gallery framing gives modern architectural restraint. |
| **Brand Color `#EA5A36` in OKLCH** | Frila Product Constraint & Brand Anchor | Used strictly for high-intent primary CTA, active pill states, and focus rings. | Keeps the brand vibrant and energetic without compromising accessibility or visually polluting creative portfolio work. |
| **The "Placard" Typographic Contrast** | Artsy App ID 218 (`7359672b`) | Creator/Client in Bold Sans; Project/Brief Title upright in a lighter weight (italic is forbidden). | Creates instant cultural distinction between the entity and the project scope, evoking fine art museum documentation. |
| **Uppercase Micro-Labels (`SCOPE`, etc.)** | Artsy App ID 218 (`e7ad5506`, `dce2b24c`) | 11pt bold uppercase with `+1.0px` letter-spacing. | Imparts archival cataloguing discipline and legal/technical clarity to contract specifications. |
| **Floating 3-Part Sticky Search Pill** | Airbnb App ID 2 (`7cc77ea1`, `0db5a079`) | 999px floating capsule that expands into a 3-part chunked modal. | Reduces search cognitive load from a huge form into progressive, micro-committed steps (*What $\rightarrow$ How $\rightarrow$ Budget*). |
| **Dual-Slider Budget Histogram** | Airbnb App ID 2 (`1e00ab54`, `265957bc`) | Interactive price distribution with dual draggable handles and dynamic CTA count. | Freelancers and clients need immediate visual feedback on where a rate sits in the market distribution. |
| **Sticky Proposal Action Bar** | Airbnb App ID 2 (`60143210`) | Fixed bottom bar pairing rate/timeline on left with prominent CTA on right. | Maximizes conversion on mobile by keeping the primary commitment trigger accessible at every scroll depth. |
| **Zero-State Remediation Chips** | Airbnb App ID 2 (`1095dff6`) | One-tap chips to dismiss conflicting filters when zero results are returned. | Eliminates search dead-ends and frustration when criteria are too strict. |
| **Solid Brand Confirmed State (role picker, experience level)** | User direction 2026-10-01; contrast review in `RULES.md` 3.2 | `dynamicBrandSolidFill` + `dynamicBrandSolidText` (selection orange `#C9470F` with white text in both modes, 4.78:1) only for a value the user chose on purpose, always with a check that bounces once and a success haptic when the user closes the wheel. Tapping the solid field reopens the picker to review. Variants in Design Lab: Borda, Laranja, Tinta. | A consolidated choice should read as done at a glance. Possible confusion with the CTA is accepted: tapping it only reopens the review and it is learned after one or two uses. Rejected: `primary600` with white (read as red, an alert or error) and the brand orange with dark ink (strange typography). The hue rotation toward yellow keeps it orange while darker. |
| **Experience as a Ranked List (`FrilaExperienceLevelPicker`)** | Train Fitness "Gym Experience" (Refero `56499cfe`, `138c7cff`), Todoist onboarding (Refero `79ce2144`) | Full-width stacked option rows, one per level, single choice. Frila marks the chosen row with a gray selection wash (never the brand color) that slides between rows on an ease-in-out Bézier, opens in place with the shared disclosure motion, answers a tap or a press-and-slide (hold about 0.15 s, then drag, with a haptic tick per row), and the choice concludes at once: the list collapses to the chosen content and the chevron turns into a check (M12). No auto-dismiss timer: the last touch is the acceptance. Dropped along the way: a 2.5 s auto-dismiss timer after the choice (an extra wait on top of the tap), a brand fill with a bouncing check while choosing (read as alert and crude), a hard cross-fade between rows, and an automatic scroll on open (read as a jump). | The four levels are an ordinal scale of effort. A 2x2 chip grid hid the order (anti-pattern M9); a list top to bottom shows it. A step glyph repeated per row was dropped (M11): order and copy carry the hierarchy until leadership icons are designed. |
| **Form Typography: Editorial Pair (`FrilaFormType`)** | Design System editorial section (Bricolage for titles and protagonist values, SF Pro for metadata); `better-typography` principles 4 to 8 and 15 | Five steps on the Minor Third scale, each tied to an iOS text style. Bricolage only for the question and catalog choices; SF Pro for labels, input, details and figures. | Gives the form one voice for "what is asked and what was chosen" and a quiet structure for everything else, instead of seven SF sizes. Inputs move from 15 to 17 pt, the iOS body size. |
| **Role Picker Group (common region, A/B)** | Gestalt common region and unity; iOS grouped list idiom; `beautiful-shadows` md | `FrilaPickerGroupStyle`: Categoria and Função share one container (R 26 = field 14 + padding 12). Light: a white card lifted by a 6% ring and four layered neutral shadows, fields `#F6F6F4` with an 8% hairline, confirmed in selection orange with white text. Dark: tone steps with a ring, confirmed graphite. Empty fields show examples, not the label (M14). Open state turns the section label into the collapse button, with a brand chevron up that bounces once (M13); a filled "Concluir" pill was dropped as shape-in-shape noise. The experience list uses the same card. | The two pickers are one decision, so they read as one body. Rejected along the way: canvas-white cutouts with absolute-black confirmed (too extreme) and flat near-gray containers in light mode (read as a low-fidelity prototype). |
| **Outside Tap Dismissal & Keyboard Useful Window (M20, M21)** | Guardrails M20 & M21 (`RULES.md` 3.3); mobile-design touch arbitration | Outside tap closes inline controls (`FrilaCoupledRolePicker`, `FrilaExperienceLevelPicker`) confirming the eligible/centered item and closes software keyboards (`FrilaKeyboardDismissModifier`), consuming the tap without triggering underlying buttons or new fields. Gesto de rolagem (pan) é 100% preservado sem overlay de tela inteira (limiares: $\le 10\text{ pt}$ de deslocamento e $\le 0,30\text{ s}$ de contato em `FrilaOutsideTapGestureRecognizer`). Decisão Q1: durante inércia, toque fora confirma o destino de snap calculado ao soltar e recolhe sem duplo commit. Decisão Q2: ação "Nova..." centrada mantém valor anterior (ou vazio) sem abrir criação. Decisão Q3: teclado tem prioridade sobre roleta aberta (1º toque fecha teclado, 2º recolhe roleta). Janela útil $T..B$ garante margem mínima de 16 pt (`FrilaGeometry.space16`) acima do teclado e recolhe chrome fixo (`publishBar`, `continuousFormDock`) durante edição. | Evita a fricção de exigir toque no cabeçalho para fechar controles ou teclado e elimina toques acidentais destrutivos em botões subjacentes, mantendo a rolagem fluida e os campos em foco 100% visíveis. |
| **3-Pillar Talent Profile Taxonomy** | Artsy App ID 218 (`4a9a4084`, `820e6a78`) | `Selected Works`, `Track Record` (Past Sales/Contracts), `Biography`. | Dismantles the toxic gig-economy rating trap; rewards provable craft, client caliber, and transparent historical delivery. |

### 5.1 Especificação Técnica de Toque Fora e Janela Útil (M20 / M21)

- **APIs SwiftUI Canônicas:**
  - `.frilaOutsideTapScope()`: define a região e espaço de coordenadas de arbitragem na raiz da tela ou sheet.
  - `.frilaOutsideTap(id:isOpen:onClose:)`: registra um controle expansível inline como âncora; protege a área interna e recolhe no toque externo.
  - `.frilaKeyboardDismissScope(observer:)`: compõe o escopo de toque fora e observa o teclado virtual via `@Observable FrilaKeyboardObserver`.
  - `.frilaFormField(id:isFocused:)`: registra a identidade e frame de um campo focado, garantindo revelação na janela útil $T..B$ com folga $\ge 16\text{ pt}$ (`FrilaGeometry.space16`) via `ScrollViewReader`.
  - `.frilaCollapseOnKeyboard()`: recolhe inteiramente barras e docks fixos do `safeAreaInset` durante digitação com sobreposição.
- **Comportamento de Fechamento por Componente:**
  - `FrilaCoupledRolePicker`: confirma o destino elegível centralizado ao fechar (Q1). Se o destino for "Nova categoria" ou "Nova função", reverte o par inteiro ao último par confirmado (ou vazio, sem iniciar criação).
  - `FrilaExperienceLevelPicker`: preserva a seleção confirmada anterior, limpando apenas o destaque temporário de arrasto (`slideTitle = nil`).
- **Suporte Multiplataforma (iOS & macOS):**
  - **iOS (UIKit):** `FrilaOutsideTapGestureRecognizer` anexado à janela real (`UIWindow`), com conversão explícita de coordenadas para o escopo, triagem em `shouldReceive`, cancelamento durante arrasto/scroll ($\Delta > 10\text{ pt}$) ou tempo excedido ($> 0,30\text{ s}$).
  - **macOS (AppKit):** `NSClickGestureRecognizer` anexado à `contentView` da janela, conversão considerando `isFlipped` e triagem pré-reconhecimento em `gestureRecognizerShouldBegin`.
  - **Exceção de Apresentações Nativas:** Apresentações do sistema (como o popover nativo de `FrilaTimeField`, sheets modais e alertas) continuam sob controle de seus hosts nativos e não sofrem interferência do escopo de fundo.

---

## 6. Implementation Roadmap for Workers Alpha & Beta

With the Design System and Tokens codified in `docs/design-system/tokens.json` and `docs/design-system/tokens.css`:
1. **Worker Alpha (Feature / Component Build)**:
   - Implement `OpportunityCard` component following the Placard typography and 16:10 carousel.
   - Implement `StickySearchCapsule` and modular 3-step modal.
   - Implement `StickyProposalBar` for the Opportunity Detail view.
2. **Worker Beta (Testing & QA)**:
   - Verify WCAG 2.2 AA contrast on `#EA5A36` against white and dark backgrounds.
   - Verify touch target hitboxes ($\ge 44 \times 44\text{pt}$) on all pill buttons and sliders.
   - Test responsive layout and zero-state recovery mechanics.
