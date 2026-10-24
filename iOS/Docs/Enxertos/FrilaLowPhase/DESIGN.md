# Frila — Design Primitives & Visual Identity Specification
**Product:** Frila (FindJob & Opportunities Marketplace for Freelancers)  
**Document:** `DESIGN.md` — Core Design Primitives (Zero-Flow / Zero-Navigation Foundation)  
**Color Anchor:** `#EA5A36` (Governed by OKLCH: `oklch(0.6510 0.1856 35.10deg)`)  
**Curated References:**  
- **Genie App (App ID 289):** Pill Button Hierarchies, Spacing Asymmetry, Continuous Corner Radius.  
- **Artsy (App ID 218):** Museum-Wall Achromatic Canvas (`#FFFFFF`), Zero Card Shadows, Placard Typography.  
- **Airbnb (App ID 2):** Floating 999px Capsule Geometry, Ambient Translucent Overlays.  
- **iOS 26+ Liquid Glass:** Native Glass Shader Modifiers, Specular Reflections & Translucency Tiers.  

---

## 1. Design Philosophy & Primitives Manifesto

Frila rejects the visual degradation common to traditional freelance gig platforms (cluttered drop-shadows, 5-star rating traps, promotional badges, loud gradients). Frila treats freelance work, technical projects, and creative talent with the dignity of an **editorial gallery** paired with the precision of a **modern OS interface**.

This document specifies the **atomic visual primitives**: colors, typography, hairlines, corner radii, elevation, button hierarchies, spacing grids, and liquid glass shaders. Screen layouts and navigation flows are intentionally excluded.

---

## 2. Color System & Tokens (Governed by OKLCH)

The primary brand color `#EA5A36` is anchored in the perceptual OKLCH color space:
$$\mathbf{L = 0.6510, \quad C = 0.1856, \quad h = 35.10^\circ}$$

### 2.1 Primary Brand Tonal Scale (OKLCH)
Strictly reserved for **primary high-intent actions, active selection capsules, focus rings, and verified highlights**. Never used as full-screen wallpaper or card background fill.

| Token | OKLCH Value | sRGB Fallback | Role & Purpose |
| :--- | :--- | :--- | :--- |
| `--frila-color-primary-50` | `oklch(0.970 0.020 35.1)` | `#FFF1EC` | Subtle active chip background, selection tint |
| `--frila-color-primary-100` | `oklch(0.930 0.050 35.1)` | `#FFDDD2` | Interactive chip hover surface, badge background |
| `--frila-color-primary-200` | `oklch(0.850 0.100 35.1)` | `#FFB6A1` | Secondary outline accent, soft focus glow |
| `--frila-color-primary-300` | `oklch(0.760 0.150 35.1)` | `#FF8B6D` | Graphic detail, disabled state outline |
| `--frila-color-primary-400` | `oklch(0.680 0.180 35.1)` | `#F26643` | Primary button hover state |
| `--frila-color-primary-500` | `oklch(0.651 0.186 35.1)` | **`#EA5A36`** | **Brand Anchor: Primary CTA, active pill, brand mark** |
| `--frila-color-primary-600` | `oklch(0.540 0.180 35.1)` | `#C03710` | Primary button pressed/active state |
| `--frila-color-primary-700` | `oklch(0.460 0.160 35.1)` | `#9D2701` | Accessible high-contrast text on light surfaces |
| `--frila-color-primary-800` | `oklch(0.380 0.130 35.1)` | `#781D03` | Deep brand glyph, iconography accent |
| `--frila-color-primary-900` | `oklch(0.290 0.090 35.1)` | `#4F1506` | Dark mode brand surface highlight |
| `--frila-color-primary-950` | `oklch(0.200 0.060 35.1)` | `#2C0903` | Deepest brand baseline |

