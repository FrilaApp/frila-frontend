import Foundation

/// Modelo puro da projeção cilíndrica da roleta: cada linha fica num cilindro imaginário, então a
/// distância linear até o centro vira ângulo, e o ângulo vira posição vertical comprimida, escala,
/// opacidade e desfoque. Desacoplado de SwiftUI para testar monotonicidade e a inversa (toque).
public enum FrilaLPEWheelPerspective: Sendable {
    /// Ângulo na borda do container. Leve de propósito: o cilindro sugere profundidade sem deformar o texto.
    public static let maxAngle: Double = 50.0 * .pi / 180.0
    /// Raio máximo do desfoque por linha, na borda (pt). O desfoque cresce de forma contínua, linha a linha.
    public static let maxBlurRadius: Double = 2.4

    /// Distância normalizada ao centro: 0 no centro, ±1 na borda do container.
    public static func normalized(delta: Double, halfHeight: Double) -> Double {
        guard halfHeight > 0 else { return 0 }
        return max(-1.25, min(1.25, delta / halfHeight))
    }

    /// Ângulo no cilindro para a distância normalizada.
    public static func angle(normalized n: Double) -> Double {
        n * maxAngle
    }

    /// Posição vertical projetada (relativa ao centro): linhas longe do centro se aproximam, como num cilindro.
    public static func projectedDelta(delta: Double, halfHeight: Double) -> Double {
        let n = normalized(delta: delta, halfHeight: halfHeight)
        return halfHeight * sin(angle(normalized: n)) / sin(maxAngle)
    }

    /// Inversa de `projectedDelta`: de uma posição de toque projetada, volta à distância linear na lista.
    public static func delta(forProjected projected: Double, halfHeight: Double) -> Double {
        guard halfHeight > 0 else { return 0 }
        let s = max(-1.0, min(1.0, projected / halfHeight * sin(maxAngle)))
        return asin(s) / maxAngle * halfHeight
    }

    /// Opacidade do texto regular: cai devagar e com curva suave, o esmaecimento final é da máscara.
    public static func opacity(normalized n: Double) -> Double {
        1.0 - 0.5 * pow(min(abs(n), 1.0), 1.5)
    }

    /// Escala horizontal leve: o texto afina um pouco ao se afastar, sem parecer encolhido.
    public static func scale(normalized n: Double) -> Double {
        1.0 - 0.06 * min(abs(n), 1.0)
    }

    /// Desfoque por linha. Curva de potência: imperceptível perto do centro, cresce só nas margens.
    public static func blurRadius(normalized n: Double) -> Double {
        maxBlurRadius * pow(min(abs(n), 1.0), 2.4)
    }
}
