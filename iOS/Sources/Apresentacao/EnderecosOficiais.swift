import Foundation

/// Endereços oficiais das páginas institucionais e termos legais do Frila.
public struct EnderecosOficiais: Sendable, Equatable {
    public let termosDeUso: URL
    public let politicaDePrivacidade: URL
    public let emailSuporte: String

    /// URL `mailto:` gerada a partir do e-mail de suporte.
    public var urlSuporte: URL? { URL(string: "mailto:\(emailSuporte)") }

    public init(termosDeUso: URL, politicaDePrivacidade: URL, emailSuporte: String) {
        self.termosDeUso = termosDeUso
        self.politicaDePrivacidade = politicaDePrivacidade
        self.emailSuporte = emailSuporte
    }

    /// Constante oficial única que reúne os endereços de Termos de Uso e Política de Privacidade.
    public static let padrao = EnderecosOficiais(
        termosDeUso: URL(string: "https://frila.app/termos")!,
        politicaDePrivacidade: URL(string: "https://frila.app/privacidade")!,
        emailSuporte: "suportefrila@gmail.com"
    )
}
