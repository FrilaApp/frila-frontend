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
    /// Logradouro, número e complemento.
    public let endereco: String
    /// Região Administrativa do DF onde o estabelecimento fica. Obrigatória desde o contrato 0.2.20.
    public let regiaoAdministrativa: String
    public let ponto: Coordenada

    public init(
        nome: String, documento: String, tipo: TipoEstabelecimento, endereco: String, regiaoAdministrativa: String,
        ponto: Coordenada
    ) {
        self.nome = nome
        self.documento = documento
        self.tipo = tipo
        self.endereco = endereco
        self.regiaoAdministrativa = regiaoAdministrativa
        self.ponto = ponto
    }
}

public struct PublicacaoVaga: Codable, Equatable, Sendable {
    public let estabelecimentoID: UUID
    public let funcaoID: UUID
    public let periodo: Periodo
    public let local: String
    /// Região Administrativa do DF onde o turno acontece. Vem preenchida com a do estabelecimento
    /// (contrato 0.2.20).
    public let regiaoAdministrativa: String
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
        regiaoAdministrativa: String,
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
        self.regiaoAdministrativa = regiaoAdministrativa
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

/// Resposta de `escolher_candidato` (`ResultadoConfirmacao` do contrato): a posição e o turno que a
/// escolha confirmou, com o contato do profissional, liberado a partir daí (RN10).
public struct ResultadoConfirmacao: Codable, Equatable, Sendable {
    public let posicaoID: UUID
    public let turnoID: UUID
    public let contato: Contato

    public init(posicaoID: UUID, turnoID: UUID, contato: Contato) {
        self.posicaoID = posicaoID
        self.turnoID = turnoID
        self.contato = contato
    }
}

public struct Denuncia: Codable, Equatable, Sendable {
    public let alvo: Alvo
    /// O turno em que aconteceu, quando a denúncia sai da tela de um turno.
    public let turnoID: UUID?
    public let motivo: MotivoDenuncia
    /// Pelo menos 10 caracteres.
    public let relato: String
    /// Gerada pelo app: reenviar com a mesma chave devolve o mesmo protocolo.
    public let chave: UUID

