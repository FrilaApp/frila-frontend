import Foundation

/// Modelo matemático puro para a física da roleta canônica do Frila.
/// Desacoplado de SwiftUI para permitir testes determinísticos de inércia,
/// amortecimento elástico (rubber banding) e snap por projeção.
public enum FrilaLPEWheelPhysics: Sendable {
    /// Taxa canônica de desaceleração do UIScrollView no UIKit (normal = 0.998).
    public static let standardDecelerationRate: CGFloat = 0.998

    /// Constante de rigidez da mola interpolada padrão do Frila.
    public static let springStiffness: Double = 350.0
    /// Constante de amortecimento da mola interpolada padrão do Frila.
    public static let springDamping: Double = 25.0

    /// Aplica resistência elástica (rubber banding estilo UIScrollView) quando o deslocamento
    /// ultrapassa os limites [0, maxOffset].
    /// - Parameters:
    ///   - offset: Deslocamento linear proposto (em pt).
    ///   - maxOffset: Deslocamento máximo permitido (geralmente `(count - 1) * rowHeight`).
    ///   - dimension: Altura de referência do container para a curva de resistência (padrão 220 pt).
    /// - Returns: O deslocamento com amortecimento elástico aplicado.
    public static func rubberBand(
        offset: CGFloat,
        maxOffset: CGFloat,
        dimension: CGFloat = 220.0
    ) -> CGFloat {
        let safeMax = max(0, maxOffset)
        let dim = max(1.0, dimension)

        if offset < 0 {
            let overscroll = -offset
            let resisted = (overscroll * 0.55) / (1.0 + (overscroll / dim))
            return -resisted
        } else if offset > safeMax {
            let overscroll = offset - safeMax
            let resisted = (overscroll * 0.55) / (1.0 + (overscroll / dim))
            return safeMax + resisted
        } else {
            return offset
        }
    }

    /// Projeta o deslocamento final com base na velocidade de soltura e na taxa de desaceleração UIKit.
    ///
    /// Fórmula física:
    /// `projetado = offset - velocityY * d / (1 - d) / 1000`
    /// - Parameters:
    ///   - currentOffset: Deslocamento no instante da soltura (em pt).
    ///   - velocityY: Componente vertical da velocidade de soltura (em pt/s).
    ///   - decelerationRate: Taxa de desaceleração (padrão 0.998).
    /// - Returns: Deslocamento projetado pela inércia.
    public static func projectedOffset(
        currentOffset: CGFloat,
        velocityY: CGFloat,
        decelerationRate: CGFloat = standardDecelerationRate
    ) -> CGFloat {
        guard decelerationRate > 0 && decelerationRate < 1.0 else {
            return currentOffset
        }
        // Fator UIKit: d / (1 - d) / 1000. Para d = 0.998 => 0.998 / 0.002 / 1000 = 0.499
        let factor = (decelerationRate / (1.0 - decelerationRate)) / 1000.0
        return currentOffset - (velocityY * factor)
    }

    /// Calcula o índice do item alvo aplicando snap por arredondamento e clamp aos limites.
    /// - Parameters:
    ///   - projectedOffset: Deslocamento projetado pela inércia.
    ///   - rowHeight: Altura de cada linha da roleta (em pt).
    ///   - itemCount: Quantidade total de itens na roleta.
    /// - Returns: Índice inteiro no intervalo `[0, max(0, itemCount - 1)]`.
    public static func targetIndex(
        projectedOffset: CGFloat,
        rowHeight: CGFloat,
        itemCount: Int
    ) -> Int {
        guard itemCount > 0 else { return 0 }
        let h = max(1.0, rowHeight)
        let rawIndex = Int(round(projectedOffset / h))
        return max(0, min(itemCount - 1, rawIndex))
    }

    /// Retorna o deslocamento exato para centralizar o item do índice informado.
    /// - Parameters:
    ///   - targetIndex: Índice do item desejado.
    ///   - rowHeight: Altura da linha.
    /// - Returns: Deslocamento em pt correspondente.
    public static func targetOffset(
        targetIndex: Int,
        rowHeight: CGFloat
    ) -> CGFloat {
        CGFloat(max(0, targetIndex)) * rowHeight
    }

    /// Retorna o índice sob a faixa central para o deslocamento atual.
    /// Utilizado para disparar feedback haptic e expor o valor acessível durante a rolagem.
    public static func indexUnderBand(
        offset: CGFloat,
        rowHeight: CGFloat,
        itemCount: Int
    ) -> Int {
        targetIndex(projectedOffset: offset, rowHeight: rowHeight, itemCount: itemCount)
    }

    /// Calcula a velocidade inicial normalizada para a mola interpolada SwiftUI.
    /// - Parameters:
    ///   - velocityY: Velocidade vertical de soltura (em pt/s).
    ///   - currentOffset: Deslocamento no instante de soltura.
    ///   - targetOffset: Deslocamento do alvo final.
    /// - Returns: Velocidade normalizada (em unidades de distância por segundo).
    public static func initialSpringVelocity(
        velocityY: CGFloat,
        currentOffset: CGFloat,
        targetOffset: CGFloat
    ) -> Double {
        let delta = targetOffset - currentOffset
        guard abs(delta) > 0.5 else { return 0.0 }
        let deltaV = -Double(velocityY)
        return deltaV / Double(abs(delta))
    }
}
