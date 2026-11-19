import Foundation

public struct CadastroConta: Codable, Equatable, Sendable {
    public let nome: String
    public let telefone: String
    public let nascimento: DataCivil
    public let perfil: PerfilConta
    /// Versão dos termos que a tela exibiu. O instante do aceite é carimbado pelo servidor.
    public let versaoTermos: String
    /// Faixa etária aferida via Declared Age Range (contrato 0.2.45, Lei 15.211/2025).
    public let sinalIdade: SinalIdade?

    public init(
        nome: String,
        telefone: String,
        nascimento: DataCivil,
        perfil: PerfilConta,
        versaoTermos: String,
        sinalIdade: SinalIdade? = nil
    ) {
        self.nome = nome
        self.telefone = telefone
        self.nascimento = nascimento
        self.perfil = perfil
        self.versaoTermos = versaoTermos
        self.sinalIdade = sinalIdade
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

    public init(estado: Estado, candidaturaID: UUID, posicaoID: UUID?, turnoID: UUID?) {
        self.estado = estado
        self.candidaturaID = candidaturaID
        self.posicaoID = posicaoID
        self.turnoID = turnoID
    }
}

/// Resposta de `escolher_candidato` (`ResultadoConfirmacao` do contrato): a posição e o turno que a
/// escolha confirmou. O contato que o servidor ainda possa devolver junto não faz parte do modelo: o app
/// não o lê.
public struct ResultadoConfirmacao: Codable, Equatable, Sendable {
    public let posicaoID: UUID
    public let turnoID: UUID

    public init(posicaoID: UUID, turnoID: UUID) {
        self.posicaoID = posicaoID
        self.turnoID = turnoID
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
    /// 0.2.54 (CD-RF12): a foto denunciada, pelo `foto_id` que o perfil mostrou. Sem ela, a denúncia
    /// é sobre o perfil, como antes. Duas denúncias de contas diferentes ocultam a foto no servidor.
    public let midiaID: UUID?
    /// 0.2.71 (A-001): a chamada em que aconteceu, quando a denúncia sai da tela de uma chamada. Ela tem de envolver as
    /// duas partes; senão, 422 `campo_invalido` (`chamada_id`).
    public let chamadaID: UUID?

    public init(alvo: Alvo, turnoID: UUID? = nil, motivo: MotivoDenuncia, relato: String, chave: UUID, midiaID: UUID? = nil,
                chamadaID: UUID? = nil) {
        self.alvo = alvo
        self.turnoID = turnoID
        self.motivo = motivo
        self.relato = relato
        self.chave = chave
        self.midiaID = midiaID
        self.chamadaID = chamadaID
    }
}

public enum EstadoChamada: String, Codable, CaseIterable, Sendable {
    case aberta, aceita, recusada, expirada, cancelada, encerrada
}

public enum MotivoRecusaChamada: String, Codable, CaseIterable, Sendable {
    case agenda, distancia, valor, outro
    case tipoDeServico = "tipo_de_servico"
}

public struct Chamada: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let vagaID: UUID
    public let profissionalID: UUID
    public let estabelecimentoID: UUID
    public let estado: EstadoChamada
    public let recado: String?
    public let motivoRecusa: MotivoRecusaChamada?
    public let expiraEm: Date
    public let respondidaEm: Date?
    public let criadaEm: Date

