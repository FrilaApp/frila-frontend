import SwiftUI
#if canImport(CoreText)
import CoreText
#endif
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Font Loader (CoreText Registration with Graceful Fallback)

public enum FrilaLPEFontLoader {
    /// Enxerto: as fontes moram no bundle do FrilaApresentacao com o prefixo `FrilaLPE-`.
    /// Regular e Bold são as mesmas do app; registrar de novo falha sem efeito.
    private static let registradas: Void = {
        #if canImport(CoreText)
        for nome in ["Regular", "Medium", "Bold", "ExtraBold"] {
            guard let url = bundleApresentacao.url(forResource: "FrilaLPE-BricolageGrotesque-\(nome)", withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        #endif
    }()

    public static func registerFontsIfNeeded() {
        _ = registradas
    }
}

/// Enxerto: substitui `FrilaLPEFonteDoSistema.fonte(size:)` da origem. No tamanho padrão de texto o resultado é o mesmo;
/// nos demais tamanhos acompanha o texto do sistema, como pede a regra 7 do `conferir-textos.sh`.
///
/// A fonte do sistema sai de `Font.custom(_:size:relativeTo:)`, que o SwiftUI reescala quando o
/// tamanho de texto muda com o app aberto (um `UIFont` medido uma vez ficava parado nos `static let`
/// de `FrilaLPETypography`, e a auditoria de acessibilidade apontava o título, a etapa e os botões
/// do estúdio como "Dynamic Type unsupported"). Serif e mono não têm nome de família fixo e seguem
/// medidos pela métrica do estilo mais próximo.
public enum FrilaLPEFonteDoSistema {
    public static func fonte(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let estilo = FrilaLPETypeScaleStep.nearest(to: size).textStyle
        guard design != .default else {
            return Font.custom(".AppleSystemUIFont", size: size, relativeTo: estilo).weight(weight)
        }
        var base = UIFont.systemFont(ofSize: size, weight: pesoUIKit(weight))
        if let desenho = desenhoUIKit(design), let descritor = base.fontDescriptor.withDesign(desenho) {
            base = UIFont(descriptor: descritor, size: size)
        }
        return Font(UIFontMetrics(forTextStyle: estiloUIKit(estilo)).scaledFont(for: base) as CTFont)
    }

    private static func estiloUIKit(_ estilo: Font.TextStyle) -> UIFont.TextStyle {
        switch estilo {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }

    private static func pesoUIKit(_ weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }

    private static func desenhoUIKit(_ design: Font.Design) -> UIFontDescriptor.SystemDesign? {
        switch design {
        case .serif: .serif
        case .monospaced: .monospaced
        case .rounded: .rounded
        default: nil
        }
    }
}

// MARK: - 0. Modular Type Scale (Mathematical Foundation)

/// Multiplier ratio options for typographic scaling based on classical harmonic intervals.
public enum FrilaLPETypeScaleRatio: Double, CaseIterable, Sendable, Identifiable {
    /// Minor Third (1.200 / 6:5): Canonical Frila Standard.
    /// Balanced for high-density mobile UI, curatorial legibility, and integer-point rendering.
    case minorThird = 1.200
    /// Major Second (1.125 / 9:8): Compact Archival density for high-throughput tables.
    case majorSecond = 1.125
    /// Major Third (1.250 / 5:4): High-contrast editorial display.
    case majorThird = 1.250
    /// Perfect Fourth (1.333 / 4:3): Large museum placard exhibitions.
    case perfectFourth = 1.333

    public var id: Double { rawValue }

    public var displayName: String {
        switch self {
        case .minorThird: return "Minor Third (1.200, Canonical)"
        case .majorSecond: return "Major Second (1.125, Archival)"
        case .majorThird: return "Major Third (1.250, Editorial)"
        case .perfectFourth: return "Perfect Fourth (1.333, Placard)"
        }
    }
}

/// The 7 Canonical Steps of the Frila Modular Type Scale.
/// All font sizes in the design system strictly map to one of these 7 harmonic steps.
/// Mathematical anchor: Base = 15pt (Step 0), Ratio = Minor Third (1.200).
/// Eliminates fractional points (10.5, 13.5, 14.5) and chaotic ad-hoc font sizes.
public enum FrilaLPETypeScaleStep: Int, CaseIterable, Sendable, Comparable, Identifiable {
    /// Step -2: 11pt: WCAG 2.2 AA legibility floor for micro labels, status chips, metadata.
    case micro = -2
    /// Step -1: 13pt: Captions, secondary info, timestamps, /h unit suffixes.
    case caption = -1
    /// Step 0: 15pt: Canonical base: body copy, buttons, client entities.
    case body = 0
    /// Step +1: 18pt: Museum placard artwork titles, monograph names.
    case placard = 1
    /// Step +2: 22pt: Section titles, hero monetary values (R$ 160/h).
    case title = 2
    /// Step +3: 26pt: Large section headers, dense display headlines.
    case titleLarge = 3
    /// Step +4: 32pt: Hero display headlines, discovery engine banners.
    case display = 4

    public var id: Int { rawValue }

    public static func < (lhs: FrilaLPETypeScaleStep, rhs: FrilaLPETypeScaleStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Exact point size in points (pt), rounded to the nearest integer to guarantee
    /// crisp pixel alignment and avoid sub-pixel antialiasing smearing.
    public var pointSize: CGFloat {
        switch self {
        case .micro: return 11
        case .caption: return 13
        case .body: return 15
        case .placard: return 18
        case .title: return 22
        case .titleLarge: return 26
        case .display: return 32
        }
    }

    /// Theoretical unrounded calculation: 15.0 * (1.200 ^ step)
    public var theoreticalSize: Double {
        15.0 * pow(FrilaLPETypeScaleRatio.minorThird.rawValue, Double(rawValue))
    }

    public var stepLabel: String {
        switch self {
        case .micro: return "Step -2 (11pt)"
        case .caption: return "Step -1 (13pt)"
        case .body: return "Step 0 (15pt Base)"
        case .placard: return "Step +1 (18pt)"
        case .title: return "Step +2 (22pt)"
        case .titleLarge: return "Step +3 (26pt)"
        case .display: return "Step +4 (32pt)"
        }
    }

    /// The canonical Apple HIG `Font.TextStyle` corresponding to this scale step.
    /// Enables native Dynamic Type non-linear accessibility scaling curves across iOS 26+ and macOS 14+.
    ///
    /// Correspondence table:
    /// - `.micro` (11pt) <-> `.caption2` (11pt default on Apple platforms)
    /// - `.caption` (13pt) <-> `.footnote` (13pt default on Apple platforms)
    /// - `.body` (15pt) <-> `.body` (primary reading curve; 15pt nominal in subheadline)
    /// - `.placard` (18pt) <-> `.title3` (20pt default on Apple platforms)
    /// - `.title` (22pt) <-> `.title2` (22pt default on Apple platforms)
    /// - `.titleLarge` (26pt) <-> `.title` (28pt default on Apple platforms)
    /// - `.display` (32pt) <-> `.largeTitle` (34pt default on Apple platforms)
    public var textStyle: Font.TextStyle {
        switch self {
        case .micro: return .caption2
        case .caption: return .footnote
        case .body: return .body
        case .placard: return .title3
        case .title: return .title2
        case .titleLarge: return .title
        case .display: return .largeTitle
        }
    }

    /// Spoken human-readable name of the Apple HIG text style correspondence.
    public var textStyleName: String {
        switch self {
        case .micro: return ".caption2 (11pt HIG)"
        case .caption: return ".footnote (13pt HIG)"
        case .body: return ".body (17pt HIG / 15pt Subheadline)"
        case .placard: return ".title3 (20pt HIG)"
        case .title: return ".title2 (22pt HIG)"
        case .titleLarge: return ".title (28pt HIG)"
        case .display: return ".largeTitle (34pt HIG)"
        }
    }

    /// Finds the nearest canonical scale step for any arbitrary point size.
    public static func nearest(to size: CGFloat) -> FrilaLPETypeScaleStep {
        allCases.min(by: { abs($0.pointSize - size) < abs($1.pointSize - size) }) ?? .body
    }

    /// Dynamic Type font adhering to Apple HIG non-linear accessibility scaling curves.
    /// Automatically expands or contracts with system accessibility text size settings.
    public func dynamicFont(
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        Font.system(textStyle, design: design).weight(weight)
    }
}

// MARK: - 1. Canonical Font Families (Max 3 Families)

/// The 3 Canonical Font Families of the Frila Design System.
/// Strictly capped at 3 families to maintain pristine curatorial restraint,
/// eliminate visual cacophony, and guarantee predictable rendering across variations.
/// (Governed by better-typography: "Rarely use more than three fonts. Weight and size define hierarchy.")
public enum FrilaLPEFontFamily: String, CaseIterable, Sendable, Identifiable {
    /// 1. SF Pro (Modern Sans-Serif / Grotesque): Modernist architectural canvas,
    /// authoritative client titles, structured UI, navigation, buttons, prices and Liquid Glass surfaces.
    case sans = "SF Pro (Sans-Serif)"

    /// 2. New York (Editorial Serif, always upright): Contemplative museum placard project titles,
    /// artist monograph subtitles, and editorial cultural distinction.
    case serif = "New York (Editorial Serif)"

    /// 3. SF Mono (Archival Monospace): Technical specifications, contract tags and
    /// uppercase micro-labels (SCOPE, TIMELINE, BUDGET). Never used for prices.
    case mono = "SF Mono (Archival Monospace)"

    public var id: String { rawValue }

    public var design: Font.Design {
        switch self {
        case .sans: return .default
        case .serif: return .serif
        case .mono: return .monospaced
        }
    }

    public var appleDesignName: String {
        switch self {
        case .sans: return "default"
        case .serif: return "serif"
        case .mono: return "monospaced"
        }
    }
}

// MARK: - 2. Type Spec (Single Source of Truth)

/// Declarative description of one typographic role.
///
/// Every `Font` exposed by `FrilaLPETypography` is derived from a spec, so tests and
/// tooling can inspect size, weight, design, digit style and tracking, which an
/// opaque `Font` does not allow.
///
/// There is deliberately **no italic/oblique field**: italic is forbidden in Frila
/// (serif and sans alike), so a spec cannot express it by construction.
public struct FrilaLPETypeSpec: Hashable, Sendable {
    /// How digits are spaced.
    public enum Digits: Hashable, Sendable {
        /// Natural digit widths. Default for static values, including hero prices:
        /// tabular figures open visible gaps between digits at display sizes.
        case proportional
        /// Fixed-width digits (`tnum`). Only for values that animate or align in a
        /// column: histogram markers, slider readouts, counters, ledgers.
        case tabular
    }

    public let size: CGFloat
    public let weight: Font.Weight
    public let design: Font.Design
    public let digits: Digits
    /// Letter-spacing in points, applied with `.tracking(_:)` (see `View.frilaLPEType(_:)`).
    public let tracking: CGFloat
    /// Explicit Apple HIG text style for Dynamic Type scaling, or nil to infer from `size`.
    public let customTextStyle: Font.TextStyle?
    /// Custom font family or PostScript name (e.g. Bricolage Grotesque)
    public let customFontName: String?

    public init(
        size: CGFloat,
        weight: Font.Weight,
        design: Font.Design = .default,
        digits: Digits = .proportional,
        tracking: CGFloat = 0,
        textStyle: Font.TextStyle? = nil,
        customFontName: String? = nil
    ) {
        self.size = size
        self.weight = weight
        self.design = design
        self.digits = digits
        self.tracking = tracking
        self.customTextStyle = textStyle
        self.customFontName = customFontName
    }

    /// The Apple HIG text style mapped to this spec. Either explicitly provided or automatically
    /// inferred from the nearest canonical modular scale step.
    public var textStyle: Font.TextStyle {
        customTextStyle ?? FrilaLPETypeScaleStep.nearest(to: size).textStyle
    }

    /// Fixed-point font (e.g. 15pt) for precise geometric alignment and tight bounds.
    public var font: Font {
        if let customFontName {
            FrilaLPEFontLoader.registerFontsIfNeeded()
            #if canImport(AppKit)
            if NSFont(name: customFontName, size: size) != nil {
                let base = Font.custom(customFontName, size: size)
                switch digits {
                case .proportional: return base
                case .tabular: return base.monospacedDigit()
                }
            }
            #elseif canImport(UIKit)
            if UIFont(name: customFontName, size: size) != nil {
                let base = Font.custom(customFontName, size: size)
                switch digits {
                case .proportional: return base
                case .tabular: return base.monospacedDigit()
                }
            }
            #endif
        }
        let base = FrilaLPEFonteDoSistema.fonte(size: size, weight: weight, design: design)
        switch digits {
        case .proportional: return base
        case .tabular: return base.monospacedDigit()
        }
    }

    /// Dynamic Type font adhering to Apple HIG accessibility scaling curves.
    /// Automatically expands or contracts with system accessibility text size settings.
    public var dynamicFont: Font {
        if let customFontName {
            FrilaLPEFontLoader.registerFontsIfNeeded()
            #if canImport(AppKit)
            if NSFont(name: customFontName, size: size) != nil {
                let base = Font.custom(customFontName, size: size, relativeTo: textStyle)
                switch digits {
                case .proportional: return base
                case .tabular: return base.monospacedDigit()
                }
            }
            #elseif canImport(UIKit)
            if UIFont(name: customFontName, size: size) != nil {
                let base = Font.custom(customFontName, size: size, relativeTo: textStyle)
                switch digits {
                case .proportional: return base
                case .tabular: return base.monospacedDigit()
                }
            }
            #endif
        }
        let base = Font.system(textStyle, design: design).weight(weight)
        switch digits {
        case .proportional: return base
        case .tabular: return base.monospacedDigit()
        }
    }

    /// Same spec with a different digit style (e.g. `metricHeroSpec.withDigits(.tabular)`)
    /// for a hero value that animates.
    public func withDigits(_ digits: Digits) -> FrilaLPETypeSpec {
        FrilaLPETypeSpec(
            size: size,
            weight: weight,
            design: design,
            digits: digits,
            tracking: tracking,
            textStyle: customTextStyle,
            customFontName: customFontName
        )
    }

    /// Metric/price spec: always SF Pro (mono stays for labels and codes), with
    /// slightly negative tracking at display sizes to keep figures tight.
    public static func metric(
        size: CGFloat,
        weight: Font.Weight = .bold,
        digits: Digits = .proportional
    ) -> FrilaLPETypeSpec {
        FrilaLPETypeSpec(size: size, weight: weight, design: .default, digits: digits, tracking: metricTracking(for: size, weight: weight))
    }

    // Heavier strokes need a touch more tightening; below 17pt SF Pro's own optical
    // sizing already spaces figures correctly, so tracking stays neutral.
    static func metricTracking(for size: CGFloat, weight: Font.Weight) -> CGFloat {
        switch size {
        case 20...: return weight == .heavy || weight == .black ? -0.5 : -0.4
        case 17..<20: return -0.2
        default: return 0
        }
    }
}

// MARK: - 3. Typography Paradigms (Strictly 3 Families)

/// Frila Design System - Primitive Typography Engine
/// Implements the Museum Placard Convention across 5 distinct typographic paradigms,
/// strictly limited to the 3 canonical font families (Sans, Serif, Mono). All upright: no italic.
/// 1. Swiss Neo-Grotesque (DEFAULT: Modernist Rigor: Unified Sans with mathematical weights)
/// 2. Curatorial Placard (Artsy Benchmark: Bold Sans + Upright Editorial Serif + Tracked Monospace)
/// 3. Humanist Atelier (Warm Editorial Craft: Optical Serif Display + Humanist Sans)
/// 4. Hyper-Dense Archival (Fintech & Dev Contracts: Compact Monospace labels, SF Pro figures)
/// 5. Tactile Liquid Glass (Next-Gen Apple OS: Crisp Sans Display + Specular Glass Depth)
public enum FrilaLPETypographyParadigm: String, CaseIterable, Identifiable, Sendable {
    // `swiss` is declared first: it is the default paradigm and leads every picker.
    case swiss = "Swiss Neo-Grotesque"
    case curatorial = "Curatorial Placard"
    case humanist = "Humanist Atelier"
    case dense = "Hyper-Dense Archival"
    case glass = "Tactile Liquid Glass"

    public var id: String { rawValue }

    public var primaryAxis: String {
        switch self {
        case .swiss: return "Structure & Spatial Geometry"
        case .curatorial: return "Expressive Contrast / Cultural Distinction"
        case .humanist: return "Warmth & Tactility / Voice"
        case .dense: return "Density & Information Throughput"
        case .glass: return "Surface Depth & Luminance"
        }
    }

    public var rightWhen: String {
        switch self {
        case .swiss: return "Default for every Frila surface: systems engineering, dev tools, marketplace feeds and contracts."
        case .curatorial: return "High-ticket creative & technical agency briefs ($20k–$100k+) requiring editorial prestige."
        case .humanist: return "Luxury branding, bespoke typography, and cultural commissions."
        case .dense: return "Smart contract audits, quantitative feeds, and terminal contracts."
        case .glass: return "iOS 26+ and visionOS spatial computing with floating translucent actions."
        }
    }

    public var shortName: String {
        switch self {
        case .swiss: return "Swiss"
        case .curatorial: return "Curatorial"
        case .humanist: return "Humanist"
        case .dense: return "Archival"
        case .glass: return "Glass"
        }
    }
}

// MARK: - 4. FrilaLPETypography Engine

public struct FrilaLPETypography: Sendable {
    public let paradigm: FrilaLPETypographyParadigm

    public init(paradigm: FrilaLPETypographyParadigm = .swiss) {
        self.paradigm = paradigm
    }

    // MARK: - Display Headline (Step +4 / 32pt, Step +3 / 26pt for Archival)
    public var displayHeadlineSpec: FrilaLPETypeSpec {
        switch paradigm {
        case .swiss: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.display.pointSize, weight: .heavy, tracking: -0.8)
        case .curatorial: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.display.pointSize, weight: .bold, tracking: -0.64)
        case .humanist: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.display.pointSize, weight: .semibold, design: .serif, tracking: -0.48)
        case .dense: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.titleLarge.pointSize, weight: .bold, design: .monospaced, tracking: -0.6)
        // Liquid Glass uses clean Sans; tactility comes from native shaders, not rounded fonts.
        case .glass: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.display.pointSize, weight: .bold, tracking: -0.7)
        }
    }

    public var displayHeadlineFont: Font { displayHeadlineSpec.font }
    public var displayTracking: CGFloat { displayHeadlineSpec.tracking }

    // MARK: - Placard Project Title (The Museum Placard, Step +1 / 18pt, always upright)
    public var placardTitleSpec: FrilaLPETypeSpec {
        switch paradigm {
        case .swiss: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.placard.pointSize, weight: .medium)
        case .curatorial: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.placard.pointSize, weight: .regular, design: .serif)
        case .humanist: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.placard.pointSize, weight: .medium, design: .serif)
        case .dense: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.body.pointSize, weight: .semibold, design: .monospaced)
        case .glass: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.placard.pointSize, weight: .medium)
        }
    }

    public var placardTitleFont: Font { placardTitleSpec.font }

    // MARK: - Client Entity Name (Step 0 / 15pt, Step -1 / 13pt for Archival)
    public var clientEntitySpec: FrilaLPETypeSpec {
        switch paradigm {
        case .swiss: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.body.pointSize, weight: .bold)
        case .curatorial: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.body.pointSize, weight: .bold)
        case .humanist: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.body.pointSize, weight: .semibold)
        case .dense: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.caption.pointSize, weight: .bold, design: .monospaced)
        case .glass: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.body.pointSize, weight: .bold)
        }
    }

    public var clientEntityFont: Font { clientEntitySpec.font }

    // MARK: - Archival Micro-Label (Step -2 / 11pt Floor, Positive Tracking)
    // Sizing floor enforced at 11pt across all paradigms to comply with WCAG 2.2 AA legibility.
    public var microLabelSpec: FrilaLPETypeSpec {
        switch paradigm {
        case .swiss: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.micro.pointSize, weight: .bold, tracking: 0.6)
        case .curatorial: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.micro.pointSize, weight: .semibold, design: .monospaced, tracking: 1.2)
        case .humanist: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.micro.pointSize, weight: .semibold, tracking: 1.4)
        case .dense: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.micro.pointSize, weight: .bold, design: .monospaced, tracking: 1.2)
        case .glass: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.micro.pointSize, weight: .semibold, design: .monospaced, tracking: 1.0)
        }
    }

    public var microLabelFont: Font { microLabelSpec.font }
    public var microLabelTracking: CGFloat { microLabelSpec.tracking }

    // MARK: - Metric / Compensation Figures (SF Pro, proportional digits, Step +2 / 22pt)
    // Static prices read as a word, so digits stay proportional. For values that
    // animate or align in a column use `metricHeroSpec.withDigits(.tabular)`.
    public var metricHeroSpec: FrilaLPETypeSpec {
        switch paradigm {
        case .swiss: return .metric(size: FrilaLPETypeScaleStep.title.pointSize, weight: .heavy)
        case .curatorial: return .metric(size: FrilaLPETypeScaleStep.title.pointSize, weight: .bold)
        case .humanist: return .metric(size: FrilaLPETypeScaleStep.title.pointSize, weight: .semibold)
        case .dense: return .metric(size: FrilaLPETypeScaleStep.placard.pointSize, weight: .bold)
        case .glass: return .metric(size: FrilaLPETypeScaleStep.title.pointSize, weight: .bold)
        }
    }

    public var metricHeroFont: Font { metricHeroSpec.font }

    // MARK: - Body Regular (Step 0 / 15pt, Step -1 / 13pt for Archival)
    public var bodySpec: FrilaLPETypeSpec {
        switch paradigm {
        case .swiss: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.body.pointSize, weight: .regular)
        case .curatorial: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.body.pointSize, weight: .regular)
        case .humanist: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.body.pointSize, weight: .regular)
        case .dense: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.caption.pointSize, weight: .regular)
        case .glass: return FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.body.pointSize, weight: .regular)
        }
    }

    public var bodyFont: Font { bodySpec.font }

    // MARK: - Static Standard Semantic Type Scale (Swiss Benchmark: the default paradigm)
    private static let standard = FrilaLPETypography(paradigm: .swiss)

    public static let displaySpec = standard.displayHeadlineSpec
    public static let titleLargeSpec = FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.titleLarge.pointSize, weight: .bold, tracking: -0.5)
    public static let titleSpec = FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.title.pointSize, weight: .bold, tracking: -0.4)
    public static let placardSpec = standard.placardTitleSpec
    public static let entitySpec = standard.clientEntitySpec
    public static let metricSpec = standard.metricHeroSpec
    public static let metricCompactSpec = FrilaLPETypeSpec.metric(size: FrilaLPETypeScaleStep.placard.pointSize, weight: .bold)
    /// Tabular hero figure: only for values that animate or align in a column.
    public static let metricTabularSpec = metricSpec.withDigits(.tabular)

    public static let display = displaySpec.font
    public static let titleLarge = titleLargeSpec.font
    public static let title = titleSpec.font
    public static let placard = placardSpec.font
    public static let entity = entitySpec.font
    public static let body = FrilaLPEFonteDoSistema.fonte(size: FrilaLPETypeScaleStep.body.pointSize, weight: .regular, design: .default)
    public static let bodyMedium = FrilaLPEFonteDoSistema.fonte(size: FrilaLPETypeScaleStep.body.pointSize, weight: .medium, design: .default)
    public static let bodyBold = FrilaLPEFonteDoSistema.fonte(size: FrilaLPETypeScaleStep.body.pointSize, weight: .bold, design: .default)
    public static let caption = FrilaLPEFonteDoSistema.fonte(size: FrilaLPETypeScaleStep.caption.pointSize, weight: .regular, design: .default)
    public static let captionMedium = FrilaLPEFonteDoSistema.fonte(size: FrilaLPETypeScaleStep.caption.pointSize, weight: .medium, design: .default)
    public static let captionBold = FrilaLPEFonteDoSistema.fonte(size: FrilaLPETypeScaleStep.caption.pointSize, weight: .bold, design: .default)
    public static let micro = FrilaLPEFonteDoSistema.fonte(size: FrilaLPETypeScaleStep.micro.pointSize, weight: .semibold, design: .default)
    public static let microBold = FrilaLPEFonteDoSistema.fonte(size: FrilaLPETypeScaleStep.micro.pointSize, weight: .bold, design: .default)
    public static let metric = metricSpec.font
    public static let metricCompact = metricCompactSpec.font
    /// Tabular hero figure: only for values that animate or align in a column.
    public static let metricTabular = metricTabularSpec.font
    public static let button = FrilaLPEFonteDoSistema.fonte(size: FrilaLPETypeScaleStep.body.pointSize, weight: .semibold, design: .default)

    // MARK: - Monumental Metric Scale ("Dado em Destaque")

    /// 44pt ExtraBold Bricolage Grotesque with condensed tracking (-0.035em)
    public static let metricHeroSpec = FrilaLPETypeSpec(
        size: 44,
        weight: .heavy,
        digits: .proportional,
        tracking: -0.035 * 44,
        textStyle: .largeTitle,
        customFontName: "BricolageGrotesque-ExtraBold"
    )
    public static let metricHero = metricHeroSpec.font

    /// 34pt ExtraBold Bricolage Grotesque with condensed tracking (-0.035em)
    public static let metricCardBigSpec = FrilaLPETypeSpec(
        size: 34,
        weight: .heavy,
        digits: .proportional,
        tracking: -0.035 * 34,
        textStyle: .largeTitle,
        customFontName: "BricolageGrotesque-ExtraBold"
    )
    public static let metricCardBig = metricCardBigSpec.font

    /// 38pt ExtraBold Bricolage Grotesque with condensed tracking (-0.035em)
    public static let metricMonumentalSpec = FrilaLPETypeSpec(
        size: 38,
        weight: .heavy,
        digits: .proportional,
        tracking: -0.035 * 38,
        textStyle: .largeTitle,
        customFontName: "BricolageGrotesque-ExtraBold"
    )
    public static let metricMonumental = metricMonumentalSpec.font

    /// 13pt Medium clean sans for deck chrome headers ("01 POR QUÊ?")
    public static let chromeHeaderSpec = FrilaLPETypeSpec(
        size: 13,
        weight: .medium,
        design: .default,
        tracking: 0.01 * 13,
        textStyle: .footnote
    )
    public static let chromeHeader = chromeHeaderSpec.font

    /// 11pt Regular clean sans for citation source footers
    public static let provenanceSourceSpec = FrilaLPETypeSpec(
        size: 11,
        weight: .regular,
        design: .default,
        tracking: 0.01 * 11,
        textStyle: .caption2
    )
    public static let provenanceSource = provenanceSourceSpec.font

    // MARK: - Tracking Constants
    public static let trackingMicro: CGFloat = 0.6
    public static let trackingDisplay: CGFloat = -0.5

    // MARK: - Family Direct Builders
    public static func sans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        FrilaLPEFonteDoSistema.fonte(size: size, weight: weight, design: .default)
    }

    public static func serif(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        FrilaLPEFonteDoSistema.fonte(size: size, weight: weight, design: .serif)
    }

    public static func mono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        FrilaLPEFonteDoSistema.fonte(size: size, weight: weight, design: .monospaced)
    }

    // MARK: - Custom Family Direct Builders (with graceful fallback)

    public static func bricolage(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        FrilaLPEFontLoader.registerFontsIfNeeded()
        let postScriptName: String
        switch weight {
        case .regular: postScriptName = "BricolageGrotesque-Regular"
        case .medium: postScriptName = "BricolageGrotesque-Medium"
        case .bold: postScriptName = "BricolageGrotesque-Bold"
        case .heavy, .black: postScriptName = "BricolageGrotesque-ExtraBold"
        default: postScriptName = "BricolageGrotesque-Bold"
        }
        #if canImport(AppKit)
        if NSFont(name: postScriptName, size: size) != nil {
            return Font.custom(postScriptName, size: size)
        }
        #elseif canImport(UIKit)
        if UIFont(name: postScriptName, size: size) != nil {
            return Font.custom(postScriptName, size: size)
        }
        #endif
        return FrilaLPEFonteDoSistema.fonte(size: size, weight: weight, design: .default)
    }

    // MARK: - Metric Builders

    /// Static figure: SF Pro, proportional digits.
    public static func metricSpec(size: CGFloat, weight: Font.Weight = .bold) -> FrilaLPETypeSpec {
        .metric(size: size, weight: weight)
    }

    /// Animated or column-aligned figure: SF Pro, tabular digits.
    public static func metricTabularSpec(size: CGFloat, weight: Font.Weight = .bold) -> FrilaLPETypeSpec {
        .metric(size: size, weight: weight, digits: .tabular)
    }

    /// Static figure: SF Pro, proportional digits.
    public static func metric(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        metricSpec(size: size, weight: weight).font
    }

    /// Animated or column-aligned figure: SF Pro, tabular digits.
    public static func metricTabular(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        metricTabularSpec(size: size, weight: weight).font
    }
}

