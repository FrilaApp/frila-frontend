import Observation
import SwiftUI
import UIKit

/// As duas aparências que a pessoa escolhe em Conta > Aparência. O claro é a identidade padrão do
/// app; o escuro é opção. Não há "seguir o sistema" de propósito (decisão do Cauê, 06/11/2026).
public enum Aparencia: String, CaseIterable, Sendable {
    case claro
    case escuro

    public var esquemaDeCor: ColorScheme {
        switch self {
        case .claro: .light
        case .escuro: .dark
        }
    }

    /// Para os pontos que falam com o UIKit direto (janela da cortina de privacidade).
    public var estiloDoUIKit: UIUserInterfaceStyle {
        switch self {
        case .claro: .light
        case .escuro: .dark
        }
    }
}

/// Guarda no aparelho (`UserDefaults`) a aparência escolhida. Nada vai ao servidor e a escolha não
/// é limpa ao sair da conta: é do aparelho, não da conta. Sem escolha guardada, ou com um valor
/// que o app não conhece, vale o claro.
@MainActor @Observable
public final class PreferenciaDeAparencia {
    public static let chave = "frila_aparencia"
    public static let compartilhada = PreferenciaDeAparencia()

    public private(set) var aparencia: Aparencia
    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        aparencia = Self.ler(de: defaults)
    }

    public var esquemaDeCor: ColorScheme { aparencia.esquemaDeCor }

    public func escolher(_ nova: Aparencia) {
        aparencia = nova
        defaults.set(nova.rawValue, forKey: Self.chave)
    }

    private static func ler(de defaults: UserDefaults) -> Aparencia {
        guard let bruto = defaults.string(forKey: chave), let guardada = Aparencia(rawValue: bruto) else { return .claro }
        return guardada
    }

    /// O esquema que o app aplica à raiz: o forçado pelos argumentos de teste (só em Debug) vem
    /// primeiro; sem ele, vale a escolha guardada. Nunca é `nil`: nunca seguimos o sistema.
    public nonisolated static func esquemaEfetivo(forcado: ColorScheme?, escolhida: Aparencia) -> ColorScheme {
        forcado ?? escolhida.esquemaDeCor
    }
}

private struct AparenciaEscolhida: ViewModifier {
    let forcado: ColorScheme?
    let preferencia: PreferenciaDeAparencia

    func body(content: Content) -> some View {
        content.preferredColorScheme(
            PreferenciaDeAparencia.esquemaEfetivo(forcado: forcado, escolhida: preferencia.aparencia)
        )
    }
}

public extension View {
    /// Aplica na raiz a aparência escolhida no aparelho (claro por padrão), por cima do modo do
    /// sistema. `forcado` (argumentos de teste de interface, só em Debug) tem prioridade.
    func aparenciaEscolhida(forcado: ColorScheme? = nil) -> some View {
        modifier(AparenciaEscolhida(forcado: forcado, preferencia: .compartilhada))
    }
}
