import SwiftUI

/// Frila Design System - Beautiful Shadows (Sistema de Sombras em Múltiplas Camadas Coordenadas)
///
/// Inspirado pela física de iluminação natural e pela engenharia de interfaces refinada:
/// Em vez de uma única sombra difusa e pesada típica da web comercial, o sistema Beautiful Shadows
/// decompõe a oclusão e dispersão de luz em três camadas geométricas coordenadas:
///
/// 1. Contact / Rim Shadow: Raio nítido e milimétrico (1-2pt) com deslocamento vertical curto (1pt),
///    responsável por ancorar a base do contêiner contra a superfície imediata.
/// 2. Key / Direct Shadow: Raio médio proporcional ao ângulo de incidência superior da luz direcional,
///    fornecendo peso e ancoragem espacial ao contêiner.
/// 3. Ambient Shadow: Raio amplo de grande difusão com baixíssima opacidade (wash sutil), simulando a luz
///    refletida pelo ambiente circundante.
///
/// Na elevação `.signal`, o sistema substitui a difusão neutra por dispersão cromática ancorada no
/// laranja curatorial (#EA5A36 / FrilaLPEColor.primary500), produzindo halo tátil de destaque.
public enum FrilaLPEShadowElevation: String, Sendable, CaseIterable, Identifiable {
    /// Nenhuma sombra física (Zero-Shadow canônico de placard de museu sobre drywall)
    case none
    /// Elevação mínima, contato nítido e difusão discreta para cartões de baixa proeminência
    case subtle
    /// Elevação de catálogo editorial, presença refinada com camadas equilibradas
    case editorial
    /// Alta elevação para modais, painéis flutuantes ou cartões de destaque no feed
    case prominent
    /// Dispersão cromática com halo de cor de sinal (#EA5A36) para status de destaque
    case signal

    public var id: String { rawValue }

    /// Título curto para exibição em controles e pickers de laboratório
    public var displayName: String {
        switch self {
        case .none:
            return "Nenhuma"
        case .subtle:
            return "Sutil"
        case .editorial:
            return "Editorial"
        case .prominent:
            return "Proeminente"
        case .signal:
            return "Sinal (#EA5A36)"
        }
    }

    /// Rótulo descritivo curatorial do comportamento de iluminação
    public var description: String {
        switch self {
        case .none:
            return "Zero-shadow de museu: integração total à parede drywall sem sombras difusas"
        case .subtle:
            return "Contato nítido de 1.5pt com difusão sutil para cartões de apoio"
        case .editorial:
            return "Três camadas coordenadas com elevação equilibrada de catálogo"
        case .prominent:
            return "Profundidade acentuada com difusão ampla de 44pt para foco espacial"
        case .signal:
            return "Dispersão cromática vibrante em laranja de sinal #EA5A36"
        }
    }

    /// Especificações técnicas das camadas (raios e deslocamentos y)
    public var technicalSpecs: String {
        switch self {
        case .none:
            return "0pt (Drywall Elevation)"
        case .subtle:
            return "Contact 1.5pt, Key 5pt, Ambient 14pt"
        case .editorial:
            return "Contact 2pt, Key 12pt, Ambient 28pt"
        case .prominent:
            return "Contact 2pt, Key 18pt, Ambient 44pt"
        case .signal:
            return "Contact 1.5pt, Chromatic 10pt e 28pt"
        }
    }

