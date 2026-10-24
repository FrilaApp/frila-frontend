# Frila Design System — Primitive Typography & Foundations Specification
**Product:** Frila (Marketplace for Elite Freelancers & Design Technologists)  
**Author:** Worker Alpha (Primitives & Typography Innovator)  
**Parent Document:** `DESIGN.md`  
**Foundations:** The Gallery-Marketplace Synthesis (Artsy Fine-Art Dignity x Airbnb Frictionless Conversion x OKLCH Brand Anchor `#EA5A36` x iOS 26+ Liquid Glass)  
**Date:** September 2026  

> **Governing rules (Onda 1 — override anything in this exploration):**
> 1. **Swiss Neo-Grotesque is the default paradigm** (`FrilaTypography()`, first `TypographyParadigm` case, all static tokens). The other four remain explicit opt-ins.
> 2. **No italic, anywhere** — neither serif italic nor oblique sans. Placard titles are upright.
> 3. **Figures are SF Pro with proportional digits** in every paradigm (Archival included). Tabular digits only for values that animate or align in a column (`FrilaTypography.metricTabular`).
> 4. **Money** is USD with a fixed `en_US` locale via `FrilaMoney` (`$140/hr`, `$33,600`); display with `FrilaPriceTag`. Canonical unit `/hr`.
> 5. **No emoji or text glyphs as icons** in badges, chips or pills — SF Symbols only. In the ASCII mockups below, `(shield)` marks an SF Symbol slot (`checkmark.shield.fill`).
> 6. **SF Pro Rounded is forbidden** (see `DESIGN.md` §3.1).
>
> Source of truth: `Sources/FrilaDesignSystem/Primitives/FrilaTypography.swift` and `DESIGN.md`.

---

## 1. Executive Summary & Design Thesis

Traditional freelance platforms (Upwork, Fiverr, Freelancer.com) suffer from structural design entropy: loud yellow badges, 5-star star traps, aggressive drop shadows, and chaotic typography that demean high-caliber creative and technical professionals.

**Frila** establishes a new design paradigm:
1. **The Museum Placard Convention (Artsy Heritage):** Every contract, project brief, and talent profile is framed with curatorial reverence. High-contrast typographic tension pairs the client authority with the creative scope and archival monospace cataloguing.
2. **The Achromatic Gallery Wall (`#FFFFFF`):** Work and portfolio pieces provide 100% of the chromatic energy. Backgrounds are pure drywall; elevation is flat with zero gratuitous card drop shadows.
3. **The OKLCH Brand Anchor (`#EA5A36`):** An energetic, warm persimmon orange-red (`oklch(0.651 0.186 35.1)`) reserved strictly for high-intent commitments, active pills, and focus rings.
4. **Next-Gen Spatial Computing (Liquid Glass):** Floating capsules, bottom proposal bars, and modal sheets leverage native iOS 26+ Liquid Glass shader mechanics and web specular CSS filters.

To give product teams, clients, and talent the optimal expression for diverse project categories (from high-craft agency branding to dev smart contracts), this document introduces **5 Distinct Primitive Typography Paradigms**.

---