### 2.2 Achromatic Gallery Wall Palette
Adheres to Artsy's museum-wall discipline: the interface is pure and quiet so that the work, portfolio pieces, and contract scopes supply 100% of the chromatic vibrancy.

| Token | Value (OKLCH / Hex) | Role & Surface Assignment |
| :--- | :--- | :--- |
| `--frila-color-canvas` | `oklch(1.000 0 0)` / `#FFFFFF` | Pure White Gallery Wall: App background across all screens |
| `--frila-color-surface-subtle` | `oklch(0.985 0.003 40.0)` / `#FBFBFA` | Subtle Card Surface: Nested blocks, grouped lists |
| `--frila-color-surface-input` | `oklch(0.960 0.005 40.0)` / `#F2F2F0` | Input Fields & Suggestion Chips (Genie pattern) |
| `--frila-color-hairline` | `oklch(0.910 0.005 40.0)` / `#E5E5E3` | 1px Architectural Divider: Non-intrusive section bounds |
| `--frila-color-border` | `oklch(0.820 0.008 40.0)` / `#CECECB` | Interactive Outlined Buttons & Unfocused Controls |
| `--frila-color-text-muted` | `oklch(0.520 0.012 40.0)` / `#767571` | Secondary Metadata: Dates, studio names, status chips |
| `--frila-color-text-primary` | `oklch(0.180 0.012 40.0)` / `#1B1A18` | Primary Body Text, Display Headlines, Client Names |
| `--frila-color-text-ink` | `oklch(0.100 0.008 40.0)` / `#090908` | Stark Solid Pill CTA alternative (Artsy/Genie style) |

### 2.3 Semantic Accents
- **Escrow Verified (`--frila-color-escrow`):** `oklch(0.620 0.160 145.0)` / `#008A3B` (Emerald trust indicator).
- **Expiring Opportunity (`--frila-color-warning`):** `oklch(0.650 0.150 75.0)` / `#C97A00` (Warm amber).
- **Error / Voided (`--frila-color-error`):** `oklch(0.580 0.210 25.0)` / `#D82020` (Crimson indicator).

---

## 3. Typography System: The Museum Placard Convention

Inspired by Artsy's fine-art placard documentation (`7359672b`) combined with modern iOS typography.

```
┌─────────────────────────────────────────────────────────────────┐
│  VERCEL LABS                              [Bold Sans / SF Pro]      │
│  NextGen Agent Orchestrator, 2026         [Medium Sans, upright]    │
│                                                                 │
│  SCOPE       SENIORITY      TIMELINE      [Uppercase micro-label]   │
│  Full-stack  Staff Level    3 Months                            │
│                                                                 │
│  $140/hr     Est. $22,400                 [Proportional SF Pro]     │
└─────────────────────────────────────────────────────────────────┘
```

### 3.0 Default Paradigm: Swiss Neo-Grotesque
`FrilaTypography()` resolves to **Swiss** (`TypographyParadigm.swiss`, the first case), and every static token (`display`, `title`, `placard`, `entity`, `metric*`) mirrors the Swiss scale. The other four paradigms (Curatorial, Humanist, Archival, Glass) remain available as explicit opt-ins and follow the same rules below.

Every role is described by a `FrilaTypeSpec` (`size`, `weight`, `design`, `digits`, `tracking`) and the `Font` is derived from it (`displayHeadlineSpec`, `placardTitleSpec`, `clientEntitySpec`, `microLabelSpec`, `metricHeroSpec`, `bodySpec`). Apply font and tracking together with `.frilaType(spec)`.

### 3.1 Strict 3-Font-Family Architectural Limit (`better-typography`)
To prevent visual cacophony and ensure pure pairing contrast, the Frila Design System enforces a **strict maximum limit of 3 font families** across all 30 component variations:

