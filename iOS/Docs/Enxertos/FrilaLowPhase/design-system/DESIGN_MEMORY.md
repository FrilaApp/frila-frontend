# Frila Design Memory

**Product:** Frila (FindJob & Opportunities Marketplace for Freelancers)  
**Last Updated:** September 2026  
**Stack:** Swift / SwiftUI (macOS 14+, iOS 17+, iOS 26+ Liquid Glass) + Web Design Lab Harness  
**Author:** Design Lab & Variants Architect  

---

## 1. Brand Tone & Aesthetics
- **Core Archetype:** The Gallery-Marketplace Synthesis.
- **Key References:**
  - **Artsy (App ID 218):** Museum-wall achromatic drywall (`#FFFFFF`), zero gratuitous card drop shadows, museum placard metadata contrast (Client in bold, Project Title upright in a lighter weight — italic is forbidden), uppercase micro-labels with wide letter-spacing (`+1.0px`).
  - **Airbnb (App ID 2):** Floating sticky 9999px search capsule with 3-part progressive disclosure (*What → How → Budget*), interactive dual-handle budget histogram, real-time matching counter.
  - **Genie App (App ID 289):** Approachable capsule geometry (9999px), continuous corner radii, tactile press physics (`scale(0.97)`), and asymmetric button spacing.
  - **Apple iOS 26+ Liquid Glass:** Native `.glassEffect()` modifiers, specular edge light-catch overlays (`border-top: 1px solid rgba(255,255,255,0.60)`).
- **Anti-Patterns (Forbidden):**
  - No 5-star rating traps, no cheap yellow badges, no promotional countdown timers, no heavy elevated card drop-shadows, no full-screen wallpaper saturation in primary colors.

---

## 2. Color System & OKLCH Tokens
- **Brand Anchor:** `#EA5A36` governed by OKLCH: `oklch(0.6510 0.1856 35.10deg)`.
  - Strictly reserved for **primary commitment CTAs, active selection tabs/pills, and focus rings**.
  - **Contrast Rule:** `#EA5A36` has a 3.49:1 contrast ratio against white. It passes WCAG AA for UI boundaries ($\ge 3.0:1$) and large text ($\ge 18.66\text{px}$ bold), but is **strictly forbidden for small body text**.
  - For accessible text links on light surfaces, use `--frila-color-primary-700` (`#9D2701`, 7.71:1) or `600` (`#C03710`, 5.53:1).
- **Achromatic Palette:**
  - Canvas: `#FFFFFF` (Dark: `#0E0D0C`)
  - Subtle Surface: `#FBFBFA` (Dark: `#171614`)
  - Input Background: `#F2F2F0` (Dark: `#23221F`)
  - Hairline: `#E5E5E3` (Dark: `#2E2D29`)
  - Text Primary: `#1B1A18` (17.39:1 contrast, AAA)
  - Text Muted: `#767571` (4.61:1 contrast, AA)
- **Semantic Accents:**
  - Contrato Direto Verificado: `#007A33` (`oklch(0.550 0.160 145.0deg)`) with `#EBF7EE` background (4.70:1 contrast, AA). *(Nota: O conceito de escrow/caução foi formalmente erradicado do projeto).*
  - Warning / Expiring: Text `#9E5C00` (`oklch(0.550 0.160 70.0deg)`) (5.27:1 contrast, AA).
  - Error: `#D82020` (5.06:1 contrast, AA).

---

## 3. Typography Primitives (The 5 Paradigms)
Global rules (all paradigms): **no italic** (serif or oblique sans), hero figures in **SF Pro with proportional digits** (tabular only for animated or column values), money via `FrilaMoney` (USD, `en_US`: `$140/hr`, `$33,600`), SF Symbols instead of emoji/glyph icons.

1. **Swiss Neo-Grotesque (Default):** Unified SF Pro with mathematical weights, upright Medium placard titles and tight negative tracking (`-1.2pt` display). `FrilaTypography()` and every static token resolve here.
2. **Curatorial Placard:**
   - Headings & Entities: SF Pro Bold (`700`).
   - Brief Titles: New York upright (`400`).
   - Micro-Labels: SF Mono Uppercase (`600`, tracking `+1.2pt`).
   - Metrics: SF Pro Bold, proportional digits.
3. **Humanist Atelier:** Warm New York display (upright) paired with humanist SF Pro.
4. **Hyper-Dense Archival:** Compact SF Mono for labels and codes; figures in SF Pro.
5. **Tactile Liquid Glass:** Crisp SF Pro (Rounded is forbidden) with specular reflections on glass surfaces.

---

## 4. Geometry & Elevation Rules
- **The "0-Shadow" Gallery Rule:** Cards and feed list units sit directly on `#FFFFFF` drywall with zero box-shadow. Visual separation is achieved strictly through negative space and 1px `#E5E5E3` hairlines.
- **Concentric Radius Rule:**
  $$\mathbf{R_{\text{inner}} = \max(0, R_{\text{outer}} - \text{Padding})}$$