    public init(id: UUID, vagaID: UUID, profissionalID: UUID, estabelecimentoID: UUID,
                estado: EstadoChamada = .aberta, recado: String? = nil,
                motivoRecusa: MotivoRecusaChamada? = nil, expiraEm: Date,
                respondidaEm: Date? = nil, criadaEm: Date) {
        self.id = id
        self.vagaID = vagaID
        self.profissionalID = profissionalID
        self.estabelecimentoID = estabelecimentoID
        self.estado = estado
        self.recado = recado
        self.motivoRecusa = motivoRecusa
        self.expiraEm = expiraEm
        self.respondidaEm = respondidaEm
        self.criadaEm = criadaEm
    }
    enum CodingKeys: String, CodingKey {
        case id, estado, recado
        case vagaID = "vaga_id"
        case profissionalID = "profissional_id"
        case estabelecimentoID = "estabelecimento_id"
        case motivoRecusa = "motivo_recusa"
        case expiraEm = "expira_em"
        case respondidaEm = "respondida_em"
        case criadaEm = "criada_em"
    }
}

/// Para onde vai a chamada (contrato 0.2.55): ou o servidor cria um trabalho novo com os campos da RN02,
/// ou a chamada entra numa vaga direta que já existe pelo `vaga_id`. Nunca os dois: o tipo não deixa.
public enum AlvoDaChamada: Equatable, Sendable {
    /// I5a: o servidor cria a vaga direta de uma posição. O total é o valor integral que o profissional
    /// recebe. `regiaoID` é o `regiao_id` da busca (0.2.88); `nil` fora dela.
    case novoTrabalho(PublicacaoVaga, regiaoID: Int?)
    /// A 2ª e a 3ª chamada do mesmo trabalho levam o `vaga_id` da 1ª: a função e a região são as da
    /// vaga, que guarda o `regiao_id` com que nasceu.
    case vagaExistente(vagaID: UUID, estabelecimentoID: UUID, chave: UUID)
}

public struct PedidoChamada: Equatable, Sendable {
    public let profissionalID: UUID
    public let alvo: AlvoDaChamada
    public let recado: String?
    public let confirmoRecorrencia: Bool

    /// Um trabalho novo. 0.2.88: `regiaoID` é o `regiao_id` da busca (`FiltroBuscaProfissionais.regiaoID`),
    /// copiado para a chamada: é com ele que o servidor confere a região atendida pelo caminho da busca.
    /// O `nome` dessa região tem de ser igual a `trabalho.regiaoAdministrativa`. `nil` fora da busca.
    public init(profissionalID: UUID, trabalho: PublicacaoVaga, recado: String? = nil, confirmoRecorrencia: Bool = false,
                regiaoID: Int? = nil) {
        self.init(profissionalID: profissionalID, alvo: .novoTrabalho(trabalho, regiaoID: regiaoID),
                  recado: recado, confirmoRecorrencia: confirmoRecorrencia)
    }

    /// Mais alguém para uma vaga direta que já existe (`vaga_id`).
    public init(profissionalID: UUID, vagaID: UUID, estabelecimentoID: UUID, chave: UUID, recado: String? = nil,
                confirmoRecorrencia: Bool = false) {
        self.init(profissionalID: profissionalID, alvo: .vagaExistente(vagaID: vagaID, estabelecimentoID: estabelecimentoID, chave: chave),
                  recado: recado, confirmoRecorrencia: confirmoRecorrencia)
    }

    public init(profissionalID: UUID, alvo: AlvoDaChamada, recado: String? = nil, confirmoRecorrencia: Bool = false) {
        self.profissionalID = profissionalID
        self.alvo = alvo
        self.recado = recado
        self.confirmoRecorrencia = confirmoRecorrencia
    }

    /// Os campos do trabalho novo; `nil` quando a chamada vai pelo `vaga_id`.
    public var trabalho: PublicacaoVaga? {
        if case let .novoTrabalho(trabalho, _) = alvo { return trabalho }
        return nil
    }

    /// O `vaga_id` da vaga direta que já existe; `nil` no trabalho novo.
    public var vagaID: UUID? {
        if case let .vagaExistente(vagaID, _, _) = alvo { return vagaID }
        return nil
    }

    /// O `regiao_id` da busca. Só o trabalho novo leva: pelo `vaga_id`, vale o da vaga.
    public var regiaoID: Int? {
        if case let .novoTrabalho(_, regiaoID) = alvo { return regiaoID }
        return nil
    }

    public var chave: UUID {
        switch alvo {
        case let .novoTrabalho(trabalho, _): trabalho.chave
        case let .vagaExistente(_, _, chave): chave
        }
    }

    public var estabelecimentoID: UUID {
        switch alvo {
        case let .novoTrabalho(trabalho, _): trabalho.estabelecimentoID
        case let .vagaExistente(_, estabelecimentoID, _): estabelecimentoID
        }
    }

