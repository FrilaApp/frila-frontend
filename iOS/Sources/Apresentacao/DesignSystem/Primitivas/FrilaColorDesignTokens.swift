import SwiftUI

/// Frila Design System - Core Color Primitives
/// Governed by OKLCH color spaces with perceptual uniformity and strict WCAG 2.2 AA compliance.
/// Brand Anchor: #EA5A36 (oklch(0.6510 0.1856 35.10deg))
public enum FrilaColor {
    // MARK: - Primary Brand Tonal Scale (Anchored on #EA5A36)
    
    /// Subtle tint, chip background (#FFF1EC)
    public static let primary50 = Color(red: 255/255, green: 241/255, blue: 236/255)
    
    /// Hover surface, light badge (#FFDDD2 / --sinal-claro)
    public static let primary100 = Color(red: 255/255, green: 221/255, blue: 210/255)
    
    /// Secondary border, soft highlight (#FFB6A1)
    public static let primary200 = Color(red: 255/255, green: 182/255, blue: 161/255)
    
    /// Graphic detail, disabled button outline (#FF8B6D)
    public static let primary300 = Color(red: 255/255, green: 139/255, blue: 109/255)
    
    /// Interactive hover state, OLED Dark Mode attenuation (#F26643)
    public static let primary400 = Color(red: 242/255, green: 102/255, blue: 67/255)
    
    /// BRAND ANCHOR: Primary CTA, active pill, brand mark (#EA5A36 / --sinal)
    public static let primary500 = Color(red: 234/255, green: 90/255, blue: 54/255)
    
    /// Active press state, accessible text on white (WCAG AA 5.1:1) (#C03710)
    public static let primary600 = Color(red: 192/255, green: 55/255, blue: 16/255)
    
    /// Dark accent, high-contrast link text on light background (WCAG AA 7.5:1) (#9D2701)
    public static let primary700 = Color(red: 157/255, green: 39/255, blue: 1/255)
    
    /// Deep brand mark, icon fill (#781D03)
    public static let primary800 = Color(red: 120/255, green: 29/255, blue: 3/255)
    
    /// Dark brand backdrop (#4F1506)
    public static let primary900 = Color(red: 79/255, green: 21/255, blue: 6/255)
    
    /// Deepest baseline (#2C0903)
    public static let primary950 = Color(red: 44/255, green: 9/255, blue: 3/255)

    // Aliases semânticos diretos do Deck
    public static var signal: Color { primary500 }
    public static var signalLight: Color { primary100 }
    
    // MARK: - Achromatic Gallery Wall Palette (Artsy Museum Wall Discipline)
    
    /// Pure White Gallery Drywall (Light: #FFFFFF, Dark: #111111)
    public static let canvas = Color(
        "CanvasColor",
        bundle: nil
    )
    
    /// Cor da superfície drywall no modo escuro (#111111)
    public static let canvasDark = Color(red: 17/255, green: 17/255, blue: 17/255)
    
    /// Cor da superfície drywall no modo claro (#FFFFFF)
    public static let canvasLight = Color(red: 255/255, green: 255/255, blue: 255/255)
    
    /// Dynamic canvas color supporting light and dark mode adaptively
    public static func dynamicCanvas(isDark: Bool) -> Color {
        isDark ? canvasDark : canvasLight
    }
    
    /// Whisper card surface for grouping lists (Light: #FBFBFA, Dark: #171614)
    public static func dynamicSurfaceSubtle(isDark: Bool) -> Color {
        isDark ? Color(red: 23/255, green: 22/255, blue: 20/255) : Color(red: 251/255, green: 251/255, blue: 250/255)
    }
    
    /// Flat input and chip background (Light: #F2F2F0, Dark: #23221F)
    public static func dynamicInputBg(isDark: Bool) -> Color {
        isDark ? Color(red: 35/255, green: 34/255, blue: 31/255) : Color(red: 242/255, green: 242/255, blue: 240/255)
    }
    
    /// Surface input alias matching DESIGN.md token --frila-color-surface-input
    public static func dynamicSurfaceInput(isDark: Bool) -> Color {
        dynamicInputBg(isDark: isDark)
    }
    
    /// 1px Architectural hairline divider (Light: #E5E5E3, Dark: #2E2D29)
    public static func dynamicHairline(isDark: Bool) -> Color {
        isDark ? Color(red: 46/255, green: 45/255, blue: 41/255) : Color(red: 229/255, green: 229/255, blue: 227/255)
    }
    