## 2. The 5 Primitive Typography Paradigms

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                               FRILA PRIMITIVE TYPOGRAPHY PARADIGMS MATRIX                               │
├───────────────────┬───────────────────────────────┬──────────────────────────┬──────────────────────────┤
│ Variant           │ Primary Axis                  │ Core Font Pairing        │ Archetype & Spirit       │
├───────────────────┼───────────────────────────────┼──────────────────────────┼──────────────────────────┤
│ 1. Curatorial     │ Expressive Contrast / Culture │ Bold Sans + Serif Upright│ Artsy Fine-Art Placard   │
│ 2. Swiss (Default)│ Structure & Spatial Geometry  │ Unified Grotesque Upright│ Vignelli / Bauhaus Rigor │
│ 3. Humanist Craft │ Warmth & Tactility / Voice    │ Warm Serif + Humanist    │ Bespoke Atelier Workshop │
│ 4. Archival Dense │ Density & Data Throughput     │ Compact Monospace        │ Terminal / Dev Contracts │
│ 5. Liquid Glass   │ Surface Depth & Luminance     │ Crisp SF Pro             │ Next-Gen Spatial Apple OS│
└───────────────────┴───────────────────────────────┴──────────────────────────┴──────────────────────────┘
```

---

### 2.1 Variant 1: "Curatorial Placard" (The Artsy Heritage Benchmark)

#### Concept & Architectural Intent
The baseline benchmark of Frila. Directly inspired by Artsy's museum wall cards (`7359672b`). It establishes cultural gravitas by pairing an authoritative bold sans client identity with a contemplative, upright editorial serif for the brief's title, grounded by tracked monospace archival spec tags.

#### Font Family Stack
- **Entity & Display:** `Inter, -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif`
- **Placard Scope (Upright):** `"Newsreader", "New York", "Georgia", "Baskerville", "Times New Roman", serif`
- **Archival Micro-Labels:** `"JetBrains Mono", "SF Mono", "Menlo", "Monaco", "Consolas", monospace`
- **Figures:** SF Pro, proportional lining numerals (`"pnum" on, "lnum" on`); tabular only for animated or column values.

#### Type Scale & Micro-Typography
| Role | Size | Line Height | Weight | Tracking | Transform | Font Family | OpenType Features |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Display Headline** | `32px` (`2.0rem`) | `1.15` (`36.8px`) | `700` | `-0.02em` (`-0.64px`) | None | Sans | `cv02, cv03, cv04` |
| **Placard Title** | `18px` (`1.125rem`) | `1.35` (`24.3px`) | `400` | `-0.01em` (`-0.18px`) | None (upright) | Serif | `kern, liga` |
| **Client Entity** | `17px` (`1.0625rem`) | `1.25` (`21.25px`) | `700` | `-0.015em` (`-0.25px`) | None | Sans | `kern` |
| **Body Copy** | `15px` (`0.9375rem`) | `1.50` (`22.5px`) | `400` | `0em` (`0px`) | None | Sans | Normal |
| **Micro-Label** | `11px` (`0.6875rem`) | `1.20` (`13.2px`) | `600` | `+0.08em` (`+0.88px`) | `uppercase` | Monospace | `zero` |
| **Metric / Price** | `22px` (`1.375rem`) | `1.15` (`25.3px`) | `700` | `-0.4px` | None | SF Pro | `pnum, lnum` |

#### In-Situ Placard Anatomy
```
┌─────────────────────────────────────────────────────────────┐
│  VERCEL LABS                              [17px Sans Bold]  │
│  NextGen Agent Orchestrator, 2026         [18px Serif Uprigh│
│  Remote · Contract (3-6 Months) · Staff   [13px Sans Muted] │
│                                                             │
│  SCOPE           TIMELINE         BUDGET  [11px Mono Upper] │
│  Design Systems  90 Days          Fixed   [13px Sans Reg]   │
│                                                             │
│  ─────────────────────────────────────────────────────────  │
│  $140/hr     Est. $22,400                 [22px Proport. Bold│
│  (shield) 100% Escrow Funded              [SF Symbol + 13px] │
└─────────────────────────────────────────────────────────────┘
```

#### Rationale & Evaluation
- **Feeling Evoked:** Curatorial prestige, institutional trust, gallery exhibition dignity.
- **Primary Axis:** Expressive Contrast / Cultural Distinction.
- **Right When:** Top 1% freelance talent, high-budget creative and technical agency briefs ($15k - $100k+), brand identity, design engineering systems.
- **Costs:** Loading 3 font families (grotesque + serif + mono) incurs ~80KB web font payload. Serif titles feel formal for rapid micro-tasks or mundane gigs.

---

### 2.2 Variant 2: "Swiss Neo-Grotesque" (Linear / Modernist Precision)

#### Concept & Architectural Intent
Rooted in the International Typographic Style (Müller-Brockmann, Vignelli, Max Bill). Rejects all decorative serif curves. Implements a unified neo-grotesque family across all roles, differentiating semantic strata exclusively through mathematical weight jumps and tight negative tracking — always upright.

#### Font Family Stack
- **Unified Family:** `"Suisse Int'l", "Neue Haas Grotesk", "Inter Tight", "Inter", "Helvetica Neue", -apple-system, sans-serif`
- **Data & Figures:** SF Pro, proportional digits (`"pnum" 1, "lnum" 1`); tabular only for animated or column values.

#### Type Scale & Micro-Typography
| Role | Size | Line Height | Weight | Tracking | Transform | Font Family | OpenType Features |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Display Headline** | `34px` (`2.125rem`) | `1.10` (`37.4px`) | `800` | `-0.035em` (`-1.2px`) | None | Grotesque | `ss01` |
| **Placard Title** | `18px` (`1.125rem`) | `1.28` (`23.0px`) | `500` | `-0.015em` (`-0.27px`) | None (upright) | Grotesque | `kern` |
| **Client Entity** | `16px` (`1.0rem`) | `1.20` (`19.2px`) | `700` | `-0.02em` (`-0.32px`) | `uppercase` | Grotesque | `ss02` |
| **Body Copy** | `14.5px` (`0.906rem`)| `1.45` (`21.0px`) | `400` | `-0.005em` (`-0.07px`)| None | Grotesque | Normal |
| **Micro-Label** | `10.5px` (`0.656rem`)| `1.15` (`12.1px`) | `700` | `+0.06em` (`+0.63px`) | `uppercase` | Grotesque | `kern` |
| **Metric / Price** | `22px` (`1.375rem`) | `1.10` (`24.2px`) | `800` | `-0.5px` | None | SF Pro | `pnum, lnum` |

#### In-Situ Placard Anatomy
```
┌─────────────────────────────────────────────────────────────┐
│  OPENAI RESEARCH                          [16px Grotesque U]│
│  Synthetic Multimodal Interface v4        [18px Grotesque Md│
│  San Francisco · Hybrid · Principal Tech  [13px Grotesque]  │
│                                                             │
│  [DOMAIN]        [CADENCE]        [VALUATION]               │
│  Foundational    Continuous       $180/hr                   │
│                                                             │
│  ─────────────────────────────────────────────────────────  │
│  $180/hr   Cap $45,000                    [22px Heavy Pnum] │
│  (shield) ESCROW VERIFIED                 [SF Symbol + 11px]│
└─────────────────────────────────────────────────────────────┘
```

#### Rationale & Evaluation
- **Feeling Evoked:** Mathematical precision, German/Swiss industrial architecture, unyielding functionalism.
- **Primary Axis:** Structure & Spatial Geometry.
- **Right When:** Systems architecture, compilers, high-frequency design engineering, enterprise tooling, hardware interfaces.
- **Costs:** Lacks warm human emotion. If spacing or negative margins are misaligned by even 2px, the aesthetic collapses into generic enterprise SaaS.

---

### 2.3 Variant 3: "Humanist Atelier" (Warm Editorial Craft)

#### Concept & Architectural Intent
The spirit of a bespoke creative workshop, private atelier, or bespoke print publisher. Celebrates organic calligraphic warmth, optical-size serifs, warm linen paper backgrounds (`#FDFAF6`), and deep espresso ink (`#241E19`).

#### Font Family Stack
- **Display & Placard Title:** `"Fraunces", "Lora", "Baskerville", "Palatino Linotype", "Book Antiqua", serif`
- **Client Entity & Body:** `"Plus Jakarta Sans", "Optima", "Gill Sans", "Candara", sans-serif`
- **Micro-Label:** Humanist Sans Small-Caps (`font-variant-caps: all-small-caps; letter-spacing: 0.12em`).
- **Figures:** SF Pro, proportional digits (the serif stays in display and titles).

#### Type Scale & Micro-Typography
| Role | Size | Line Height | Weight | Tracking | Transform | Font Family | OpenType Features |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Display Headline** | `32px` (`2.0rem`) | `1.20` (`38.4px`) | `600` | `-0.015em` (`-0.48px`) | None | Warm Serif | `kern, onum` |
| **Placard Title** | `19px` (`1.1875rem`)| `1.35` (`25.65px`)| `500` | `-0.01em` (`-0.19px`) | None | Warm Serif | `swsh, liga` |
| **Client Entity** | `16px` (`1.0rem`) | `1.30` (`20.8px`) | `600` | `0em` (`0px`) | None | Humanist Sans | Normal |
| **Body Copy** | `15px` (`0.9375rem`) | `1.55` (`23.25px`)| `400` | `+0.005em` (`+0.075px`)| None | Humanist Sans | Normal |
| **Micro-Label** | `11px` (`0.6875rem`) | `1.25` (`13.75px`)| `600` | `+0.12em` (`+1.32px`) | `all-small-caps`| Humanist Sans | `c2sc, smcp` |
| **Metric / Price** | `22px` (`1.375rem`)| `1.20` (`26.4px`) | `600` | `-0.4px` | None | SF Pro | `pnum, lnum` |

#### In-Situ Placard Anatomy
```
┌─────────────────────────────────────────────────────────────┐
│  Studio Ciguë Paris                       [16px Humanist Med│
│  Bespoke Spatial Identity & Flagship      [19px Warm Serif] │
│  Paris, FR · Atelier Retainer · Lead      [13.5px Humanist] │
│                                                             │
│  discipline      provenance       commitment  [Small-Caps]  │
│  Creative Dir    Direct Client    6 Months                  │
│                                                             │
│  ─────────────────────────────────────────────────────────  │
│  € 16,500 / mo   Guaranteed               [23px Warm Serif] │
│  (shield) 100% Escrow Deposited           [SF Symbol + 13px]│
└─────────────────────────────────────────────────────────────┘
```

#### Rationale & Evaluation
- **Feeling Evoked:** Artisanal mastery, bespoke luxury, literary warmth, crafted tactility.
- **Primary Axis:** Warmth & Tactility / Voice.
- **Right When:** Luxury brand identity, interior & industrial design, editorial illustration, high-end motion graphics, agency partner talent.
- **Costs:** Requires more generous vertical padding (`padding: 24px`); lowest information density among the five variants. Not suited for data-heavy financial matrices.

---

### 2.4 Variant 4: "Hyper-Dense Archival" (Fintech & Dev Contracts)

#### Concept & Architectural Intent
Constructed for developers, quantitative engineers, and smart-contract auditors. Treats the interface as a high-throughput operational console (inspired by Bloomberg Terminal, Vercel telemetry, and GitHub code reviews). Every pixel carries maximum information bandwidth with zero decorative fluff.

#### Font Family Stack
- **Primary Monospace:** `"Commit Mono", "SF Mono", "JetBrains Mono", "IBM Plex Mono", "Fira Code", monospace`
- **Secondary Condensed Sans:** `"Geist", "Inter Tight", "Roboto Condensed", -apple-system, sans-serif`
- **Data Numerals:** Hero figures in SF Pro, proportional. Tabular digits only in ledgers/columns (`FrilaTypography.metricTabular`); SF Mono stays for labels and codes.

#### Type Scale & Micro-Typography
| Role | Size | Line Height | Weight | Tracking | Transform | Font Family | OpenType Features |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Display Headline** | `26px` (`1.625rem`) | `1.15` (`29.9px`) | `700` | `-0.03em` (`-0.78px`) | None | Monospace | `zero, ss01` |
| **Placard Title** | `15px` (`0.9375rem`) | `1.25` (`18.75px`)| `600` | `-0.01em` (`-0.15px`) | None | Monospace | `zero` |
| **Client Entity** | `14px` (`0.875rem`) | `1.20` (`16.8px`) | `700` | `+0.02em` (`+0.28px`) | `uppercase` | Monospace | `zero` |
| **Body Copy** | `13px` (`0.8125rem`) | `1.38` (`17.94px`)| `400` | `0em` (`0px`) | None | Condensed Sans | Normal |
| **Micro-Label** | `9.5px` (`0.594rem`) | `1.10` (`10.45px`)| `700` | `+0.10em` (`+0.95px`) | `uppercase` | Monospace | `zero` |
| **Metric / Price** | `19px` (`1.1875rem`)| `1.10` (`20.9px`) | `700` | `-0.2px` | None | SF Pro | `pnum, lnum` |

#### In-Situ Placard Anatomy
```
┌─────────────────────────────────────────────────────────────┐
│  [PARADIGM LABS] // PROTOCOL-09           [14px Mono Bold U]│
│  ZK-Rollup Prover Audit & Gas Optimize    [15px Mono Semibd]│
│  REMOTE // CONTRACT // SENIOR PROTOCOL    [11px Mono Muted] │
│                                                             │
│  [STACK: RUST · SOL · CIRCOM]   [SLOT: 1/1]  [TIME: 45D]    │
│                                                             │
│  ─────────────────────────────────────────────────────────  │
│  $165/hr · Max $39,600                    [19px SF Pro Pnum]│
│  [ESCROW:100%_LOCKED]                     [10px Emerald]    │
└─────────────────────────────────────────────────────────────┘
```

#### Rationale & Evaluation
- **Feeling Evoked:** Developer sovereignty, cryptographic rigor, financial transparency, terminal telemetry.
- **Primary Axis:** Density & Information Throughput.
- **Right When:** Smart contract audits, backend infrastructure retainers, crypto protocol engineering, DevOps sprints, algorithmic trading briefs.
- **Costs:** Extreme cognitive load for non-technical clients. Monospace headings can feel rigid and abrasive if applied to creative storytelling.

---

### 2.5 Variant 5: "Tactile Liquid Glass" (Next-Gen Apple OS / VisionOS)

#### Concept & Architectural Intent
Anticipates the spatial computing era (iOS 26+, macOS Sequoia+, visionOS). Replaces flat opaque cards with continuous rounded squircle glass slabs (`backdrop-filter: blur(24px)`), ambient specular light refractions, and embossed micro-badges. Typography acts as light refracting through polished crystal.

#### Font Family Stack
- **Crisp Grotesque:** `-apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif` (SF Pro Rounded is forbidden)
- **Micro-Badges:** Medium rounded sans with micro text-shadow embossing.
- **Figures:** SF Pro, proportional digits, no glow.

#### Type Scale & Micro-Typography
| Role | Size | Line Height | Weight | Tracking | Transform | Font Family | Effects & Shaders |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Display Headline** | `32px` (`2.0rem`) | `1.18` (`37.76px`)| `750` | `-0.025em` (`-0.80px`)| None | Rounded Sans | `text-shadow: 0 1px 0 rgba(255,255,255,0.7)` |
| **Placard Title** | `18px` (`1.125rem`) | `1.30` (`23.4px`) | `550` | `-0.015em` (`-0.27px`)| None | Rounded Sans | Crisp edge rendering |
| **Client Entity** | `16px` (`1.0rem`) | `1.22` (`19.52px`)| `700` | `-0.01em` (`-0.16px`)| None | Rounded Sans | Specular contrast |
| **Body Copy** | `15px` (`0.9375rem`) | `1.48` (`22.2px`) | `450` | `0em` (`0px`) | None | Rounded Sans | Anti-aliased |
| **Micro-Label** | `11px` (`0.6875rem`) | `1.15` (`12.65px`)| `650` | `+0.07em` (`+0.77px`) | `uppercase` | Rounded Sans | `letter-spacing: +0.07em` |
| **Metric / Price** | `22px` (`1.375rem`) | `1.15` (`25.3px`) | `700` | `-0.4px` | None | SF Pro (`pnum`) | None |

#### In-Situ Placard Anatomy (Rendered on Specular Glass)
```
┌─────────────────────────────────────────────────────────────┐
│ ░░░░░░░░░░░░░░ [SPECULAR TOP LIGHT: 1px rgba(255,255,255,0.7)] ░░░░░░░░░░░░ │
│  Teenage Engineering                      [16px Rounded 700]│
│  Portable Acoustic Synthesizer HMI        [18px Rounded 550]│
│  Stockholm · Spatial Audio UI · Senior    [13px Rounded 450]│
│                                                             │
│  ( AUDIO DSP )   ( HARDWARE UI )   ( C++23 )  [Glass Badges]│
│                                                             │
│ ─────────────────────────────────────────────────────────── │
│  $150/hr     Est. $36,000                 [22px SF Pro Bold]│
│  (shield) Escrow Protected                [Glass Pill Badge]│
│ ░░░░░░░░░░░░░░ [BOTTOM SHADOW: 1px rgba(0,0,0,0.06)] ░░░░░░░░░░░░░░░░░░░░░░ │
└─────────────────────────────────────────────────────────────┘
```

#### Rationale & Evaluation
- **Feeling Evoked:** Spatial depth, tactile glass physics, fluid optical feedback, next-generation Apple OS luxury.
- **Primary Axis:** Surface Depth & Luminance.
- **Right When:** Mobile touch apps, VisionOS / spatial computing interfaces, floating search capsules, sticky proposal action bars, modal sheets.
- **Costs:** GPU composition cost for `backdrop-filter: blur()`; can cause battery drain or frame drops on low-end mobile devices without fallback.

---

## 3. Comparative Trade-Off & Decision Matrix

| Dimension | 1. Curatorial Placard | 2. Swiss Neo-Grotesque | 3. Humanist Atelier | 4. Hyper-Dense Archival | 5. Tactile Liquid Glass |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Primary Axis** | Expressive Contrast | Structure & Geometry | Warmth & Voice | Density & Speed | Surface Depth |
| **Dominant Tone** | Prestigious & Curatorial| Clinical & Rigorous | Bespoke & Warm | Terminal & Technical | Tactile & Luminous |
| **Font Payload** | High (~80KB, 3 families) | Low (~25KB, 1 family) | Moderate (~50KB) | Low (~30KB) | Low (~25KB, system-ui) |
| **Information Density**| Balanced (Medium) | High | Low-Medium (Relaxed) | Extreme (Ultra-High) | Medium |
| **Right When** | Top 1% creative & tech talent; high-ticket briefs ($15k+) | Systems engineering, dev tools, Swiss modern portfolios | Luxury branding, fashion, interior, craft agency briefs | Smart contract audits, backend retainers, DevOps sprints | Floating toolbars, iOS/macOS apps, sticky bottom sheets |
| **Vulnerability** | Serif titles feel formal on mundane gig tasks | Can feel sterile and cold without impeccable white space | Slower scanning speed; high vertical consumption | Visually intimidating to non-technical business clients | Backdrop blur GPU overhead; specular contrast sensitivity |

---

## 4. Refined OKLCH Color Tokens & Mathematical Contrast Proof

### 4.1 The Brand Anchor `#EA5A36` in OKLCH
$$\mathbf{L = 0.6510, \quad C = 0.1856, \quad h = 35.10^\circ}$$

### 4.2 WCAG 2.2 AA Contrast Validation (Calculated via Relative Luminance)
Standard formula: $\text{Ratio} = \frac{L_1 + 0.05}{L_2 + 0.05}$ where $L \in [0, 1]$.

| Token | Hex Fallback | OKLCH Coordinates | Contrast on `#FFFFFF` | WCAG 2.2 AA Body ($\ge 4.5:1$) | WCAG 2.2 AA Large / UI ($\ge 3.0:1$) | Strict Design System Rule |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `--frila-color-canvas` | `#FFFFFF` | `oklch(1.000 0.000 0)` | `1.00:1` | N/A | N/A | Pure white gallery drywall |
| `--frila-color-surface-subtle` | `#FBFBFA` | `oklch(0.985 0.003 40.0)`| `1.04:1` | N/A | N/A | Card surface against canvas |
| `--frila-color-input-bg` | `#F2F2F0` | `oklch(0.960 0.005 40.0)`| `1.12:1` | N/A | N/A | Non-text form inputs |
| `--frila-color-divider` | `#E5E5E3` | `oklch(0.910 0.005 40.0)`| `1.26:1` | N/A | N/A | 1px hairline boundary |
| `--frila-color-border` | `#CECECB` | `oklch(0.820 0.008 40.0)`| `1.58:1` | N/A | N/A | Non-text interactive borders |
| `--frila-color-text-muted` | `#767571` | `oklch(0.520 0.012 40.0)`| **`4.61:1`** | **PASS (AA)** | **PASS (AAA Large)** | Metadata, sub-labels |
| `--frila-color-text-primary` | `#1B1A18` | `oklch(0.180 0.012 40.0)`| **`17.39:1`**| **PASS (AAA)** | **PASS (AAA)** | Primary body text & titles |
| `--frila-color-text-ink` | `#090908` | `oklch(0.100 0.008 40.0)`| **`19.92:1`**| **PASS (AAA)** | **PASS (AAA)** | Stark black pill CTAs |
| `--frila-color-primary-500` | `#EA5A36` | `oklch(0.651 0.186 35.1)` | **`3.49:1`** | FAIL | **PASS (AA Large & UI)** | **Button fills & $\ge 18.66\text{px}$ bold only!** |
| `--frila-color-primary-600` | `#C03710` | `oklch(0.540 0.180 35.1)` | **`5.53:1`** | **PASS (AA)** | **PASS (AAA Large)** | **Active pill press; accessible text links** |
| `--frila-color-primary-700` | `#9D2701` | `oklch(0.460 0.160 35.1)` | **`7.71:1`** | **PASS (AAA)**| **PASS (AAA)** | Small orange badges & icons |
| `--frila-color-escrow` (Refined) | `#008639` | `oklch(0.605 0.160 145.0)`| **`4.70:1`** | **PASS (AA)** | **PASS (AAA Large)** | 100% Escrow deposit badge |
| `--frila-color-warning-text` | `#9E5C00` | `oklch(0.550 0.160 70.0)` | **`5.27:1`** | **PASS (AA)** | **PASS (AAA Large)** | Expiring brief text labels |
| `--frila-color-error` | `#D82020` | `oklch(0.580 0.210 25.0)` | **`5.06:1`** | **PASS (AA)** | **PASS (AAA Large)** | Form validation error alerts |

> [!IMPORTANT]
> **The 3.49:1 Accessibility Law on `#EA5A36`:**
> 1. `#EA5A36` background with `#FFFFFF` text delivers `3.49:1` contrast ratio. Under WCAG 2.2 SC 1.4.3, text larger than `18.66px` bold (or `24px` regular) requires `3.0:1`, and SC 1.4.11 requires `3.0:1` for interactive component boundaries. Therefore, standard Frila 48px CTA pills (`Semibold 16px` with bold visual weight) pass UI boundary criteria.
> 2. Naked text rendered in `--frila-color-primary-500` against `#FFFFFF` below 18.66px bold **fails** WCAG AA. Designers and engineers MUST use `--frila-color-primary-600` (`#C03710`, `5.53:1`) or `--frila-color-primary-700` (`#9D2701`, `7.71:1`) for any uncontained inline text or micro-links.

---

## 5. Liquid Glass & Specular Translucency Specification

### 5.1 Three Glass Tiers
1. **Tier 1: Glass Regular (Interactive Utility)**
   - Used for: Floating search capsule, category scroller pill, filter chip triggers.
   - CSS: `background: rgba(255, 255, 255, 0.82); backdrop-filter: blur(20px) saturate(180%); -webkit-backdrop-filter: blur(20px) saturate(180%);`
   - Border: Top `1px solid rgba(255, 255, 255, 0.60)`, Bottom `1px solid rgba(0, 0, 0, 0.06)`.
2. **Tier 2: Glass Prominent (High-Intent Action)**
   - Used for: Sticky bottom proposal bar, active submit trigger, instant counter indicator.
   - CSS: `background: rgba(234, 90, 54, 0.92); backdrop-filter: blur(24px) saturate(200%); -webkit-backdrop-filter: blur(24px) saturate(200%); color: #FFFFFF;`
   - Border: Top `1px solid rgba(255, 255, 255, 0.35)`, Bottom `1px solid rgba(0, 0, 0, 0.20)`.
   - Ambient Glow: `box-shadow: 0 4px 20px rgba(234, 90, 54, 0.28);`
3. **Tier 3: Glass Backdrop (Modal Sheet Scrim)**
   - Used for: Modal drawer underlay, 3-step search expansion backdrop.
   - CSS: `background: rgba(15, 17, 21, 0.40); backdrop-filter: blur(16px); -webkit-backdrop-filter: blur(16px);`

### 5.2 Native iOS 26+ SwiftUI Implementation
```swift
// SwiftUI Native Liquid Glass Container Spec
import SwiftUI

struct FrilaOpportunityActionBar: View {
    let rateText: String
    let submitAction: () -> Void
    
    var body: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rateText) // FrilaMoney.rate(140, per: .hour) → "$140/hr"
                        .font(FrilaTypography.metric(size: 20)) // SF Pro, proportional digits
                        .foregroundColor(Color(hex: "1B1A18"))
                    Text("100% Escrow Secured")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "008639"))
                }
                
                Spacer()
                
                Button(action: submitAction) {
                    Text("Submit Proposal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .frame(height: 48)
                }
                .glassEffect(.prominent.tint(Color(hex: "EA5A36")).interactive(), in: .capsule)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        }
    }
}
```

---

## 6. Implementation Guide & Token Architecture

The token system is architected to allow dynamic switching via standard CSS custom properties:
```html
<!-- Swapping paradigms at runtime via dataset -->
<div data-frila-theme="swiss">      <!-- Default: Modernist Linear -->
<div data-frila-theme="curatorial"> <!-- Artsy Benchmark -->
<div data-frila-theme="atelier">    <!-- Warm Craft -->
<div data-frila-theme="archival">   <!-- Dev Terminal Console -->
<div data-frila-theme="glass">      <!-- Spatial Computing -->
```

All 5 paradigms map seamlessly to semantic layout classes:
- `.frila-placard-card`: Standard 0-shadow gallery frame.
- `.frila-entity-name`: Authoritative client / studio headline.
- `.frila-project-title`: Brief / opportunity scope name.
- `.frila-micro-label`: Archival metadata headers.
- `.frila-metric-hero`: Compensation figures (proportional digits; tabular only when animated or in a column).
- `.frila-button-primary`: 9999px high-intent commitment pill.
