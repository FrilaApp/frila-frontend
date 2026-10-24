import Foundation

/// Fricção entre roletas acopladas: quanto mais rápido a roleta de Categoria passa pelas linhas,
/// mais a lista de Função espera para trocar. Rolagem lenta quase não atrasa (a lista acompanha);
/// rolagem rápida adia até a mão desacelerar. Um teto de espera total garante que a lista nunca
/// fique desatualizada por mais que `maxWait`, mesmo num arrasto longo e contínuo.
public enum FrilaCouplingDelay: Sendable {
    /// Atraso com a mão devagar (s): só o suficiente para filtrar o ruído de uma linha isolada.
    public static let minDelay: Double = 0.05
    /// Atraso com a mão rápida (s).
    public static let maxDelay: Double = 0.45
    /// Espera total máxima desde a primeira troca pendente (s): o limitador de estresse.
    public static let maxWait: Double = 0.6
    /// Atraso mínimo (s) a partir do qual a lista de Função mostra o estado aguardando em vez de ficar parada.
    public static let skeletonThreshold: Double = 0.15
    /// Linhas por segundo a partir das quais o atraso satura em `maxDelay`.
    public static let saturationRowsPerSecond: Double = 10

    /// Atraso para a velocidade medida em linhas por segundo, com curva suavizada (smoothstep).
    public static func delay(rowsPerSecond: Double) -> Double {
        let t = max(0, min(1, rowsPerSecond / saturationRowsPerSecond))
        let eased = t * t * (3 - 2 * t)
        return minDelay + (maxDelay - minDelay) * eased
    }

    /// Reduz o atraso para que a espera total (já esperada + atraso) não passe de `maxWait`.
    public static func cappedDelay(_ delay: Double, alreadyWaited: Double) -> Double {
        max(0, min(delay, maxWait - alreadyWaited))
    }
}