    /// Interactive control border (Light: #CECECB, Dark: #44433E)
    public static func dynamicBorder(isDark: Bool) -> Color {
        isDark ? Color(red: 68/255, green: 67/255, blue: 62/255) : Color(red: 206/255, green: 206/255, blue: 203/255)
    }
    
    // MARK: - Job Form Achromatic Surfaces (pure neutral, zero warm tint)

    /// Fundo de campo interativo do formulario (Light: #F5F5F5, Dark: #1C1C1C).
    /// Neutro puro (R = G = B). Contra o canvas: 1.09:1 light, 1.11:1 dark. A identificacao do campo vem da borda `dynamicFormFieldBorder`.
    public static func dynamicFormFieldSurface(isDark: Bool) -> Color {
        isDark ? Color(red: 28/255, green: 28/255, blue: 28/255) : Color(red: 245/255, green: 245/255, blue: 245/255)
    }

    /// Borda de campo interativo do formulario (Light: #8C8C8C, Dark: #6A6A6A). WCAG 1.4.11 (>= 3:1).
    /// Light: 3.36:1 contra #FFFFFF e 3.08:1 contra #F5F5F5. Dark: 3.49:1 contra #111111 e 3.15:1 contra #1C1C1C.
    public static func dynamicFormFieldBorder(isDark: Bool) -> Color {
        isDark ? Color(red: 106/255, green: 106/255, blue: 106/255) : Color(red: 140/255, green: 140/255, blue: 140/255)
    }

    /// Superficie de card e chip do formulario (Light: #FAFAFA, Dark: #171717). Neutro puro.
    /// Separacao do canvas via `dynamicFormCardBorder` e, no modo claro, sombra `.subtle`.
    public static func dynamicFormCardSurface(isDark: Bool) -> Color {
        isDark ? Color(red: 23/255, green: 23/255, blue: 23/255) : Color(red: 250/255, green: 250/255, blue: 250/255)
    }

    /// Hairline de card, chip e divisor do formulario (Light: #D6D6D6, Dark: #363636). Decorativa, neutra.
    /// Light: 1.45:1 contra #FFFFFF. Dark: 1.56:1 contra #111111.
    public static func dynamicFormCardBorder(isDark: Bool) -> Color {
        isDark ? Color(red: 54/255, green: 54/255, blue: 54/255) : Color(red: 214/255, green: 214/255, blue: 214/255)
    }

    /// Texto secundario do formulario sobre campo ou card (Light: #6B6B6B, Dark: #A3A3A3). Neutro puro.
    /// Light: 4.89:1 sobre #F5F5F5 e 5.11:1 sobre #FAFAFA. Dark: 6.76:1 sobre #1C1C1C e 7.11:1 sobre #171717.
    public static func dynamicFormTextMuted(isDark: Bool) -> Color {
        isDark ? Color(red: 163/255, green: 163/255, blue: 163/255) : Color(red: 107/255, green: 107/255, blue: 107/255)
    }

    /// Secondary metadata, client studio text (Light: #767571, Dark: #9E9D97) (WCAG AA: 4.61:1)
    public static func dynamicTextMuted(isDark: Bool) -> Color {
        isDark ? Color(red: 158/255, green: 157/255, blue: 151/255) : Color(red: 118/255, green: 117/255, blue: 113/255)
    }

    /// Preenchimento neutro para etapas do formulário preenchidas fora da ordem linear estrita (Light: #5F5E5A, Dark: #888781).
    /// Tom de cinza calibrado e ligeiramente mais escuro que dynamicTextMuted para manter contraste nítido contra o fundo
    /// e contra a calha inativa, assinalando visualmente que o dado foi inserido mas aguarda validação das etapas anteriores.
    public static func dynamicProgressNeutral(isDark: Bool) -> Color {
        isDark ? Color(red: 136/255, green: 135/255, blue: 129/255) : Color(red: 95/255, green: 94/255, blue: 90/255)
    }
    
    /// Primary charcoal body text and display headlines (Light: #1B1A18, Dark: #F5F4F0) (WCAG AAA: 17.39:1)
    public static func dynamicTextPrimary(isDark: Bool) -> Color {
        isDark ? Color(red: 245/255, green: 244/255, blue: 240/255) : Color(red: 27/255, green: 26/255, blue: 24/255)
    }
    
