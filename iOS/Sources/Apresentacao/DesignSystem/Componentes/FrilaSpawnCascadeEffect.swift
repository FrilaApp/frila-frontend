import SwiftUI

/// Modelo puro do "nascimento" em cascata: quando uma lista nova chega, cada linha surge (opacidade,
/// um pulo curto de escala e posição, e uma passada de brilho) com atraso proporcional à distância
/// até a linha de origem (a selecionada). A onda se propaga igualmente para cima e para baixo, e
/// só até onde houver linhas. Sutil de propósito.
public enum FrilaSpawnCascade: Sendable {
    /// Atraso entre linhas vizinhas (s).
    public static let stepDelay: Double = 0.05
    /// Máximo de passos considerados no atraso: limita a duração total da cascata.
    public static let maxSteps: Int = 5
    /// Duração do surgimento de cada linha (s).
    public static let duration: Double = 0.42
    /// Duração total da cascata, da primeira à última linha (s).
    public static var totalDuration: Double { stepDelay * Double(maxSteps) + duration }

    /// Escala inicial e deslocamento vertical inicial (pt): um pulo curto, quase imperceptível.
    public static let startScale: Double = 0.95
    public static let startOffset: Double = 5
    /// Opacidade inicial: o texto nasce de uma base visível (acréscimo), sem cair a zero na troca da lista.
    public static let startOpacity: Double = 0.35

    public static func distance(row: Int, origin: Int) -> Int { abs(row - origin) }

    public static func delay(distance: Int) -> Double {
        stepDelay * Double(min(max(0, distance), maxSteps))
    }

    /// Progresso 0...1 da linha para o tempo decorrido desde o início da cascata.
    public static func progress(elapsed: Double, delay: Double) -> Double {
        max(0, min(1, (elapsed - delay) / duration))
    }

    /// Ease-out com leve overshoot (back, c = 1.2): o "pulo" de nascimento.
    public static func easeOutBack(_ t: Double) -> Double {
        let c1 = 1.2, c3 = c1 + 1
        let x = t - 1
        return 1 + c3 * x * x * x + c1 * x * x
    }

    /// Ease-out cúbico, para a opacidade (sem overshoot).
    public static func easeOut(_ t: Double) -> Double { 1 - pow(1 - t, 3) }
}

/// Passada diagonal de brilho recortada pelo próprio conteúdo. Compartilhada pelos estados do texto.
struct FrilaTextSweep<Content: View>: View {
    let content: Content
    let phase: Double
    let intensity: Double
    let isDark: Bool

    var body: some View {
        GeometryReader { geo in
            let band = geo.size.width * 0.55
            let travel = geo.size.width + band
            LinearGradient(
                colors: [.clear, FrilaColor.dynamicFormFieldSurface(isDark: isDark).opacity(0.85 * intensity), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: band, height: geo.size.height * 2.2)
            .rotationEffect(.degrees(18))
            .offset(x: -band + travel * phase, y: -geo.size.height * 0.6)
        }
        .mask { content }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Aplica o nascimento em cascata a uma linha. `start == nil` significa sem cascata em curso.
public struct FrilaSpawnCascadeEffect: ViewModifier {
    public let start: Date?
    public let distance: Int
    public let isDark: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func body(content: Content) -> some View {
        if let start, !reduceMotion {
            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSince(start)
                let q = FrilaSpawnCascade.progress(elapsed: elapsed, delay: FrilaSpawnCascade.delay(distance: distance))
                let back = FrilaSpawnCascade.easeOutBack(q)
                content
                    .overlay {
                        FrilaTextSweep(content: content, phase: q, intensity: sin(.pi * q), isDark: isDark)
                    }
                    .opacity(FrilaSpawnCascade.startOpacity + (1 - FrilaSpawnCascade.startOpacity) * FrilaSpawnCascade.easeOut(q))
                    .scaleEffect(FrilaSpawnCascade.startScale + (1 - FrilaSpawnCascade.startScale) * back)
                    .offset(y: FrilaSpawnCascade.startOffset * (1 - back))
            }
        } else {
            content
        }
    }
}

public extension View {
    func frilaSpawnCascade(start: Date?, distance: Int, isDark: Bool) -> some View {
        modifier(FrilaSpawnCascadeEffect(start: start, distance: distance, isDark: isDark))
    }
}
