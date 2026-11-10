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
    /// Alguma leitura do toque veio de fonte simulada por software (`isSimulatedBySoftware`).
    public let simulada: Bool
    /// A posição saltou entre as leituras do mesmo toque (`SaltoDePosicao`).
    public let saltoDePosicao: Bool

    public init(coordenada: Coordenada, precisaoHorizontalMetros: Double, simulada: Bool = false, saltoDePosicao: Bool = false) {
        self.coordenada = coordenada
        self.precisaoHorizontalMetros = precisaoHorizontalMetros
        self.simulada = simulada
        self.saltoDePosicao = saltoDePosicao
    }
}

/// O salto de posição do check-in por código (contrato 0.2.68, desenho 9.5): entre duas leituras do mesmo
/// toque, a posição andou mais do que alguém andaria no intervalo. Critério do app, confirmado pelo João
/// Paulo em 08/11/2026: 50 m/s (180 km/h), intervalo mínimo de 1 s, e uma leitura só não tem salto. A
/// distância entre as leituras vale menos a soma das duas precisões, para o ruído do GPS não valer como salto.
public enum SaltoDePosicao {
    public static let velocidadeMaximaMetrosPorSegundo = 50.0
    public static let intervaloMinimoSegundos = 1.0

    public static func houve(
        de anterior: (coordenada: Coordenada, precisaoMetros: Double, instante: Date),
        para atual: (coordenada: Coordenada, precisaoMetros: Double, instante: Date)
    ) -> Bool {
        let intervalo = atual.instante.timeIntervalSince(anterior.instante)
        guard intervalo >= intervaloMinimoSegundos else { return false }
        let andou = anterior.coordenada.distancia(emMetrosDe: atual.coordenada) - anterior.precisaoMetros - atual.precisaoMetros
        return andou > velocidadeMaximaMetrosPorSegundo * intervalo
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
    /// Check-in por código semiautomático (Etapa 1, backend bedcd4c):
    /// O raio de proximidade para validação é de 50 metros provisório.
    public static let raioDoCodigoSemiautoMetros = 50

    /// Check-in por código legado (0.2.68).
    public static let raioDoCodigoMetros = 100
    public static let tempoLimiteDaLeitura: Duration = .seconds(10)
    public static let chaveDaPrecisaoTemporaria = "CheckIn"

    /// Decisão de envio do código semiautomático (Etapa 1, backend bedcd4c):
    /// Exige leitura de localização presente (não-nula) e dentro de 50 metros.
    /// Se a distância for nula ou superior a 50m, avisa "chegue mais perto" e não envia o código,
    /// evitando queimar tentativas contra o servidor (que recusa estritamente nil e >50m com 422).
    public static func decisaoDoEnvioDoCodigoSemiauto(distanciaMetros: Int?) -> DecisaoDoEnvioDoCodigo {
        guard let distanciaMetros else { return .chegueMaisPerto(distanciaMetros: 0) }
        guard distanciaMetros <= raioDoCodigoSemiautoMetros else { return .chegueMaisPerto(distanciaMetros: distanciaMetros) }
        return .liberado
    }

    /// O "chegue mais perto" do check-in por código (cartão LX77r6gR): mantido para compatibilidade.
    public static func decisaoDoEnvioDoCodigo(distanciaMetros: Int?) -> DecisaoDoEnvioDoCodigo {
        guard let distanciaMetros, distanciaMetros > raioDoCodigoMetros else { return .liberado }
        return .chegueMaisPerto(distanciaMetros: distanciaMetros)
    }
}

public enum DecisaoDoEnvioDoCodigo: Equatable, Sendable {
    case liberado
    case chegueMaisPerto(distanciaMetros: Int)
}