    /// Stark Pitch Black pill button (Light: #090908, Dark: #FFFFFF)
    public static func dynamicTextInk(isDark: Bool) -> Color {
        isDark ? Color.white : Color(red: 9/255, green: 9/255, blue: 8/255)
    }
    
    /// Boundary hairline for photographs and media assets (Light: 8% black outline, Dark: 10% white outline)
    /// Prevents dark media from bleeding into gallery walls and keeps boundaries crisp on dark canvas.
    public static func dynamicMediaOutline(isDark: Bool) -> Color {
        isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }
    
    /// Adaptive brand accent calibrated for Dark Mode without hue drift (preserved OKLCH hue 35.1 deg).
    /// Light mode uses primary500 (#EA5A36); Dark mode uses calibrated primary400 (#F26643) to prevent chroma vibration against dark canvas.
    public static func dynamicBrandAccent(isDark: Bool) -> Color {
        isDark ? primary400 : primary500
    }
    
    /// Brand-colored text over input surfaces, such as the selected wheel row.
    /// Light: primary600 on #F2F2F0 (~4.9:1). Dark: primary400 on #23221F (~5.1:1). Both pass AA for body text.
    public static func dynamicBrandText(isDark: Bool) -> Color {
        isDark ? primary400 : primary600
    }

    /// Laranja de seleção (#C9470F, OKLCH 0.572 0.176 39.3): a marca escurecida o bastante para texto
    /// branco em AA (4,78:1), com o matiz girado 4 graus para o amarelo para continuar laranja.
    /// Escurecer sem girar (`primary600`, matiz 35) puxava para o vermelho e lia como alerta.
    public static let primarySelection = Color(red: 201/255, green: 71/255, blue: 15/255)

    /// Preenchimento sólido do estado confirmado (campo ou linha escolhida de propósito), nos dois modos.
    public static func dynamicBrandSolidFill(isDark: Bool) -> Color {
        primarySelection
    }

    /// Texto e ícones sobre `dynamicBrandSolidFill`: branco nos dois modos (4,78:1).
    public static func dynamicBrandSolidText(isDark: Bool) -> Color {
        canvasLight
    }

    // MARK: Grupo de seletores (Categoria e Função numa região comum)

    /// Preto absoluto do estado confirmado (#090908), igual nos dois modos.
    public static let inkAbsolute = Color(red: 9/255, green: 9/255, blue: 8/255)

    /// Campo dentro do grupo no modo claro: superfície de entrada (#F6F6F4) com filete de 8%, sobre o
    /// grupo branco elevado. O contraste vem do contorno e da sombra, não de cinzas aproximados.
    public static let groupFieldLight = Color(red: 246/255, green: 246/255, blue: 244/255)
    public static let groupFieldStrokeLight = Color.black.opacity(0.08)

    // Paletas de grupo: segregação suave, não espaço negativo. O campo se separa do grupo por pouco
    // (1,1:1 a 1,2:1) e o confirmado é um grafite, não o preto absoluto (texto branco ~7,5:1 a 9:1).
    // No escuro o campo é mais claro que o grupo: uma camada elevada, não um buraco.

    /// Grafite (neutro frio). Grupo: Claro #F3F3F1, Escuro #1C1C1A.
    public static func dynamicGroupGraphite(isDark: Bool) -> Color {
        isDark ? Color(red: 28/255, green: 28/255, blue: 26/255) : Color(red: 243/255, green: 243/255, blue: 241/255)
    }
    /// Campo no grupo grafite: Claro #FFFFFF, Escuro #2A2A27.
    public static func dynamicGroupGraphiteField(isDark: Bool) -> Color {
        isDark ? Color(red: 42/255, green: 42/255, blue: 39/255) : canvasLight
    }
    /// Confirmado no grupo grafite: Claro #55534E (branco 7,5:1), Escuro #4B4A45 (branco 8,9:1).
    public static func dynamicGroupGraphiteConfirmed(isDark: Bool) -> Color {
        isDark ? Color(red: 75/255, green: 74/255, blue: 69/255) : Color(red: 85/255, green: 83/255, blue: 78/255)
    }

