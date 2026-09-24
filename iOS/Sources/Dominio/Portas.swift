import Foundation

public struct CadastroConta: Codable, Equatable, Sendable {
    public let nome: String
    public let telefone: String
    public let nascimento: Date
    public let perfil: PerfilConta
    public let versaoTermos: String
    public let aceitouEm: Date

    public init(nome: String, telefone: String, nascimento: Date, perfil: PerfilConta, versaoTermos: String, aceitouEm: Date) {
        self.nome = nome
        self.telefone = telefone
        self.nascimento = nascimento
        self.perfil = perfil
        self.versaoTermos = versaoTermos
        self.aceitouEm = aceitouEm
    }
}

public struct PublicacaoVaga: Codable, Equatable, Sendable {
    public let estabelecimentoID: UUID
    public let funcaoID: UUID
    public let periodo: Periodo
    public let local: String
    public let ponto: Coordenada
    public let valor: Dinheiro
    public let posicoes: Int
    public let inclusos: Inclusos
    public let responsavelLocal: String
    public let modo: ModoPreenchimento
    public let chave: UUID

    public init(
        estabelecimentoID: UUID,
        funcaoID: UUID,
        periodo: Periodo,
        local: String,
        ponto: Coordenada,
        valor: Dinheiro,
        posicoes: Int,
        inclusos: Inclusos,
        responsavelLocal: String,
        modo: ModoPreenchimento = .urgencia,
        chave: UUID
    ) {
        self.estabelecimentoID = estabelecimentoID
        self.funcaoID = funcaoID
        self.periodo = periodo
        self.local = local
        self.ponto = ponto
        self.valor = valor
        self.posicoes = posicoes
        self.inclusos = inclusos
        self.responsavelLocal = responsavelLocal
        self.modo = modo
        self.chave = chave
    }
}

public struct VagaPublicada: Codable, Equatable, Sendable {
    public let vagaID: UUID
    public let posicoes: [UUID]
    public init(vagaID: UUID, posicoes: [UUID]) { self.vagaID = vagaID; self.posicoes = posicoes }
}

public struct ResultadoCandidatura: Codable, Equatable, Sendable {
    public enum Estado: String, Codable, Sendable { case confirmada, pendente }
    public let estado: Estado
    public let candidaturaID: UUID
    public let posicaoID: UUID?
    public let turnoID: UUID?
    public let contato: Contato?

    public init(estado: Estado, candidaturaID: UUID, posicaoID: UUID?, turnoID: UUID?, contato: Contato?) {
        self.estado = estado
        self.candidaturaID = candidaturaID
        self.posicaoID = posicaoID
        self.turnoID = turnoID
        self.contato = contato
    }
}

public struct ConfiguracaoApp: Codable, Equatable, Sendable {
    public let versaoMinimaIOS: String
    public let mensagem: String
    public let urlDaLoja: URL

    public init(versaoMinimaIOS: String, mensagem: String, urlDaLoja: URL) {
        self.versaoMinimaIOS = versaoMinimaIOS
        self.mensagem = mensagem
        self.urlDaLoja = urlDaLoja
    }
}

public protocol ApiCliente: Sendable {
    func solicitarCodigo(email: String) async throws
    func verificarCodigo(email: String, codigo: String) async throws -> SessaoUsuario
    func criarConta(_ cadastro: CadastroConta) async throws -> SessaoUsuario
    func funcoes() async throws -> [Funcao]
    func cadastrarEstabelecimento(_ estabelecimento: Estabelecimento) async throws -> Estabelecimento
    func meusEstabelecimentos() async throws -> [Estabelecimento]
    func publicarVaga(_ publicacao: PublicacaoVaga) async throws -> VagaPublicada
    func republicarVaga(id: UUID, periodo: Periodo, chave: UUID) async throws -> VagaPublicada
    func vagasAbertas() async throws -> [Vaga]
    func detalheDaVaga(id: UUID) async throws -> Vaga
    func candidatar(vagaID: UUID) async throws -> ResultadoCandidatura
    func meusTurnos() async throws -> [Turno]
    func contatoDoTurno(id: UUID) async throws -> Contato
    func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date, chave: UUID) async throws
    func fazerCheckout(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date, chave: UUID) async throws
    func avaliar(turnoID: UUID, resposta: Bool, chave: UUID) async throws -> Avaliacao
    func configuracaoDoApp() async throws -> ConfiguracaoApp
    func removerDispositivo(tokenFCM: String) async throws
    func sair(tokenFCM: String?) async
}

public protocol VagaRepositorio: Sendable {
    func abertas() async throws -> [Vaga]
    func detalhe(id: UUID) async throws -> Vaga
    func publicar(_ publicacao: PublicacaoVaga) async throws -> VagaPublicada
}

public protocol ProfissionalRepositorio: Sendable {
    func funcoes() async throws -> [Funcao]
}

public protocol TurnoRepositorio: Sendable {
    func meusTurnos() async throws -> [Turno]
}

public protocol ContaRepositorio: Sendable {
    func sair(tokenFCM: String?) async
}

public protocol NotificacaoPort: Sendable {
    func registrar(token: String) async throws
    func remover(token: String) async throws
}

public protocol TelemetryReporter: Sendable {
    func registrarErroDaApi(codigo: String, rpc: String, duracao: Duration) async
}

public struct TelemetryNula: TelemetryReporter {
    public init() {}
    public func registrarErroDaApi(codigo: String, rpc: String, duracao: Duration) async {}
}