| Font Family | Apple HIG Implementation | System Assignment | Justification (`better-typography`) |
| :--- | :--- | :--- | :--- |
| **1. Primary Sans** | `Font.Design.default` (SF Pro) | Client names, body text, buttons, primary UI | Crisp neutral structure, maximum legibility, dynamic type |
| **2. Editorial Serif** | `Font.Design.serif` (New York, **upright only**) | Placard brief titles in Curatorial/Humanist, curatorial subtitles | High-culture distinction, provenance, authentic gallery feel |
| **3. Archival Monospace** | `Font.Design.monospaced` (SF Mono) | Micro-labels, contract telemetry, status codes | Archival museum inventory code feel. **Never for prices** |

> **Prohibited 4th Families:** The `.rounded` design (SF Pro Rounded) is **strictly forbidden**. Pairing SF Pro with SF Pro Rounded violates the core typography rule (*"Pair for contrast, not similarity — two near-identical sans-serifs read as a mistake"*).

> **No Italic — Ever:** Italic is forbidden in every paradigm, for serif (New York) and sans (oblique SF Pro) alike. Placard titles are upright: Swiss/Glass use SF Pro Medium, Curatorial/Humanist use New York upright, Archival uses SF Mono. `FrilaTypeSpec` has no italic field, so the token layer cannot express it; do not add `.italic()` in components either.

### 3.2 Accessibility Floor & Legibility Rules (`better-accessibility`)
- **Micro-Label Floor:** Sub-accessible text (8pt, 9pt) is strictly eliminated. Micro-labels must be at least **10pt–11pt Bold** (SF Pro in Swiss/Humanist, SF Mono in Curatorial/Archival/Glass), always styled with uppercase transformation and positive tracking (`+0.8` to `+1.2pt`).
- **Figures Law (proportional by default, tabular only when it moves or stacks):**
  - **Proportional (`digits: .proportional`)** — every static figure, **including the hero price**. Tabular digits at 19–24pt open visible holes around narrow digits (`1`, `7`), so `$140` reads as `$ 1 4 0`. Hero metrics use SF Pro in every paradigm (Archival included — SF Mono stays for labels and codes) with slightly negative tracking (`-0.4` at 22pt, `-0.5` for heavy).
  - **Tabular (`digits: .tabular`)** — only values that **animate** (slider readouts, live counters, histogram markers while dragging) or **align in a column** (ledgers, breakdown tables). Use `FrilaTypography.metricTabular`, `metricTabular(size:weight:)`, `metricHeroSpec.withDigits(.tabular)` or `.frilaMetric(digits: .tabular)`.
- **Money Formatting:** Prices are USD formatted with a fixed `en_US` locale through `FrilaMoney` — `total(33600)` → `$33,600`, `rate(140, per: .hour)` → `$140/hr`, `estimate(33600)` → `Est. $33,600`. Never interpolate numbers into a `Text` literal (`Text("Est. $\(amount)")` becomes a `LocalizedStringKey` and groups digits with the device locale, e.g. `$33.600` on pt-BR). The canonical unit is `/hr` — not `/ hr`, `/h` or `/HR`.
- **Price Display:** Use `FrilaPriceTag` (value in the hero metric + smaller muted unit on the first baseline + optional estimate). It never wraps (`lineLimit(1)`, horizontal `fixedSize`, `layoutPriority(1)`).
- **Reading Comfort:** Body copy is bounded to 15pt with 1.5 line-height for effortless scanning.