    /// Pedra (neutro quente, da família dos divisores). Grupo: Claro #F1EFEA, Escuro #1D1C19.
    public static func dynamicGroupStone(isDark: Bool) -> Color {
        isDark ? Color(red: 29/255, green: 28/255, blue: 25/255) : Color(red: 241/255, green: 239/255, blue: 234/255)
    }
    /// Campo no grupo pedra: Claro #FBFAF7, Escuro #2B2925.
    public static func dynamicGroupStoneField(isDark: Bool) -> Color {
        isDark ? Color(red: 43/255, green: 41/255, blue: 37/255) : Color(red: 251/255, green: 250/255, blue: 247/255)
    }
    /// Confirmado no grupo pedra: Claro #5A564C (branco 7,3:1), Escuro #4D4A43 (branco 8,8:1).
    public static func dynamicGroupStoneConfirmed(isDark: Bool) -> Color {
        isDark ? Color(red: 77/255, green: 74/255, blue: 67/255) : Color(red: 90/255, green: 86/255, blue: 76/255)
    }

    /// Camada de seleção em listas abertas (linha escolhida e linha sob o dedo): cinza bem claro.
    /// Separação mínima do cartão (Claro #EDEDEB, 1,12:1; Escuro #282826, 1,21:1); o texto por cima
    /// mantém AA com folga (título 15:1 e 13:1, detalhe em tinta secundária 9,7:1 e 8,5:1).
    public static func dynamicSelectionWash(isDark: Bool) -> Color {
        isDark ? Color(red: 40/255, green: 40/255, blue: 38/255) : Color(red: 237/255, green: 237/255, blue: 235/255)
    }

    /// Camada de seleção dentro de um cartão que já é a superfície elevada (o cartão flutuante do turno,
    /// #2A2A27 no escuro, onde o campo do grupo sumiria). Claro: o campo do grupo (#F6F6F4), usado com o
    /// filete de 8% sobre o cartão branco. Escuro: um degrau acima do cartão (#393935, 1,24:1), pouco mais
    /// que o degrau entre grupo e campo do seletor de experiência (1,19:1), porque o véu denso achata os tons.
    /// Texto por cima em AA com folga (título 10,5:1, detalhe em tinta secundária 7:1).
    public static func dynamicRaisedSelectionLayer(isDark: Bool) -> Color {
        isDark ? Color(red: 57/255, green: 57/255, blue: 53/255) : groupFieldLight
    }

    /// Dynamic chip/badge background for brand/primary tags
    public static func dynamicBrandChipBg(isDark: Bool) -> Color {
        isDark ? primary500.opacity(0.18) : primary50
    }
    
    /// Dynamic chip/badge foreground for brand/primary tags
    public static func dynamicBrandChipText(isDark: Bool) -> Color {
        isDark ? primary400 : primary700
    }
    
    /// Dynamic chip/badge border for brand/primary tags
    public static func dynamicBrandChipBorder(isDark: Bool) -> Color {
        isDark ? primary500.opacity(0.32) : Color.clear
    }
    
    // MARK: - Editorial Ink & Dividers
    
    /// Texto Tinta Principal (Light: #111111, Dark: #F4F1EA)
    public static func dynamicInk(isDark: Bool) -> Color {
        isDark ? Color(red: 244/255, green: 241/255, blue: 234/255) : Color(red: 17/255, green: 17/255, blue: 17/255)
    }
    
    /// Texto Secundário Editorial (Light: #3A3A3A, Dark: #CFCAC0)
    public static func dynamicInkSecondary(isDark: Bool) -> Color {
        isDark ? Color(red: 207/255, green: 202/255, blue: 192/255) : Color(red: 58/255, green: 58/255, blue: 58/255)
    }
    
    /// Metadados & Proveniência Sutil (Light: #6B6B6B, Dark: #9A968D)
    public static func dynamicSubtle(isDark: Bool) -> Color {
        isDark ? Color(red: 154/255, green: 150/255, blue: 141/255) : Color(red: 107/255, green: 107/255, blue: 107/255)
    }

    
    /// Bordas de Separação Nítida 2px (Light: #D4D0C6, Dark: #33322E)
    public static func dynamicDividerStrong(isDark: Bool) -> Color {
        isDark ? Color(red: 51/255, green: 50/255, blue: 46/255) : Color(red: 212/255, green: 208/255, blue: 198/255)
    }
    
    // MARK: - Semantic Trust & Status Accents (WCAG AA Compliant)
    
    /// Verified status emerald badge (WCAG AA >= 4.5:1 on light and dark backgrounds) (#007A33)
    public static let verified = Color(red: 0/255, green: 122/255, blue: 51/255)
    