    /// Camadas coordenadas de sombra para o modo claro ou escuro
    public func layers(isDark: Bool) -> [FrilaLPEShadowLayer] {
        switch self {
        case .none:
            return []

        case .subtle:
            if isDark {
                return [
                    FrilaLPEShadowLayer(color: Color.black.opacity(0.26), radius: 1.5, x: 0, y: 1),
                    FrilaLPEShadowLayer(color: Color.black.opacity(0.20), radius: 5, x: 0, y: 2.5),
                    FrilaLPEShadowLayer(color: Color.black.opacity(0.14), radius: 14, x: 0, y: 6)
                ]
            } else {
                return [
                    FrilaLPEShadowLayer(color: Color.black.opacity(0.04), radius: 1.5, x: 0, y: 1),
                    FrilaLPEShadowLayer(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2.5),
                    FrilaLPEShadowLayer(color: Color.black.opacity(0.02), radius: 14, x: 0, y: 6)
                ]
            }

        case .editorial:
            if isDark {
                return [
                    FrilaLPEShadowLayer(color: Color.black.opacity(0.36), radius: 2, x: 0, y: 1),
                    FrilaLPEShadowLayer(color: Color.black.opacity(0.28), radius: 12, x: 0, y: 6),
                    FrilaLPEShadowLayer(color: Color.black.opacity(0.22), radius: 28, x: 0, y: 14)
                ]
            } else {
                return [
                    FrilaLPEShadowLayer(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1),
                    FrilaLPEShadowLayer(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6),
                    FrilaLPEShadowLayer(color: Color.black.opacity(0.04), radius: 28, x: 0, y: 14)
                ]
            }

        case .prominent:
            if isDark {
                return [
                    FrilaLPEShadowLayer(color: Color.black.opacity(0.46), radius: 2, x: 0, y: 1),
                    FrilaLPEShadowLayer(color: Color.black.opacity(0.38), radius: 18, x: 0, y: 10),
                    FrilaLPEShadowLayer(color: Color.black.opacity(0.30), radius: 44, x: 0, y: 22)
                ]
            } else {
                return [
                    FrilaLPEShadowLayer(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1),
                    FrilaLPEShadowLayer(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10),
                    FrilaLPEShadowLayer(color: Color.black.opacity(0.07), radius: 44, x: 0, y: 22)
                ]
            }

        case .signal:
            let signalColor = FrilaLPEColor.dynamicBrandAccent(isDark: isDark)
            if isDark {
                return [
                    FrilaLPEShadowLayer(color: Color.black.opacity(0.42), radius: 1.5, x: 0, y: 1),
                    FrilaLPEShadowLayer(color: signalColor.opacity(0.32), radius: 10, x: 0, y: 4),
                    FrilaLPEShadowLayer(color: signalColor.opacity(0.24), radius: 28, x: 0, y: 12)
                ]
            } else {
                return [
                    FrilaLPEShadowLayer(color: Color.black.opacity(0.06), radius: 1.5, x: 0, y: 1),
                    FrilaLPEShadowLayer(color: signalColor.opacity(0.20), radius: 10, x: 0, y: 4),
                    FrilaLPEShadowLayer(color: signalColor.opacity(0.14), radius: 28, x: 0, y: 12)
                ]
            }
        }
    }
}

/// Representação individual de uma camada de sombra dentro do sistema Beautiful Shadows
public struct FrilaLPEShadowLayer: Sendable, Equatable {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat

    public init(color: Color, radius: CGFloat, x: CGFloat = 0, y: CGFloat) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
    }
}

/// ViewModifier que decompõe e aplica as camadas coordenadas de Beautiful Shadows sem alocações dinâmicas de AnyView.
public struct FrilaLPEShadowModifier: ViewModifier {
    public let elevation: FrilaLPEShadowElevation
    public let isDark: Bool

    public init(elevation: FrilaLPEShadowElevation, isDark: Bool = false) {
        self.elevation = elevation
        self.isDark = isDark
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        let layers = elevation.layers(isDark: isDark)
        switch layers.count {
        case 0:
            content
        case 1:
            content
                .shadow(color: layers[0].color, radius: layers[0].radius, x: layers[0].x, y: layers[0].y)
        case 2:
            content
                .shadow(color: layers[0].color, radius: layers[0].radius, x: layers[0].x, y: layers[0].y)
                .shadow(color: layers[1].color, radius: layers[1].radius, x: layers[1].x, y: layers[1].y)
        case 3:
            content
                .shadow(color: layers[0].color, radius: layers[0].radius, x: layers[0].x, y: layers[0].y)
                .shadow(color: layers[1].color, radius: layers[1].radius, x: layers[1].x, y: layers[1].y)
                .shadow(color: layers[2].color, radius: layers[2].radius, x: layers[2].x, y: layers[2].y)
        default:
            content
                .shadow(color: layers[0].color, radius: layers[0].radius, x: layers[0].x, y: layers[0].y)
                .shadow(color: layers[1].color, radius: layers[1].radius, x: layers[1].x, y: layers[1].y)
                .shadow(color: layers[2].color, radius: layers[2].radius, x: layers[2].x, y: layers[2].y)
        }
    }
}

