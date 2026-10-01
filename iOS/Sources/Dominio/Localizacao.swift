import Foundation

/// O que a pessoa autorizou. O app só conhece a permissão "ao usar": a "sempre" não existe aqui,
/// porque a localização é lida só no toque do check-in e do check-out (RN22).
public enum PermissaoDeLocalizacao: Equatable, Sendable {
    case naoDeterminada
    /// Negada, restrita ou com o serviço de localização desligado.
    case negada
    case aoUsarPrecisa
    /// "Localização precisa" desligada: a leitura vem com erro de quilômetros e não mede 200 m.
    case aoUsarAproximada
}

/// Uma leitura do GPS. A coordenada fica no aparelho; para o servidor vai só a distância.
public struct LeituraDeLocalizacao: Equatable, Sendable {
    public let coordenada: Coordenada
    public let precisaoHorizontalMetros: Double

    public init(coordenada: Coordenada, precisaoHorizontalMetros: Double) {
        self.coordenada = coordenada
        self.precisaoHorizontalMetros = precisaoHorizontalMetros
    }
}

public enum ErroDeLocalizacao: Error, Equatable, Sendable {
    case permissaoNegada
    case semSinal
    case tempoEsgotado
}

public protocol LeitorDeLocalizacao: Sendable {
    func permissao() async -> PermissaoDeLocalizacao
    /// Pede a permissão "ao usar" e devolve o que a pessoa respondeu.
    func pedirPermissao() async -> PermissaoDeLocalizacao
    /// Com a localização aproximada, pede a precisa só para este uso. `chave` é a do
    /// `NSLocationTemporaryUsageDescriptionDictionary`.
    func pedirPrecisaoTemporaria(chave: String) async -> PermissaoDeLocalizacao
    /// Uma leitura, que termina sozinha: na primeira posição com a precisão pedida, ou no fim do
    /// prazo com a melhor que chegou. Nada continua lendo depois.
    func lerUmaVez(tempoLimite: Duration, precisaoSuficienteMetros: Double) async throws(ErroDeLocalizacao) -> LeituraDeLocalizacao
}

/// Limites do registro de presença pelo GPS (RF13, RN22 e `/rpc/fazer_checkin` do contrato).
public enum RegraDePresenca {
    /// Até aqui o check-in é `geolocalizado` e a presença fica `verificado` na hora.
    public static let distanciaMaximaDoCheckinMetros = 200
    /// Leitura com erro maior do que isto não prova que a pessoa está no endereço.
    public static let precisaoHorizontalMaximaMetros = 100.0
    public static let tempoLimiteDaLeitura: Duration = .seconds(10)
    public static let chaveDaPrecisaoTemporaria = "CheckIn"
}