    /// Subtle verified chip background (#EBF7EE)
    public static let verifiedBg = Color(red: 235/255, green: 247/255, blue: 238/255)
    
    /// Dynamic verified text and badge foreground supporting adaptive light/dark mode
    public static func dynamicVerified(isDark: Bool) -> Color {
        isDark ? Color(red: 74/255, green: 222/255, blue: 128/255) : Color(red: 0/255, green: 122/255, blue: 51/255)
    }
    
    /// Dynamic verified chip background supporting adaptive light/dark mode
    public static func dynamicVerifiedBg(isDark: Bool) -> Color {
        isDark ? Color(red: 15/255, green: 43/255, blue: 26/255) : Color(red: 235/255, green: 247/255, blue: 238/255)
    }

    /// Expiring brief amber graphic (#C97A00)
    public static let warningGraphic = Color(red: 201/255, green: 122/255, blue: 0/255)
    
    /// Expiring brief text label (WCAG AA 5.27:1) (#9E5C00)
    public static let warningText = Color(red: 158/255, green: 92/255, blue: 0/255)
    
    /// Warning chip background (#FFF6E6)
    public static let warningBg = Color(red: 255/255, green: 246/255, blue: 230/255)
    
    /// Dynamic warning text label supporting adaptive light/dark mode
    public static func dynamicWarningText(isDark: Bool) -> Color {
        isDark ? Color(red: 251/255, green: 191/255, blue: 36/255) : Color(red: 158/255, green: 92/255, blue: 0/255)
    }
    
    /// Dynamic warning chip background supporting adaptive light/dark mode
    public static func dynamicWarningBg(isDark: Bool) -> Color {
        isDark ? Color(red: 51/255, green: 29/255, blue: 0/255) : Color(red: 255/255, green: 246/255, blue: 230/255)
    }
    
    /// Error and deadline passed crimson (#D82020) (WCAG AA 5.06:1)
    public static let error = Color(red: 216/255, green: 32/255, blue: 32/255)
    
    /// Error chip background (#FEECEC)
    public static let errorBg = Color(red: 254/255, green: 236/255, blue: 236/255)
    
    /// Dynamic error label supporting adaptive light/dark mode
    public static func dynamicError(isDark: Bool) -> Color {
        isDark ? Color(red: 248/255, green: 113/255, blue: 113/255) : Color(red: 216/255, green: 32/255, blue: 32/255)
    }
    
    /// Dynamic error chip background supporting adaptive light/dark mode
    public static func dynamicErrorBg(isDark: Bool) -> Color {
        isDark ? Color(red: 54/255, green: 16/255, blue: 16/255) : Color(red: 254/255, green: 236/255, blue: 236/255)
    }

    // MARK: - Semantic Skeleton Loading Tokens (Achromatic Museum Wall Discipline)

    /// Subtle placeholder baseline tone for loading skeletons.
    /// Light: #EAEAE7 (warm museum drywall), Dark: #22211E (calibrated dark basalt).
    public static func dynamicSkeletonBase(isDark: Bool) -> Color {
        isDark ? Color(red: 34/255, green: 33/255, blue: 30/255)
               : Color(red: 234/255, green: 234/255, blue: 231/255)
    }

    /// Specular shimmer wave tone sweeping across skeleton placeholders.
    /// Light: #F7F7F5 (silky matte sweep), Dark: #32312C (anti-glare OLED highlight, Y < 0.05).
    public static func dynamicSkeletonHighlight(isDark: Bool) -> Color {
        isDark ? Color(red: 50/255, green: 49/255, blue: 44/255)
               : Color(red: 247/255, green: 247/255, blue: 245/255)
    }

    // MARK: - Functional Pastel Tokens (Calm & Low-Chroma OKLCH Space)

    public enum FunctionalPastelTheme: String, CaseIterable, Sendable {
        case terracotta = "Terracotta Soft"
        case sage = "Sage"
        case slate = "Slate"
    }