    public init(alvo: Alvo, turnoID: UUID? = nil, motivo: MotivoDenuncia, relato: String, chave: UUID) {
        self.alvo = alvo
        self.turnoID = turnoID
        self.motivo = motivo
        self.relato = relato
        self.chave = chave
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

/// Avisa quando a sessão deste aparelho foi encerrada: saída, ou um 401 que prova autenticação
/// inválida (token vencido ou recusado, ou conta encerrada, contrato 0.2.18). O aviso não prova
/// que o armazenamento apagou a sessão; quem precisa saber confere de novo.
public protocol ObservadorDeSessao: Sendable {
    func encerramentos() -> AsyncStream<Void>
}

/// As operações do contrato que o app usa até a Sprint 2.
public protocol ApiCliente: TurnoRepositorio, Sendable {
    // Entrada
    func solicitarCodigo(email: String) async throws
    func verificarCodigo(email: String, codigo: String) async throws
    func entrarDemonstracao(email: String, codigo: String) async throws
    /// Se há sessão guardada neste aparelho (válida ou renovável), sem expor e-mail nem token.
    func possuiSessao() async -> Bool

    // Conta e perfil
    /// `ErroDaApi.naoEncontrado` quando há sessão e ainda não há conta: é o primeiro acesso.
    func minhaConta() async throws -> Conta
    func criarConta(_ cadastro: CadastroConta) async throws -> Conta
    func criarPerfilProfissional(_ dados: DadosPerfilProfissional) async throws -> PerfilProfissional
    func meuPerfilProfissional() async throws -> PerfilProfissional
    func atualizarPerfilProfissional(_ alteracao: AlteracaoPerfilProfissional) async throws -> PerfilProfissional

    // Por que recebo vagas (RF27)
    /// Os critérios em vigor para quem chama. Conta de contratante é `perfilIncompativel`; sem
    /// perfil profissional, `naoEncontrado`. A leitura não exige conta ativa: a suspensa também lê.
    func criteriosDeNotificacao() async throws -> CriteriosDeNotificacao
    /// "Contestar" na tela: pede à Equipe Frila a revisão do despacho, com relato de pelo menos 10
    /// caracteres; a resposta vai por e-mail em até 5 dias úteis. Relato em branco é
    /// `campoObrigatorio` e curto, `campoInvalido`, os dois com `relato` no detalhe; conta suspensa é
    /// `semPermissao` com `conta_suspensa`. Não é idempotente: cada pedido abre uma ocorrência nova.
    func pedirRevisaoDespacho(relato: String) async throws -> Protocolo

    // Estabelecimento
    func cadastrarEstabelecimento(_ cadastro: CadastroEstabelecimento) async throws -> Estabelecimento
    func meusEstabelecimentos() async throws -> [EstabelecimentoDaConta]
    /// O cadastro de um estabelecimento de que a conta é membro (contrato 0.2.29): o endereço, a
    /// região e o ponto que preenchem a publicação de uma vaga. `meusEstabelecimentos` não os traz.
    /// Quem não é membro recebe `sem_permissao`.
    func meuEstabelecimento(id: UUID) async throws -> Estabelecimento
    func painelEstabelecimento(id: UUID, periodo: Periodo) async throws -> Painel

    // Catálogo e vagas
    func funcoes() async throws -> [Funcao]
    func publicarVaga(_ publicacao: PublicacaoVaga) async throws -> VagaPublicada
    func republicarVaga(id: UUID, periodo: Periodo, chave: UUID) async throws -> VagaPublicada
    func vagasAbertas(_ filtro: FiltroVagas) async throws -> [VagaNaLista]
    func detalheDaVaga(id: UUID) async throws -> Vaga
    func candidatar(vagaID: UUID) async throws -> ResultadoCandidatura
    func perfilPublico(id: UUID) async throws -> PerfilPublico

    // Modo seleção (contrato 0.2.24)
    /// Os candidatos que ainda esperam a escolha, por ordem de chegada, com perfil e reputação.
    /// Só para membro da casa (`semPermissao`); vaga que não existe é `naoEncontrado`. Quem já foi
    /// escolhido não vem aqui: está na posição confirmada do painel.
    func candidatosDaVaga(id: UUID) async throws -> [Candidato]
    /// A casa confirma um candidato numa posição aberta, com a garantia da RN19. **Não é
    /// idempotente:** escolher de novo a candidatura já escolhida responde
    /// `candidaturaIndisponivel`, e não o mesmo turno. Por isso a escolha nunca entra em fila
    /// offline, e depois de uma resposta perdida a tela relê os candidatos e o painel antes de
    /// dizer que falhou. `posicaoJaPreenchida`: outra escolha ocupou a última posição;
    /// `vagaEncerrada`: fechada pelas 24 h, cancelada ou encerrada; `candidaturaIndisponivel`:
    /// retirada, expirada ou já escolhida; `inelegivel`: `turno_sobreposto` ou `perfil_suspenso`;
    /// `vagaOculta`: ocultada pela moderação, e a candidatura segue pendente.
    func escolherCandidato(candidaturaID: UUID) async throws -> ResultadoConfirmacao
    /// O profissional desiste antes da escolha, sem penalidade (RN24). Retirar de novo devolve a
    /// mesma candidatura retirada. Escolhida, recusada ou expirada é `candidaturaIndisponivel`; a
    /// que não é de quem chama, `naoEncontrado`.
    func retirarCandidatura(id: UUID) async throws -> Candidatura
    /// As candidaturas do profissional, da mais nova para a mais antiga. Sem `estado`, todas:
    /// inclusive as `aceita` do modo urgência.
    func minhasCandidaturas(estado: EstadoCandidatura?) async throws -> [Candidatura]

    // Turno
    func meusTurnos() async throws -> [Turno]
    func contatoDoTurno(id: UUID) async throws -> Contato
    /// "Estou a caminho" (contrato 0.2.25): de 3 h antes até 15 min depois do início, e idempotente
    /// pelo turno. Não é presença. A porta existe; o botão fica para a v1.1 (decisão de produto).
    func avisarACaminho(turnoID: UUID) async throws -> ResultadoACaminho
    func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro
    func fazerCheckout(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro
    func avaliar(turnoID: UUID, resposta: Bool) async throws -> Avaliacao

    // Turno do contratante
    /// Um toque de quem opera a casa: só então o check-in manual conta como presença (RN22).
    /// Reenviar devolve o registro já confirmado. Sem check-in é `checkinPendente`; check-in
    /// geolocalizado, que já nasceu verificado, é `checkinJaConfirmado`.
    func confirmarCheckinManual(turnoID: UUID) async throws -> ResultadoRegistro
    /// Declara que o profissional não veio: marca falta e abre uma posição nova (D06). Antes dos
    /// 15 minutos do início é `reaberturaAntesDaTolerancia`; com check-in feito, `posicaoNaoCancelavel`.
    func reabrirPorAtraso(posicaoID: UUID) async throws -> ResultadoCancelamento

    // Cancelamento
    /// Qualquer das partes, com motivo de pelo menos 3 caracteres (RN12). O motivo vai para a tela
    /// da outra parte. Reenvio pelo mesmo autor devolve o resultado original sem repetir efeitos
    /// (0.2.35); `posicaoNaoCancelavel` indica recusa, inclusive cancelamento pela outra parte.
    func cancelarPosicao(id: UUID, motivo: String) async throws -> ResultadoCancelamento
    /// Só o contratante: cancela as posições abertas e as confirmadas, sem falta para ninguém.
    /// Reenvio pelo mesmo autor devolve o resultado original; `vagaEncerrada` indica recusa (0.2.35).
    func cancelarVaga(id: UUID, motivo: String) async throws -> VagaCancelada

    // Confiança e direitos
    func denunciar(_ denuncia: Denuncia) async throws -> Protocolo
    /// Imediato e idempotente: bloquear de novo devolve o bloqueio que já existe. O alvo é sempre
    /// do outro perfil (profissional bloqueia estabelecimento, e contratante, profissional); alvo do
    /// mesmo perfil é `campoInvalido`, com `alvo_tipo` no detalhe.
    func bloquear(_ alvo: Alvo) async throws -> Bloqueio
    func situacaoDaConta() async throws -> SituacaoDaConta
    /// Relato de pelo menos 10 caracteres. Sem suspensão em vigor é `semSuspensaoAtiva`. Se já
    /// houve contestação desta suspensão, em análise ou resolvida, é `contestacaoJaAberta`: a tela
    /// trata esse erro mesmo quando `Suspensao.contestacao` veio nula.
    func contestarSuspensao(relato: String) async throws -> Protocolo
    /// Portabilidade da LGPD (cartão #219, US25, RF25): devolve o JSON dos dados pessoais no corpo da resposta.
    func exportarMeusDados() async throws -> Data
    /// Relatório dos turnos do período em CSV ou PDF (cartão #23, US20, RF22, RN17), no corpo da
    /// resposta. `.semTurnos` é o 204: o período não tem turnos e não há arquivo (UC13, 1a). O
    /// estabelecimento que não é de quem chama é `semPermissao` (403).
    func exportarTurnos(_ pedido: PedidoExportacaoTurnos) async throws -> ResultadoExportacaoTurnos

    // Aplicativo e dispositivo
    func configuracaoDoApp() async throws -> ConfiguracaoApp
    /// A cada abertura com sessão e sempre que o token mudar. Reenviar o mesmo token só renova a
    /// data; o token que era de outra conta passa para quem chamou (troca de conta no mesmo
    /// aparelho). Token em branco é `campoObrigatorio`, e com menos de 20 caracteres,
    /// `campoInvalido`, os dois com `token_fcm` no detalhe.
    func registrarDispositivo(tokenFCM: String) async throws -> Dispositivo
    /// Antes de encerrar a sessão, que é quem autoriza a chamada. Só tira o token da própria conta,
    /// e o token que não estava registrado não é erro.
    func removerDispositivo(tokenFCM: String) async throws
    func sair(tokenFCM: String?) async
}

public extension ApiCliente {
    func vagasAbertas() async throws -> [VagaNaLista] { try await vagasAbertas(.todas) }
    func minhasCandidaturas() async throws -> [Candidatura] { try await minhasCandidaturas(estado: nil) }
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
    func ler() async throws -> LeituraDeTurnos
}

public extension TurnoRepositorio {
    func ler() async throws -> LeituraDeTurnos {
        let turnos = try await meusTurnos()
        return LeituraDeTurnos(turnos: turnos, origem: .rede)
    }
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