// MARK: - 4b. Formulário: par editorial (Bricolage para a voz, SF Pro para a estrutura)

/// Escala tipográfica do formulário de publicar vaga, no par editorial do Design System:
/// **Bricolage Grotesque** dá voz ao que é pergunta ou escolha (a pergunta da seção e as palavras escolhidas
/// num catálogo: categoria, função, nível); **SF Pro** carrega a estrutura (rótulos, texto digitado,
/// apoio, números). Números e dinheiro seguem sempre em SF Pro (pilar 4).
///
/// Cinco tamanhos, todos na escala Minor Third e mapeados ao estilo de texto do iOS para o Dynamic Type:
/// 26 (pergunta, `.title`), 17 (escolha e entrada, `.body`), 15 (apoio, `.subheadline`),
/// 13 (rótulo e detalhe, `.footnote`), 11 (micro rótulo, `.caption2`).
/// Tracking negativo só no tamanho de título; positivo só no micro rótulo em maiúsculas.
public enum FrilaLPEFormType {
    /// Pergunta da seção ("Qual é a vaga?"): Bricolage Bold 26, tracking −0,6 (≈ −0,023 em).
    public static let question = FrilaLPETypeSpec(
        size: FrilaLPETypeScaleStep.titleLarge.pointSize, weight: .bold, tracking: -0.6,
        textStyle: .title, customFontName: "BricolageGrotesque-Bold"
    )
    /// Palavra escolhida num catálogo (categoria, função, nível): Bricolage Bold 17, tracking −0,15.
    public static let answer = FrilaLPETypeSpec(
        size: 17, weight: .bold, tracking: -0.15,
        textStyle: .body, customFontName: "BricolageGrotesque-Bold"
    )
    /// Escolha só deduzida (categoria vinda da função): mesma voz, peso regular, lida como contexto.
    public static let answerContext = FrilaLPETypeSpec(
        size: 17, weight: .regular, tracking: -0.1,
        textStyle: .body, customFontName: "BricolageGrotesque-Regular"
    )
    /// Texto digitado, placeholder e rótulo de linha de opção: SF Pro 17, o corpo do iOS.
    public static let input = FrilaLPETypeSpec(size: 17, weight: .regular, textStyle: .body)
    /// Valor de dado escolhido que não é palavra de catálogo (data): SF Pro Semibold 17.
    public static let value = FrilaLPETypeSpec(size: 17, weight: .semibold, textStyle: .body)
    /// Apoio sob a pergunta da seção: SF Pro 15.
    public static let support = FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.body.pointSize, weight: .regular, textStyle: .subheadline)
    /// Rótulo acima do campo: SF Pro Semibold 13, tracking +0,1.
    public static let fieldLabel = FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.caption.pointSize, weight: .semibold, tracking: 0.1, textStyle: .footnote)
    /// Detalhe e dica sob um campo ou opção: SF Pro 13.
    public static let detail = FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.caption.pointSize, weight: .regular, textStyle: .footnote)
    /// Micro rótulo em maiúsculas ("O que está incluso"): SF Pro Semibold 11, tracking +0,8 (≈ 0,07 em).
    /// O texto fica em caixa natural no código; a caixa alta vem de `.textCase(.uppercase)`.
    public static let microLabel = FrilaLPETypeSpec(size: FrilaLPETypeScaleStep.micro.pointSize, weight: .semibold, tracking: 0.8, textStyle: .caption2)
}

