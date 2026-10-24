# Frila Design System — Master Tradeoff Matrix (/variants Specification)

**Product:** Frila (Marketplace for Elite Freelancers & Design Technologists)  
**Stack:** Swift / SwiftUI (Native Package) + Web Design Lab Harness  
**Methodology:** Governed by the `/variants` skill (Disciplined single-primary-axis exploration, non-generic naming, real content evaluation, and objective tradeoff analysis).  
**Foundations:** The Gallery-Marketplace Synthesis (Artsy Museum Placard × Airbnb Discovery Engine × OKLCH `#EA5A36` × iOS 26+ Liquid Glass).

---

## 1. The Floor Every Variant Clears

Before entering this matrix, every variant cleared the `better-interface` and WCAG AA escalation triggers:
- **Accessible Names:** Every interactive control has an accessible label (`aria-label`, `<button>`, or semantic text).
- **Keyboard Reachable:** All controls are reachable via `Tab` with visible focus rings (`box-shadow: 0 0 0 2px var(--frila-color-canvas), 0 0 0 4px var(--frila-color-primary-500)`).
- **No Meaning on Color Alone:** All status indicators pair chromatic tokens with a text label, optionally led by an SF Symbol (`checkmark.shield.fill`, `hourglass`). Emoji and text glyphs are never used as icons.
- **Responsive at 320px:** No horizontal overflow clipping or broken layouts down to 320px viewport width.
- **Touch Target Hitbox:** All clickable pills, sliders, and buttons maintain a strict $\ge 44 \times 44\text{pt}$ hitbox.

---

## 2. Primitive Typography Paradigms Matrix

| Variant Name | Primary Axis | Font Stack | Right When | Costs / Tradeoffs |
| :--- | :--- | :--- | :--- | :--- |
| **1. Swiss Neo-Grotesque** *(Default)* | Structure & Geometry | Unified SF Pro, upright, mathematical weights | Default for every Frila surface: developer tools, AI infra, marketplace feeds and contracts. | Clinical, architectural feel with reduced fine-art emotional warmth. |
| **2. Curatorial Placard** | Expressive Contrast / Culture | Bold Sans + Upright Serif (New York) + Tracked Monospace | High-budget agency & studio briefs ($20k–$100k+) requiring editorial prestige. | Three families on one card; serif titles feel formal for micro-tasks. |
| **3. Humanist Atelier** | Warmth & Tactility | Warm Serif (Fraunces/Lora) + Humanist Sans | High-craft branding, bespoke typography, and cultural institution commissions. | Less suited for dense tabular data or high-frequency quantitative feeds. |
| **4. Hyper-Dense Archival** | Density & Data Throughput | Compact Monospace labels (SF Mono) + SF Pro figures | High-volume financial transactions, smart contract audits, and terminal feeds. | Extreme visual density requires high cognitive focus from casual non-technical users. |
| **5. Tactile Liquid Glass** | Surface Depth & Luminance | Crisp SF Pro (Rounded is forbidden) | Next-gen spatial interfaces (iOS 26+, macOS, visionOS) and floating docks. | Relies on hardware GPU backdrop filters; potential legibility loss on complex backgrounds. |

---

## 3. Component Variations Matrix (30 Variations Across 6 Core Components)

### 3.1 Component 1: `OpportunityCard` (Feed Unit)

| Variant | Axis Position | Right When | Costs |
| :--- | :--- | :--- | :--- |
| **Quiet Gallery (A)** | Structure (Achromatic Frame) | Fine-art and design engineering briefs where card drop-shadows degrade craft dignity. | Lower click affordance for non-editorial users accustomed to card boxes. |
| **Curatorial Placard (B)** | Type (Museum Documentation) | High-value contracts requiring instant cultural gravitas and verifiable pedigree. | Consumes ~20% more vertical space on mobile screens. |
| **Dense Marketplace (C)** | Density (Terminal Ledger) | Quantitative feeds where users need to scan 10+ jobs per screen view. | Visual compression reduces photographic presentation impact. |
| **Tactile Stage (D)** | Interaction (Spring Physics) | Touch-first mobile devices where tactile spring response drives browsing engagement. | Continuous GPU composite redraws on budget mobile hardware. |
| **Liquid Glass Vitrine (E)** | Expression (Apple iOS 26+) | High-end spatial displays and contextual floating overlays over rich imagery. | Strict requirement for CSS backdrop-filter and WebGL shader support. |

---

### 3.2 Component 2: `StickySearchCapsule & 3-Step Discovery Sheet`

| Variant | Axis Position | Right When | Costs |
| :--- | :--- | :--- | :--- |
| **Monolithic Whisper (A)** | Structure (Minimalist 3-Segment) | Standard top-level navigation on white drywall backgrounds. | May disappear optically on pages with heavy photographic backgrounds. |
| **Lexicon Index (B)** | Type (Curatorial Categories) | Editorial taxonomy browsing (Fine Art, Type Systems, Sound, Spatial). | Text-heavy tags take longer to read than iconographic chips. |
| **Matrix Command Bar (C)** | Density (Linear / Raycast Style) | Keyboard power users who prefer typing filters (`cmd+k`) over multi-step sheet modals. | Steeper learning curve for non-technical casual clients. |
| **Elastic Capsule (D)** | Interaction (Spring Expansion) | Mobile screens where tapping expands inline instead of opening full modals. | Can push feed content downward causing visual layout shifts if unpinned. |
| **Refractive Lens (E)** | Expression (Liquid Glass) | Floating sticky navigation over scrolling gallery feeds. | Specular borders require careful opacity tuning against light/dark imagery. |

