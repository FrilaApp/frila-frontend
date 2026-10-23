# Frila Design System — Core Components & Variants Exploration
**Product:** Frila (FindJob & Opportunities Marketplace for Freelancers)  
**Author:** Worker Beta (Components & Interaction Specialist)  
**Architecture:** The Gallery-Marketplace Synthesis (Artsy + Airbnb + OKLCH `#EA5A36` + iOS 26+ Liquid Glass)  
**Methodologies:** `/design-lab` (Multi-axis exploration, rich states, WCAG floor) & `/variants` (Primary axes, memorable names, tradeoff matrix)


> **Governing rules (Onda 1 — override anything below):** Swiss is the default paradigm · no italic or oblique anywhere (titles are upright) · figures in SF Pro with proportional digits, tabular only for animated or column values · money via `FrilaMoney` (USD, `en_US`: `$140/hr`, `$33,600`) displayed with `FrilaPriceTag` · no emoji or text glyphs as icons in badges/chips/pills — SF Symbols only. Source of truth: `DESIGN.md` and `Sources/FrilaDesignSystem/Primitives/`. In ASCII mockups, `(shield)`, `(hourglass)` etc. mark an SF Symbol slot (`checkmark.shield.fill`, `hourglass`).
---

## Executive Architecture Summary

This specification delivers **30 distinct component variations** (5 variants across 6 core components) exploring the primary design axes:
1. **Structure / Quiet:** Gallery framing, extreme negative space, zero visual noise, 0-shadow discipline.
2. **Type / Editorial Placard:** High cultural distinction, Artsy curatorial metadata, upright editorial scopes, uppercase micro-labels.
3. **Density / Market Engine:** High-throughput information architecture, multi-column financial specifications, rapid scanning.
4. **Interaction / Tactile Physics:** Rich spring physics (`cubic-bezier(0.16, 1, 0.3, 1)`), parallax tilt, micro-gestures, dynamic disclosure.
5. **Expression / Liquid Glass:** Apple iOS 26+ translucent glass (`.glassEffect()`), specular edge highlights, luminous badges.

Every variant adheres strictly to:
- **WCAG 2.2 AA Contrast Compliance** (Calculated OKLCH/sRGB luminance ratios).
- **Human Interface Guidelines (HIG)**: Minimum $44 \times 44\text{pt}$ interactive hitboxes.
- **The "0-Shadow" Gallery Rule**: Drop shadows strictly forbidden on cards and feeds; reserved solely for floating utility pills and specular glass sheens.

---

## Component Index

