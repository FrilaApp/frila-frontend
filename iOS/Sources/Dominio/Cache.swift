import Foundation

public struct TurnoEmCache: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let turno: Turno
    public let salvoEm: Date

    public init(id: UUID, turno: Turno, salvoEm: Date) {
        self.id = id
        self.turno = turno
        self.salvoEm = salvoEm
    }
}

/// De onde vieram os turnos: da API agora, ou do que ficou guardado da última leitura.
public enum OrigemDosTurnos: Equatable, Sendable {
    case rede
    case cache
}

public struct LeituraDeTurnos: Equatable, Sendable {
    public let turnos: [Turno]
    public let origem: OrigemDosTurnos

    public init(turnos: [Turno], origem: OrigemDosTurnos) {
        self.turnos = turnos
        self.origem = origem
    }
}

public enum TipoAcaoPendente: String, Codable, CaseIterable, Sendable {
    case checkin
    case checkout
    case avaliacao
    case publicacaoVaga
    case republicacaoVaga
}

public struct RepublicacaoVaga: Codable, Equatable, Sendable {
    public let vagaID: UUID
    public let periodo: Periodo

    public init(vagaID: UUID, periodo: Periodo) {
        self.vagaID = vagaID
        self.periodo = periodo
    }
}

public struct AcaoPendente: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let tipo: TipoAcaoPendente
    public let turnoID: UUID?
    public let instanteDoToque: Date
    public let chave: UUID
    public let distanciaMetros: Int?
    public let resposta: Bool?
    /// Autor da avaliação local; nil nos registros legados e nas outras ações.
    public let contaID: UUID?
    public let publicacao: PublicacaoVaga?
    public let republicacao: RepublicacaoVaga?

    public init(
        id: UUID = UUID(),
        tipo: TipoAcaoPendente,
        turnoID: UUID? = nil,
        contaID: UUID? = nil,
        instanteDoToque: Date,
        chave: UUID,
        distanciaMetros: Int? = nil,
        resposta: Bool? = nil,
        publicacao: PublicacaoVaga? = nil,
        republicacao: RepublicacaoVaga? = nil
    ) {
        self.id = id
        self.tipo = tipo
        self.turnoID = turnoID
        self.contaID = contaID
        self.instanteDoToque = instanteDoToque
        self.chave = chave
        self.distanciaMetros = distanciaMetros
        self.resposta = resposta
        self.publicacao = publicacao
        self.republicacao = republicacao
    }
}

public protocol CacheLocal: Sendable {
    func salvar(sessao: SessaoUsuario) async throws
    func sessao() async throws -> SessaoUsuario?
    func salvar(turnos: [Turno], em instante: Date) async throws
    func turnosValidos(em instante: Date) async throws -> [Turno]
    func salvar(contato: Contato, doTurno turnoID: UUID) async throws
    func contato(doTurno turnoID: UUID, em instante: Date) async throws -> Contato?
    func removerContato(doTurno turnoID: UUID) async throws
    func salvar(funcoes: [Funcao]) async throws
    func funcoes() async throws -> [Funcao]
    func limpar() async throws
}

public protocol FilaDeAcoes: Sendable {
    func enfileirar(_ acao: AcaoPendente) async throws
    func pendentes() async throws -> [AcaoPendente]
    func remover(id: UUID) async throws
    /// Guarda o aviso e tira a ação dos reenvios na mesma gravação.
    func recusar(_ acao: AcaoPendente, codigo: CodigoErroAPI) async throws
    func recusadas() async throws -> [AcaoRecusada]
    func limpar() async throws
}

/// Se o aparelho tem conexão agora. O primeiro valor é o estado atual; os seguintes, cada mudança.
public protocol MonitorDeConexao: Sendable {
    func estados() -> AsyncStream<Bool>
}

/// Registro mínimo da recusa: não guarda o formulário, a localização nem os detalhes do servidor.
public struct AcaoRecusada: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let tipo: TipoAcaoPendente
    public let turnoID: UUID?
    public let vagaID: UUID?
    public let estabelecimentoID: UUID?
    public let codigo: CodigoErroAPI

    public init(acao: AcaoPendente, codigo: CodigoErroAPI) {
        id = acao.id
        tipo = acao.tipo
        turnoID = acao.turnoID
        vagaID = acao.republicacao?.vagaID
        estabelecimentoID = acao.publicacao?.estabelecimentoID
        self.codigo = codigo
    }
}

public extension Notification.Name {
    static let filaDeAcoesAtualizada = Notification.Name("frila.filaDeAcoesAtualizada")
}