// MARK: - 5. Semantic View Modifiers

public struct FrilaLPEMicroLabelModifier: ViewModifier {
    public let tracking: CGFloat

    public init(tracking: CGFloat = 1.0) {
        self.tracking = tracking
    }

    public func body(content: Content) -> some View {
        content
            .font(FrilaLPETypography.microBold)
            .tracking(tracking)
    }
}

public struct FrilaLPEMetricModifier: ViewModifier {
    public let spec: FrilaLPETypeSpec

    public var size: CGFloat { spec.size }
    public var weight: Font.Weight { spec.weight }

    public init(size: CGFloat = 22, weight: Font.Weight = .bold, digits: FrilaLPETypeSpec.Digits = .proportional) {
        self.spec = .metric(size: size, weight: weight, digits: digits)
    }

    public func body(content: Content) -> some View {
        content.frilaLPEType(spec)
    }
}

public struct FrilaLPETypeSpecModifier: ViewModifier {
    public let spec: FrilaLPETypeSpec
    public let isDynamic: Bool

    public init(_ spec: FrilaLPETypeSpec, isDynamic: Bool = false) {
        self.spec = spec
        self.isDynamic = isDynamic
    }

    public func body(content: Content) -> some View {
        content
            .font(isDynamic ? spec.dynamicFont : spec.font)
            .tracking(spec.tracking)
    }
}

