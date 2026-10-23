import SwiftUI

/// Estado "aguardando" aplicado direto ao texto, sem trocá-lo por um esqueleto: o texto continua legível
/// enquanto um brilho diagonal o atravessa, a opacidade respira e a escala pulsa de leve. Os três
/// movimentos compartilham a mesma fase (um ciclo único), e cada linha entra com um deslocamento de fase,
/// então a onda corre encadeada pela lista. A intensidade entra e sai em rampa, sem salto de estado.
public struct FrilaLPEPendingTextEffect: ViewModifier {
    public let isActive: Bool
    /// Deslocamento de fase da linha (ciclos). Valores crescentes ao longo da lista criam a onda encadeada.
    public let phaseOffset: Double
    public let isDark: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var intensity: Double = 0

    /// Duração de um ciclo completo de brilho, respiração e pulso (s).
    public static let cycleDuration: Double = 1.5
    /// Queda máxima de opacidade na respiração.
    public static let opacityDip: Double = 0.4
    /// Variação máxima de escala no pulso (± metade).
    public static let scaleSwing: Double = 0.03

    /// Fase normalizada (0..1) para um instante e um deslocamento.
    public static func phase(time: Double, offset: Double) -> Double {
        let p = (time / cycleDuration + offset).truncatingRemainder(dividingBy: 1)
        return p < 0 ? p + 1 : p
    }

    /// Respiração suave: 0 no início do ciclo, 1 no meio, 0 no fim.
    public static func pulse(phase p: Double) -> Double {
        0.5 - 0.5 * cos(2 * .pi * p)
    }

    public func body(content: Content) -> some View {
        Group {
            if reduceMotion {
                content.opacity(1 - Self.opacityDip * 0.6 * intensity)
            } else {
                TimelineView(AnimationTimelineSchedule(paused: !isActive && intensity == 0)) { context in
                    let p = Self.phase(time: context.date.timeIntervalSinceReferenceDate, offset: phaseOffset)
                    let pulse = Self.pulse(phase: p)
                    content
                        .overlay { FrilaLPETextSweep(content: content, phase: p, intensity: intensity, isDark: isDark) }
                        .opacity(1 - Self.opacityDip * pulse * intensity)
                        .scaleEffect(1 + Self.scaleSwing * (pulse - 0.5) * intensity)
                }
            }
        }
        .onChange(of: isActive, initial: true) { _, active in
            withAnimation(FrilaMovimento.animacao(.easeOut(duration: 0.22), reduzir: FrilaLPEMovimentoReduzido.ativo)) { intensity = active ? 1 : 0 }
        }
    }
}

public extension View {
    /// Aplica o estado "aguardando" ao texto: brilho diagonal, respiração de opacidade e pulso de escala encadeados.
    func frilaLPEPendingText(isActive: Bool, phaseOffset: Double = 0, isDark: Bool) -> some View {
        modifier(FrilaLPEPendingTextEffect(isActive: isActive, phaseOffset: phaseOffset, isDark: isDark))
    }
}
