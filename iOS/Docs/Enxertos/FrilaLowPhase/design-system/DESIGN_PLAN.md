# Frila Design System — Implementation & Engineering Plan

**Target:** Frila iOS & macOS Client (`FrilaDesignSystem` Swift Package) + Web Design Lab Harness  
**Author:** Design Lab & Variants Architect  
**Methodologies Combined:** `/design-lab` (Interactive exploration, Feedback overlay, States & Accessibility) & `/variants` (Primary axes, non-generic naming, Tradeoff matrix)  
**Foundations:** The Gallery-Marketplace Synthesis (Artsy Museum Placard × Airbnb Discovery Engine × OKLCH `#EA5A36` × iOS 26+ Liquid Glass)  
**Status:** Curated, Unified & Verified (`swift test` passing, 0 errors, 11/11 tests green)  

---

## 1. Summary & Winning Variant Recommendations

Through multi-axis exploration and systematic tradeoff evaluation, the following winning variants are designated for production integration into the Frila App:

| Component | Canonical Unified Component | Winning Base & Merged Traits | Production Placement | Rationale |
| :--- | :--- | :--- | :--- | :--- |
| **Typography Primitives** | **`FrilaTypography` (Swiss default)** | Swiss Neo-Grotesque (Heavy Display + Upright Medium Placard + Proportional SF Pro figures); Curatorial, Humanist, Archival and Glass stay as opt-ins | Global Typography Engine | Structural rigor with zero italic, prices that read as one word (`$140/hr`) and `FrilaTypeSpec` as the single source of truth. |
| **Component 1: OpportunityCard** | **`FrilaOpportunityCard`** | Placard (B) + Tactile Spring (D) + Glass Option (E) | Main Feed & Featured Briefs | Delivers Artsy-grade museum documentation, 3-column archival spec grid, 0-shadow gallery framing, and 44pt touch hitboxes. |
| **Component 2: SearchCapsule** | **`FrilaSearchCapsule`** | Matrix Command Bar (C) + Liquid Glass (E) | Top Global Navigation | 3 independent touch zones (*What → How → Budget*) with HIG 44pt hitboxes, instant modal jump, and `⌘K` support. |
| **Component 3: BudgetHistogram** | **`FrilaBudgetHistogram`** | Quant Matrix (C) + Magnetic Snapping (D) | Discovery Sheet Step 3 | 13 discrete distribution bars, stepped magnetic snapping ($25/step), real-time counter, and 1-tap quick presets. |
| **Component 4: Button System** | **`FrilaButton`** | Haptic Spring Pill (D) + Semantics (A, C, E) | Global Interactive CTAs | Tactile `scale(0.96)` press compression over 120ms with spring overshoot, 5 variants (.primary, .secondary, .outline, .ghost, .glass), and 3 sizes. |
| **Component 5: StickyProposalBar** | **`FrilaProposalBar`** | Floating Glass Dock (E) + Commitment Metrics (B) | Opportunity Detail View | Translucent iOS 26+ glass capsule floating above home indicator with dual-tone specular edge and progressive fee split sheet. |
| **Component 6: CreatorProfileHero** | **`FrilaCreatorProfileHero`** | Retrospective Catalog (B) + Monograph Frame (A) | Talent Creator Profile | Replaces cheap 5-star ratings with the anti-gig 3-Pillar Taxonomy (*Selected Works, Track Record, Biography*) and 44pt tab hitboxes. |

---

## 2. Implemented Code Architecture (Swift Package)