    /// O mesmo pedido (mesmo alvo e mesma chave), com a confirmação da recorrência (J7).
    public func confirmando(_ confirmoRecorrencia: Bool) -> PedidoChamada {
        PedidoChamada(profissionalID: profissionalID, alvo: alvo, recado: recado, confirmoRecorrencia: confirmoRecorrencia)
    }
}

public struct ConfiguracaoApp: Codable, Equatable, Sendable {
    public let versaoMinima: String
    public let versaoRecomendada: String
    public let mensagem: String?
    public let urlDaLoja: URL
    /// Interruptores do servidor (contrato 0.2.54). Ausente vale desligado.
    public let recursos: RecursosDoApp

    public init(
        versaoMinima: String,
        versaoRecomendada: String,
        mensagem: String?,
        urlDaLoja: URL,
        recursos: RecursosDoApp = .desligados
    ) {
        self.versaoMinima = versaoMinima
        self.versaoRecomendada = versaoRecomendada
        self.mensagem = mensagem
        self.urlDaLoja = urlDaLoja
        self.recursos = recursos
    }

    /// Cópia guardada antes da 0.2.54 não tem `recursos`: vale desligado.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        versaoMinima = try container.decode(String.self, forKey: .versaoMinima)
        versaoRecomendada = try container.decode(String.self, forKey: .versaoRecomendada)
        mensagem = try container.decodeIfPresent(String.self, forKey: .mensagem)
        urlDaLoja = try container.decode(URL.self, forKey: .urlDaLoja)
        recursos = try container.decodeIfPresent(RecursosDoApp.self, forKey: .recursos) ?? .desligados
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
    func meusServicos() async throws -> [ServicoNoPerfil]
    func definirServicos(_ servicos: [ServicoOferecido]) async throws -> [ServicoNoPerfil]
    func especialidades(funcaoID: UUID) async throws -> [Especialidade]
    func atualizarPerfilProfissional(_ alteracao: AlteracaoPerfilProfissional) async throws -> PerfilProfissional
    /// Apresentação e regiões atendidas (Fatia F2, contrato 0.2.53)
    func meuPerfilDetalhado() async throws -> PerfilProfissionalDetalhado
    func atualizarApresentacaoProfissional(_ apresentacao: ApresentacaoDoProfissional) async throws -> PerfilProfissionalDetalhado
    func definirRegioesAtendidas(_ regioes: RegioesAtendidas) async throws -> PerfilProfissionalDetalhado
    /// Troca telefone e/ou e-mail da conta. O backend ainda não oferece a operação (ver o handoff em
    /// `operacao/conta-editar-contato-handoff-backend.md`): `suportaEdicaoDeContato` diz se este cliente a
    /// atende, e a interface só oferece Editar quando diz que sim. O padrão é não suportar.
    var suportaEdicaoDeContato: Bool { get }
    func atualizarContato(_ alteracao: AlteracaoDeContato) async throws -> Conta

    // Por que recebo vagas (RF27)
    /// Os critérios em vigor para quem chama. Conta de contratante é `perfilIncompativel`; sem
    /// perfil profissional, `naoEncontrado`. A leitura não exige conta ativa: a suspensa também lê.
    func criteriosDeNotificacao() async throws -> CriteriosDeNotificacao
    /// "Contestar" na tela: pede à Equipe Frila a revisão do despacho, com relato de pelo menos 10
    /// caracteres; a resposta vai por e-mail em até 5 dias úteis. Relato em branco é
    /// `campoObrigatorio` e curto, `campoInvalido`, os dois com `relato` no detalhe; conta suspensa é
    /// `semPermissao` com `conta_suspensa`. Reenvio é `contestacaoJaAberta` (409), sem protocolo.
    func pedirRevisaoDespacho(relato: String) async throws -> Protocolo

    // Estabelecimento
    func cadastrarEstabelecimento(_ cadastro: CadastroEstabelecimento) async throws -> Estabelecimento
    func meusEstabelecimentos() async throws -> [EstabelecimentoDaConta]
    /// O cadastro de um estabelecimento de que a conta é membro (contrato 0.2.29): o endereço, a
    /// região e o ponto que preenchem a publicação de uma vaga. `meusEstabelecimentos` não os traz.
    /// Quem não é membro recebe `sem_permissao`.
    func meuEstabelecimento(id: UUID) async throws -> Estabelecimento
    func painelEstabelecimento(id: UUID, periodo: Periodo) async throws -> Painel