---

### 3.3 Component 3: `BudgetHistogram & Dual-Handle Filter`

| Variant | Axis Position | Right When | Costs |
| :--- | :--- | :--- | :--- |
| **Horizon Density (A)** | Structure (Achromatic Curve) | Quiet editorial aesthetic with zero loud graphical distraction. | Less immediate visual understanding of discrete rate bins. |
| **Valuation Ledger (B)** | Type (Tabular Bracket Display) | Institutional clients budgeting fixed brackets ($10k, $25k, $50k+). | Requires extra screen estate for tabular numerical breakdowns. |
| **Quant Matrix (C)** | Density (Step Bar Histogram) | Freelancers and clients needing exact market percentile distribution. | Complex presentation can overwhelm novice freelancers. |
| **Magnetic Dual-Pill (D)** | Interaction (Snapping Drag Handles) | Touch-based rate negotiation where handles snap to standard $10/hr increments. | Can frustrate users wanting freeform arbitrary numbers ($137.50/hr). |
| **Luminous Prism (E)** | Expression (OKLCH Color Spectrum) | Highlighting active market sweet-spots with vivid OKLCH brand gradients. | Risk of breaking the strict "achromatic gallery drywall" rule if overused. |

---

### 3.4 Component 4: `FrilaButton & Pill Hierarchies`

| Variant | Axis Position | Right When | Costs |
| :--- | :--- | :--- | :--- |
| **Achromatic Line (A)** | Structure (Pure Hairline) | Secondary utility controls (`Save`, `Share`, `Follow`). | Cannot serve as primary conversion CTA due to low optical mass. |
| **Placard Press Stamp (B)** | Type (Uppercase Tracked Pill) | High-contrast editorial confirmation actions. | Longer labels eat horizontal space due to `+1.0px` tracking. |
| **High-Throughput Suite (C)** | Density (Compact 36px Height) | Dense list rows and data tables with multiple actions per row. | Hitbox requires padding invisible touch extensions to clear 44px HIG. |
| **Haptic Spring Pill (D)** | Interaction (`scale(0.97)` Bounce) | Primary commitments (`Accept Opportunity`, `Submit Proposal`). | Slightly delayed visual settlement if spring physics are overtuned. |
| **Specular Glass Pill (E)** | Expression (iOS 26+ Native Glass) | Floating actions on top of dynamic media and carousels. | Requires active contrast management against white background layers. |

---

### 3.5 Component 5: `StickyProposalBar`

| Variant | Axis Position | Right When | Costs |
| :--- | :--- | :--- | :--- |
| **Subterranean Ledger (A)** | Structure (Flat Grounded Dock) | Desktop views and long-form proposal composition flows. | Less prominent floating presence on small mobile viewports. |
| **Commitment Dock (B)** | Type (Placard Metric Hierarchy) | Contracts where compensation transparency is the deciding factor. | Height reaches 72px, reducing feed reading viewport. |
| **Dynamic Breakdown (C)** | Density (Interactive Fee Split) | Multi-milestone contracts with escrow calculation and platform fee breakdown. | Higher cognitive load before clicking proposal submission. |
| **Spring-Dock Expansion (D)** | Interaction (Expandable Sheet) | Progressive proposal submission starting with rate summary then expanding. | Two-step interaction required to complete commitment. |
| **Floating Glass Dock (E)** | Expression (Liquid Glass Floating) | Sticky mobile proposal trigger staying accessible at every scroll depth. | Covers bottom 64px of scrolling feed content without bottom padding spacer. |

---

### 3.6 Component 6: `CreatorProfileHero`

| Variant | Axis Position | Right When | Costs |
| :--- | :--- | :--- | :--- |
| **White Monograph (A)** | Structure (Quiet Gallery) | Elite design technologist portfolios with museum-grade imagery. | Minimal social proof upfront. |
| **Retrospective Catalog (B)** | Type (Artsy 3-Pillar Taxonomy) | Establishing verifiable historical credentials without cheap 5-star ratings. | Requires comprehensive profile data onboarding from freelancer. |
| **Talent Terminal (C)** | Density (Quantitative Track Record) | Financial engineering and algorithmic contract specialists. | Clinical appearance de-emphasizes creative visual design talent. |
| **Parallax Stage (D)** | Interaction (Fluid Scroll Exploration) | Interactive web design and creative technologist profiles. | Requires smooth 60fps/120fps scrolling hardware. |
| **Luminous Atelier (E)** | Expression (Liquid Glass Showcase) | Next-gen digital spatial creators and 3D visual artists. | Increased GPU shader usage. |