### 3.3 Semantic Type Scale
```swift
/* Static tokens mirror the Swiss (default) paradigm; *Spec twins expose the FrilaTypeSpec */

/* Display / Hero Headline */
FrilaTypography.display        // 34pt Heavy Sans (-1.2 tracking)   · displaySpec

/* Section Title */
FrilaTypography.title          // 20pt Bold Sans (-0.3 tracking)    · titleSpec

/* Museum Placard Brief Title (upright, never italic) */
FrilaTypography.placard        // 18pt Medium Sans                  · placardSpec

/* Client / Creator Entity Name */
FrilaTypography.entity         // 16pt Bold Sans                    · entitySpec

/* Body Text Regular */
FrilaTypography.body           // 15pt Regular Sans (1.5 line-height)

/* Secondary Metadata / Subtitles */
FrilaTypography.caption        // 13pt Regular Sans (Muted)
FrilaTypography.captionMedium  // 13pt Medium Sans
FrilaTypography.captionBold    // 13pt Bold Sans

/* Archival Uppercase Micro-Label */
FrilaTypography.micro          // 11pt Regular Mono (+0.8 tracking)
FrilaTypography.microBold      // 11pt Bold Mono (+1.0 tracking, Uppercase)

/* Financial Metrics & Hourly Rates — SF Pro, proportional digits */
FrilaTypography.metric         // 22pt Heavy Sans (-0.5 tracking)   · metricSpec
FrilaTypography.metricCompact  // 17pt Bold Sans (-0.2 tracking)    · metricCompactSpec
FrilaTypography.metric(size:weight:)

/* Animated or column-aligned figures only — SF Pro, tabular digits */
FrilaTypography.metricTabular  // 22pt Heavy Sans (tnum)            · metricTabularSpec
FrilaTypography.metricTabular(size:weight:)

/* Action Buttons & Pills */
FrilaTypography.button         // 15pt Semibold Sans
```

---

## 4. Corner Radius & Spatial Geometry (Genie Benchmark)

Inspected empirically from **Genie App (App ID 289, screens `d5d39326`, `bc0a303e`)**:
Genie prioritizes organic, friendly, yet rigorous capsule-geometry. Every button and interactive control feels approachable, highly tactile, and completely free of harsh, sharp corners.

### 4.1 Corner Radii Hierarchy
```css
--frila-radius-pill:   9999px; /* Primary Buttons, Chips, Search Capsules, Status Badges */
--frila-radius-sheet:  24px;   /* Modal Bottom Sheets, Drawer Panels */
--frila-radius-card:   16px;   /* Media Preview Containers, Opportunity Cards */
--frila-radius-input:  14px;   /* Text Input Fields, Steppers */
--frila-radius-nested: 8px;    /* Nested interior badges */
```

### 4.2 Concentric Radius Rule
To prevent optical dissonance when nesting curved surfaces:
$$\mathbf{R_{\text{outer}} = R_{\text{inner}} + \text{Padding}}$$
*Example:* A `16px` card containing an image preview with `8px` interior padding uses an inner image radius of `8px` ($16 - 8 = 8$).

---

## 5. Button System & Interactive Hierarchies (Genie App Synthesis)

From Genie's empirical screens, button hierarchy is established through **visual weight asymmetry** and **deliberate spacing** rather than noisy borders.

```
       [ Decline ]      [      Accept      ]
     (Ghost / Text)      (Solid Pill #EA5A36)
      Gap: 14px          Height: 44px
```

### 5.1 Button Types & Specifications

#### A. Primary Action Button (Brand Prominent)
- **Role:** High-intent commitment (`Apply for Brief`, `Submit Proposal`, `Accept Opportunity`).
- **Geometry:** Height `48px` (desktop/modal: `52px`), `border-radius: 9999px` (Full Capsule).
- **Padding:** `14px 24px` (minimum horizontal padding).
- **Colors:** Fill `#EA5A36` (`--frila-color-primary-500`), Label `#FFFFFF` (Semibold 16pt).
- **Tactile Feedback:** `transform: scale(0.97)` on active press, with smooth spring transition (`cubic-bezier(0.16, 1, 0.3, 1)`).
- **Shadow:** Optional subtle colored ambient glow: `0 4px 14px rgba(234, 90, 54, 0.20)`.