    // Equipe da casa (RF21, US24; contratos 0.2.73 e 0.2.103)
    /// `membros_do_estabelecimento` (0.2.103): as pessoas da casa, os administradores primeiro e, em cada papel, do mais
    /// antigo ao mais novo. **Só o administrador**: o operador, quem não é membro e a casa que não existe recebem a mesma
    /// recusa, `semPermissao` sem `detalhes`; conta suspensa, `semPermissao` com `conta_suspensa`.
    func membrosDaCasa(estabelecimentoID: UUID) async throws -> [MembroDaCasa]
    /// `convidar_membro` (0.2.73): gera o convite de uso único, válido por 7 dias. Só o administrador (`semPermissao`,
    /// também para a casa que não existe); `campoObrigatorio` (`papel`) e `campoInvalido` (`email`) no 422.
    func convidarMembro(estabelecimentoID: UUID, email: String, papel: PapelMembro) async throws -> ConviteDeMembro
    /// `aceitar_convite_membro` (0.2.73): consome o token e põe a conta na equipe da casa. Exige conta com perfil de
    /// contratante (`perfilIncompativel`); token que não existe, já usado ou vencido é `422 convite_invalido`
    /// (`ErroDaApi.conviteInvalido`).
    func aceitarConviteDeMembro(token: String) async throws -> MembroAdicionado
    /// `remover_membro` (0.2.73): só o administrador. `naoEncontrado` se o membro não é da casa e `422 ultimo_administrador`
    /// (`ErroDaApi.ultimoAdministrador`) ao tirar o único administrador.
    func removerMembro(estabelecimentoID: UUID, membroID: UUID) async throws
    /// `transferir_administracao` (0.2.73): promove outro membro a administrador; quem chama continua administrador. Só o
    /// administrador; `naoEncontrado` se o membro não é da casa.
    func transferirAdministracao(estabelecimentoID: UUID, novoAdministradorID: UUID) async throws

    // Equipe de confiança (RF18, UC11)
    /// Os profissionais da equipe, do mais recente para o mais antigo, como a casa os vê (perfil
    /// público, sem contato). Só membro do estabelecimento: quem não é recebe `semPermissao`.
    func equipeDeConfianca(estabelecimentoID: UUID) async throws -> [PerfilPublico]
    /// Só o administrador da casa, e só quem já cumpriu nela um turno com presença verificada:
    /// senão é `semPermissao` com `sem_turno_cumprido` no detalhe (o servidor decide; o botão
    /// condicional da tela é só conveniência). Conta suspensa é `semPermissao` com `conta_suspensa`;
    /// profissional que não existe, `naoEncontrado`. Idempotente.
    func incluirNaEquipe(_ membro: MembroDaEquipe) async throws -> MembroDaEquipe
    /// Só o administrador. Sem penalidade nem aviso ao profissional (RN16). Idempotente.
    func removerDaEquipe(_ membro: MembroDaEquipe) async throws -> MembroDaEquipe

