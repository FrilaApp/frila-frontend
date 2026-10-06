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
    /// `cancelar_posicao` e `cancelar_vaga` entram na fila sem rede (contrato 0.2.17, RN12). O
    /// motivo vai junto; o id da posição ou da vaga fica em `alvoID`.
    case cancelamentoPosicao
    case cancelamentoVaga
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
    /// Conta da sessão que criou a ação; nil nos registros legados de desenvolvimento.
    public let contaID: UUID?
    public let publicacao: PublicacaoVaga?
    public let republicacao: RepublicacaoVaga?
    /// A posição (`cancelamentoPosicao`) ou a vaga (`cancelamentoVaga`) que o cancelamento mira.
    public let alvoID: UUID?
    /// O motivo do cancelamento, já no texto que vai ao servidor (pelo menos 3 caracteres).
    public let motivo: String?

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
        republicacao: RepublicacaoVaga? = nil,
        alvoID: UUID? = nil,
        motivo: String? = nil
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
        self.alvoID = alvoID
        self.motivo = motivo
    }

    public func com(contaID: UUID) -> AcaoPendente {
        AcaoPendente(id: id, tipo: tipo, turnoID: turnoID, contaID: contaID,
                     instanteDoToque: instanteDoToque, chave: chave, distanciaMetros: distanciaMetros,
                     resposta: resposta, publicacao: publicacao, republicacao: republicacao,
                     alvoID: alvoID, motivo: motivo)
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
    /// A reconciliação precisa saber da recusa mesmo depois de fechar o aviso.
    func recusadas(incluirReconhecidas: Bool) async throws -> [AcaoRecusada]
    /// Uma tentativa aceita encerra os avisos anteriores da mesma operação e conta.
    func resolverRecusas(_ acao: AcaoPendente) async throws
    /// Fecha somente o aviso; o ID continua impedido de voltar aos reenvios.
    func reconhecerRecusa(id: UUID) async throws
    func limpar() async throws
}

public extension FilaDeAcoes {
    func recusadas(incluirReconhecidas: Bool) async throws -> [AcaoRecusada] { try await recusadas() }
    // Filas sem persistência de avisos (dublês) não têm recusas a resolver.
    func resolverRecusas(_ acao: AcaoPendente) async throws {}
    func reconhecerRecusa(id: UUID) async throws { throw ErroDaApi(codigo: .respostaInvalida) }
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
    public let contaID: UUID?
    public let codigo: CodigoErroAPI
    /// Ausente no JSON anterior: o aviso ainda deve aparecer.
    public private(set) var avisoReconhecido: Bool?

    public init(acao: AcaoPendente, codigo: CodigoErroAPI) {
        id = acao.id
        tipo = acao.tipo
        turnoID = acao.turnoID
        vagaID = acao.tipo == .cancelamentoVaga ? acao.alvoID : acao.republicacao?.vagaID
        estabelecimentoID = acao.publicacao?.estabelecimentoID
        contaID = acao.contaID
        self.codigo = codigo
    }

    public func comAvisoReconhecido() -> AcaoRecusada {
        var reconhecida = self
        reconhecida.avisoReconhecido = true
        return reconhecida
    }

    public func corresponde(a acao: AcaoPendente) -> Bool {
        tipo == acao.tipo && turnoID == acao.turnoID && vagaID == (acao.tipo == .cancelamentoVaga ? acao.alvoID : acao.republicacao?.vagaID)
            && estabelecimentoID == acao.publicacao?.estabelecimentoID
            && (contaID == nil || contaID == acao.contaID)
    }
}

public extension Notification.Name {
    static let filaDeAcoesAtualizada = Notification.Name("frila.filaDeAcoesAtualizada")
}