public extension View {
    /// Aplica o sistema Beautiful Shadows com camadas coordenadas de contato, luz direta e difusão ambiente.
    ///
    /// - Parameters:
    ///   - elevation: O nível de elevação desejado (.none, .subtle, .editorial, .prominent, .signal).
    ///   - isDark: Indicador de modo escuro para calibração das opacidades das camadas.
    func frilaLPEShadow(_ elevation: FrilaLPEShadowElevation, isDark: Bool = false) -> some View {
        modifier(FrilaLPEShadowModifier(elevation: elevation, isDark: isDark))
    }
}

public extension View {
    /// Elevacao discreta de superficies do formulario (cards, chips, steppers).
    /// Modo claro: `.subtle` (tres camadas empilhadas de preto a 2% a 4%). Modo escuro: sem sombra,
    /// a separacao vem da hairline `dynamicFormCardBorder` e da luminancia da superficie.
    func frilaLPEFormLift(isDark: Bool, isActive: Bool = true) -> some View {
        frilaLPEShadow(isDark || !isActive ? .none : .subtle, isDark: isDark)
    }
}

// MARK: - Elevação de grupo (Beautiful Shadows md)

public extension View {
    /// Elevação de um grupo de campos sobre a tela, traduzida do "Beautiful md": um anel de 1 pt a 6%
    /// (o contorno que separa superfícies de baixo contraste) e quatro camadas neutras em progressão
    /// (y 1, 3, 6, 12) com opacidade baixa e decrescente. No escuro a sombra não separa nada sobre o
    /// fundo escuro: fica só o anel, em branco a 6%.
    func frilaLPEGroupElevation(isDark: Bool, cornerRadius: CGFloat) -> some View {
        let ring = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .overlay { ring.strokeBorder(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06), lineWidth: 1) }
            .shadow(color: .black.opacity(isDark ? 0 : 0.05), radius: 0.5, x: 0, y: 1)
            .shadow(color: .black.opacity(isDark ? 0 : 0.045), radius: 1.5, x: 0, y: 3)
            .shadow(color: .black.opacity(isDark ? 0 : 0.04), radius: 3, x: 0, y: 6)
            .shadow(color: .black.opacity(isDark ? 0 : 0.035), radius: 6, x: 0, y: 12)
    }
}

// MARK: - Elevação de modal (Beautiful Shadows lg)

public extension View {
    /// Elevação de um cartão em foco (modal, seletor flutuante), traduzida do "Beautiful lg": anel de 1 pt a
    /// 6% e seis camadas neutras em progressão (y 2,8 a 100, raio de metade do desfoque CSS), opacidade
    /// de 3,4% a 12%. No escuro: anel branco a 12% e as mesmas camadas com o dobro de opacidade (preto sobre
    /// o véu denso ainda separa o cartão do fundo), mais a superfície do cartão um tom acima.
    func frilaLPEModalElevation(isDark: Bool, cornerRadius: CGFloat) -> some View {
        let ring = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let k: Double = isDark ? 2.2 : 1
        return self
            .overlay { ring.strokeBorder(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.06), lineWidth: 1) }
            .shadow(color: .black.opacity(0.034 * k), radius: 1.1, x: 0, y: 2.8)
            .shadow(color: .black.opacity(0.048 * k), radius: 2.65, x: 0, y: 6.7)
            .shadow(color: .black.opacity(0.06 * k), radius: 5, x: 0, y: 12.5)
            .shadow(color: .black.opacity(0.072 * k), radius: 9, x: 0, y: 22.3)
            .shadow(color: .black.opacity(0.086 * k), radius: 16.7, x: 0, y: 41.8)
            .shadow(color: .black.opacity(0.12 * k), radius: 40, x: 0, y: 100)
    }
}