    // Catálogo e vagas
    func funcoes() async throws -> [Funcao]
    func resolverServico(termo: String) async throws -> [Funcao]
    func regioesAdministrativas() async throws -> [RegiaoAdministrativa]
    func chamarProfissional(_ pedido: PedidoChamada) async throws -> Chamada
    func responderChamada(id: UUID, resposta: RespostaChamada, motivoRecusa: MotivoRecusaChamada?) async throws -> ResultadoChamada
    func cancelarChamada(id: UUID) async throws -> Chamada
    func minhasChamadas(estado: EstadoChamada?, cursor: String?, limite: Int?) async throws -> [ChamadaResumo]
    /// 0.2.95: a mesma `minhas_chamadas`, com o `proximoCursor` da página, para seguir o cursor (a busca procura a vaga
    /// do `409 trabalho_ja_aberto`). Sem implementação própria, é a página de `minhasChamadas`, sem cursor.
    func paginaDeMinhasChamadas(estado: EstadoChamada?, cursor: String?, limite: Int?) async throws -> PaginaChamadas
    func detalheChamada(id: UUID) async throws -> ChamadaDetalhe
    func publicarAPartirDaChamada(vagaID: UUID, chave: UUID, modo: ModoPreenchimento?) async throws -> VagaPublicada
    func definirPreferenciaChamadas(_ preferencias: AlteracaoPreferenciaChamadas) async throws -> PreferenciaChamadas
    /// Busca de profissionais (0.2.88, `POST /rpc/buscar_profissionais`). `cursor` é o `proximoCursor`
    /// da página anterior, com o mesmo filtro; `limite` vai de 1 a 20 (`nil` vale 20). Só membro ativo
    /// da casa: senão `semPermissao` (também `conta_suspensa` e `recurso_desligado` no detalhe).
    /// Mais de 60 buscas por hora: `limiteExcedido` (429). Cursor de outra busca ou de outro dia:
    /// `cursorInvalido`, e o app refaz a busca da primeira página. Lista vazia: oferecer "Publicar para todos".
    func buscarProfissionais(_ filtro: FiltroBuscaProfissionais, cursor: String?, limite: Int?) async throws -> PaginaBuscaProfissionais
    /// 0.2.90 (`POST /rpc/aceitar_termos`): quem já tem conta aceita uma versão dos Termos e da Política que a tela
    /// exibiu. O servidor carimba o instante; repetir a mesma versão devolve o aceite que existe. Versão vazia:
    /// `campoObrigatorio`; anterior à já aceita: `campoInvalido`. Primeiro uso: depois de `termosPendentes` na busca.
    func aceitarTermos(versao: String) async throws -> AceiteDeTermos
    func publicarVaga(_ publicacao: PublicacaoVaga) async throws -> VagaPublicada
    func republicarVaga(id: UUID, periodo: Periodo, chave: UUID) async throws -> VagaPublicada
    /// 0.2.41: Republica em urgência as posições restantes de uma vaga de seleção que fechou (D1-C).
    func republicarPosicoesRestantes(vagaID: UUID, chave: UUID) async throws -> VagaPublicada
    /// 0.2.96 (`POST /rpc/publicar_escala`): um evento e de 1 a 10 vagas de uma vez, tudo ou nada. A `chave` é uma só
    /// para a escala inteira: reenviar devolve a mesma escala, sem publicar de novo, e uma escala recusada não gasta a
    /// chave. Recusas: `campoObrigatorio` e `campoInvalido` com o caminho do campo em `detalhes` (`evento.nome`,
    /// `vagas[2].valor_centavos`, `vagas`, `posicoes`), `horarioInvalido` e `selecaoSemAntecedencia` com `vagas[i]`,
    /// `perfilIncompativel`, `semPermissao` (também `conta_suspensa`) e `limiteExcedido`.
    func publicarEscala(_ escala: PublicacaoEscala) async throws -> EscalaPublicada
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
    /// Com os `sinais` da leitura (0.2.68); `nil` é o corpo de antes. Só o app com a chave
    /// `checkin_por_codigo` ligada os manda.
    func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date, sinais: SinaisDoCheckin?) async throws -> ResultadoRegistro
    func fazerCheckout(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro
    func avaliar(turnoID: UUID, resposta: Bool) async throws -> Avaliacao

    // Turno do contratante
    /// Um toque de quem opera a casa: só então o check-in manual conta como presença (RN22).
    /// Reenviar devolve o registro já confirmado. Sem check-in é `checkinPendente`; check-in
    /// geolocalizado, que já nasceu verificado, é `checkinJaConfirmado`.
    func confirmarCheckinManual(turnoID: UUID) async throws -> ResultadoRegistro
    /// A casa gera, ou revê, o código de check-in do turno (0.2.68). Só quem opera a casa do turno; o
    /// profissional recebe `semPermissao`. Chave desligada: `semPermissao` com `recurso_desligado`, sem
    /// tocar em dado. O código nunca sai em log.
    func gerarCodigoCheckin(turnoID: UUID) async throws -> CodigoDeCheckin
    /// O profissional valida o código lido (0.2.68), depois de um `fazerCheckin` pendente. `distanciaMetros`
    /// é a medida no aparelho (nula sem localização). Fora da fila offline e sem repetição automática: se
    /// a resposta se perder, quem chama relê o turno e deixa a pessoa digitar de novo (0.2.69), porque a
    /// tentativa errada já foi gravada. Erros: `codigoInvalido`, `codigoBloqueado`, `checkinJaConfirmado`.
    func validarCodigoCheckin(turnoID: UUID, codigo: String, distanciaMetros: Int?) async throws -> ResultadoRegistro
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
    /// Abre chamado de suporte a partir de um turno (contrato 0.2.40, UC14, RF23, RN15). Devolve o protocolo
    /// com prazo de resposta de até 5 dias úteis. Idempotente pela chave. Conta suspensa recebe `semPermissao` (403)
    /// com `details: conta_suspensa`. Teto diário de 5 chamados novos por conta devolve `limiteExcedido` (429).
    func abrirSuporte(turnoID: UUID, categoria: CategoriaSuporte, chave: UUID) async throws -> Protocolo
    func denunciar(_ denuncia: Denuncia) async throws -> Protocolo
    /// Imediato e idempotente: bloquear de novo devolve o bloqueio que já existe. O alvo é sempre
    /// do outro perfil (profissional bloqueia estabelecimento, e contratante, profissional); alvo do
    /// mesmo perfil é `campoInvalido`, com `alvo_tipo` no detalhe.
    func bloquear(_ alvo: Alvo) async throws -> Bloqueio
    /// Lista os bloqueios ativos criados pelo chamador (decisão A8 da PO, RF26, RN10).
    /// Devolve do mais recente para o mais antigo, sem expor o id de conta da outra parte.
    /// Lista vazia quando não houver bloqueios ativos.
    func bloqueios() async throws -> [ItemBloqueio]
    /// Desfaz o bloqueio criado contra a outra parte (decisão A8 da PO, RF26).
    /// Idempotente: desbloquear quem já não está bloqueado devolve o bloqueio desfeito com 200.
    /// Para contratante, desfaz o bloqueio para todo o estabelecimento.
    func desbloquear(_ alvo: Alvo) async throws -> Bloqueio
    func situacaoDaConta() async throws -> SituacaoDaConta
    /// Relato de pelo menos 10 caracteres. Sem suspensão em vigor é `semSuspensaoAtiva`. Se já
    /// houve contestação desta suspensão, em análise ou resolvida, é `contestacaoJaAberta`: a tela
    /// trata esse erro mesmo quando `Suspensao.contestacao` veio nula.
    func contestarSuspensao(relato: String) async throws -> Protocolo
    /// Portabilidade da LGPD (cartão #219, US25, RF25): devolve o JSON dos dados pessoais no corpo da resposta.
    func exportarMeusDados() async throws -> Data
    /// Relatório dos turnos do período em CSV ou PDF (cartão #23, US20, RF22, RN17), no corpo da
    /// resposta. `.semTurnos` é o 204: o período não tem turnos e não há arquivo (UC13, 1a). O
    /// estabelecimento que não é de quem chama é `semPermissao` (403). Datas omitidas cobrem os
    /// últimos 15 dias; intervalo acima de 30 dias é `intervaloMaximoExcedido` (422).
    func exportarTurnos(_ pedido: PedidoExportacaoTurnos) async throws -> ResultadoExportacaoTurnos

    // Aplicativo e dispositivo
    func configuracaoDoApp() async throws -> ConfiguracaoApp
    /// A cada abertura com sessão e sempre que o token mudar. Reenviar o mesmo token só renova a
    /// data; o token que era de outra conta passa para quem chamou (troca de conta no mesmo
    /// aparelho). Token em branco é `campoObrigatorio`, e com menos de 20 caracteres,
    /// `campoInvalido`, os dois com `token_fcm` no detalhe.
    func registrarDispositivo(tokenFCM: String) async throws -> Dispositivo
    func registrarDispositivo(tokenFCM: String, versaoApp: String?) async throws -> Dispositivo
    /// Antes de encerrar a sessão, que é quem autoriza a chamada. Só tira o token da própria conta,
    /// e o token que não estava registrado não é erro.
    func removerDispositivo(tokenFCM: String) async throws

    // Telemetria (RN15, RNF08, contrato 0.2.41)
    /// Registra um evento de telemetria do dicionário fechado (RPC registrar_evento, contrato 0.2.41).
    /// Sem texto livre nem dado pessoal (RN15). Devolve true quando registrado pelo servidor.
    func registrarEvento(_ registro: RegistroDeEvento) async throws -> Bool
    func sair(tokenFCM: String?) async

    // Foto de perfil (contrato 0.2.54, RN37 e RN46)
    /// Cria a mídia em `enviando` e devolve a URL assinada de upload. Com `recursos.foto_de_perfil`
    /// desligado é `semPermissao` com `recursoDesligado`; tipo reservado e formato ou tamanho
    /// fora do limite são `midiaInvalida`.
    func solicitarUploadMidia(_ pedido: PedidoDeUploadDeMidia) async throws -> UploadDeMidia
    /// Enfileira a análise (a resposta não espera o modelo). Idempotente: confirmar de novo devolve o estado atual.
    func confirmarUploadMidia(id: UUID) async throws -> Midia
    /// Funciona mesmo com o recurso desligado: remover o próprio dado nunca depende do interruptor.
    func removerMidia(id: UUID) async throws -> Midia
    /// Todas as mídias de quem chama, em qualquer estado. Também não depende do interruptor.
    func minhasMidias() async throws -> [Midia]
    /// Uma vez por foto `recusada` ou `nao_publicada`. Em outro estado ou depois do expurgo é `midiaIndisponivel`.
    func pedirNovaAnaliseMidia(id: UUID) async throws -> Midia
}

public extension ApiCliente {
    /// Quem não conhece os sinais manda o check-in de antes (sem `sinais`).
    func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date, sinais: SinaisDoCheckin?) async throws -> ResultadoRegistro {
        try await fazerCheckin(turnoID: turnoID, distanciaMetros: distanciaMetros, registradoEm: registradoEm)
    }
    func publicarEscala(_ escala: PublicacaoEscala) async throws -> EscalaPublicada { throw ErroDaApi(codigo: .respostaInvalida) }
    func membrosDaCasa(estabelecimentoID: UUID) async throws -> [MembroDaCasa] { throw ErroDaApi(codigo: .respostaInvalida) }
    func convidarMembro(estabelecimentoID: UUID, email: String, papel: PapelMembro) async throws -> ConviteDeMembro {
        throw ErroDaApi(codigo: .respostaInvalida)
    }
    func aceitarConviteDeMembro(token: String) async throws -> MembroAdicionado { throw ErroDaApi(codigo: .respostaInvalida) }
    func removerMembro(estabelecimentoID: UUID, membroID: UUID) async throws { throw ErroDaApi(codigo: .respostaInvalida) }
    func transferirAdministracao(estabelecimentoID: UUID, novoAdministradorID: UUID) async throws { throw ErroDaApi(codigo: .respostaInvalida) }
    func gerarCodigoCheckin(turnoID: UUID) async throws -> CodigoDeCheckin { throw ErroDaApi(codigo: .respostaInvalida) }
    func validarCodigoCheckin(turnoID: UUID, codigo: String, distanciaMetros: Int?) async throws -> ResultadoRegistro {
        throw ErroDaApi(codigo: .respostaInvalida)
    }
    func meusServicos() async throws -> [ServicoNoPerfil] { throw ErroDaApi(codigo: .respostaInvalida) }
    func definirServicos(_ servicos: [ServicoOferecido]) async throws -> [ServicoNoPerfil] { throw ErroDaApi(codigo: .respostaInvalida) }
    func especialidades(funcaoID: UUID) async throws -> [Especialidade] { throw ErroDaApi(codigo: .respostaInvalida) }
    func solicitarUploadMidia(_ pedido: PedidoDeUploadDeMidia) async throws -> UploadDeMidia {
        throw ErroDaApi(codigo: .respostaInvalida)
    }
    func confirmarUploadMidia(id: UUID) async throws -> Midia { throw ErroDaApi(codigo: .respostaInvalida) }
    func removerMidia(id: UUID) async throws -> Midia { throw ErroDaApi(codigo: .respostaInvalida) }
    func minhasMidias() async throws -> [Midia] { throw ErroDaApi(codigo: .respostaInvalida) }
    func pedirNovaAnaliseMidia(id: UUID) async throws -> Midia { throw ErroDaApi(codigo: .respostaInvalida) }
    var suportaEdicaoDeContato: Bool { false }
    func atualizarContato(_ alteracao: AlteracaoDeContato) async throws -> Conta {
        throw ErroDaApi(codigo: .respostaInvalida)
    }

