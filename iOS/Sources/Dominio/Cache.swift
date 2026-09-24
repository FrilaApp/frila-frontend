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

public enum TipoAcaoPendente: String, Codable, CaseIterable, Sendable {
    case checkin
    case checkout
    case avaliacao
}

public struct AcaoPendente: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let tipo: TipoAcaoPendente
    public let turnoID: UUID
    public let instanteDoToque: Date
    public let chave: UUID
    public let distanciaMetros: Int?
    public let resposta: Bool?

    public init(
        id: UUID = UUID(),
        tipo: TipoAcaoPendente,
        turnoID: UUID,
        instanteDoToque: Date,
        chave: UUID,
        distanciaMetros: Int? = nil,
        resposta: Bool? = nil
    ) {
        self.id = id
        self.tipo = tipo
        self.turnoID = turnoID
        self.instanteDoToque = instanteDoToque
        self.chave = chave
        self.distanciaMetros = distanciaMetros
        self.resposta = resposta
    }
}

public protocol CacheLocal: Sendable {
    func salvar(sessao: SessaoUsuario) async throws
    func sessao() async throws -> SessaoUsuario?
    func salvar(turnos: [Turno], em instante: Date) async throws
    func turnosValidos(em instante: Date) async throws -> [Turno]
    func salvar(funcoes: [Funcao]) async throws
    func funcoes() async throws -> [Funcao]
    func limpar() async throws
}

public protocol FilaDeAcoes: Sendable {
    func enfileirar(_ acao: AcaoPendente) async throws
    func pendentes() async throws -> [AcaoPendente]
    func remover(id: UUID) async throws
    func limpar() async throws
}