```
Sources/FrilaDesignSystem/
├── Primitives/
│   ├── FrilaColor.swift          # OKLCH #EA5A36, Achromatic Gallery, Semantic Escrow/Warning tokens
│   ├── FrilaTypography.swift     # 5 Primitive Typography Paradigms (Curatorial, Swiss, Humanist, Dense, Glass)
│   ├── FrilaGeometry.swift       # Radii (9999pt, 24pt, 16pt, 14pt, 8pt), concentric rules, HIG 44pt hitboxes
│   └── FrilaLiquidGlass.swift    # iOS 26+ .glassEffect() and specular highlight modifiers
├── Components/
│   ├── FrilaButtonVariants.swift       # Brand Primary Pill, Stark Ink, Outlined, Ghost, Passive Status Chips
│   ├── OpportunityCardVariants.swift   # Quiet, Placard, Dense, Tactile, and Glass Opportunity Cards
│   ├── SearchCapsuleVariants.swift     # 3-segment floating search capsule with progressive discovery
│   ├── BudgetHistogramVariants.swift   # Dual-handle draggable rate distribution histogram
│   ├── ProposalBarVariants.swift       # Sticky proposal action bar with rate breakdown
│   └── CreatorProfileVariants.swift    # Anti-gig 3-pillar creator profile
└── DesignLab/
    ├── FrilaDesignLabView.swift  # Master interactive SwiftUI Design Lab & switcher view
    ├── DesignLabFeedback.swift   # Feedback overlay store, pin manager, and Markdown exporter
    └── DesignLabFixtures.swift   # Realistic test data fixtures

Tests/FrilaDesignSystemTests/
└── FrilaDesignSystemTests.swift  # 4 test suites: Typography, Geometry, WCAG AA Contrast, and Feedback Exporter
```

---

## 3. Component APIs & Usage Guidelines

### 3.1 `OpportunityCardPlacard` (Curatorial Monograph)
```swift
import SwiftUI
import FrilaDesignSystem

OpportunityCardPlacard(
    item: OpportunityItem(
        id: "brief-01",
        client: "Vercel Labs",
        title: "NextGen Multi-Modal Autonomous Agent Canvas",
        scope: "Design Systems & Architecture",
        duration: "3-6 Months Retainer",
        seniority: "Staff Level",
        rateHourly: 140,
        totalBudget: 33600,
        escrowVerified: true
    ),
    isDark: false
)
```

### 3.2 `FrilaPillButtonStyle`
```swift
// Primary High-Intent Brand Action
Button("Accept Brief") {
    // Commit action
}
.buttonStyle(FrilaPillButtonStyle(variant: .primary))

// Asymmetric Dismissive Alternative (14pt spacing)
HStack(spacing: FrilaGeometry.space14) {
    Button("Decline") { }
        .buttonStyle(FrilaPillButtonStyle(variant: .ghost))
    
    Button("Submit Proposal") { }
        .buttonStyle(FrilaPillButtonStyle(variant: .primary))
}
```

### 3.3 `FrilaLiquidGlass`
```swift
VStack {
    Text("Floating Search Capsule")
}
.padding(.horizontal, 20)
.padding(.vertical, 12)
.frilaLiquidGlass(tier: .regular, cornerRadius: FrilaGeometry.radiusPill, isInteractive: true)
```

---

## 4. Accessibility (WCAG 2.2 AA) & Human Interface Verification

- [x] **Mathematical Contrast Verification:**
  - Charcoal Primary Text (`#1B1A18`) on Canvas (`#FFFFFF`): **17.39:1** (Passes AAA).
  - Secondary Metadata Text (`#767571`) on Canvas: **4.61:1** (Passes AA).
  - Escrow Verified Badge (`#008639`) on Canvas: **4.70:1** (Passes AA).
  - Warning Text (`#9E5C00`) on Canvas: **5.27:1** (Passes AA).
  - Brand Anchor `#EA5A36` on White: **3.49:1** (Passes UI component boundaries $\ge 3.0:1$ and large bold text $\ge 18.66\text{px}$; body text under 18pt is strictly forbidden in `#EA5A36`).
- [x] **Touch Target Hitbox Verification:**
  - All interactive buttons, chips, and sliders enforce `FrilaGeometry.hitboxMinimum` ($44 \times 44\text{pt}$).
- [x] **Keyboard & VoiceOver:**
  - Tab navigation with accessible `focusEffect` rings.
  - Informational badges pair colors with a text label (optionally led by an SF Symbol such as `checkmark.shield.fill`) ensuring zero meaning rides on color alone. No emoji or text glyphs as icons.
- [x] **Reduced Motion Support:**
  - Respects `@Environment(\.accessibilityReduceMotion)`.

---

## 5. Engineering Next Steps

1. **Host App Integration:** Add `FrilaDesignSystem` as a local Swift Package dependency in the main iOS/macOS workspace.
2. **Asset Catalog Integration:** Connect high-resolution artwork bundles to `OpportunityCard` previews.
3. **Observation & ViewModel Binding:** Wire `BudgetHistogramView` handles to the backend query pipeline.
4. **Liquid Glass Polish:** Verify runtime metal shader rendering under iOS 26+ and visionOS preview devices.