    func vagasAbertas() async throws -> [VagaNaLista] { try await vagasAbertas(.todas) }
    func minhasCandidaturas() async throws -> [Candidatura] { try await minhasCandidaturas(estado: nil) }

    /// Conveniência para registrar evento de telemetria com parâmetros diretos.
    func registrarEvento(
        _ evento: EventoDeTelemetria,
        vagaID: UUID? = nil,
        turnoID: UUID? = nil,
        ocorridoEm: Date? = nil
    ) async throws -> Bool {
        try await registrarEvento(RegistroDeEvento(
            evento: evento,
            vagaID: vagaID,
            turnoID: turnoID,
            ocorridoEm: ocorridoEm
        ))
    }
}

public protocol VagaRepositorio: Sendable {
    func abertas(_ filtro: FiltroVagas) async throws -> [VagaNaLista]
    func detalhe(id: UUID) async throws -> Vaga
    func publicar(_ publicacao: PublicacaoVaga) async throws -> VagaPublicada
}

public protocol ProfissionalRepositorio: Sendable {
    func funcoes() async throws -> [Funcao]
}

public extension ApiCliente {
    func registrarDispositivo(tokenFCM: String, versaoApp: String?) async throws -> Dispositivo {
        try await registrarDispositivo(tokenFCM: tokenFCM)
    }

