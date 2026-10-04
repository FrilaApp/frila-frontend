import Foundation

/// O resultado da checagem de faixa etária pela Declared Age Range (iOS 26.2+, cartão #215).
public enum ResultadoVerificacaoIdade: String, Equatable, Sendable {
    /// O sistema informou que a pessoa tem menos de 18 anos.
    case abaixoDe18 = "abaixo-de-18"
    /// O sistema informou que a pessoa tem 18 anos ou mais.
    case dezoitoOuMais = "18-ou-mais"
    /// A pessoa recusou compartilhar a faixa etária com o app.
    case recusou
    /// O serviço está indisponível (erro de sistema, rede, aparelho/região não elegível ou iOS < 26.2).
    case indisponivel
}

/// Porta no domínio para verificação de maioridade via Declared Age Range (iOS 26.2+, RN20).
public protocol VerificadorDeIdade: Sendable {
    @MainActor
    func verificarMaioridade() async -> ResultadoVerificacaoIdade
}

/// Implementação padrão que sempre devolve indisponível (usada como fallback e em plataformas/versões sem suporte).
public struct VerificadorDeIdadeIndisponivel: VerificadorDeIdade {
    public init() {}

    @MainActor
    public func verificarMaioridade() async -> ResultadoVerificacaoIdade {
        .indisponivel
    }
}