public extension View {
    func frilaLPEMicroLabel(tracking: CGFloat = 1.0) -> some View {
        modifier(FrilaLPEMicroLabelModifier(tracking: tracking))
    }

    /// Applies a spec's font and tracking together.
    /// - Parameter dynamic: When true, scales with Apple HIG Dynamic Type curves based on `spec.textStyle`.
    func frilaLPEType(_ spec: FrilaLPETypeSpec, dynamic: Bool = false) -> some View {
        modifier(FrilaLPETypeSpecModifier(spec, isDynamic: dynamic))
    }

    /// Applies a spec with native Apple HIG Dynamic Type accessibility scaling.
    func frilaLPEDynamicType(_ spec: FrilaLPETypeSpec) -> some View {
        modifier(FrilaLPETypeSpecModifier(spec, isDynamic: true))
    }

    /// SF Pro figure. Pass `digits: .tabular` only for values that animate or align in a column.
    func frilaLPEMetric(size: CGFloat = 22, weight: Font.Weight = .bold, digits: FrilaLPETypeSpec.Digits = .proportional) -> some View {
        modifier(FrilaLPEMetricModifier(size: size, weight: weight, digits: digits))
    }
}

// MARK: - 6. Escala nativa das telas de Turnos (MidFi)

public extension FrilaLPETypography {
    /// Escala iOS com Dynamic Type para as telas de Turnos (SF Pro, sempre em pé).
    enum Native {
        public static let largeTitle = Font.largeTitle.weight(.bold)
        public static let screenSubtitle = Font.title3
        public static let fieldLabel = Font.headline
        public static let fieldValue = Font.body
        public static let chip = Font.body.weight(.semibold)
        public static let cardTitle = Font.title3.weight(.semibold)
        public static let cardBody = Font.body
        public static let meta = Font.subheadline
        public static let note = Font.footnote
        public static let overline = Font.footnote
        public static let summary = Font.headline
        /// Preço estático do card: SF Pro, algarismos proporcionais.
        public static let price = Font.title2.weight(.bold)
        /// Total que muda com o contador: algarismos tabulares para não tremer.
        public static let tickerTotal = Font.title.weight(.bold).monospacedDigit()
        /// Contador de posições: algarismos tabulares.
        public static let tickerCount = Font.title3.weight(.semibold).monospacedDigit()
        /// Contagem regressiva em texto corrido: algarismos tabulares.
        public static let tickerNote = Font.subheadline.monospacedDigit()
    }
}