    func resolverServico(termo: String) async throws -> [Funcao] {
        let limpo = termo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard limpo.count >= 2 else { return [] }
        let todas = try await funcoes()
        return todas.filter { $0.nome.localizedCaseInsensitiveContains(limpo) }
    }

    func regioesAdministrativas() async throws -> [RegiaoAdministrativa] {
        []
    }

    func meuPerfilDetalhado() async throws -> PerfilProfissionalDetalhado {
        let base = try await meuPerfilProfissional()
        return PerfilProfissionalDetalhado(perfil: base)
    }

    func atualizarApresentacaoProfissional(_ apresentacao: ApresentacaoDoProfissional) async throws -> PerfilProfissionalDetalhado {
        try await meuPerfilDetalhado()
    }

    func definirRegioesAtendidas(_ regioes: RegioesAtendidas) async throws -> PerfilProfissionalDetalhado {
        try await meuPerfilDetalhado()
    }

    func responderChamada(id: UUID, resposta: RespostaChamada, motivoRecusa: MotivoRecusaChamada?) async throws -> ResultadoChamada {
        throw ErroDaApi(codigo: .respostaInvalida)
    }

    func cancelarChamada(id: UUID) async throws -> Chamada {
        throw ErroDaApi(codigo: .respostaInvalida)
    }