#### B. Primary Neutral Button (Stark Ink — Artsy/Genie "Get Started")
- **Role:** General onboarding, high-contrast utility commitments.
- **Geometry:** Height `48px`, `border-radius: 9999px`.
- **Colors:** Fill `#1B1A18` (`--frila-color-text-primary`), Label `#FFFFFF` (Semibold 16pt).
- **Tactile Feedback:** `scale(0.97)` on active press.

#### C. Secondary Outlined Button (Genie "Invite" Pattern)
- **Role:** Secondary actions (`Follow`, `Save for Later`, `View Details`).
- **Geometry:** Height `40px` (or `44px`), `border-radius: 9999px`.
- **Colors:** Background `#FFFFFF` (or `transparent`), Border `1px solid #CECECB`, Label `#1B1A18` (Medium 15pt).
- **Hover/Active:** Background fills with `--frila-color-surface-subtle` (`#FBFBFA`).

#### D. Tertiary / Ghost Button (Genie "Decline" Pattern)
- **Role:** Dismissive or alternative actions paired with a primary CTA.
- **Geometry:** Height `44px` (maintaining $44\times 44\text{pt}$ minimum hitbox), no border, no fill.
- **Colors:** Label `#767571` (`--frila-color-text-muted`), Medium 15pt.
- **Active State:** Opacity `0.70`.

#### E. Passive Status Chip (Genie "Sent" Pattern) — `FrilaStatusChip`
- **Role:** Informational non-clickable indicator (`Pending`, `Sent`, `Under Review`, `100% Escrow`).
- **API:** `FrilaStatusChip(_ text:, style: .neutral | .escrow | .warning, systemImage: String? = nil, isDark: Bool = false)`.
- **Geometry:** Height `FrilaGeometry.chipHeight` (`28pt`), horizontal padding `chipPaddingHorizontal` (`12pt`), capsule. Non-interactive, so exempt from the 44pt hitbox.
- **Type:** `FrilaTypography.captionMedium` (13pt Medium Sans), single line.
- **Icon (optional):** a leading SF Symbol at `chipIconSpacing` (`4pt`), inheriting the chip font with `.imageScale(.small)` so its stroke weight matches the label; `accessibilityHidden(true)` because the text carries the meaning.
- **Colors (tokens only):** Neutral = `FrilaColor.dynamicInputBg` fill + `dynamicTextMuted` text; Escrow = `escrowBg` + `escrow`; Warning = `warningBg` + `warningText`. Non-reactive to hover/press.

> **No Emoji or Glyphs as Icons:** Badges, chips and pills never carry emoji (`🛡️`, `⏳`) or text glyphs (`●`, `★`, `✓`) as icons. Use an SF Symbol through the component's `systemImage` parameter (e.g. `checkmark.shield.fill`, `hourglass`). Status meaning is carried by the text label plus color, never by color alone.

### 5.2 Button Layout & Pairings Rules
1. **Asymmetric Spacing:** When pairing a negative/dismissive action with a positive action, the tertiary text button sits to the left with a `14px` gap, giving the right-hand primary pill dominant optical attraction.
2. **Full-Width vs. Compact:** Detail sheets use full-width primary buttons; list rows use compact pill buttons (`height: 36px`, `padding: 6px 16px`).

---

## 6. Liquid Glass & Translucency Primitives (iOS 26+ SwiftUI & Web)

Frila incorporates modern Apple Liquid Glass specifications (`swiftui-liquid-glass` skill) for floating toolbars, sticky action footers, and modal backdrops, keeping the gallery content visible underneath.

### 6.1 Glass Tiers & Prominence

| Glass Tier | SwiftUI iOS 26+ API | CSS / Web Standard Fallback | Usage in Frila |
| :--- | :--- | :--- | :--- |
| **Glass Regular** | `.glassEffect(.regular.interactive())` | `backdrop-filter: blur(20px) saturate(180%); background: rgba(255, 255, 255, 0.82);` | Floating Search Pill, Sticky Proposal Bar |
| **Glass Prominent** | `.glassEffect(.prominent.tint(Color(hex: "EA5A36")).interactive())` | `backdrop-filter: blur(24px); background: rgba(234, 90, 54, 0.90);` | Floating High-Intent Action Triggers |
| **Glass Backdrop** | `.glassEffect(.thin)` | `backdrop-filter: blur(16px); background: rgba(0, 0, 0, 0.25);` | Modal Sheet Dimming / Backdrop Scrim |