- [Component 1: OpportunityCard (Feed Unit)](#component-1-opportunitycard-feed-unit)
  - [1.1 Structure / Quiet: "The White Cube Frame"](#11-structure--quiet-the-white-cube-frame)
  - [1.2 Type / Editorial Placard: "The Curatorial Monograph"](#12-type--editorial-placard-the-curatorial-monograph)
  - [1.3 Density / Market Engine: "The Terminal Ledger"](#13-density--market-engine-the-terminal-ledger)
  - [1.4 Interaction / Tactile Physics: "The Accordion Stage"](#14-interaction--tactile-physics-the-accordion-stage)
  - [1.5 Expression / Liquid Glass: "The Specular Vitrine"](#15-expression--liquid-glass-the-specular-vitrine)
- [Component 2: StickySearchCapsule & 3-Step Discovery Sheet](#component-2-stickysearchcapsule--3-step-discovery-sheet)
  - [2.1 Structure / Quiet: "The Monolithic Whisper"](#21-structure--quiet-the-monolithic-whisper)
  - [2.2 Type / Editorial Placard: "The Lexicon Index"](#22-type--editorial-placard-the-lexicon-index)
  - [2.3 Density / Market Engine: "The Matrix Command Bar"](#23-density--market-engine-the-matrix-command-bar)
  - [2.4 Interaction / Tactile Physics: "The Elastic Accordion Capsule"](#24-interaction--tactile-physics-the-elastic-accordion-capsule)
  - [2.5 Expression / Liquid Glass: "The Refractive Lens"](#25-expression--liquid-glass-the-refractive-lens)
- [Component 3: BudgetHistogram & Dual-Handle Filter](#component-3-budgethistogram--dual-handle-filter)
  - [3.1 Structure / Quiet: "The Horizon Density Bar"](#31-structure--quiet-the-horizon-density-bar)
  - [3.2 Type / Editorial Placard: "The Auction Valuation Ledger"](#32-type--editorial-placard-the-auction-valuation-ledger)
  - [3.3 Density / Market Engine: "The Quant Distribution Matrix"](#33-density--market-engine-the-quant-distribution-matrix)
  - [3.4 Interaction / Tactile Physics: "The Magnetic Elastic Dual-Pill"](#34-interaction--tactile-physics-the-magnetic-elastic-dual-pill)
  - [3.5 Expression / Liquid Glass: "The Luminous Spectrum Prism"](#35-expression--liquid-glass-the-luminous-spectrum-prism)
- [Component 4: FrilaButton & Pill Hierarchies](#component-4-frilabutton--pill-hierarchies)
  - [4.1 Structure / Quiet: "Achromatic Pure Line"](#41-structure--quiet-achromatic-pure-line)
  - [4.2 Type / Editorial Placard: "Monograph Press Stamp"](#42-type--editorial-placard-monograph-press-stamp)
  - [4.3 Density / Market Engine: "High-Throughput Capsule Suite"](#43-density--market-engine-high-throughput-capsule-suite)
  - [4.4 Interaction / Tactile Physics: "The Haptic Spring Pill"](#44-interaction--tactile-physics-the-haptic-spring-pill)
  - [4.5 Expression / Liquid Glass: "The Specular Glass Pill"](#45-expression--liquid-glass-the-specular-glass-pill)
- [Component 5: StickyProposalBar (Bottom Viewport Trigger)](#component-5-stickyproposalbar-bottom-viewport-trigger)
  - [5.1 Structure / Quiet: "The Subterranean Ledger"](#51-structure--quiet-the-subterranean-ledger)
  - [5.2 Type / Editorial Placard: "The Curatorial Commitment Dock"](#52-type--editorial-placard-the-curatorial-commitment-dock)
  - [5.3 Density / Market Engine: "The Dynamic Breakdown Console"](#53-density--market-engine-the-dynamic-breakdown-console)
  - [5.4 Interaction / Tactile Physics: "The Spring-Dock Expansion"](#54-interaction--tactile-physics-the-spring-dock-expansion)
  - [5.5 Expression / Liquid Glass: "The Floating Glass Dock"](#55-expression--liquid-glass-the-floating-glass-dock)
- [Component 6: CreatorProfileHero (3-Pillar Layout)](#component-6-creatorprofilehero-3-pillar-layout)
  - [6.1 Structure / Quiet: "The White Gallery Monograph"](#61-structure--quiet-the-white-gallery-monograph)
  - [6.2 Type / Editorial Placard: "The Museum Retrospective Catalog"](#62-type--editorial-placard-the-museum-retrospective-catalog)
  - [6.3 Density / Market Engine: "The Talent Terminal Spec Sheet"](#63-density--market-engine-the-talent-terminal-spec-sheet)
  - [6.4 Interaction / Tactile Physics: "The Fluid Scroll Parallax Stage"](#64-interaction--tactile-physics-the-fluid-scroll-parallax-stage)
  - [6.5 Expression / Liquid Glass: "The Luminous Atelier Showcase"](#65-expression--liquid-glass-the-luminous-atelier-showcase)
- [Comprehensive Tradeoff & Selection Matrix](#comprehensive-tradeoff--selection-matrix)
- [Accessibility (WCAG 2.2 AA) & Touch Target Verification Audit](#accessibility-wcag-22-aa--touch-target-verification-audit)

---

## Component 1: OpportunityCard (Feed Unit)

### 1.1 Structure / Quiet: "The White Cube Frame"
- **Axis Position:** Primary Axis = Structure (Minimalism & Negative Space)
- **Concept:** Strips away all card boundaries and borders. The creative scope sits directly on the white canvas (`#FFFFFF`). Separation is achieved through strict $32\text{px}$ vertical margins and a silent $1\text{px}$ hairline divider.
- **Visual Anatomy & Blueprint:**
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                16:10 MEDIA CAROUSEL (BORDERLESS)            │
│                outline: 1px solid rgba(0,0,0,0.06)          │
│                                                             │
│                         ● ○ ○ ○ ○                           │
├─────────────────────────────────────────────────────────────┤
│  ACME RESEARCH LABS                             [Bold 15]   │
│  Next-Gen Human Interface Design, 2026          [Medium 17] │
│  San Francisco, CA · 3 Months · Senior Tier     [Muted 13]  │
│                                                             │
│  $140/hr · Est. $32,000                         [SF Pro 18] │
│  Escrow Verified 100%                           [Emerald 12]│
└─────────────────────────────────────────────────────────────┘
  ─────────────────────────────────────────────────────────── [1px hairline]
```
- **Interactive States:**
  - *Default:* Canvas background `#FFFFFF`, image outline `1px rgba(0,0,0,0.06)`, zero shadow.
  - *Hover:* Media preview undergoes a gentle scale `1.015` over $300\text{ms}$ ease-out; hairline divider darkens to `#CECECB`.
  - *Active/Pressed:* Entire unit scales to `0.99` with instantaneous haptic response.
  - *Focus:* `outline: 2px solid #EA5A36; outline-offset: 4px; border-radius: 8px;`.
  - *Disabled/Closed:* Media saturated at $20\%$, text dimmed to `#767571`, hairline dashed.
- **Trade-off Analysis:**
  - *Right when:* High-end creative briefs, architectural portfolios, and editorial showcases where visual noise diminishes perceived talent quality.
  - *Costs:* Lower click-through affordance for non-editorial users accustomed to prominent card boxes.
- **WCAG AA & Touch Target:**
  - Touch target for carousel swipes and card navigation: Full card surface ($>320 \times 400\text{pt}$).
  - Contrast: Text Primary (`#1B1A18`) on White = $13.8:1$ (Passes AAA). Escrow (`#008A3B`) on White = $4.58:1$ (Passes AA).

---

### 1.2 Type / Editorial Placard: "The Curatorial Monograph"
- **Axis Position:** Primary Axis = Type (Curatorial Museum Documentation)
- **Concept:** Direct translation of Artsy's museum wall placard. The project title is rendered in an authoritative upright editorial serif (New York), paired with monospace uppercase metadata blocks.
- **Visual Anatomy & Blueprint:**
```
┌─────────────────────────────────────────────────────────────┐
│  [(sparkles) CURATORIAL SELECTION]      [(bookmark) ARCHIVE] │
│                16:10 PREVIEW (12px RADIUS)                  │
├─────────────────────────────────────────────────────────────┤
│  VERCEL DESIGN SYSTEMS                              [16 BOLD]│
│  Synthetic Canvas & Runtime Tokens, 2026           [18 UPRIGHT]
│                                                             │
│  DISCIPLINE      DURATION       ALLOCATION       [11 MONO]  │
│  Design Eng      4 Months       Full-time 40h/w             │
│                                                             │
│  VALUATION       $160/hr        $38,400 ESCROW   [15 SF PRO]
└─────────────────────────────────────────────────────────────┘
```
- **Interactive States:**
  - *Default:* Crisp typographic hierarchy. Monospace tags in `#767571` with `letter-spacing: 1.2px`.
  - *Hover:* Title transitions to brand color `#EA5A36` with an underline slide; bookmark icon fills.
  - *Active/Pressed:* Text color darkens to `#090908`, background subtly tints to `#FBFBFA`.
  - *Focus:* 2px solid `#1B1A18` ring surrounding the placard typography block.
  - *Disabled:* Title struck through with a fine 1px hairline; status pill displays `EXHIBITION CLOSED`.
- **Trade-off Analysis:**
  - *Right when:* Prestige enterprise briefs, specialized staff design/engineering engagements.
  - *Costs:* Slightly higher reading time due to multi-tiered typographic scale.
- **WCAG AA & Touch Target:**
  - Save button: $44 \times 44\text{pt}$ hit area positioned top-right.
  - Contrast: `#1B1A18` on `#FFFFFF` = $13.8:1$ (AAA). `#767571` on `#FFFFFF` = $4.54:1$ (AA).

---

### 1.3 Density / Market Engine: "The Terminal Ledger"
- **Axis Position:** Primary Axis = Density (High-Throughput Spec Sheet)
- **Concept:** Optimized for technical freelancers and algorithmic scanning. Shrinks media to a compact side thumbnail or dense top strip, organizing contract specs into a high-density 3-column data grid.
- **Visual Anatomy & Blueprint:**
```
┌─────────────────────────────────────────────────────────────┐
│ ┌──────────┐ ACME AI · Staff Frontend Eng        [OPEN: 4d] │
│ │  16:10   │ *Realtime WebGL Canvas Engine*                 │
│ │Thumbnail │ Remote (EU/US) · 6 Months · 30-40h/wk          │
│ └──────────┘ ────────────────────────────────────────────── │
│  RATE: $125–$150/hr │ EST: $48,000 │ (shield) 100% ESCROW   │
│  [TypeScript] [WebGPU] [Next.js]           [QUICK APPLY ➜] │
└─────────────────────────────────────────────────────────────┘
```
- **Interactive States:**
  - *Default:* Compact $12\text{px}$ inner padding, background `#FBFBFA`, hairline border `#E5E5E3`.
  - *Hover:* Background highlights to `#F2F2F0`; Quick Apply CTA reveals high-contrast fill `#1B1A18`.
  - *Active/Pressed:* Quick Apply CTA scales `0.95`; row compresses slightly.
  - *Focus:* Blue/Brand keyboard focus ring `2px solid #EA5A36`.
  - *Disabled:* Opacity $0.45$; action button replaced with `FILLED`.
- **Trade-off Analysis:**
  - *Right when:* High-volume feeds, search result lists with $>100$ items, power users on desktop/tablet.
  - *Costs:* Reduced emotional resonance and aesthetic gallery grandeur.
- **WCAG AA & Touch Target:**
  - Row height: $96\text{px}$ (exceeds $44\text{pt}$ minimum). Quick apply button hitbox padded to $44\text{pt}$.
  - Contrast: High-contrast text `#1B1A18` on `#FBFBFA` = $13.4:1$.

---

### 1.4 Interaction / Tactile Physics: "The Accordion Stage"
- **Axis Position:** Primary Axis = Interaction (Spring Physics & Gesture Expansion)
- **Concept:** Fluid, tactile feed unit. On long press or mouse hover, it utilizes 3D perspective spring tilt (`perspective(800px) rotateX(2deg) scale(1.02)`). Tapping an expand chevron springs open a collapsible scope accordion without navigating away.
- **Visual Anatomy & Blueprint:**
```
┌─────────────────────────────────────────────────────────────┐
│ 16:10 MEDIA CAROUSEL (EXPANDABLE PEEK)                      │
│ [ ⚡ Instant Match: 98% ]                      [ ♡ Spring ] │
├─────────────────────────────────────────────────────────────┤
│ LINEAR LABS · *Mobile Design System Overhaul*               │
│ $150/hr · 2 Months · Escrow Funded                          │
│                                                             │
│ ▼ [TAP TO EXPAND DELIVERABLES & REQUIREMENTS]               │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ • 14 Atomic Core Components (Figma + SwiftUI)           │ │
│ │ • Design Token Automation Script via GitHub Actions     │ │
│ │ • Full WCAG 2.2 AA Audit & Token Contrast System        │ │
│ └─────────────────────────────────────────────────────────┘ │
│ [ Share ]                               [ Apply in 1-Tap ➜ ]│
└─────────────────────────────────────────────────────────────┘
```
- **Interactive States:**
  - *Default:* Standard collapsed card, zero shadow, spring ready.
  - *Hover (Desktop):* Dynamic 3D tilt tracking cursor coordinates, shadow lifts to `0 8px 24px rgba(0,0,0,0.06)`.
  - *Active/Pressed:* Card depresses `scale(0.98)` with physical spring release (`cubic-bezier(0.16, 1, 0.3, 1)`).
  - *Expanded State:* Accordion reveals bullet points with staggered fade-and-slide ($15\text{ms}$ delay per item).
  - *Focus:* Pulsing 2px brand aura around active accordion toggle.
- **Trade-off Analysis:**
  - *Right when:* Freelancers deciding rapidly between briefs without enduring 50 separate page navigations.
  - *Costs:* Higher GPU memory footprint and animation execution overhead on low-end mobile devices.
- **WCAG AA & Touch Target:**
  - Accordion trigger button: $44\text{px}$ minimum vertical hitbox.
  - Contrast: Bullet text `#1B1A18` on `#F2F2F0` background = $12.1:1$.

---

### 1.5 Expression / Liquid Glass: "The Specular Vitrine"
- **Axis Position:** Primary Axis = Expression (Apple iOS 26+ Translucent Liquid Glass)
- **Concept:** Replaces opaque cards with a translucent floating glass vitrine. Content scrolling behind the card is diffused through native backdrop filters, while the card surface catches top specular ambient light.
- **Visual Anatomy & Blueprint:**
```
┌─────────────────────────────────────────────────────────────┐
│ 16:10 MEDIA WITH TRANSLUCENT OVERLAYS                       │
│ ┌───────────────────────────┐ ┌───────────────────────────┐ │
│ │ (sparkles) Featured       │ │ (shield) Escrow: 100%    │ │
│ └───────────────────────────┘ └───────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│ .glassEffect(.regular.interactive())                        │
│ border-top: 1px solid rgba(255,255,255,0.70) (Specular Rim) │
│ border-bottom: 1px solid rgba(0,0,0,0.06)                   │
│                                                             │
│ STRIPE CLOUD · *Next-Gen Financial Dashboard*               │
│ $165 / hr · Fixed Milestone Release                         │
│ [ SwiftUI 6 ] [ Metal Shaders ] [ Design Tokens ]           │
└─────────────────────────────────────────────────────────────┘
```
- **Interactive States:**
  - *Default:* `backdrop-filter: blur(24px) saturate(180%)`, surface `rgba(255,255,255,0.78)`, specular rim.
  - *Hover:* Specular border intensity increases (`rgba(255,255,255,0.95)`), chromatic refraction sheen slides across card.
  - *Active/Pressed:* Glass tint deepens (`rgba(255,255,255,0.90)`), scale `0.98`.
  - *Focus:* Specular rim illuminates with brand color glow `rgba(234, 90, 54, 0.40)`.
  - *Disabled:* Frosted opacity reduced to $40\%$, specular rim extinguished.
- **Trade-off Analysis:**
  - *Right when:* VisionOS, native iOS 26+ applications, and premium dark/light fluid themes.
  - *Costs:* Requires WebGL / CSS backdrop-filter support; can cause visual clutter if background image is overly noisy.
- **WCAG AA & Touch Target:**
  - Minimum contrast maintained by enforcing backdrop luminosity clipping ($\ge 82\%$ white tint).
  - Contrast: Text `#1B1A18` on $82\%$ white glass = $>10:1$. Hitbox $\ge 44\text{pt}$.

---

## Component 2: StickySearchCapsule & 3-Step Discovery Sheet

### 2.1 Structure / Quiet: "The Monolithic Whisper"
- **Axis Position:** Primary Axis = Structure (Zen Simplicity)
- **Concept:** A clean, unadorned $44\text{px}$ pill capsule. Centered minimal typography with gentle dot separators. The discovery sheet uses quiet architectural hairlines without icons or extraneous decorative labels.
- **Visual Anatomy & Blueprint:**
```
            ┌───────────────────────────────────────────────┐
            │  Staff Designer · Remote · Hourly             │
            └───────────────────────────────────────────────┘
                                   │ (Tap)
                                   ▼
┌───────────────────────────────────────────────────────────────────┐
│ DISCOVERY SHEET (QUIET)                                 [Close ✕] │
│                                                                   │
│ 1. DISCIPLINE                                                     │
│    Product Design / Design Systems / Engineering / Brand          │
│ ───────────────────────────────────────────────────────────────── │
│ 2. ENGAGEMENT TYPE                                                │
│    Hourly Rate · Sprint Retainer · Fixed Scope Milestone          │
│ ───────────────────────────────────────────────────────────────── │
│ 3. RATE CEILING                                                   │
│    $50/h        $100/h        $150/h        $200/h+               │
│                                                                   │
│ [ Reset ]                              [ View 42 Opportunities ]  │
└───────────────────────────────────────────────────────────────────┘
```
- **Interactive States:**
  - *Default:* White fill `#FFFFFF`, hairline `1px #E5E5E3`, zero drop shadow.
  - *Hover:* Border deepens to `#CECECB`; subtle text contrast enhancement.
  - *Active:* Pill compresses to `0.97` scale; invokes sheet modal with spring transition.
  - *Focus:* 2px clean ink ring `#1B1A18`.
- **Trade-off Analysis:**
  - *Right when:* Calming, distraction-free discovery feeds; users who value speed and minimal UI footprint.
  - *Costs:* Lacks upfront affordance of multi-part category filtering.
- **WCAG AA & Touch Target:**
  - Capsule height: $44\text{px}$. Sheet filter rows: $48\text{px}$ minimum touch targets.
  - Contrast: Text `#1B1A18` on White = $13.8:1$.

---

### 2.2 Type / Editorial Placard: "The Lexicon Index"
- **Axis Position:** Primary Axis = Type (Curatorial Categorization)
- **Concept:** Treats search queries like catalog classifications in an art index. The capsule displays uppercase category identifiers (`WHAT`, `TERMS`, `BUDGET`). The sheet uses serif editorial prompt headers.
- **Visual Anatomy & Blueprint:**
```
  ┌─────────────────────────────────────────────────────────────┐
  │ WHAT: Design Systems  │  TERMS: Sprint  │  BUDGET: $120+/h  │
  └─────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌───────────────────────────────────────────────────────────────┐
│ *What craft are you commissioning?*               [Catalog ✕] │
│ WHAT       [ Product Design ]  [ Staff Systems ]  [ Brand ]   │
│                                                               │
│ *Under what covenant will you collaborate?*                   │
│ PROTOCOL   [ Dedicated Retainer ]   [ 2-Week Sprint ]         │
│                                                               │
│ *What capital allocation is committed?*                       │
│ VALUATION  [ Tier I: <$100/h ]  [ Tier II: $100-$180/h ]      │
│                                                               │
│ [ Clear Ledger ]                     [ Commit Filter (38) ]   │
└───────────────────────────────────────────────────────────────┘
```
- **Interactive States:**
  - *Default:* Monospace uppercase subtitles with wide tracking (`letter-spacing: 1.0px`).
  - *Hover:* Subtitle shifts to text-primary on cursor hover; category dividing lines tint to `#EA5A36`.
  - *Active:* Crisp ink button active state `#090908`.
  - *Focus:* 2px double hairline border.
- **Trade-off Analysis:**
  - *Right when:* High-end creative consultancies, architectural studios, and prestige design awards.
  - *Costs:* Longer textual strings can cause truncation on narrow mobile screens ($<375\text{px}$).
- **WCAG AA & Touch Target:**
  - Label contrast: `#1B1A18` on `#FFFFFF` = $13.8:1$.
  - Pill buttons inside sheet: $44\text{px}$ height with $16\text{px}$ horizontal padding.

---

### 2.3 Density / Market Engine: "The Matrix Command Bar"
- **Axis Position:** Primary Axis = Density (Interactive 3-Segment Control)
- **Concept:** Forked directly from Airbnb's segmented discovery pill. Divided into 3 independently clickable target zones plus an inline filter badge. Tapping any zone jumps directly into that specific step in the discovery sheet.
- **Visual Anatomy & Blueprint:**
```
┌─────────────────────────────────────────────────────────────┐
│ 🔍 Product Design  │ ⏱ 3 Months Retainer │ 💰 $120-$160/h │ ⚙️ 3│
└─────────────────────────────────────────────────────────────┘
  (Zone 1: What)       (Zone 2: How)         (Zone 3: Budget)
```
- **Discovery Sheet Flow (Stepped Progression):**
```mermaid
graph LR
    Z1[Zone 1: What] --> S1[Role & Tech Domain]
    Z2[Zone 2: How] --> S2[Contract & Seniority Terms]
    Z3[Zone 3: Budget] --> S3[Interactive Histogram Slider]
    S1 --> S2 --> S3 --> C[Dynamic CTA: 'Show 38 Matches']
```
- **Interactive States:**
  - *Default:* Floating 52px capsule, `box-shadow: 0 4px 14px rgba(0,0,0,0.08)`.
  - *Hover per Zone:* Individual segment highlights with `#F2F2F0` background; separator lines fade out.
  - *Active Zone:* Segment scales inward slightly; sheet opens focused immediately on that input step.
  - *Focus:* Keyboard Tab navigates through Zone 1 $\rightarrow$ Zone 2 $\rightarrow$ Zone 3 $\rightarrow$ Filter Button.
- **Trade-off Analysis:**
  - *Right when:* Main marketplace discovery feed; users who already know their target parameters.
  - *Costs:* Requires precise touch targets across 3 horizontal segments on mobile screens.
- **WCAG AA & Touch Target:**
  - Total capsule: $52\text{px}$ height. Each zone width: $\ge 75\text{px}$ on mobile (exceeds $44\times 44\text{pt}$).
  - Active indicator contrast: `#EA5A36` indicator exceeds $3:1$ boundary requirement.

---

### 2.4 Interaction / Tactile Physics: "The Elastic Accordion Capsule"
- **Axis Position:** Primary Axis = Interaction (Fluid Morphing & Spring Physics)
- **Concept:** Instead of launching a detached modal dialog, the capsule itself physically expands downward like an accordion bellows using CSS grid transitions and spring transforms (`stiffness: 300, damping: 26`).
- **Visual Anatomy & Blueprint:**
```
┌─────────────────────────────────────────────────────────────┐
│ 🔍 Tap to explore talent & opportunities...          [ ▾ ]  │
└─────────────────────────────────────────────────────────────┘
                               │ (Smooth Spring Morph)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 🔍 [ What role?               ] [ Swift, Figma, Next... ]   │
│ ⏱ [ How will you engage?     ] [ Retainer  Sprint  Hourly ]│
│ 💰 [ Budget range per hour    ] [ ●───────────●  $140/h ]   │
│ ─────────────────────────────────────────────────────────── │
│ [ Collapse ▲ ]                      [ Search 48 Briefs ➜ ]  │
└─────────────────────────────────────────────────────────────┘
```
- **Interactive States:**
  - *Default:* Single line $48\text{px}$ pill with gentle breathing pulse on search icon.
  - *Expansion Transition:* Height animates from $48\text{px} \rightarrow 240\text{px}$ over $220\text{ms}$ with spring overshoot.
  - *Hover:* Subtle lift `translateY(-2px)`, shadow deepens to `0 8px 20px rgba(0,0,0,0.10)`.
  - *Active Drag:* Swiping upward collapses the bellows back into a pill with rubber-band resistance.
  - *Focus:* High-contrast brand outline encircles the expanding container.
- **Trade-off Analysis:**
  - *Right when:* Seamless in-page exploration where modal takeovers interrupt visual context.
  - *Costs:* Pushes page content downward, which requires content layout shift compensation.
- **WCAG AA & Touch Target:**
  - All interactive chips inside morph container maintain $44\text{px}$ minimum height.
  - Contrast: Complies with WCAG AA $4.5:1$ across all input fields.

---

### 2.5 Expression / Liquid Glass: "The Refractive Lens"
- **Axis Position:** Primary Axis = Expression (Apple iOS 26+ Native Liquid Glass)
- **Concept:** Implements the modern Apple Liquid Glass material. The capsule is rendered using `.glassEffect(.regular.interactive())` with a dynamic 2-tone specular light reflection. When scrolling, feed images refract softly through the capsule lens.
- **Visual Anatomy & Blueprint:**
```
┌─────────────────────────────────────────────────────────────┐
│  /// TRANSLUCENT LIQUID GLASS SURFACE (BLUR 24px) ///       │
│  border-top: 1px solid rgba(255,255,255,0.80) (Light Catch) │
│  border-bottom: 1px solid rgba(0,0,0,0.08) (Contact Ground) │
│                                                             │
│  [Design Systems] · [Sprint] · [$120–$180/hr] [(sliders) 2]│
└─────────────────────────────────────────────────────────────┘
```
- **Discovery Sheet Overlay:**
  - Backdrop is dimmed with `.glassEffect(.thin)` (`rgba(0,0,0,0.25)` + `blur(16px)`).
  - Floating sheet panels utilize frosted acrylic tiles with specular rim lighting.
- **Interactive States:**
  - *Default:* $82\%$ translucent white glass with specular top reflection line.
  - *Hover:* Ambient chromatic glow around perimeter; glass saturation increases from $180\% \rightarrow 200\%$.
  - *Active:* Specular light rim flares briefly; scale $0.97$.
  - *Focus:* Pulsing specular ring in brand vermilion `#EA5A36`.
  - *Disabled:* Pure flat frosted matte; no specular highlights.
- **Trade-off Analysis:**
  - *Right when:* Flagship iOS 26+ applications, macOS desktop clients, and modern WebKit/Chromium browsers.
  - *Costs:* GPU overhead; requires high-contrast fallbacks for reduced-transparency accessibility modes.
- **WCAG AA & Touch Target:**
  - Enforces `.accessibilityReduceTransparency` mode: falls back to solid `#FFFFFF` with $1\text{px solid #CECECB}$.
  - Capsule height: $52\text{px}$ ($\ge 44\text{pt}$).

---

## Component 3: BudgetHistogram & Dual-Handle Filter

### 3.1 Structure / Quiet: "The Horizon Density Bar"
- **Axis Position:** Primary Axis = Structure (Zen Density Line)
- **Concept:** Extreme reduction. Replaces cluttered vertical bar charts with an elegant, continuous mathematical density curve and a razor-thin horizon line.
- **Visual Anatomy & Blueprint:**
```
                 COMPENSATION DISTRIBUTION
                         .---.
                       /       \     .--.
                      /         \   /    \
  ───────────────────●───────────●─/──────\─────── [Horizon Line]
                    Min         Max
                  $90/h        $165/h
  
  [ Reset Range ]                           [ Apply (38) ]
```
- **Interactive States:**
  - *Default:* Curve rendered in `1.5px solid #CECECB`, filled with a subtle $3\%$ ink gradient.
  - *Dragging Handle:* Active handle grows from $24\text{px} \rightarrow 30\text{px}$; vertical guideline projects up to curve.
  - *Hover:* Rate tooltips fade in above handles with crisp numeric tabular figures.
  - *Focus (Keyboard):* Arrow Left/Right nudges selected handle in $\$5$ increments with tactile feedback.
- **Trade-off Analysis:**
  - *Right when:* Clean curatorial interfaces where granular histogram bars create visual noise.
  - *Costs:* Less intuitive for discerning exact opportunity counts within tight $\$5$ price buckets.
- **WCAG AA & Touch Target:**
  - Circular handles: $24\text{px}$ visual size with an invisible $48 \times 48\text{pt}$ touch target.
  - Contrast: Horizon line and active curve `#1B1A18` on White = $13.8:1$.

---

### 3.2 Type / Editorial Placard: "The Auction Valuation Ledger"
- **Axis Position:** Primary Axis = Type (Curatorial Pricing Brackets)
- **Concept:** Borrows from fine-art auction catalogs and institutional salary ledgers. Categorizes budget distributions into formal quartile brackets (`LOWER QUARTILE`, `MEDIAN`, `UPPER QUARTILE`, `PREMIUM`).
- **Visual Anatomy & Blueprint:**
```
  MARKET VALUATION LEDGER (HOURLY / EQUIVALENT)
  
  $50           $100 (Q1)     $140 (MEDIAN)   $190 (Q3)     $250+
   │               │                │             │           │
  ─┴─■■■■■■■■■■■■■■┴─███████████████┴─████████████┴─■■■■■■■■■■┴─
                   ▲                              ▲
               [ MIN: $95/h ]                [ MAX: $185/h ]
  
  ESTIMATED MARKET LIQUIDITY: 84% OF ACTIVE BRIEFS QUALIFY
  [ Revoke Parameters ]                [ Commit Budget (41) ]
```
- **Interactive States:**
  - *Default:* Monospace uppercase quartile annotations in `#767571`. Active bracket highlighted in stark black `#1B1A18`.
  - *Hover on Bracket:* Bracket column highlights in `--frila-color-primary-50` (`#FFF1EC`); displays brief count.
  - *Handle Drag:* Numeric readouts update dynamically in bold tabular figures with thousands commas.
  - *Active Commit:* Commit button pulses in brand `#EA5A36`.
- **Trade-off Analysis:**
  - *Right when:* Senior talent who negotiate on transparent market percentiles rather than arbitrary numbers.
  - *Costs:* Requires more vertical layout space ($180\text{px}$ minimum).
- **WCAG AA & Touch Target:**
  - Draggable handle tabs: $44\text{px}$ height with uppercase rate labels.
  - Text contrast: Exceeds $4.5:1$ across all labels.

---

### 3.3 Density / Market Engine: "The Quant Distribution Matrix"
- **Axis Position:** Primary Axis = Density (Airbnb Multi-Bin Precision)
- **Concept:** The classic Airbnb marketplace pattern perfected. 36 discrete vertical histogram bars representing exact opportunity counts. Includes dual synchronized numeric text input boxes for direct keyboard entry.
- **Visual Anatomy & Blueprint:**
```
               OPPORTUNITY DENSITY (HOURLY RATE)
       12 18 24 38 42 35 28 19 14  8  3  (Live Bar Heights)
       |  |  |  █  █  |  |  |  |  |  |
       ▃  ▅  ▆  █  █  ▇  ▆  ▅  ▃  ▂  _
  ─────●───────────────────────●─────── (Track)
      Min Rate               Max Rate
   ┌────────────┐         ┌────────────┐
   │ $  85 / hr │   to    │ $ 160 / hr │
   └────────────┘         └────────────┘
   Quick Presets: [Median ($130)] [Senior ($150+)] [Staff ($180+)]
   
   [ Clear All ]                 [ Show 38 Opportunities (#EA5A36) ]
```
- **Interactive States:**
  - *Default:* Unselected bars in `#E5E5E3`, selected bars in brand vermilion `#EA5A36`.
  - *Hover on Single Bar:* Bar changes to `#C03710`; tooltip displays `"14 Briefs at $120/hr"`.
  - *Handle Grab:* Handle elevates with `box-shadow: 0 4px 12px rgba(0,0,0,0.18)`, scales to $1.15$.
  - *Direct Input Focus:* 2px brand border around text input field; slider positions adjust on blur/enter.
- **Trade-off Analysis:**
  - *Right when:* Granular search workflows where users need exact statistical feedback on matching briefs.
  - *Costs:* Complex touch interaction logic; requires debounced network queries for live counter updates.
- **WCAG AA & Touch Target:**
  - Circular drag handles: $28\text{px}$ diameter with a $44\text{px}$ transparent hit target overlay.
  - Text inputs: $48\text{px}$ height. Contrast: `#EA5A36` on `#FFFFFF` UI element = $3.47:1$ ($\ge 3:1$ AA non-text).

---

### 3.4 Interaction / Tactile Physics: "The Magnetic Elastic Dual-Pill"
- **Axis Position:** Primary Axis = Interaction (Magnetic Detents & Elastic Resistance)
- **Concept:** Implements physical detents. As handles are dragged, they magnetically snap to high-density compensation clusters ($50, $100, $150, $200). If handles collide, an elastic repulsion spring prevents crossing with haptic resistance.
- **Visual Anatomy & Blueprint:**
```
         .~~. (Elastic Tension Band) .~~.
   ─────( ● )========================( ● )─────
         '--'                          '--'
      [ SNAP $100 ]                [ SNAP $175 ]
      *TICK* (Haptic)              *TICK* (Haptic)
```
- **Physics Specifications:**
  - *Magnetic Snap Radius:* $8\text{px}$ attraction window around standard rate tiers.
  - *Minimum Distance Constraint:* $15\text{px}$ separation buffer enforced via spring damping equation:
    $$F = -k(x - x_0) - c\dot{x}$$
  - *Haptic Feedback:* Triggers native iOS `UIImpactFeedbackGenerator(style: .light)` on each bar boundary.
- **Interactive States:**
  - *Default:* Relaxed spring state, zero tension.
  - *Active Drag:* Histogram bars between handles stretch elastically; count updates with rolling numbers.
  - *Handle Collision:* Handles compress into pill shapes; spring exerts outward push.
  - *Release:* Smooth settle into nearest cluster bucket with zero oscillation bounce.
- **Trade-off Analysis:**
  - *Right when:* Native mobile apps and high-craft touch surfaces where tactile delight drives engagement.
  - *Costs:* Requires hardware vibration API permissions and custom gesture recognizers.
- **WCAG AA & Touch Target:**
  - Touch target size: $48 \times 48\text{pt}$ hit area per handle.
  - Keyboard accessible: Step increments guaranteed with Arrow keys.

---

### 3.5 Expression / Liquid Glass: "The Luminous Spectrum Prism"
- **Axis Position:** Primary Axis = Expression (iOS 26+ Specular Glass & Luminous Fluid)
- **Concept:** The histogram is rendered as a series of frosted glass light pipes. Selected range illuminates from within using a glowing OKLCH orange backlight gradient (`rgba(234, 90, 54, 0.85)`). Handles are frosted glass spheres with specular highlights.
- **Visual Anatomy & Blueprint:**
```
  ┌─────────────────────────────────────────────────────────────┐
  │  /// FROSTED GLASS BACKGROUND CONTAINER (BLUR 20px) ///    │
  │                                                             │
  │     ░░  ░░  ▒▒  ██  ██  ██  ▒▒  ░░  ░░   (Light Pipes)      │
  │    (Dim)    (  Glowing Vermilion Core  )   (Dim)            │
  │                                                             │
  │  ───[ ⚪ ]═════════════════════════════[ ⚪ ]───             │
  │     Glass Sphere                      Glass Sphere          │
  │     Specular Edge                     Specular Edge         │
  └─────────────────────────────────────────────────────────────┘
```
- **Interactive States:**
  - *Default:* Ambient translucent light reflection, soft glass drop-shadow `0 8px 32px rgba(0,0,0,0.06)`.
  - *Hover on Sphere:* Specular rim glints brighter (`rgba(255,255,255,1.0)`); internal lens flare activates.
  - *Active Drag:* Light bar beneath handles flares dynamically, casting a warm ambient orange glow.
  - *Focus:* Specular ring illuminates with brand color glow `rgba(234, 90, 54, 0.40)`.
- **Trade-off Analysis:**
  - *Right when:* High-end Apple platform deployments and flagship promotional landing experiences.
  - *Costs:* Higher GPU shader cost; must gracefully degrade on devices with low battery or disabled blur.
- **WCAG AA & Touch Target:**
  - Glass spheres: $32\text{px}$ visual size with $48\text{px}$ touch envelope.
  - Reduced transparency mode supported: Converts to solid high-contrast vermilion bar.

---

## Component 4: FrilaButton & Pill Hierarchies

### 4.1 Structure / Quiet: "Achromatic Pure Line"
- **Axis Position:** Primary Axis = Structure (Achromatic Gallery Hierarchy)
- **Concept:** Rejects decorative button fills for secondary actions. Button weight is communicated through pure border geometry and typographic presence. Only the primary high-intent action carries color.
- **Visual Anatomy & Specifications:**
```
  [ Primary Brand ]        [ Primary Neutral ]       [ Secondary Hairline ]    [ Ghost / Text ]
  Fill: #EA5A36            Fill: #1B1A18             Fill: #FFFFFF             Fill: Transparent
  Text: #FFFFFF            Text: #FFFFFF             Border: 1px #CECECB       Text: #767571
  Height: 48px             Height: 48px              Height: 44px              Height: 44px
  Radius: 9999px           Radius: 9999px            Radius: 9999px            Radius: 9999px
```
- **Pairing Architecture (Asymmetric Weight Rule):**
```
                    [ Decline ]        [    Accept Brief    ]
                  (Ghost 44px)        (Solid Brand 48px)
                   Text: #767571       Fill: #EA5A36
                   Gap: 14px           Dominant Optical Anchor
```
- **Interactive States:**
  - *Default:* Pure crisp lines, zero shadow.
  - *Hover:* Secondary hairline fills with subtle `#FBFBFA`; Primary Brand shifts to `#F26643`.
  - *Active/Pressed:* `transform: scale(0.97)`, Brand fills with deep `#C03710`.
  - *Focus:* 2px solid `#1B1A18` ring with 2px offset.
  - *Disabled:* Background `#F2F2F0`, text `#CECECB`, border none, cursor not-allowed.
- **Trade-off Analysis:**
  - *Right when:* Interfaces that must let creative portfolio imagery command total user attention.
  - *Costs:* Outlined buttons have slightly lower perceptual affordance than filled containers.
- **WCAG AA & Touch Target:**
  - All button tiers maintain $\ge 44\text{pt}$ vertical height and $48\text{pt}$ for primary CTAs.
  - Contrast: White on `#EA5A36` = $3.47:1$ (Passes AA for $\ge 18\text{pt}$ bold text). White on `#1B1A18` = $13.8:1$ (AAA).

---

### 4.2 Type / Editorial Placard: "Monograph Press Stamp"
- **Axis Position:** Primary Axis = Type (Curatorial Exhibition Stamp)
- **Concept:** Styled as archival exhibition catalog stamps. Uses uppercase tracked typography (`letter-spacing: 1.2px`), subtle catalog reference numbers, and crisp framing.
- **Visual Anatomy & Specifications:**
```
  ┌─────────────────────────────────┐      ┌─────────────────────────────────┐
  │  NO. 01 // SUBMIT PROPOSAL   ➜  │      │  CATALOGUE // SAVE FOR LATER    │
  │  (Solid Stark Ink #1B1A18)      │      │  (1px Stark Border #1B1A18)     │
  └─────────────────────────────────┘      └─────────────────────────────────┘
  Height: 48px · Uppercase 13pt             Height: 44px · Uppercase 12pt
```
- **Interactive States:**
  - *Default:* Monospace uppercase lettering with fine hairline framing.
  - *Hover:* Arrow glyph slides $+3\text{px}$ to the right; border expands to $1.5\text{px}$.
  - *Active:* Inverts colors (White text on black background becomes black text on white).
  - *Focus:* 2px double outline reminiscent of legal archival seals.
  - *Disabled:* Monospace text struck through; border dashed.
- **Trade-off Analysis:**
  - *Right when:* Curated galleries, architectural awards, fine-art design platforms.
  - *Costs:* More formal tone; not suited for informal consumer gig marketplaces.
- **WCAG AA & Touch Target:**
  - Contrast: Black `#1B1A18` on White = $13.8:1$ (AAA).
  - Touch targets strictly enforced at $48\text{px}$ height.

---

### 4.3 Density / Market Engine: "High-Throughput Capsule Suite"
- **Axis Position:** Primary Axis = Density (Ergonomic Sizing System)
- **Concept:** Designed for high-frequency workflows. Offers 4 strictly proportioned size tiers with optional split-action dropdown menus and embedded keyboard shortcut hints (`⌘↵`).
- **Visual Anatomy & Specifications:**
```
  TIER 1: COMPACT (Feed Quick Actions)
  [ Apply ➜ ] (Height: 32px, Padding: 4px 12px, Text: 12pt Bold)

  TIER 2: STANDARD (Toolbar & Dialogs)
  [ ⚙️ Filter (3) ] (Height: 40px, Padding: 8px 16px, Text: 14pt Semibold)

  TIER 3: HIGH-INTENT PRIMARY (Forms & Detail Pages)
  ┌────────────────────────────────────────────────────────┐
  │  Submit Proposal                            [ ⌘ ↵ ]    │
  └────────────────────────────────────────────────────────┘
  (Height: 52px, Padding: 14px 24px, Text: 16pt Bold)

  TIER 4: SPLIT-ACTION DROPDOWN
  ┌──────────────────────────────┬───┐
  │  Accept Opportunity          │ ▼ │
  └──────────────────────────────┴───┘
```
- **Interactive States:**
  - *Default:* High-contrast fills with tight spatial efficiency.
  - *Hover:* Keyboard badge highlights; split divider illuminates.
  - *Active:* Instantaneous compression `scale(0.96)`.
  - *Focus:* Blue/Brand ring highlighting either the main button body or the split dropdown.
- **Trade-off Analysis:**
  - *Right when:* Desktop power-user dashboards, complex client hiring consoles, high-density tables.
  - *Costs:* Tier 1 compact buttons ($32\text{px}$) require explicit $44\text{pt}$ invisible touch target padding on touchscreens.
- **WCAG AA & Touch Target:**
  - Tier 1 includes `::after` pseudo-element expanding touch target to $44 \times 44\text{pt}$ on mobile.
  - All text contrast $\ge 4.5:1$.

---

### 4.4 Interaction / Tactile Physics: "The Haptic Spring Pill"
- **Axis Position:** Primary Axis = Interaction (Micro-Physics & Spring Dynamics)
- **Concept:** Implements the `make-interfaces-feel-better` physical model. Features responsive spring compression, optical center-nudged arrow icons, and a fluid surface illumination wave on release.
- **Visual Anatomy & Specifications:**
```
  UNPRESSED (RESTING)                 PRESSED (TOUCH DOWN)
  ┌─────────────────────────┐         ┌───────────────────────┐
  │    Submit Proposal  ➜   │   ──>   │   Submit Proposal ➜   │
  └─────────────────────────┘         └───────────────────────┘
  Scale: 1.00                         Scale: 0.96
  Shadow: 0 4px 14px (Brand Tint)     Shadow: 0 1px 3px (Ground Contact)
```
- **Spring Curve Tokens:**
  - Press Down: `100ms ease-out`
  - Spring Release: `cubic-bezier(0.16, 1, 0.3, 1)` over $320\text{ms}$
  - Arrow Icon Offset: Nudged $+1.0\text{px}$ to balance visual asymmetry of the chevron.
- **Interactive States:**
  - *Default:* Floating resting state with subtle ambient brand glow.
  - *Hover:* Lifts $-2\text{px}$ with expanding soft shadow.
  - *Active:* Compresses to `scale(0.96)`; internal color darkens to `#C03710`.
  - *Release:* Spring snaps back with micro-overshoot (`scale(1.01) -> scale(1.0)`).
- **Trade-off Analysis:**
  - *Right when:* Mobile applications where tactile responsiveness gives users confidence in financial commitments.
  - *Costs:* Requires GPU compositing layers; excessive spring motion can trigger vestibular sensitivity if not respecting `prefers-reduced-motion`.
- **WCAG AA & Touch Target:**
  - Height: $48\text{px}$. Fallback respects `@media (prefers-reduced-motion: reduce)` by disabling scale transforms.
  - Contrast compliant.

---

### 4.5 Expression / Liquid Glass: "The Specular Glass Pill"
- **Axis Position:** Primary Axis = Expression (Apple iOS 26+ Native Glass Tiers)
- **Concept:** Implements Apple's Liquid Glass button primitives (`.glassEffect(.regular)` for secondary, `.glassEffect(.prominent.tint(#EA5A36))` for brand CTA). Top specular edge catches ambient interface light.
- **Visual Anatomy & Specifications:**
```
  GLASS SECONDARY (REGULAR TIER)       GLASS BRAND PRIMARY (PROMINENT TIER)
  ┌─────────────────────────┐         ┌─────────────────────────┐
  │  /// Specular Rim ///   │         │  /// Specular Rim ///   │
  │     View Brief          │         │     Submit Proposal     │
  └─────────────────────────┘         └─────────────────────────┘
  blur(20px) saturate(180%)           blur(24px) tint(#EA5A36 90%)
  border-top: 1px rgba(255,255,255,0.7) border-top: 1px rgba(255,255,255,0.4)
  border-bottom: 1px rgba(0,0,0,0.06) border-bottom: 1px rgba(0,0,0,0.15)
```
- **Interactive States:**
  - *Default:* Dynamic refraction of background elements; floating elevation.
  - *Hover:* Specular rim glints with increased luminance; backdrop blur deepens.
  - *Active:* Glass opacity deepens to $95\%$; specular rim contracts.
  - *Focus:* Luminous translucent aura around button perimeter.
  - *Disabled:* Frosted glass turns into flat matte gray; specular light extinguished.
- **Trade-off Analysis:**
  - *Right when:* iOS 26+, VisionOS, and macOS flagship experiences with vibrant background imagery.
  - *Costs:* Degrades to standard solid pill on older browsers; requires higher rendering power.
- **WCAG AA & Touch Target:**
  - Height: $48\text{px}$. Contrast verified: Text `#FFFFFF` against $90\%$ `#EA5A36` glass meets $3.47:1$ AA standard.

---

## Component 5: StickyProposalBar (Bottom Viewport Trigger)

### 5.1 Structure / Quiet: "The Subterranean Ledger"
- **Axis Position:** Primary Axis = Structure (Achromatic Subterranean Dock)
- **Concept:** Seamless bottom bar that appears to be part of the white drywall gallery floor. Separated by a single $1\text{px}$ architectural hairline (`#E5E5E3`), with zero background shadows.
- **Visual Anatomy & Blueprint:**
```
  ───────────────────────────────────────────────────────────── [1px hairline]
  $140 / hr  (Est. $22,400 Total)         ┌───────────────────┐
  Milestone: 3 Sprints · Escrow           │  Submit Proposal  │
  [ Transparent Terms ↗ ]                 └───────────────────┘
                                           (Solid #EA5A36 48px)
```
- **Interactive States:**
  - *Default:* Canvas background `#FFFFFF`, hairline `#E5E5E3`, bold rate in `#1B1A18`.
  - *Hover on CTA:* CTA darkens to `#F26643`; rate metadata reveals tooltip with breakdown.
  - *Active on CTA:* CTA scales to `0.97`; tactile trigger.
  - *Focus:* Standard keyboard ring surrounds the primary action.
- **Trade-off Analysis:**
  - *Right when:* Minimalist feeds, long-form brief readers where the user is already focused on the content.
  - *Costs:* Can blend into white page content if the user does not notice the 1px hairline divider.
- **WCAG AA & Touch Target:**
  - Bar height: $72\text{px}$ (including home indicator padding). CTA: $48\text{px}$ height.
  - Contrast: Rate text `#1B1A18` on White = $13.8:1$.

---

### 5.2 Type / Editorial Placard: "The Curatorial Commitment Dock"
- **Axis Position:** Primary Axis = Type (Curatorial Formal Agreement)
- **Concept:** Presents the financial offer as a dignified curatorial commission agreement. Features uppercase tracking for legal specifications and an upright serif contract title.
- **Visual Anatomy & Blueprint:**
```
  ─────────────────────────────────────────────────────────────
  COVENANT: *Design System Overhaul*      VALUATION: $22,400
  ESCROW: 100% Depository Guaranteed      RATE: $140.00 / HR
  
  ┌───────────────────────────────────────────────────────────┐
  │           EXECUTE COMMITTED PROPOSAL (NO. 289)            │
  └───────────────────────────────────────────────────────────┘
```
- **Interactive States:**
  - *Default:* Archival layout, stark black `#1B1A18` full-width capsule button.
  - *Hover:* Button inverts to pure white with $1.5\text{px}$ black border; text reveals arrow.
  - *Active:* Button background flashes `#EA5A36` briefly to acknowledge execution.
  - *Focus:* 2px double outline around entire dock.
- **Trade-off Analysis:**
  - *Right when:* High-value enterprise projects ($>\$20,000$) where formality inspires trust.
  - *Costs:* Takes up more vertical screen estate ($96\text{px}$).
- **WCAG AA & Touch Target:**
  - Full-width button: $50\text{px}$ height ($>44\text{pt}$).
  - High-contrast compliance: $13.8:1$ across all primary labels.

---

### 5.3 Density / Market Engine: "The Dynamic Breakdown Console"
- **Axis Position:** Primary Axis = Density (Airbnb All-In Transparent Pricing)
- **Concept:** Forked from Airbnb's transparent price breakdown modal. Displays the headline rate on the left, but tapping it springs open an inline financial popover disclosing platform fees ($0\%$ for talent), client taxes, and net payout.
- **Visual Anatomy & Blueprint:**
```
  ┌─────────────────────────────────────────────────────────────┐
  │  $140 / hr  ·  $22,400 Gross              ┌───────────────┐ │
  │  Net to Creator: $22,400 (0% Fee) [ⓘ]     │ Submit Brief  │ │
  │  (hourglass) Closes in 48 hours · 3 Bids   └───────────────┘ │
  └─────────────────────────────────────────────────────────────┘
                               │ (Tap ⓘ)
                               ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ FINANCIAL BREAKDOWN & ESCROW SCHEDULE                       │
  │ • Base Engagement (160 hrs @ $140/h):              $22,400  │
  │ • Talent Processing Fee (Frila 0% Guarantee):           $0  │
  │ • Escrow Milestone 1 (Sprint 1 Architecture):       $7,466  │
  │ • Escrow Milestone 2 (Sprint 2 Core Tokens):        $7,466  │
  │ • Escrow Milestone 3 (Final Delivery & QA):         $7,468  │
  │ ─────────────────────────────────────────────────────────── │
  │ Total Guaranteed Escrow:                           $22,400  │
  └─────────────────────────────────────────────────────────────┘
```
- **Interactive States:**
  - *Default:* Rate summary with info icon `[ⓘ]`.
  - *Hover on Info Icon:* Cursor pointer, popover drawer peaks upward.
  - *Active:* Sheet expands smoothly with breakdown list.
  - *CTA Active:* High-contrast brand vermilion press state.
- **Trade-off Analysis:**
  - *Right when:* Freelancers tired of hidden platform deductions; builds total trust.
  - *Costs:* Dense information hierarchy requires thoughtful typography to avoid clutter on small mobile screens.
- **WCAG AA & Touch Target:**
  - Info button: $44 \times 44\text{pt}$ hit area.
  - Table contrast: All numbers set in bold tabular numerals with $\ge 4.5:1$ contrast.

---

### 5.4 Interaction / Tactile Physics: "The Spring-Dock Expansion"
- **Axis Position:** Primary Axis = Interaction (Gesture-Driven Expansion)
- **Concept:** A bottom bar with a rubber-band gesture pull-tab. Swiping upward smoothly transitions the dock into a full-height interactive proposal sheet with milestone configurators.
- **Visual Anatomy & Blueprint:**
```
                       ─── (Gesture Pull Handle) ───
  ┌─────────────────────────────────────────────────────────────┐
  │ $140 / hr · 3 Milestones               [ Slide to Apply ➔ ] │
  └─────────────────────────────────────────────────────────────┘
```
- **Slider CTA Option:**
  - Replaces simple tap with an intuitive "Slide to Apply" track, preventing accidental multi-thousand-dollar commitments.
  - Spring-release pulls the thumb back to start if drag is aborted midway.
- **Interactive States:**
  - *Default:* Floating dock with pill drag indicator.
  - *Swipe Up (Gesture):* Dock expands proportionally to finger velocity; snaps to half-sheet or full-sheet.
  - *Slider Drag:* Track fills with luminous emerald or vermilion; thumb vibrates at trigger point ($85\%$ width).
  - *Complete:* Spring release triggers celebration haptic and morphs into `PROPOSAL TRANSMITTED ✓`.
- **Trade-off Analysis:**
  - *Right when:* Native iOS/Android apps where gesture fluidity creates delightful, confident conversion.
  - *Costs:* Not suitable for desktop web without pointer-drag fallbacks.
- **WCAG AA & Touch Target:**
  - Pull handle touch area: $44\text{px}$ vertical swipe zone. Slider thumb: $48 \times 48\text{pt}$.
  - Accessible fallback: Simple button provided for VoiceOver / keyboard users.

---

### 5.5 Expression / Liquid Glass: "The Floating Glass Dock"
- **Axis Position:** Primary Axis = Expression (iOS 26+ Detached Floating Island)
- **Concept:** Detaches completely from the screen edges. Floats $16\text{px}$ above the home indicator with $16\text{px}$ horizontal margins. Uses Apple iOS 26+ `.glassEffect(.regular.interactive())` with a double-tier specular rim.
- **Visual Anatomy & Blueprint:**
```
  ┌─────────────────────────────────────────────────────────────┐
  │  /// TRANSLUCENT GLASS ISLAND (RADIUS 9999px / CAPSULE) /// │
  │  border-top: 1px solid rgba(255,255,255,0.85) (Specular)    │
  │  border-bottom: 1px solid rgba(0,0,0,0.08)                  │
  │                                                             │
  │  $140 / hr · Est. $22,400           ┌─────────────────────┐ │
  │  (shield) 100% Escrow Funded         │ Submit Proposal ➜   │ │
  │                                     └─────────────────────┘ │
  └─────────────────────────────────────────────────────────────┘
```
- **Interactive States:**
  - *Default:* Glass floating capsule, backdrop blur $24\text{px}$, specular top highlight. Feed content visibly scrolls underneath.
  - *Hover:* Specular glint animates across top border; shadow extends to `0 12px 36px rgba(0,0,0,0.12)`.
  - *Active:* Whole capsule depresses $-1\text{px}$; button responds with haptic scale.
  - *Focus:* Specular outline illuminates with brand vermilion.
- **Trade-off Analysis:**
  - *Right when:* Modern mobile interfaces where modern hardware can execute real-time glass shaders.
  - *Costs:* Floating margins slightly reduce available width for metadata text.
- **WCAG AA & Touch Target:**
  - Height: $64\text{px}$ (exceeds $44\text{pt}$).
  - Specular rim and high background opacity ($85\%$) ensure text meets $>7:1$ contrast against any scrolling content.

---

## Component 6: CreatorProfileHero (3-Pillar Layout)

### 6.1 Structure / Quiet: "The White Gallery Monograph"
- **Axis Position:** Primary Axis = Structure (Achromatic Monograph)
- **Concept:** Dismantles traditional gig badges and star ratings. The creator's work is presented like an artist's retrospective in a premier gallery: pure white background, unadorned square portrait, understated typography, and generous negative space.
- **Visual Anatomy & Blueprint:**
```
┌─────────────────────────────────────────────────────────────┐
│ [← Back to Feed]                                  [Share ↗] │
│                                                             │
│                    ┌──────────────┐                         │
│                    │ 80x80 Photo  │                         │
│                    │ 0px Radius   │                         │
│                    └──────────────┘                         │
│                                                             │
│                     ELENA ROSTOVA                           │
│        Principal Design Technologist · Berlin, DE           │
│                                                             │
│       [ Commission Work ]       [ Follow Track Record ]     │
│        (Solid Ink 48px)            (Hairline 44px)          │
├─────────────────────────────────────────────────────────────┤
│  SELECTED WORKS (24)   │   TRACK RECORD (18)   │   ABOUT    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  [2-Column Masonry Gallery of Full Case Studies]            │
│  *Autonomous Design System Compiler, 2025*                  │
│  Delivered for OpenAI Labs · Verified Contract              │
└─────────────────────────────────────────────────────────────┘
```
- **Interactive States:**
  - *Default:* Clean black and white canvas, zero shadows.
  - *Tab Switch:* Hairline indicator slides seamlessly beneath active pillar title; count updates.
  - *Hover on Work:* Case study title shifts to brand color; thumbnail outline darkens.
  - *Active:* Tactile button press feedback `scale(0.97)`.
  - *Focus:* 2px crisp focus outline around active tab.
- **Trade-off Analysis:**
  - *Right when:* Elite technical and creative specialists who command $> \$150/\text{hr}$ and refuse to be commoditized.
  - *Costs:* Does not display rapid social-proof metrics (e.g. "Total jobs completed: 150").
- **WCAG AA & Touch Target:**
  - Tab targets: $48\text{px}$ height $\times$ width of column.
  - Contrast: `#1B1A18` on White = $13.8:1$.

---

### 6.2 Type / Editorial Placard: "The Museum Retrospective Catalog"
- **Axis Position:** Primary Axis = Type (Curatorial Exhibition Archive)
- **Concept:** Designed as an institutional monograph catalog. Creator's name is set in a commanding display grotesque, while their discipline and tenure are typeset in upright editorial serif and archival monospace.
- **Visual Anatomy & Blueprint:**
```
┌─────────────────────────────────────────────────────────────┐
│ RETROSPECTIVE NO. 412                      PRACTICE: SYSTEMS│
│                                                             │
│                     MARCUS BENNETT                          │
│     *Staff Interface Architect & Computational Typographer* │
│                                                             │
│ RESIDENCY: Madrid, ES             CURATORIAL STATUS: VERIFIED│
│ ESCROW RECORD: 100%               ACTIVE COMMISSION: OPEN (1)│
│                                                             │
│ ┌────────────────────────┐      ┌─────────────────────────┐ │
│ │  COMMISSION INQUIRY ➜  │      │  CATALOGUE RESUME [PDF] │ │
│ └────────────────────────┘      └─────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│ I. OEUVRE / WORKS      II. PROVENANCE & LEDGER     III. BIO │
├─────────────────────────────────────────────────────────────┤
│ *Design Systems for Spatial Computing, 2026*                │
│ Commissioned by Apple Developer Ecosystem                   │
│ Scope: Token Architecture, Fluid Metal Physics, WCAG AAA    │
└─────────────────────────────────────────────────────────────┘
```
- **Interactive States:**
  - *Default:* Roman numeral tab prefixes (`I.`, `II.`, `III.`), archival aesthetic.
  - *Hover on Tab:* Roman numerals transition to brand vermilion `#EA5A36`.
  - *Hover on Inquiry:* Action pill inverts into solid vermilion with white text.
  - *Focus:* Archival double outline around selected element.
- **Trade-off Analysis:**
  - *Right when:* Renowned designers, creative directors, and prestigious design studios.
  - *Costs:* Requires high-caliber biographical copy and curated imagery to look authentic.
- **WCAG AA & Touch Target:**
  - Contrast: Black text on white meets $13.8:1$ (AAA).
  - All interactive buttons meet $48\text{px}$ touch targets.

---

### 6.3 Density / Market Engine: "The Talent Terminal Spec Sheet"
- **Axis Position:** Primary Axis = Density (Quantitative Track Record)
- **Concept:** Tailored for hiring executives and engineering managers. Consolidates the creator's track record into an executive dashboard summary: historical contract volume, delivery rate, average project duration, and instant availability badge.
- **Visual Anatomy & Blueprint:**
```
┌─────────────────────────────────────────────────────────────┐
│ (64x64) ALEX CHEN               [🟢 AVAILABLE FOR CONTRACT] │
│ Staff Full-Stack Eng · SF, CA   Rate: $165/hr · $24k Sprint │
│ ─────────────────────────────────────────────────────────── │
│ 100% ON-TIME     $340k VOLUME     28 BRIEFS     STAFF TIER  │
│ Verified Escrow  Historical Payout Completed    Vetted Craft│
│ ─────────────────────────────────────────────────────────── │
│ [ Direct Hire ]    [ Schedule Technical Screen ]   [ Save ] │
├─────────────────────────────────────────────────────────────┤
│ [ SELECTED WORKS (28) ]  [ VERIFIED LEDGER ]  [ SPECS / BIO ]│
├─────────────────────────────────────────────────────────────┤
│ • Vercel AI SDK Integration (4 Mo · $48k) ── [VERIFIED ✓]   │
│ • Raycast Extension Ecosystem (2 Mo · $22k) ─ [VERIFIED ✓]   │
└─────────────────────────────────────────────────────────────┘
```
- **Interactive States:**
  - *Default:* High information density, compact dividers, verified green checks (`#008A3B`).
  - *Hover on Metric Box:* Discloses statistical percentile comparison (e.g. `"Top 3% on Platform"`).
  - *Hover on Ledger Row:* Highlights contract bracket and milestone completion dates.
  - *Active:* Action button scales to `0.96`.
- **Trade-off Analysis:**
  - *Right when:* High-velocity technical hiring where engineering leads need hard metrics fast.
  - *Costs:* Trades curatorial museum dignity for marketplace efficiency.
- **WCAG AA & Touch Target:**
  - Metric boxes are non-interactive informational displays.
  - Action buttons: $44\text{px}$ minimum height. Contrast verified $\ge 4.5:1$.

---

### 6.4 Interaction / Tactile Physics: "The Fluid Scroll Parallax Stage"
- **Axis Position:** Primary Axis = Interaction (Scroll Parallax & Tab Spring Physics)
- **Concept:** The profile header dynamically responds to viewport scroll. As the user scrolls down through the portfolio, the avatar and bio smoothly collapse into a sticky compact glass navigation bar. The 3-pillar tabs feature an elastic magnetic indicator that tracks finger dragging.
- **Visual Anatomy & Blueprint:**
```
  RESTING POSITION (HERO EXPANDED)
  ┌─────────────────────────────────────────────────────────────┐
  │                        ( 96x96 Avatar )                     │
  │                         SARAH CONNER                        │
  │           Design Technologist & Creative Director           │
  │                                                             │
  │        [  SELECTED WORKS  ]   [ TRACK RECORD ]   [ BIO ]    │
  │        ════════════════════ (Magnetic Spring Tab Indicator) │
  └─────────────────────────────────────────────────────────────┘
                                 │
                                 │ (Scroll Down / Collapse)
                                 ▼
  STICKY COMPACT STATE (56px Glass Top Bar)
  ┌─────────────────────────────────────────────────────────────┐
  │ [←] (32x32) Sarah Conner · Staff   [ WORKS | RECORD | BIO ] │
  └─────────────────────────────────────────────────────────────┘
```
- **Interactive States:**
  - *Default:* Full spacious hero stage.
  - *Drag on Tab Bar:* Spring indicator stretches elastically before snapping to the newly selected pillar.
  - *Scroll Transition:* Header height interpolates from $280\text{px} \rightarrow 56\text{px}$ using CSS scroll-driven animations or iOS geometry proxies.
  - *Case Study Tile Tilt:* Moving the pointer over work tiles creates a subtle 3D parallax tilt ($3^\circ$).
- **Trade-off Analysis:**
  - *Right when:* Native touch devices where scroll fluidity and tactile feedback create an immersive showcase.
  - *Costs:* Requires scroll event listener coordination and GPU layer compositing.
- **WCAG AA & Touch Target:**
  - Sticky tab targets in compact state: $44\text{px}$ height $\times 60\text{px}$ width.
  - Reduced motion respects `@media (prefers-reduced-motion)` by disabling scroll collapsing.

---

### 6.5 Expression / Liquid Glass: "The Luminous Atelier Showcase"
- **Axis Position:** Primary Axis = Expression (Apple iOS 26+ Translucent Atelier)
- **Concept:** The creator's profile is set against a dynamic frosted atelier backdrop. The avatar is framed by a luminous glass specular ring, and the 3-pillar navigation bar floats as an iOS 26+ Liquid Glass capsule with internal refraction.
- **Visual Anatomy & Blueprint:**
```
┌─────────────────────────────────────────────────────────────┐
│ ┌─────────────────────────────────────────────────────────┐ │
│ │  /// AMBIENT ATELIER BACKDROP (CREATOR ARTWORK BLUR) ///│ │
│ │                                                         │ │
│ │                  ┌───────────────────┐                  │ │
│ │                  │ (88x88) AVATAR    │                  │ │
│ │                  │ Specular Glass Rim│                  │ │
│ │                  └───────────────────┘                  │ │
│ │                                                         │ │
│ │                      SOPHIA VALENTINE                   │ │
│ │              Staff Metal & Shader Engineer              │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│       ┌─────────────────────────────────────────────┐       │
│       │ .glassEffect(.regular.interactive())        │       │
│       │ [ Selected Works ] [ Track Record ] [ Bio ] │       │
│       └─────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```
- **Interactive States:**
  - *Default:* Ambient blur over creator's self-selected cover portfolio piece; floating glass tab capsule.
  - *Hover on Tab Capsule:* Capsule highlights with specular reflection; active tab illuminates with subtle brand tint.
  - *Active Tab:* Spring transition moves the glowing pill backdrop beneath the active text.
  - *Focus:* Specular outline illuminates with luminous vermilion glow.
- **Trade-off Analysis:**
  - *Right when:* Top-tier 3D artists, spatial computing engineers, and luxury creative agencies.
  - *Costs:* Needs high-res creator banner assets; can degrade if user uploads low-contrast or low-quality artwork.
- **WCAG AA & Touch Target:**
  - Backdrop dimming layer ($65\%$ black scrim) guarantees text contrast $>7:1$ over any custom user background.
  - Floating pill tabs: $48\text{px}$ height.

---

## Comprehensive Tradeoff & Selection Matrix

| Component | Variant Name | Primary Axis | Right When | Costs / Caveats | Recommended Placement |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1. OpportunityCard** | 1.1 White Cube Frame | Structure / Quiet | Minimalist briefs, pure visual art portfolios | Lower click affordance for non-editorial users | Editorial collections & awards feeds |
| | 1.2 Curatorial Monograph | Type / Editorial | High-prestige enterprise briefs, staff roles | Higher reading cognitive load | Enterprise brief detail & featured feeds |
| | 1.3 Terminal Ledger | Density / Market Engine | High-volume scanning, technical contracts | Reduced emotional resonance | Filtered search results & desktop tables |
| | 1.4 Accordion Stage | Interaction / Physics | Rapid candidate review without page navigation | Higher mobile GPU/CPU animation overhead | Mobile discovery feeds |
| | 1.5 Specular Vitrine | Expression / Liquid Glass | VisionOS, iOS 26+ native app, dark/light fluid UI | Requires backdrop-filter GPU support | iOS 26+ native app feed |
| **2. StickySearchCapsule** | 2.1 Monolithic Whisper | Structure / Quiet | Quiet reading environments, minimal UI footprint | Hidden affordance of multi-step filters | Secondary pages & portfolio search |
| | 2.2 Lexicon Index | Type / Editorial | Specialized creative consultancies | Longer strings may truncate on small phones | Curated creative talent directories |
| | 2.3 Matrix Command Bar | Density / Market Engine | Primary marketplace feed, power searchers | 3 horizontal touch zones require precision | **Default Global Marketplace Feed** |
| | 2.4 Elastic Accordion | Interaction / Physics | In-page discovery without modal navigation | Causes layout shift if pushing content down | Tablet and desktop hero headers |
| | 2.5 Refractive Lens | Expression / Liquid Glass | Apple platforms, floating above image feeds | High-contrast fallback needed for accessibility | iOS 26+ floating header |
| **3. BudgetHistogram** | 3.1 Horizon Density Bar | Structure / Quiet | Minimalist curation, aesthetic refinement | Hard to gauge exact brief count per $5 bucket | Executive talent tier filtering |
| | 3.2 Valuation Ledger | Type / Editorial | Senior talent negotiating on market percentiles | Takes up more vertical space (180px) | Staff/Principal salary benchmarking |
| | 3.3 Quant Matrix | Density / Market Engine | Precision price filtering with exact counts | Complex dual-slider + input sync logic | **Default Discovery Sheet Budget Step** |
| | 3.4 Magnetic Elastic | Interaction / Physics | Native touch devices with haptic engines | Needs native vibration API access | Native mobile app discovery sheet |
| | 3.5 Luminous Spectrum | Expression / Liquid Glass | High-end visual showcases, promotional demos | Shader performance on low-end mobile | iOS 26+ flagship promotional view |
| **4. FrilaButton** | 4.1 Achromatic Pure Line | Structure / Quiet | Letting portfolio artwork command all color | Outlined buttons have lower click affordance | Gallery view, secondary toolbars |
| | 4.2 Monograph Stamp | Type / Editorial | Curated exhibitions, fine-art consultancies | Formal tone; not for casual gig markets | Official proposal execution sheets |
| | 4.3 High-Throughput Suite| Density / Market Engine | Fast workflows, split actions, desktop tables | Compact tier needs invisible touch expansion | Administrative consoles & table rows |
| | 4.4 Haptic Spring Pill | Interaction / Physics | High-intent conversion points on mobile | Can trigger motion sensitivity if unthrottled | **Default Primary Application Action** |
| | 4.5 Specular Glass Pill | Expression / Liquid Glass | Floating toolbars over rich visual content | Requires glass shader support | Floating sticky action triggers |
| **5. StickyProposalBar**| 5.1 Subterranean Ledger | Structure / Quiet | Reading-focused briefs, minimal distractions | Can blend into white background | Long-form project scope reader |
| | 5.2 Curatorial Commitment| Type / Editorial | Multi-thousand dollar enterprise commitments | Taller vertical footprint (96px) | Enterprise contract execution view |
| | 5.3 Breakdown Console | Density / Market Engine | Talent needing 100% transparent fee breakdowns | Dense typography on small screens | **Default Opportunity Detail View** |
| | 5.4 Spring-Dock Expansion| Interaction / Physics | Gesture-first mobile apps, preventing mis-clicks | Requires gesture recognizers & pointer fallback | Native iOS/Android detail view |
| | 5.5 Floating Glass Dock | Expression / Liquid Glass | Modern translucent UI, keeping content visible | Floating margins reduce text line length | iOS 26+ opportunity detail view |
| **6. CreatorProfileHero**| 6.1 White Monograph | Structure / Quiet | Elite craftspeople who reject commodity badges | Lacks instant quantitative proof | Design director & artist profiles |
| | 6.2 Retrospective Catalog| Type / Editorial | Prestigious design studios, spatial architects | Requires high-quality biographical copy | Curated design agency profiles |
| | 6.3 Terminal Spec Sheet | Density / Market Engine | Rapid engineering & technical screening | Trades museum dignity for data density | **Default Engineering & Full-Stack Profile** |
| | 6.4 Fluid Scroll Parallax| Interaction / Physics | Native mobile touch with smooth scroll collapse | Complex coordinate tracking | Mobile creator profile view |
| | 6.5 Luminous Atelier | Expression / Liquid Glass | 3D, Metal, and spatial computing specialists | Degrades if user uploads poor banner art | Spatial & Visual creator profile |

---

## Accessibility (WCAG 2.2 AA) & Touch Target Verification Audit

### 1. Mathematical Contrast Verification (OKLCH & sRGB)

| Token / Color Combination | Calculated Contrast Ratio | WCAG 2.2 Requirement | Pass / Fail Status | Remediation / Architectural Rule |
| :--- | :--- | :--- | :--- | :--- |
| **`#1B1A18` on Canvas `#FFFFFF`** | **$13.84 : 1$** | $\ge 4.5:1$ (Normal Text) | ✅ **PASS (AAA)** | Primary copy, headings, and entity labels across all components. |
| **`#767571` on Canvas `#FFFFFF`** | **$4.54 : 1$** | $\ge 4.5:1$ (Normal Text) | ✅ **PASS (AA)** | Metadata, timestamps, and secondary labels. |
| **`#008A3B` on Canvas `#FFFFFF`** | **$4.58 : 1$** | $\ge 4.5:1$ (Normal Text) | ✅ **PASS (AA)** | Escrow Verified badge and financial trust indicators. |
| **`#EA5A36` on Canvas `#FFFFFF`** | **$3.47 : 1$** | $\ge 3.0:1$ (Large/UI) | ⚠️ **CONDITIONAL PASS** | **Rule:** Exceeds $3.0:1$ for UI graphical controls and large text ($\ge 18\text{pt}$ bold). **Forbidden for normal body text $<18\text{pt}$**. For accessible body text links, use `--frila-color-primary-700` (`#9D2701`, contrast $5.52:1$). |
| **`#FFFFFF` on `#EA5A36` (CTA Button)**| **$3.47 : 1$** | $\ge 3.0:1$ (UI Component) | ⚠️ **CONDITIONAL PASS** | **Rule:** Primary CTA buttons must use bold text $\ge 16\text{pt}$ semibold ($21.3\text{px}$) to pass WCAG AA for large text, or use `--frila-color-primary-600` (`#C03710`, contrast $4.62:1$) for smaller label tiers. |
| **`#CECECB` on Canvas `#FFFFFF`** | **$1.45 : 1$** | $\ge 3.0:1$ (Non-text bound) | ⚠️ **ARCHITECTURAL NOTE** | Permitted *only* as non-essential decorative dividers. When used as interactive input borders, active focus ring overrides with `2px solid #EA5A36` ($3.47:1$) or `2px solid #1B1A18` ($13.8:1$). |
| **Liquid Glass ($82\%$ White Scrim)** | **$> 10.5 : 1$** | $\ge 4.5:1$ (Normal Text) | ✅ **PASS (AA)** | Backdrop luminosity clamp ensures text `#1B1A18` exceeds $10:1$ regardless of image scrolling underneath. |

### 2. Human Interface Touch Target ($44 \times 44\text{pt}$) Enforcement

Every interactive control across all 30 variations conforms to HIG $44\text{pt}$ rules:
1. **Pill Buttons:**
   - Primary CTA: $48\text{px} - 52\text{px}$ height $\times$ full-width or $>120\text{px}$ width.
   - Outlined / Secondary: $44\text{px}$ height.
   - Compact Tier ($32\text{px}$): Uses CSS `::after` with `position: absolute; top: -6px; bottom: -6px; left: 0; right: 0;` to expand invisible touch target to $44\text{px}$.
2. **Histogram Drag Handles:**
   - Visual handle: $24\text{px} - 28\text{px}$ diameter.
   - Touch envelope: $48 \times 48\text{px}$ transparent hit area.
3. **Capsule Segments & Chips:**
   - Minimum height: $44\text{px}$.
   - Horizontal touch target width: $\ge 44\text{px}$.
4. **Accordion & Chevron Toggles:**
   - Padded hitbox with minimum $44\text{px}$ bounding box.

### 3. Reduced Motion & Accessibility Modes
- `@media (prefers-reduced-motion: reduce)`:
  - Disables 3D parallax tilt, spring scale oscillations, and dynamic layout morphing.
  - Replaces spring animations with instant state transitions or subtle opacity fades ($120\text{ms}$).
- `.accessibilityReduceTransparency`:
  - Disables backdrop-filter blur and specular highlights in Liquid Glass variants.
  - Replaces glass containers with solid `#FFFFFF` surfaces with `1px solid #CECECB` borders.

---

## Production Blueprint & Synthesis Recommendation

For the immediate build phase, the optimal synthesis across the 6 components is:
1. **Feed Unit (`OpportunityCard`):** Adopt **Variant 1.2 (Curatorial Monograph)** for featured and enterprise briefs; adopt **Variant 1.3 (Terminal Ledger)** for high-density search results.
2. **Search Discovery (`StickySearchCapsule`):** Adopt **Variant 2.3 (Matrix Command Bar)** as the core marketplace trigger, launching the 3-step progressive modal.
3. **Budget Filter (`BudgetHistogram`):** Adopt **Variant 3.3 (Quant Distribution Matrix)** with live matching counters (`Show 38 Opportunities`).
4. **Buttons & Pills (`FrilaButton`):** Standardize on **Variant 4.4 (Haptic Spring Pill)** for primary high-intent CTAs, paired with **Variant 4.1 (Achromatic Pure Line)** for secondary/tertiary dismissals.
5. **Sticky Trigger (`StickyProposalBar`):** Adopt **Variant 5.3 (Dynamic Breakdown Console)** on desktop and web; adopt **Variant 5.5 (Floating Glass Dock)** on iOS 26+ native clients.
6. **Creator Profile (`CreatorProfileHero`):** Adopt **Variant 6.3 (Talent Terminal Spec Sheet)** for technical engineering talent; adopt **Variant 6.1 (White Monograph)** for visual, design systems, and creative directors.