    func minhasChamadas(estado: EstadoChamada?, cursor: String?, limite: Int?) async throws -> [ChamadaResumo] {
        []
    }

    func paginaDeMinhasChamadas(estado: EstadoChamada?, cursor: String?, limite: Int?) async throws -> PaginaChamadas {
        PaginaChamadas(itens: try await minhasChamadas(estado: estado, cursor: cursor, limite: limite))
    }

    func detalheChamada(id: UUID) async throws -> ChamadaDetalhe {
        throw ErroDaApi(codigo: .naoEncontrado)
    }

    func publicarAPartirDaChamada(vagaID: UUID, chave: UUID, modo: ModoPreenchimento?) async throws -> VagaPublicada {
        throw ErroDaApi(codigo: .respostaInvalida)
    }

    func definirPreferenciaChamadas(_ preferencias: AlteracaoPreferenciaChamadas) async throws -> PreferenciaChamadas {
        throw ErroDaApi(codigo: .respostaInvalida)
    }

    func buscarProfissionais(_ filtro: FiltroBuscaProfissionais, cursor: String?, limite: Int?) async throws -> PaginaBuscaProfissionais {
        throw ErroDaApi(codigo: .respostaInvalida)
    }

    func aceitarTermos(versao: String) async throws -> AceiteDeTermos {
        throw ErroDaApi(codigo: .respostaInvalida)
    }
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