### 6.2 Cohesive Grouping with `GlassEffectContainer`
When multiple glass elements coexist (e.g. back button, share icon, and floating search pill), they must be wrapped in a shared container to prevent conflicting specular refraction layers:

```swift
// SwiftUI Native Glass Specification
GlassEffectContainer(spacing: 16) {
    HStack(spacing: 12) {
        Button(action: openSearch) {
            Text("Search opportunities...")
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        
        Button(action: openFilters) {
            Image(systemName: "slider.horizontal.3")
        }
        .glassEffect(.regular.interactive(), in: .circle)
    }
}
```

### 6.3 Specular Edge Highlight (CSS Implementation)
All glass surfaces in Frila possess an ultra-fine, optical 2-tone border:
```css
.frila-glass-surface {
  background: rgba(255, 255, 255, 0.82);
  backdrop-filter: blur(20px) saturate(180%);
  -webkit-backdrop-filter: blur(20px) saturate(180%);
  border-top: 1px solid rgba(255, 255, 255, 0.60);    /* Top specular light catch */
  border-bottom: 1px solid rgba(0, 0, 0, 0.06);        /* Bottom contact grounding */
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.05);
}
```

---

## 7. Elevation, Borders & The "0-Shadow" Gallery Rule

- **The "0-Shadow" Rule:** Project and opportunity cards have **zero box-shadow**. They sit directly on the `#FFFFFF` canvas, separated only by generous negative space and a crisp `1px #E5E5E3` hairline.
- **Image Edge Outlines:** To prevent photographic creative assets from bleeding into the pure white canvas:
  ```css
  .frila-media-preview {
    outline: 1px solid rgba(0, 0, 0, 0.08);
    outline-offset: -1px;
    border-radius: var(--frila-radius-card);
  }
  ```
- **Utility Shadows Only:**
  - Floating Search Capsule: `0 4px 14px rgba(0, 0, 0, 0.08)`
  - Sticky Bottom Action Bar: `0 -1px 0 var(--frila-color-hairline), 0 -4px 16px rgba(0, 0, 0, 0.03)`

---

## 8. Spacing Grid & Human Interface Touch Targets

Based on the 4pt/8pt fluid spatial system:

```css
--frila-space-2:   2px;
--frila-space-4:   4px;
--frila-space-8:   8px;   /* Intra-component gap (icon to text) */
--frila-space-12:  12px;  /* Tag & chip spacing */
--frila-space-16:  16px;  /* Standard mobile screen margin & row gap */
--frila-space-20:  20px;  /* Card interior padding */
--frila-space-24:  24px;  /* Major section separation */
--frila-space-32:  32px;  /* Headline to content block */
--frila-space-48:  48px;  /* Section rhythm spacing */

/* Human Interface Guideline: Strict 44pt minimum hitbox */
--frila-hitbox-min: 44px;
```

---

## 9. Micro-Interactions & Craft Physics

Governed by the `make-interfaces-feel-better` principles:
- **Button Press:** `transform: scale(0.97)` over `120ms` with `ease-out`.
- **Spring Curve:** `cubic-bezier(0.16, 1, 0.3, 1)` for sheet expansions and modal slides.
- **Optical Alignment Offset:** Center-aligned arrow and chevron icons are nudged `+0.5px` or `+1px` horizontally to account for asymmetric visual mass.
- **Font Smoothing:** Enforced globally:
  ```css
  html, body {
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
    text-rendering: optimizeLegibility;
  }
  ```