- **Radius Scale:**
  - Pill: `9999px`
  - Sheet: `24px`
  - Card: `16px`
  - Input: `14px`
  - Nested: `8px`

---

## 5. Interaction & Craft Physics
- **Button Press:** `transform: scale(0.97)` over 120ms with `cubic-bezier(0.16, 1, 0.3, 1)`.
- **Asymmetric Pairing:** Ghost dismiss button sits to the left with a 14px gap, directing primary optical weight to the right-hand `#EA5A36` pill.
- **Hitbox Standard:** Minimum $44 \times 44\text{pt}$ touch target enforced on all clickable surfaces.

---

## 6. Swift Architecture Conventions
- Swift 6.3+ / SwiftUI with Observation (`@Observable`).
- Clean separation between `Primitives/` (Color, Typography, Geometry, LiquidGlass), `Components/`, and `DesignLab/`.
- Native iOS 26+ Liquid Glass integration (`.glassEffect()`) with graceful `.ultraThinMaterial` and specular gradient borders.

---

## 7. Job Creation Studio & Persona Architecture
- **Persona Switch (Canonical Apple HIG .principal):** Curatorial Segmented Capsule (`FrilaSegmentedControl`) toggling between **Modo Talento** (discovery & marketplace feed) and **Modo Estúdio** (recruitment management & opportunity publishing). Elevated directly to `ToolbarItem(placement: .principal)` at 224pt width and 32pt compact height (`FrilaGeometry.buttonHeightCompact`). This eliminates scroll-away amnesia, removes dead vertical titles ("Marketplace Frila" / "Estúdio Contratante"), and ensures consistent mode switching across the entire lifecycle.
- **Single Authoritative CTA (Anti-Duplicate Action):** Eliminated the redundant `+ Criar Vaga` from the navigation toolbar. The studio dashboard anchors on a single, clear, authoritative 44pt HIG standard capsule button: `[+ Publicar Oportunidade]`.
- **Streamlined Dashboard Architecture (6-Tier Avalanche Elimination):** Removed repetitive 3-line placard headers ("PAINEL DO CONTRATANTE / Estúdio & Vagas Frila / Publique oportunidades...") that consumed >70% of the mobile viewport. The Studio view anchors immediately with the 3 Curatorial Metric Pillars (`VAGAS ATIVAS`, `PROPOSTAS`, `RESPOSTA`), followed directly by the primary CTA and live opportunities feed.
- **Studio 3-Stage Macro Flow:** Designed for $\le 90$s completion time, inspired by high-velocity gallery curations rather than bloated 70-screen micro-step listing engines:
  - **Etapa 1 (Área & Requisitos):** Título livre da vaga (ex: *"Caixa de Padaria"*, *"Terapeuta Ocupacional Infantil"*, *"Barista"*, *"Designer de Interfaces"*), matriz de setores universais com chips táteis (`activationPop`), nível de experiência em grid 2×2 (*Qualquer Experiência*, *Iniciante / Prático*, *Intermediário*, *Especialista*) e nuvem de requisitos com campo de adição dinâmica personalizada (`+`).
  - **Etapa 2 (Formato & Remuneração):** Modalidades reais de contratação (*Diária ou Plantão*, *Projeto Fechado*, *Mensal ou Recorrente*, *Por Hora Trabalhada*), duração e localização, controle interativo de remuneração (R$ 15/h a R$ 260/h com atalhos táteis de valores usuais) e card de compensação total estimada.
  - **Etapa 3 (Revisão & Apresentação):** Identidade da vaga e contratante/empresa, 6 fotos curatoriais fotográficas abrangentes de diversos setores (comércio/balcão, clínica/saúde, café/gastronomia, estúdio/design, tecnologia, educação) + upload nativo via `PhotosPicker` ("Enviar Foto"), prévia ao vivo em escala real com `FrilaOpportunityCard` e botão proeminente de publicação de 52pt.
- **Draft Resumption & Celebration:** Confirmação de saída salvando `JobCreationDraft` com card de retomada no painel do estúdio; post-publish `FrilaJobCelebrationSheet` com `ShareLink` nativo.

---

## 8. Anti-Slop Directive: Zero Ponto Médio (`·`) & Universalidade Brasileira
- **Erradicação do Ponto Médio (`·` / `\u{00B7}`):** Proibido o uso de `·` em qualquer string de cabeçalho, subtítulo, cartões, chips ou notificações. Metadados são separados por hierarquia visual pura, espaçamento ou travessão em-dash (`—`).
- **Universalidade de Escopo:** O Frila transcende o nicho restrito de tech/São Francisco e serve a qualquer negócio ou serviço autônomo no Brasil, garantindo clareza, linguagem natural e acessibilidade.
- **Scroll Clearance Mandatório:** Áreas com dock inferior persistente exigem folga de rolagem mínima de 160pt (`Spacer().frame(height: 160)`) e fundo 100% sólido para assegurar que nenhum conteúdo fique encoberto ou ilegível.

---

*Updated by Design Lab & Variants Architect*