    /// Background for calm functional pastels (Terracotta Soft, Sage, Slate)
    public static func dynamicPastelBg(theme: FunctionalPastelTheme, isDark: Bool) -> Color {
        switch theme {
        case .terracotta:
            // L* > 92%, C < 0.05 in OKLCH (Light: #FFF2ED, Dark: #2D1711)
            return isDark ? Color(red: 45/255, green: 23/255, blue: 17/255) : Color(red: 255/255, green: 242/255, blue: 237/255)
        case .sage:
            // Calm low-chroma herbal sage (Light: #EFF6F1, Dark: #15271B)
            return isDark ? Color(red: 21/255, green: 39/255, blue: 27/255) : Color(red: 239/255, green: 246/255, blue: 241/255)
        case .slate:
            // Soft museum slate / charcoal whisper (Light: #F1F3F5, Dark: #192026)
            return isDark ? Color(red: 25/255, green: 32/255, blue: 38/255) : Color(red: 241/255, green: 243/255, blue: 245/255)
        }
    }

    /// High contrast foreground text for functional pastels ensuring strict WCAG AAA compliance (> 7.0:1)
    public static func dynamicPastelText(theme: FunctionalPastelTheme, isDark: Bool) -> Color {
        switch theme {
        case .terracotta:
            // Primary 800 (#781D03) on #FFF2ED -> 9.99:1 AAA in Light; #FFC0B0 on #2D1711 -> 10.5:1 AAA in Dark
            return isDark ? Color(red: 255/255, green: 192/255, blue: 176/255) : Color(red: 120/255, green: 29/255, blue: 3/255)
        case .sage:
            // Deep curatorial forest (#0F3F1E) on #EFF6F1 -> 10.6:1 AAA in Light; #A8E6BA on #15271B -> 8.5:1 AAA in Dark
            return isDark ? Color(red: 168/255, green: 230/255, blue: 186/255) : Color(red: 15/255, green: 63/255, blue: 30/255)
        case .slate:
            // Deep basalt slate (#18222A) on #F1F3F5 -> 14.1:1 AAA in Light; #D7E0E8 on #192026 -> 9.4:1 AAA in Dark
            return isDark ? Color(red: 215/255, green: 224/255, blue: 232/255) : Color(red: 24/255, green: 34/255, blue: 42/255)
        }
    }

    /// Subtle 0.5pt/1pt border for functional pastel surfaces
    public static func dynamicPastelBorder(theme: FunctionalPastelTheme, isDark: Bool) -> Color {
        switch theme {
        case .terracotta:
            return isDark ? Color(red: 242/255, green: 102/255, blue: 67/255).opacity(0.35) : Color(red: 255/255, green: 182/255, blue: 161/255).opacity(0.65)
        case .sage:
            return isDark ? Color(red: 74/255, green: 222/255, blue: 128/255).opacity(0.28) : Color(red: 180/255, green: 215/255, blue: 190/255).opacity(0.65)
        case .slate:
            return isDark ? Color(red: 120/255, green: 144/255, blue: 164/255).opacity(0.30) : Color(red: 200/255, green: 210/255, blue: 218/255).opacity(0.65)
        }
    }

    /// Selected / active background for functional pastel category chips
    public static func dynamicPastelSelectedBg(theme: FunctionalPastelTheme, isDark: Bool) -> Color {
        switch theme {
        case .terracotta:
            return primarySelection
        case .sage:
            return isDark ? Color(red: 22/255, green: 101/255, blue: 52/255) : Color(red: 20/255, green: 83/255, blue: 45/255)
        case .slate:
            return isDark ? Color(red: 51/255, green: 65/255, blue: 85/255) : Color(red: 30/255, green: 41/255, blue: 59/255)
        }
    }

    /// Selected / active text for functional pastel category chips
    public static func dynamicPastelSelectedText(theme: FunctionalPastelTheme, isDark: Bool) -> Color {
        dynamicBrandSolidText(isDark: isDark)
    }
}

// MARK: - Enxerto (Estúdio de Criação)

/// Cores que a origem declarava fora dos tokens; ficam aqui pela regra 8 do `conferir-textos.sh`.
public extension FrilaColor {
    static let bannerTelaDeBloqueioFundo = Color(red: 0.93, green: 0.93, blue: 0.92)
    static let bannerTelaDeBloqueioTexto = Color(red: 0.10, green: 0.10, blue: 0.10)
    static let bannerTelaDeBloqueioTextoApagado = Color(red: 0.40, green: 0.40, blue: 0.40)
    static let pontoDoPassoNoEscuro = Color(white: 0.1)
    #if canImport(UIKit)
    static var uiPrimary400: UIColor { UIColor(primary400) }
    static var uiPrimary500: UIColor { UIColor(primary500) }
    #endif
}
