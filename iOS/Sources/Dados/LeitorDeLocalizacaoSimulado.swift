import Foundation
import FrilaDominio

/// Dublê do GPS para testes e para o esquema Frila-Local. Responde o que foi combinado e conta as
/// chamadas, para o teste provar que a posição só é lida no toque.
public actor LeitorDeLocalizacaoSimulado: LeitorDeLocalizacao {
    /// `-FRILA_LOCALIZACAO <cenário>` no esquema Local. As distâncias são até a vaga das fixtures.
    public enum Cenario: String, CaseIterable, Sendable {
        case perto
        case longe
        case negada
        case semSinal = "sem-sinal"
        case imprecisa
        case aproximada
    }

    private var permissaoAtual: PermissaoDeLocalizacao
    private let respostaAoPedido: PermissaoDeLocalizacao
    private let respostaAPrecisaoTemporaria: PermissaoDeLocalizacao
    private let resultado: Result<LeituraDeLocalizacao, ErroDeLocalizacao>

    public private(set) var pedidosDePermissao = 0
    public private(set) var chavesDePrecisaoTemporaria: [String] = []
    public private(set) var leituras = 0
    public private(set) var ultimoTempoLimite: Duration?

    public init(
        permissao: PermissaoDeLocalizacao = .aoUsarPrecisa,
        respostaAoPedido: PermissaoDeLocalizacao = .aoUsarPrecisa,
        respostaAPrecisaoTemporaria: PermissaoDeLocalizacao = .aoUsarAproximada,
        resultado: Result<LeituraDeLocalizacao, ErroDeLocalizacao>
    ) {
        self.permissaoAtual = permissao
        self.respostaAoPedido = respostaAoPedido
        self.respostaAPrecisaoTemporaria = respostaAPrecisaoTemporaria
        self.resultado = resultado
    }

    public func permissao() async -> PermissaoDeLocalizacao { permissaoAtual }

    public func pedirPermissao() async -> PermissaoDeLocalizacao {
        pedidosDePermissao += 1
        if permissaoAtual == .naoDeterminada { permissaoAtual = respostaAoPedido }
        return permissaoAtual
    }

    public func pedirPrecisaoTemporaria(chave: String) async -> PermissaoDeLocalizacao {
        chavesDePrecisaoTemporaria.append(chave)
        if permissaoAtual == .aoUsarAproximada { permissaoAtual = respostaAPrecisaoTemporaria }
        return permissaoAtual
    }

    public func lerUmaVez(tempoLimite: Duration, precisaoSuficienteMetros: Double) async throws(ErroDeLocalizacao) -> LeituraDeLocalizacao {
        leituras += 1
        ultimoTempoLimite = tempoLimite
        return try resultado.get()
    }
}

public extension LeitorDeLocalizacaoSimulado {
    /// Posição a `metros` ao norte de `ponto`, pela mesma esfera de `Coordenada.distancia`.
    static func leitura(a metros: Double, de ponto: Coordenada, precisaoMetros: Double = 10) -> LeituraDeLocalizacao {
        let grausPorMetro = 180 / (Double.pi * 6_371_000)
        let latitude = min(ponto.latitude + metros * grausPorMetro, 90)
        let coordenada = (try? Coordenada(latitude: latitude, longitude: ponto.longitude)) ?? ponto
        return LeituraDeLocalizacao(coordenada: coordenada, precisaoHorizontalMetros: precisaoMetros)
    }

    /// Começa sem permissão decidida, para a tela mostrar a explicação antes do pedido.
    init(cenario: Cenario, pontoDaVaga: Coordenada) {
        switch cenario {
        case .perto:
            self.init(permissao: .naoDeterminada, resultado: .success(Self.leitura(a: 150, de: pontoDaVaga)))
        case .longe:
            self.init(permissao: .naoDeterminada, resultado: .success(Self.leitura(a: 350, de: pontoDaVaga)))
        case .negada:
            self.init(permissao: .naoDeterminada, respostaAoPedido: .negada, resultado: .failure(.permissaoNegada))
        case .semSinal:
            self.init(permissao: .naoDeterminada, resultado: .failure(.tempoEsgotado))
        case .imprecisa:
            self.init(permissao: .naoDeterminada, resultado: .success(Self.leitura(a: 150, de: pontoDaVaga, precisaoMetros: 180)))
        case .aproximada:
            self.init(permissao: .naoDeterminada, respostaAoPedido: .aoUsarAproximada, resultado: .failure(.semSinal))
        }
    }

    #if DEBUG
    /// `nil` sem o argumento: quem compõe o app usa então o GPS de verdade. Só em Debug (#96).
    static func pelosArgumentos(_ argumentos: [String] = ProcessInfo.processInfo.arguments) -> LeitorDeLocalizacaoSimulado? {
        guard let indice = argumentos.firstIndex(of: "-FRILA_LOCALIZACAO"), argumentos.indices.contains(indice + 1),
              let cenario = Cenario(rawValue: argumentos[indice + 1]),
              let vaga = try? FixturesDoContrato.carregar("vaga", como: ContratoAPI.VagaDTO.self).dominio() else { return nil }
        return LeitorDeLocalizacaoSimulado(cenario: cenario, pontoDaVaga: vaga.ponto)
    }
    #endif
}
