import Foundation

public struct CadastroConta: Codable, Equatable, Sendable {
    public let nome: String
    public let telefone: String
    public let nascimento: DataCivil
    public let perfil: PerfilConta
    /// Versão dos termos que a tela exibiu. O instante do aceite é carimbado pelo servidor.
    public let versaoTermos: String

    public init(nome: String, telefone: String, nascimento: DataCivil, perfil: PerfilConta, versaoTermos: String) {
        self.nome = nome
        self.telefone = telefone
        self.nascimento = nascimento
        self.perfil = perfil
        self.versaoTermos = versaoTermos
    }
}

public struct DadosPerfilProfissional: Codable, Equatable, Sendable {
    public let funcoes: [UUID]
    public let pontoBase: Coordenada
    public let disponibilidades: [JanelaDeDisponibilidade]

    public init(funcoes: [UUID], pontoBase: Coordenada, disponibilidades: [JanelaDeDisponibilidade]) {
        self.funcoes = funcoes
        self.pontoBase = pontoBase
        self.disponibilidades = disponibilidades
    }
}

/// Só o que muda vai para o servidor; campo nulo fica como está.
public struct AlteracaoPerfilProfissional: Codable, Equatable, Sendable {
    public let funcoes: [UUID]?
    public let pontoBase: Coordenada?
    public let disponibilidades: [JanelaDeDisponibilidade]?

    public init(funcoes: [UUID]? = nil, pontoBase: Coordenada? = nil, disponibilidades: [JanelaDeDisponibilidade]? = nil) {
        self.funcoes = funcoes
        self.pontoBase = pontoBase
        self.disponibilidades = disponibilidades
    }
}

public struct CadastroEstabelecimento: Codable, Equatable, Sendable {
    public let nome: String
    /// CPF (11) ou CNPJ (14), só dígitos.
    public let documento: String
    public let tipo: TipoEstabelecimento
    public let endereco: String
    public let ponto: Coordenada

    public init(nome: String, documento: String, tipo: TipoEstabelecimento, endereco: String, ponto: Coordenada) {
        self.nome = nome
        self.documento = documento
        self.tipo = tipo
        self.endereco = endereco
        self.ponto = ponto
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
    public let traje: String?
    public let participaRateio: Bool?
    public let observacoes: String?
    public let modo: ModoPreenchimento
    public let alertaAntecedenciaMinutos: Int?
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
        traje: String? = nil,
        participaRateio: Bool? = nil,
        observacoes: String? = nil,
        modo: ModoPreenchimento = .urgencia,
        alertaAntecedenciaMinutos: Int? = nil,
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
        self.traje = traje
        self.participaRateio = participaRateio
        self.observacoes = observacoes
        self.modo = modo
        self.alertaAntecedenciaMinutos = alertaAntecedenciaMinutos
        self.chave = chave
    }
}

public struct VagaPublicada: Codable, Equatable, Sendable {
    public let vagaID: UUID
    public let posicoes: [UUID]
    public init(vagaID: UUID, posicoes: [UUID]) { self.vagaID = vagaID; self.posicoes = posicoes }
}

/// Filtros de `vagas_abertas`. A distância ordena; só `distanciaMaximaKm` filtra (B07).
public struct FiltroVagas: Codable, Equatable, Sendable {
    public let referencia: Coordenada?
    public let funcaoID: UUID?
    /// Dia do início no fuso de São Paulo.
    public let data: DataCivil?
    public let distanciaMaximaKm: Double?
    public let limite: Int?
    public let deslocamento: Int?

    public init(
        referencia: Coordenada? = nil,
        funcaoID: UUID? = nil,
        data: DataCivil? = nil,
        distanciaMaximaKm: Double? = nil,
        limite: Int? = nil,
        deslocamento: Int? = nil
    ) {
        self.referencia = referencia
        self.funcaoID = funcaoID
        self.data = data
        self.distanciaMaximaKm = distanciaMaximaKm
        self.limite = limite
        self.deslocamento = deslocamento
    }

    public static let todas = FiltroVagas()
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
    public let versaoMinima: String
    public let versaoRecomendada: String
    public let mensagem: String?
    public let urlDaLoja: URL

    public init(versaoMinima: String, versaoRecomendada: String, mensagem: String?, urlDaLoja: URL) {
        self.versaoMinima = versaoMinima
        self.versaoRecomendada = versaoRecomendada
        self.mensagem = mensagem
        self.urlDaLoja = urlDaLoja
    }
}

/// As operações do contrato que o app usa até o Sprint 1, mais check-in, check-out e avaliação.
public protocol ApiCliente: Sendable {
    // Entrada
    func solicitarCodigo(email: String) async throws
    func verificarCodigo(email: String, codigo: String) async throws
    func entrarDemonstracao(email: String, codigo: String) async throws

    // Conta e perfil
    /// `ErroDaApi.naoEncontrado` quando há sessão e ainda não há conta: é o primeiro acesso.
    func minhaConta() async throws -> Conta
    func criarConta(_ cadastro: CadastroConta) async throws -> Conta
    func criarPerfilProfissional(_ dados: DadosPerfilProfissional) async throws -> PerfilProfissional
    func meuPerfilProfissional() async throws -> PerfilProfissional
    func atualizarPerfilProfissional(_ alteracao: AlteracaoPerfilProfissional) async throws -> PerfilProfissional

    // Estabelecimento
    func cadastrarEstabelecimento(_ cadastro: CadastroEstabelecimento) async throws -> Estabelecimento
    func meusEstabelecimentos() async throws -> [EstabelecimentoDaConta]
    func painelEstabelecimento(id: UUID, periodo: Periodo) async throws -> Painel

    // Catálogo e vagas
    func funcoes() async throws -> [Funcao]
    func publicarVaga(_ publicacao: PublicacaoVaga) async throws -> VagaPublicada
    func republicarVaga(id: UUID, periodo: Periodo, chave: UUID) async throws -> VagaPublicada
    func vagasAbertas(_ filtro: FiltroVagas) async throws -> [VagaNaLista]
    func detalheDaVaga(id: UUID) async throws -> Vaga
    func candidatar(vagaID: UUID) async throws -> ResultadoCandidatura
    func perfilPublico(id: UUID) async throws -> PerfilPublico

    // Turno
    func meusTurnos() async throws -> [Turno]
    func contatoDoTurno(id: UUID) async throws -> Contato
    func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro
    func fazerCheckout(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro
    func avaliar(turnoID: UUID, resposta: Bool) async throws -> Avaliacao

    // Aplicativo e dispositivo
    func configuracaoDoApp() async throws -> ConfiguracaoApp
    func removerDispositivo(tokenFCM: String) async throws
    func sair(tokenFCM: String?) async
}

public extension ApiCliente {
    func vagasAbertas() async throws -> [VagaNaLista] { try await vagasAbertas(.todas) }
}

public protocol VagaRepositorio: Sendable {
    func abertas(_ filtro: FiltroVagas) async throws -> [VagaNaLista]
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
