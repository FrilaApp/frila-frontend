import Foundation

/// Endereços oficiais das páginas institucionais e termos legais do Frila.
public struct EnderecosOficiais: Sendable, Equatable {
    public let termosDeUso: URL
    public let politicaDePrivacidade: URL

    public init(termosDeUso: URL, politicaDePrivacidade: URL) {
        self.termosDeUso = termosDeUso
        self.politicaDePrivacidade = politicaDePrivacidade
    }

    /// Constante oficial única que reúne os endereços de Termos de Uso e Política de Privacidade.
    public static let padrao = EnderecosOficiais(
        termosDeUso: URL(string: "https://frila.app/termos")!,
        politicaDePrivacidade: URL(string: "https://frila.app/privacidade")!
    )
}

public extension EnderecosOficiais {
    var termos: URL { termosDeUso }
    var privacidade: URL { politicaDePrivacidade }

    static var termosDeUso: URL { padrao.termosDeUso }
    static var politicaDePrivacidade: URL { padrao.politicaDePrivacidade }
}

public let enderecosOficiais = EnderecosOficiais.padrao
