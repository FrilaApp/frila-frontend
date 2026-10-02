import Foundation
import FrilaDominio

/// Dublê do contrato para previews, testes de UI e o esquema Frila-Local. Parte das fixtures do
/// contrato e guarda o que o app faz durante a sessão. Simula uma conta só: não cobra RN25 fora
/// dos cadastros de perfil, porque o fluxo de ponta a ponta atravessa os dois perfis.
public actor ApiClienteEmMemoria: ApiCliente {
    public enum Cenario: String, CaseIterable, Sendable {
        case sucesso = "success"
        case primeiroAcesso = "primeiro-acesso"
        case vagaPreenchida = "vaga-preenchida"
        case inelegivel
        case semRede = "sem-rede"
        case contaSuspensa = "conta-suspensa"
        /// Só a lista de vagas falha, com `422 campo_invalido/limite`, um erro que `vagas_abertas` produz no
        /// backend e que não é falta de rede nem de ponto de referência (estado de erro do #104).
        case erroNaLista = "erro-na-lista"
        /// `candidatar` responde `409 vaga_encerrada` (vaga cancelada, encerrada ou já iniciada).
        case vagaEncerrada = "vaga-encerrada"
        /// `candidatar` responde `422 inelegivel/perfil_suspenso` (conta suspensa, #105).
        case inelegivelSuspenso = "inelegivel-suspenso"
        case codigoErrado = "codigo-errado"
        case codigoExpirado = "codigo-expirado"
        case menorDeIdade = "menor-de-idade"
        case contaExistente = "conta-existente"
        case semPerfilProfissional = "sem-perfil-profissional"
        case entrada = "entrada"
        case contratante = "contratante"
        case perfilProfissionalComErroDeRede = "perfil-profissional-com-erro-de-rede"
        /// A vaga foi criada, mas a primeira resposta se perdeu. A repetição precisa reutilizar a chave.
        case respostaPerdidaPublicacao = "resposta-perdida-publicacao"
        /// A vaga foi criada, mas o gateway devolve uma resposta inválida na primeira tentativa.
        case respostaInvalidaPublicacao = "resposta-invalida-publicacao"
        /// Painel com uma vaga vazia dentro da janela de alerta do contratante.
        case alertaVagaVazia = "alerta-vaga-vazia"
        /// Painel com uma posição confirmada para testar perfil público e contato liberado.
        case painelContratante = "painel-contratante"
        /// Painel sem vagas para conferir a orientação do primeiro acesso do contratante.
        case painelVazio = "painel-vazio"
        /// Conta de contratante com um turno em andamento cujo check-in manual espera a confirmação (#19).
        case checkinManualPendente = "checkin-manual-pendente"
        /// Conta de contratante com um turno que começou há 20 minutos e ainda não teve check-in (#19).
        case atrasoNoTurno = "atraso-no-turno"
        /// Configuração remota exige versão mínima superior à atual.
        case atualizacaoObrigatoria = "atualizacao-obrigatoria"
    }

    private let cenario: Cenario
    private let relogio: any Relogio
    private let envelopes: [String: EnvelopeErroAPI]
    private let catalogo: [Funcao]
    private let configuracao: ConfiguracaoApp
    private let contatoDeExemplo: Contato
    private let perfilPublicoDeExemplo: PerfilPublico
    private var sessaoAtiva = false
    private var conta: Conta?
    private var perfilProfissional: PerfilProfissional?
    private var estabelecimentos: [Estabelecimento]
    private var vagas: [Vaga]
    private var turnos: [Turno] = []
    private var contatos: [UUID: Contato] = [:]
    /// Candidatura pendente por vaga de seleção (contrato 0.2.24): reenviar devolve a mesma.
    private var candidaturasPendentes: [UUID: UUID] = [:]
    /// Quantas vezes `candidatar` foi chamado: os testes de toque duplo leem isso.
    public private(set) var chamadasACandidatar = 0
    public private(set) var chamadasAVerificarCodigo = 0
    public private(set) var chamadasACriarConta = 0
    public private(set) var chamadasAPublicarVaga = 0
    public private(set) var chavesPublicacaoRecebidas: [UUID] = []
    public private(set) var publicacoesRecebidas: [PublicacaoVaga] = []
    public private(set) var vagasCriadas = 0
    private var publicacoesPorChave: [UUID: VagaPublicada] = [:]
    /// Registros de presença gravados por turno, como o backend guarda: repetir devolve o gravado.
    private var checkins: [UUID: ResultadoRegistro] = [:]
    private var checkouts: [UUID: ResultadoRegistro] = [:]
    /// Turnos cuja posição foi cancelada: saem de `meusTurnos` e continuam no painel, como posição
    /// `cancelada`. A posição cancelada não volta a ficar aberta (RN12).
    private var turnosCancelados: [Turno] = []
    /// Posições novas que um cancelamento ou uma reabertura abriu, por vaga: o painel as mostra com
    /// o id que a chamada devolveu, e a próxima candidatura ocupa a primeira.
    private var posicoesReabertas: [UUID: [UUID]] = [:]
    /// O que `reabrir_por_atraso` devolveu por posição: reenviar devolve o mesmo.
    private var reaberturasPorAtraso: [UUID: ResultadoCancelamento] = [:]
    private var denunciasPorChave: [UUID: Protocolo] = [:]
    private var bloqueios: [Alvo: Bloqueio] = [:]
    /// Só no cenário `contaSuspensa`.
    private var suspensao: Suspensao?

    public init(
        cenario: Cenario = .sucesso,
        relogio: any Relogio = RelogioDoSistema(),
        vagas: [Vaga]? = nil,
        sessaoAtivaInicial: Bool = false
    ) {
        self.cenario = cenario
        self.relogio = relogio
        self.sessaoAtiva = sessaoAtivaInicial
        do {
            envelopes = try FixturesDoContrato.erros()
            catalogo = try FixturesDoContrato.carregar("funcoes", como: [ContratoAPI.FuncaoDTO].self).map { $0.dominio() }
            configuracao = try FixturesDoContrato.carregar("configuracao-do-app", como: ContratoAPI.ConfiguracaoDoAppDTO.self).dominio()
            contatoDeExemplo = try FixturesDoContrato.carregar("contato", como: ContratoAPI.ContatoDTO.self).dominio()
            perfilPublicoDeExemplo = try FixturesDoContrato.carregar("perfil-publico", como: ContratoAPI.PerfilPublicoDTO.self).dominio()
            let usuario = try FixturesDoContrato.carregar("usuario", como: ContratoAPI.UsuarioDTO.self).dominio()
            if cenario == .primeiroAcesso || cenario == .entrada || cenario == .menorDeIdade || cenario == .codigoErrado || cenario == .codigoExpirado {
                conta = nil
                perfilProfissional = nil
            } else {
                if cenario == .contratante || cenario == .checkinManualPendente || cenario == .atrasoNoTurno {
                    conta = Conta(
                        id: usuario.id,
                        perfil: .contratante,
                        nome: usuario.nome,
                        telefone: usuario.telefone,
                        email: usuario.email,
                        nascimento: usuario.nascimento,
                        estado: usuario.estado
                    )
                    perfilProfissional = nil
                } else {
                    conta = usuario
                    if cenario == .semPerfilProfissional {
                        perfilProfissional = nil
                    } else {
                        perfilProfissional = try FixturesDoContrato.carregar("perfil-profissional", como: ContratoAPI.PerfilProfissionalDTO.self).dominio()
                    }
                }
            }
            if cenario == .contaSuspensa, let ativa = conta {
                conta = Conta(
                    id: ativa.id, perfil: ativa.perfil, nome: ativa.nome, telefone: ativa.telefone, email: ativa.email,
                    nascimento: ativa.nascimento, estado: .suspensa
                )
                suspensao = Suspensao(
                    motivo: "Denúncia grave confirmada pela Equipe Frila",
                    desde: relogio.agora.addingTimeInterval(-2 * 24 * 60 * 60), contestacao: nil
                )
            }
            estabelecimentos = conta == nil ? [] : [try FixturesDoContrato.carregar("estabelecimento", como: ContratoAPI.EstabelecimentoDTO.self).dominio()]
            if let vagas {
                self.vagas = vagas
            } else {
                let vaga = try FixturesDoContrato.carregar("vaga", como: ContratoAPI.VagaDTO.self).dominio()
                let ateInicio: TimeInterval = switch cenario {
                case .alertaVagaVazia: 2 * 60 * 60
                case .checkinManualPendente: -10 * 60
                case .atrasoNoTurno: -20 * 60
                default: 24 * 60 * 60
                }
                self.vagas = [try Self.noFuturo(vaga, agora: relogio.agora, inicioEm: ateInicio)]
            }
            if cenario == .painelVazio { self.vagas = [] }
            if cenario == .painelContratante || cenario == .checkinManualPendente || cenario == .atrasoNoTurno, let vaga = self.vagas.first {
                let turnoID = UUID(uuidString: "82000000-0000-0000-0000-000000000001")!
                let posicaoID = UUID(uuidString: "82000000-0000-0000-0000-000000000002")!
                let contato = Contato(
                    nome: perfilPublicoDeExemplo.nome,
                    telefone: contatoDeExemplo.telefone,
                    whatsappURL: contatoDeExemplo.whatsappURL,
                    visivelAte: vaga.periodo.fim.addingTimeInterval(7 * 24 * 60 * 60)
                )
                turnos = [Turno(
                    id: turnoID, posicaoID: posicaoID, vaga: vaga.resumo,
                    contraparte: perfilPublicoDeExemplo, contatoVisivelAte: contato.visivelAte,
                    verificacao: cenario == .painelContratante ? .verificado : .pendente, valorAcordado: vaga.valor, podeAvaliar: false
                )]
                contatos[turnoID] = contato
                if cenario == .checkinManualPendente {
                    checkins[turnoID] = ResultadoRegistro(
                        turnoID: turnoID, tipo: .manual, verificacao: .pendente,
                        registradoEm: vaga.periodo.inicio.addingTimeInterval(-2 * 60), distanciaMetros: nil
                    )
                }
                self.vagas[0] = Self.comPosicoesAbertas(max(0, vaga.posicoesAbertas - 1), em: vaga)
            }
        } catch {
            preconditionFailure("Fixture do contrato ilegível: \(error)")
        }
    }

    #if DEBUG
    /// Só em Debug (#96): o Release não lê argumentos de lançamento.
    public static func pelosArgumentos(_ argumentos: [String] = ProcessInfo.processInfo.arguments) -> ApiClienteEmMemoria {
        let semSessaoArgumento = argumentos.contains("-FRILA_ABRIR_CATALOGO") || argumentos.contains("-FRILA_ENTRADA")
        guard let indice = argumentos.firstIndex(of: "-FRILA_SCENARIO"), argumentos.indices.contains(indice + 1),
              let cenario = Cenario(rawValue: argumentos[indice + 1]) else {
            return ApiClienteEmMemoria(sessaoAtivaInicial: !semSessaoArgumento)
        }
        let cenariosSemSessao: Set<Cenario> = [.primeiroAcesso, .entrada, .menorDeIdade, .codigoErrado, .codigoExpirado]
        let sessaoAtiva = !semSessaoArgumento && !cenariosSemSessao.contains(cenario)
        if cenario == .semRede {
            DestinoGuardado.salvar(.profissional)
        } else if !sessaoAtiva {
            DestinoGuardado.limpar()
        }
        return ApiClienteEmMemoria(cenario: cenario, sessaoAtivaInicial: sessaoAtiva)
    }
    #endif

    // MARK: Entrada

    public func solicitarCodigo(email: String) async throws { try verificarRede() }

    public func verificarCodigo(email: String, codigo: String) async throws {
        chamadasAVerificarCodigo += 1
        await Task.yield()
        try verificarRede()
        if cenario == .codigoErrado || codigo == "000000" {
            throw ErroDaApi(codigo: .naoAutenticado, codigoOriginal: "codigo_invalido")
        }
        if cenario == .codigoExpirado || codigo == "999999" {
            throw ErroDaApi(codigo: .naoAutenticado, codigoOriginal: "otp_expired")
        }
        sessaoAtiva = true
    }

    public func possuiSessao() async -> Bool { sessaoAtiva }

    public func entrarDemonstracao(email: String, codigo: String) async throws {
        try verificarRede()
        guard !codigo.isEmpty else { throw erro("nao_encontrado") }
        if cenario == .codigoErrado || codigo == "000000" {
            throw erro("nao_encontrado")
        }
        if cenario == .codigoExpirado || codigo == "999999" {
            throw erro("nao_encontrado")
        }
        sessaoAtiva = true
    }

    // MARK: Conta e perfil

    public func minhaConta() async throws -> Conta {
        try verificarRede()
        guard let conta else { throw erro("nao_encontrado") }
        return conta
    }

    public func criarConta(_ cadastro: CadastroConta) async throws -> Conta {
        chamadasACriarConta += 1
        await Task.yield()
        try verificarRede()
        guard conta == nil && cenario != .contaExistente else { throw erro("conta_existente") }
        if cenario == .menorDeIdade {
            throw erro("menor_de_idade")
        }
        if let hoje = DataCivil.deSaoPaulo(relogio.agora),
           let aniversario18 = try? DataCivil(ano: cadastro.nascimento.ano + 18, mes: cadastro.nascimento.mes, dia: cadastro.nascimento.dia),
           aniversario18 > hoje {
            throw erro("menor_de_idade")
        }
        let nova = Conta(
            id: UUID(), perfil: cadastro.perfil, nome: cadastro.nome, telefone: cadastro.telefone,
            email: "voce@frila.app", nascimento: cadastro.nascimento, estado: .ativa
        )
        conta = nova
        return nova
    }

    public func criarPerfilProfissional(_ dados: DadosPerfilProfissional) async throws -> PerfilProfissional {
        try verificarFalhaGeral()
        let conta = try await minhaConta()
        guard conta.perfil == .profissional else { throw erro("perfil_incompativel") }
        guard perfilProfissional?.usuarioID != conta.id else { throw erro("perfil_ja_existe") }
        let perfil = PerfilProfissional(
            id: UUID(), usuarioID: conta.id, funcoes: try doCatalogo(dados.funcoes), pontoBase: dados.pontoBase,
            disponibilidades: dados.disponibilidades,
            reputacao: Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
        )
        perfilProfissional = perfil
        return perfil
    }

    public func meuPerfilProfissional() async throws -> PerfilProfissional {
        try verificarRede()
        if cenario == .perfilProfissionalComErroDeRede {
            throw ErroDaApi(codigo: .semRede)
        }
        guard let perfilProfissional else { throw erro("nao_encontrado") }
        return perfilProfissional
    }

    public func atualizarPerfilProfissional(_ alteracao: AlteracaoPerfilProfissional) async throws -> PerfilProfissional {
        try verificarFalhaGeral()
        let atual = try await meuPerfilProfissional()
        let perfil = PerfilProfissional(
            id: atual.id, usuarioID: atual.usuarioID,
            funcoes: try alteracao.funcoes.map(doCatalogo) ?? atual.funcoes,
            pontoBase: alteracao.pontoBase ?? atual.pontoBase,
            disponibilidades: alteracao.disponibilidades ?? atual.disponibilidades,
            reputacao: atual.reputacao
        )
        perfilProfissional = perfil
        return perfil
    }

    // MARK: Estabelecimento

    public func cadastrarEstabelecimento(_ cadastro: CadastroEstabelecimento) async throws -> Estabelecimento {
        try verificarFalhaGeral()
        if let conta, conta.perfil == .profissional { throw erro("perfil_incompativel") }
        // Obrigatória desde o contrato 0.2.20; em branco é ausência, como no backend.
        let regiao = cadastro.regiaoAdministrativa.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !regiao.isEmpty else { throw erro("campo_obrigatorio", detalhes: "regiao_administrativa") }
        guard !estabelecimentos.contains(where: { $0.documento == cadastro.documento }) else { throw erro("documento_ja_cadastrado") }
        let novo = Estabelecimento(
            id: UUID(), nome: cadastro.nome, documento: cadastro.documento, tipo: cadastro.tipo,
            endereco: cadastro.endereco, regiaoAdministrativa: regiao, ponto: cadastro.ponto, papel: .administrador
        )
        estabelecimentos.append(novo)
        return novo
    }

    public func meusEstabelecimentos() async throws -> [EstabelecimentoDaConta] {
        try verificarFalhaGeral()
        return estabelecimentos.map { EstabelecimentoDaConta(id: $0.id, nome: $0.nome, papel: $0.papel, tipo: $0.tipo, reputacao: perfilDo($0).reputacao) }
    }

    public func painelEstabelecimento(id: UUID, periodo: Periodo) async throws -> Painel {
        try verificarFalhaGeral()
        guard estabelecimentos.contains(where: { $0.id == id }) else { throw erro("sem_permissao") }
        let agora = relogio.agora
        let daCasa = vagas.filter { $0.estabelecimento.id == id && $0.periodo.sobrepoe(periodo) }
        return Painel(
            estabelecimentoID: id,
            vagas: daCasa.map { vaga in
                // `em_atraso` do backend: confirmada, sem check-in, dos 15 minutos do início até o fim (D06).
                let atrasada = agora >= vaga.periodo.inicio.addingTimeInterval(Self.toleranciaDeAtraso) && agora < vaga.periodo.fim
                let confirmadas = turnos.filter { $0.vaga.id == vaga.id }.map { turno in
                    let registro = checkins[turno.id]
                    return PosicaoNoPainel(
                        id: turno.posicaoID, estado: .confirmada, profissional: perfilPublicoDeExemplo, turnoID: turno.id,
                        verificacao: registro?.verificacao ?? turno.verificacao,
                        emAtraso: atrasada && registro == nil && turno.checkin == nil, aCaminhoEm: turno.aCaminhoEm
                    )
                }
                // A presença que ainda esperava prova fica `nao_verificado` quando a posição é cancelada.
                let canceladas = turnosCancelados.filter { $0.vaga.id == vaga.id }.map { turno in
                    let verificacao = checkins[turno.id]?.verificacao ?? turno.verificacao
                    return PosicaoNoPainel(
                        id: turno.posicaoID, estado: .cancelada, profissional: perfilPublicoDeExemplo, turnoID: turno.id,
                        verificacao: verificacao == .pendente ? .naoVerificado : verificacao, emAtraso: false, aCaminhoEm: turno.aCaminhoEm
                    )
                }
                let reabertas = posicoesReabertas[vaga.id] ?? []
                let abertas = (0..<vaga.posicoesAbertas).map { indice in
                    PosicaoNoPainel(
                        id: indice < reabertas.count ? reabertas[indice] : UUID(), estado: .aberta, profissional: nil, turnoID: nil,
                        verificacao: nil, emAtraso: false
                    )
                }
                // `alerta_vaga_vazia` do backend: vaga publicada, com posição aberta, dentro da janela
                // crítica e antes do início. A janela do dublê é a padrão, de 3 horas.
                let vazia = vaga.estado == .publicada && vaga.posicoesAbertas > 0 && agora < vaga.periodo.inicio
                    && vaga.periodo.inicio.timeIntervalSince(agora) <= 3 * 60 * 60
                return VagaNoPainel(
                    vaga: vaga.resumo, modo: vaga.modo, estado: vaga.estado, oculta: vaga.oculta, alertaVagaVazia: vazia,
                    candidatosPendentes: candidaturasPendentes[vaga.id] == nil ? 0 : 1, posicoes: confirmadas + canceladas + abertas
                )
            },
            // Check-in manual que ninguém da casa confirmou ainda, do mais antigo para o mais novo.
            checkinsPendentes: turnos
                .filter { turno in daCasa.contains { $0.id == turno.vaga.id } }
                .compactMap { checkins[$0.id] }
                .filter { $0.tipo == .manual && $0.verificacao == .pendente }
                .sorted { $0.registradoEm < $1.registradoEm }
                .map(\.turnoID)
        )
    }

    // MARK: Catálogo e vagas

    public func funcoes() async throws -> [Funcao] {
        try verificarFalhaGeral()
        return catalogo
    }

    public func publicarVaga(_ publicacao: PublicacaoVaga) async throws -> VagaPublicada {
        chamadasAPublicarVaga += 1
        chavesPublicacaoRecebidas.append(publicacao.chave)
        publicacoesRecebidas.append(publicacao)
        if let resposta = publicacoesPorChave[publicacao.chave] { return resposta }
        try verificarFalhaGeral()
        guard let estabelecimento = estabelecimentos.first(where: { $0.id == publicacao.estabelecimentoID }) else { throw erro("sem_permissao") }
        let regiao = publicacao.regiaoAdministrativa.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !regiao.isEmpty else { throw erro("campo_obrigatorio", detalhes: "regiao_administrativa") }
        guard let funcao = catalogo.first(where: { $0.id == publicacao.funcaoID }) else { throw erro("campo_invalido", detalhes: "funcao_id") }
        // RN24, contrato 0.2.24: o modo seleção fecha 24 h antes do início; com 24 h ou menos, a vaga nem entra.
        if publicacao.modo == .selecao, publicacao.periodo.inicio <= relogio.agora.addingTimeInterval(Self.antecedenciaDaSelecao) {
            throw erro("selecao_sem_antecedencia")
        }
        let vaga = Vaga(
            id: UUID(), estabelecimento: perfilDo(estabelecimento), funcao: funcao, periodo: publicacao.periodo,
            local: publicacao.local, regiaoAdministrativa: regiao, ponto: publicacao.ponto, valor: publicacao.valor, posicoes: publicacao.posicoes,
            posicoesAbertas: publicacao.posicoes, inclusos: publicacao.inclusos, responsavelLocal: publicacao.responsavelLocal,
            traje: publicacao.traje, participaRateio: publicacao.participaRateio, observacoes: publicacao.observacoes,
            modo: publicacao.modo, estado: .publicada, publicadoEm: relogio.agora
        )
        vagas.append(vaga)
        vagasCriadas += 1
        let resposta = VagaPublicada(vagaID: vaga.id, posicoes: (0..<publicacao.posicoes).map { _ in UUID() })
        publicacoesPorChave[publicacao.chave] = resposta
        if cenario == .respostaPerdidaPublicacao { throw ErroDaApi(codigo: .semRede) }
        if cenario == .respostaInvalidaPublicacao { throw ErroDaApi(codigo: .respostaInvalida) }
        return resposta
    }

    public func republicarVaga(id: UUID, periodo: Periodo, chave: UUID) async throws -> VagaPublicada {
        guard let original = vagas.first(where: { $0.id == id }) else { throw erro("nao_encontrado") }
        // Contrato 0.2.23: republicar não contorna a moderação.
        guard !original.oculta else { throw erro("vaga_oculta") }
        return try await publicarVaga(
            PublicacaoVaga(
                estabelecimentoID: original.estabelecimento.id, funcaoID: original.funcao.id, periodo: periodo,
                local: original.local, regiaoAdministrativa: original.regiaoAdministrativa, ponto: original.ponto,
                valor: original.valor, posicoes: original.posicoes,
                inclusos: original.inclusos, responsavelLocal: original.responsavelLocal, traje: original.traje,
                participaRateio: original.participaRateio, observacoes: original.observacoes, modo: original.modo, chave: chave
            )
        )
    }

    public func vagasAbertas(_ filtro: FiltroVagas) async throws -> [VagaNaLista] {
        try verificarFalhaGeral()
        if cenario == .erroNaLista { throw erro("campo_invalido", detalhes: "limite") }

        let limite = filtro.limite ?? 30
        let deslocamento = filtro.deslocamento ?? 0
        if limite < 1 || limite > 100 {
            throw erro("campo_invalido", detalhes: "limite")
        }
        if deslocamento < 0 {
            throw erro("campo_invalido", detalhes: "deslocamento")
        }

        let referencia = filtro.referencia ?? perfilProfissional?.pontoBase
        let agora = relogio.agora
        let ordenadas = vagas
            .filter { vaga in
                // Fora da vitrine: a vaga ocultada pela moderação (contrato 0.2.23) e a que já começou (0.2.19).
                guard vaga.estado == .publicada, !vaga.oculta, vaga.periodo.inicio > agora else { return false }
                // RF26: as partes de um bloqueio não se cruzam em lista, detalhe nem candidatura.
                guard !bloqueada(vaga) else { return false }
                if let funcaoID = filtro.funcaoID, vaga.funcao.id != funcaoID { return false }
                if let data = filtro.data, DataCivil.deSaoPaulo(vaga.periodo.inicio) != data { return false }
                return true
            }
            .map { vaga in
                let distancia = referencia.map { vaga.ponto.distancia(emMetrosDe: $0) / 1_000 } ?? 0
                return VagaNaLista(
                    id: vaga.id, funcao: vaga.funcao, estabelecimento: vaga.estabelecimento, periodo: vaga.periodo,
                    local: vaga.local, regiaoAdministrativa: vaga.regiaoAdministrativa, distanciaKm: distancia,
                    valor: vaga.valor, posicoesAbertas: vaga.posicoesAbertas, inclusos: vaga.inclusos, modo: vaga.modo
                )
            }
            .filter { vaga in filtro.distanciaMaximaKm.map { vaga.distanciaKm <= $0 } ?? true }
            .sorted {
                if $0.distanciaKm != $1.distanciaKm {
                    return $0.distanciaKm < $1.distanciaKm
                }
                return $0.id.uuidString < $1.id.uuidString
            }

        let inicio = min(deslocamento, ordenadas.count)
        let fim = min(inicio + limite, ordenadas.count)
        return Array(ordenadas[inicio..<fim])
    }

    public func detalheDaVaga(id: UUID) async throws -> Vaga {
        try verificarFalhaGeral()
        guard let vaga = vagas.first(where: { $0.id == id }), !bloqueada(vaga) else { throw erro("nao_encontrado") }
        // Contrato 0.2.23: a vaga ocultada só abre, com `oculta: true`, para quem ocupa posição ou tem
        // candidatura nela; para os demais é o mesmo 404 da vaga escondida por bloqueio.
        if vaga.oculta, !turnos.contains(where: { $0.vaga.id == id }), candidaturasPendentes[id] == nil {
            throw erro("nao_encontrado")
        }
        // Contrato 0.2.19: depois do início o detalhe continua respondendo, com o estado real e sem
        // nada para pegar. Não vira 404, para o toque numa notificação antiga abrir a vaga.
        guard vaga.periodo.inicio > relogio.agora else { return Self.copia(vaga, posicoesAbertas: 0) }
        return vaga
    }

    public func candidatar(vagaID: UUID) async throws -> ResultadoCandidatura {
        chamadasACandidatar += 1
        try verificarFalhaGeral()
        if cenario == .vagaPreenchida { throw erro("posicao_ja_preenchida") }
        if cenario == .vagaEncerrada { throw erro("vaga_encerrada") }
        if cenario == .inelegivel { throw erro("inelegivel", detalhes: "turno_sobreposto") }
        if cenario == .inelegivelSuspenso { throw erro("inelegivel", detalhes: "perfil_suspenso") }
        guard let indice = vagas.firstIndex(where: { $0.id == vagaID }) else { throw erro("nao_encontrado") }
        let vaga = vagas[indice]
        // Contrato 0.2.23: candidatura nova em vaga ocultada responde 404, como a escondida por bloqueio.
        guard !vaga.oculta, !bloqueada(vaga) else { throw erro("nao_encontrado") }
        // A vaga cancelada não existe mais para quem chega: `vaga_encerrada`, e não "alguém chegou antes".
        guard vaga.estado != .cancelada, vaga.estado != .encerrada else { throw erro("vaga_encerrada") }
        // Chegar depois da última posição é o funcionamento normal do modo urgência (RN19).
        guard vaga.estado != .preenchida, vaga.posicoesAbertas > 0 else { throw erro("posicao_ja_preenchida") }
        guard vaga.estado == .publicada else { throw erro("vaga_encerrada") }
        // Contrato 0.2.19: início já passado é vaga encerrada. A exceção do backend, a posição
        // reaberta por atraso, que aceita candidatura até 1 h antes do fim, o dublê não modela.
        let agora = relogio.agora
        guard vaga.periodo.inicio > agora else { throw erro("vaga_encerrada") }
        // Contrato 0.2.24: na vaga de seleção a candidatura fica pendente, sem posição, turno nem
        // contato, e a vaga não aceita candidatura a partir de 24 h antes do início (RN24).
        if vaga.modo == .selecao {
            guard agora < vaga.periodo.inicio.addingTimeInterval(-Self.antecedenciaDaSelecao) else { throw erro("vaga_encerrada") }
            let candidaturaID = candidaturasPendentes[vagaID] ?? UUID()
            candidaturasPendentes[vagaID] = candidaturaID
            return ResultadoCandidatura(estado: .pendente, candidaturaID: candidaturaID, posicaoID: nil, turnoID: nil, contato: nil)
        }

        let visivelAte = vaga.periodo.fim.addingTimeInterval(7 * 24 * 60 * 60)
        let contato = Contato(nome: vaga.estabelecimento.nome, telefone: contatoDeExemplo.telefone, whatsappURL: contatoDeExemplo.whatsappURL, visivelAte: visivelAte)
        // A posição que um cancelamento reabriu é ocupada com o id que o painel já mostrava.
        var reabertas = posicoesReabertas[vagaID] ?? []
        let posicaoID = reabertas.isEmpty ? UUID() : reabertas.removeFirst()
        posicoesReabertas[vagaID] = reabertas
        let turno = Turno(
            id: UUID(), posicaoID: posicaoID, vaga: vaga.resumo, contraparte: vaga.estabelecimento, contatoVisivelAte: visivelAte,
            verificacao: .pendente, valorAcordado: vaga.valor, podeAvaliar: false
        )
        turnos.append(turno)
        contatos[turno.id] = contato
        vagas[indice] = Self.comPosicoesAbertas(vaga.posicoesAbertas - 1, em: vaga)
        return ResultadoCandidatura(estado: .confirmada, candidaturaID: UUID(), posicaoID: turno.posicaoID, turnoID: turno.id, contato: contato)
    }

    public func perfilPublico(id: UUID) async throws -> PerfilPublico {
        try verificarFalhaGeral()
        if id == perfilPublicoDeExemplo.id { return perfilPublicoDeExemplo }
        guard let perfil = vagas.map(\.estabelecimento).first(where: { $0.id == id }) else { throw erro("nao_encontrado") }
        return perfil
    }

    // MARK: Turno

    public func meusTurnos() async throws -> [Turno] {
        try verificarFalhaGeral()
        return turnos
    }

    public func contatoDoTurno(id: UUID) async throws -> Contato {
        try verificarFalhaGeral()
        guard let turno = turnos.first(where: { $0.id == id }), let contato = contatos[id] else { throw erro("nao_encontrado") }
        // Contrato 0.2.9: com bloqueio entre as partes, o contato responde 404.
        guard bloqueios[Alvo(turno.contraparte)] == nil else { throw erro("nao_encontrado") }
        guard turno.contatoVisivel(em: relogio.agora) else { throw erro("contato_expirado") }
        return contato
    }

    /// Segue `avisar_a_caminho` do backend (`20260930160000_avisar_a_caminho.sql`): o aviso já
    /// gravado volta como está, antes de conferir a janela; a janela vai de 3 h antes até 15 min
    /// depois do início, com as duas bordas dentro; turno que não é de quem chama é `403 sem_permissao`.
    public func avisarACaminho(turnoID: UUID) async throws -> ResultadoACaminho {
        try verificarFalhaGeral()
        guard let indice = turnos.firstIndex(where: { $0.id == turnoID }) else { throw erro("sem_permissao") }
        let turno = turnos[indice]
        if let gravado = turno.aCaminhoEm { return ResultadoACaminho(turnoID: turnoID, aCaminhoEm: gravado) }
        let agora = relogio.agora
        let inicio = turno.vaga.periodo.inicio
        guard agora >= inicio.addingTimeInterval(-3 * 60 * 60), agora <= inicio.addingTimeInterval(15 * 60) else {
            throw erro("a_caminho_fora_da_janela")
        }
        turnos[indice] = turno.com(aCaminhoEm: agora)
        return ResultadoACaminho(turnoID: turnoID, aCaminhoEm: agora)
    }

    /// Segue `fazer_checkin` do backend (definição vigente em
    /// `20260925233000_notificacao_para_qualquer_conta.sql`): repetir devolve o registro gravado;
    /// até 200 m é `geolocalizado` e `verificado`, acima disso ou sem distância é `manual` e
    /// `pendente`, e o manual não guarda a distância.
    public func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        try verificarFalhaGeral()
        guard turnos.contains(where: { $0.id == turnoID }) else { throw erro("nao_encontrado") }
        if let gravado = checkins[turnoID] { return gravado }
        try validarRegistro(distanciaMetros: distanciaMetros, registradoEm: registradoEm)
        let perto = distanciaMetros.map { $0 <= 200 } ?? false
        let registro = ResultadoRegistro(
            turnoID: turnoID, tipo: perto ? .geolocalizado : .manual, verificacao: perto ? .verificado : .pendente,
            registradoEm: registradoEm, distanciaMetros: perto ? distanciaMetros : nil
        )
        checkins[turnoID] = registro
        return registro
    }

    /// Segue `fazer_checkout` do backend (`20260925000000_checkin_e_checkout.sql`): sem check-in é
    /// `409 checkin_pendente`; a distância não tem teto e é gravada como veio; repetir devolve o
    /// registro gravado. Tipo e verificação vêm do check-in gravado no dublê, que o
    /// `confirmarCheckinManual` atualiza, como a verificação atual do turno no backend.
    public func fazerCheckout(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        try verificarFalhaGeral()
        guard turnos.contains(where: { $0.id == turnoID }) else { throw erro("nao_encontrado") }
        if let gravado = checkouts[turnoID] { return gravado }
        guard let checkin = checkins[turnoID] else { throw erro("checkin_pendente") }
        try validarRegistro(distanciaMetros: distanciaMetros, registradoEm: registradoEm)
        let registro = ResultadoRegistro(
            turnoID: turnoID, tipo: checkin.tipo, verificacao: checkin.verificacao,
            registradoEm: registradoEm, distanciaMetros: distanciaMetros
        )
        checkouts[turnoID] = registro
        return registro
    }

    public func avaliar(turnoID: UUID, resposta: Bool) async throws -> Avaliacao {
        try verificarFalhaGeral()
        guard turnos.contains(where: { $0.id == turnoID }) else { throw erro("nao_encontrado") }
        return Avaliacao(turnoID: turnoID, resposta: resposta, criadaEm: relogio.agora)
    }

    // MARK: Turno do contratante

    /// Segue `confirmar_checkin_manual` do backend (`20260926060100_exigir_conta_ativa_escrita.sql`):
    /// turno que não existe é `404`; sem check-in, `409 checkin_pendente`; check-in geolocalizado,
    /// `409 checkin_ja_confirmado`; o manual já confirmado volta como está. O `403` de quem não é
    /// membro da casa (inclusive o profissional do turno) não é modelado: o dublê simula uma conta só.
    public func confirmarCheckinManual(turnoID: UUID) async throws -> ResultadoRegistro {
        try verificarFalhaGeral()
        guard turnos.contains(where: { $0.id == turnoID }) else { throw erro("nao_encontrado") }
        guard let checkin = checkins[turnoID] else { throw erro("checkin_pendente") }
        guard checkin.tipo == .manual else { throw erro("checkin_ja_confirmado") }
        guard checkin.verificacao != .verificado else { return checkin }
        let confirmado = ResultadoRegistro(
            turnoID: turnoID, tipo: checkin.tipo, verificacao: .verificado,
            registradoEm: checkin.registradoEm, distanciaMetros: checkin.distanciaMetros
        )
        checkins[turnoID] = confirmado
        // O check-out já gravado passa a responder com a verificação atual do turno.
        if let checkout = checkouts[turnoID] {
            checkouts[turnoID] = ResultadoRegistro(
                turnoID: turnoID, tipo: checkout.tipo, verificacao: .verificado,
                registradoEm: checkout.registradoEm, distanciaMetros: checkout.distanciaMetros
            )
        }
        return confirmado
    }

    /// Segue `reabrir_por_atraso` do backend (`20260928220000_alerta_de_atraso_e_reabrir_por_atraso.sql`):
    /// posição que não existe ou de outra casa é `403 sem_permissao`; reenviar devolve o mesmo
    /// resultado; posição que não está confirmada é `409 posicao_nao_cancelavel`, e com check-in o
    /// mesmo código traz `checkin_registrado`; antes dos 15 minutos, `422
    /// reabertura_antes_da_tolerancia`; a menos de 1 h do fim, marca a falta e não abre posição.
    /// Diferença declarada: o backend conta os 15 minutos do início ou da confirmação, o que for
    /// mais tarde; o dublê não guarda a hora da confirmação e conta do início.
    public func reabrirPorAtraso(posicaoID: UUID) async throws -> ResultadoCancelamento {
        try verificarFalhaGeral()
        if let gravado = reaberturasPorAtraso[posicaoID] { return gravado }
        guard let indice = turnos.firstIndex(where: { $0.posicaoID == posicaoID }) else {
            throw erro(conhecidaSemTurno(posicaoID) ? "posicao_nao_cancelavel" : "sem_permissao")
        }
        let turno = turnos[indice]
        guard checkins[turno.id] == nil, turno.checkin == nil else { throw erro("posicao_nao_cancelavel", detalhes: "checkin_registrado") }
        let agora = relogio.agora
        guard agora >= turno.vaga.periodo.inicio.addingTimeInterval(Self.toleranciaDeAtraso) else {
            throw erro("reabertura_antes_da_tolerancia")
        }
        let resultado = cancelarTurno(em: indice, falta: true, reabrir: agora < turno.vaga.periodo.fim.addingTimeInterval(-60 * 60))
        reaberturasPorAtraso[posicaoID] = resultado
        return resultado
    }

    // MARK: Cancelamento

    /// Segue `cancelar_posicao` do backend (`20260926060100_exigir_conta_ativa_escrita.sql` e
    /// `privado.cancelar_uma_posicao`): motivo com menos de 3 caracteres é `422 campo_obrigatorio`;
    /// posição que não existe, `404`; a que não está confirmada, `409 posicao_nao_cancelavel`; antes
    /// do início a vaga ganha uma posição nova, depois dele o turno fica descoberto. Quem cancela é
    /// a conta do dublê: com perfil de profissional é o profissional da posição, e a menos de 24 h
    /// do início leva falta; com perfil de contratante é a casa, sem falta. O filtro de termos da
    /// diretriz 1.2 (`422 campo_invalido`, `motivo`) não é modelado.
    public func cancelarPosicao(id: UUID, motivo: String) async throws -> ResultadoCancelamento {
        try verificarFalhaGeral()
        try validarMotivo(motivo)
        guard let indice = turnos.firstIndex(where: { $0.posicaoID == id }) else {
            throw erro(conhecidaSemTurno(id) ? "posicao_nao_cancelavel" : "nao_encontrado")
        }
        let agora = relogio.agora
        let inicio = turnos[indice].vaga.periodo.inicio
        let peloProfissional = conta?.perfil == .profissional
        return cancelarTurno(
            em: indice, falta: peloProfissional && inicio.timeIntervalSince(agora) < 24 * 60 * 60, reabrir: inicio > agora
        )
    }

    /// Segue `cancelar_vaga` do backend (`20260925020000_cancelamentos.sql`): vaga que não existe
    /// ou de outra casa é `404`; a já cancelada ou encerrada, `409 vaga_encerrada`; as posições
    /// confirmadas caem sem falta e sem reabertura, e as abertas, junto. O `422 perfil_incompativel`
    /// da conta de profissional não é modelado: o dublê não cobra RN25 fora dos cadastros.
    public func cancelarVaga(id: UUID, motivo: String) async throws -> VagaCancelada {
        try verificarFalhaGeral()
        try validarMotivo(motivo)
        guard let indice = vagas.firstIndex(where: { $0.id == id }),
              estabelecimentos.contains(where: { $0.id == vagas[indice].estabelecimento.id }) else { throw erro("nao_encontrado") }
        let vaga = vagas[indice]
        guard vaga.estado != .cancelada, vaga.estado != .encerrada else { throw erro("vaga_encerrada") }
        var confirmadas = 0
        while let turno = turnos.firstIndex(where: { $0.vaga.id == id }) {
            _ = cancelarTurno(em: turno, falta: false, reabrir: false)
            confirmadas += 1
        }
        posicoesReabertas[id] = nil
        candidaturasPendentes[id] = nil
        vagas[indice] = Self.copia(vaga, posicoesAbertas: 0, estado: .cancelada)
        return VagaCancelada(vagaID: id, estado: .cancelada, posicoesCanceladas: vaga.posicoesAbertas + confirmadas)
    }

    // MARK: Confiança e direitos

    /// Segue `denunciar` do backend (`20260929100000_denunciar_e_bloquear.sql`): a chave decide antes
    /// de qualquer validação, e reenviar devolve o mesmo protocolo; relato em branco é `422
    /// campo_obrigatorio`, e com menos de 10 caracteres, `422 campo_invalido`; alvo que não existe e
    /// turno que não é das duas partes são `404`. Denunciar a si mesmo (`422 campo_invalido`,
    /// `alvo_id`) não é modelado: a conta única do dublê é também o profissional e a casa de exemplo.
    public func denunciar(_ denuncia: Denuncia) async throws -> Protocolo {
        try verificarFalhaGeral()
        if let gravado = denunciasPorChave[denuncia.chave] { return gravado }
        try validarRelato(denuncia.relato)
        guard existe(denuncia.alvo) else { throw erro("nao_encontrado") }
        if let turnoID = denuncia.turnoID {
            guard let turno = (turnos + turnosCancelados).first(where: { $0.id == turnoID }) else { throw erro("nao_encontrado") }
            let casa = vagas.first { $0.id == turno.vaga.id }?.estabelecimento.id
            guard [turno.contraparte.id, perfilPublicoDeExemplo.id, casa].contains(denuncia.alvo.id) else { throw erro("nao_encontrado") }
        }
        let protocolo = try novoProtocolo(.denuncia)
        denunciasPorChave[denuncia.chave] = protocolo
        return protocolo
    }

    /// Segue `bloquear` do backend (`20260929100000_denunciar_e_bloquear.sql`): alvo que não existe é
    /// `404`, e bloquear de novo devolve o bloqueio que já existe. A partir daí as vagas da casa
    /// bloqueada saem da lista, e detalhe, candidatura e contato respondem `404`. O `perfil_publico`
    /// continua respondendo, como no contrato 0.2.27. Não modelados: o `422 campo_invalido` de alvo
    /// do mesmo perfil de quem bloqueia e o bloqueio de si mesmo, pela conta única do dublê.
    public func bloquear(_ alvo: Alvo) async throws -> Bloqueio {
        try verificarFalhaGeral()
        guard existe(alvo) else { throw erro("nao_encontrado") }
        if let gravado = bloqueios[alvo] { return gravado }
        let bloqueio = Bloqueio(alvo: alvo, criadoEm: relogio.agora)
        bloqueios[alvo] = bloqueio
        return bloqueio
    }

    /// Segue `situacao_da_conta` do backend (`20261001100000_suspensao_da_conta.sql`): responde
    /// também para a conta suspensa, que as outras operações recusam; sem conta é `401`.
    public func situacaoDaConta() async throws -> SituacaoDaConta {
        try verificarRede()
        guard let conta else { throw erro("nao_autenticado") }
        return SituacaoDaConta(estado: conta.estado, suspensao: suspensao)
    }

    /// Segue `contestar_suspensao` do backend (`20261001100000_suspensao_da_conta.sql`), na ordem
    /// dele: sem suspensão é `422 sem_suspensao_ativa`; relato em branco, `422 campo_obrigatorio`; com
    /// menos de 10 caracteres, `422 campo_invalido`; contestação já aberta, `409 contestacao_ja_aberta`.
    public func contestarSuspensao(relato: String) async throws -> Protocolo {
        try verificarRede()
        guard conta != nil else { throw erro("nao_autenticado") }
        guard let atual = suspensao else { throw erro("sem_suspensao_ativa") }
        try validarRelato(relato)
        guard atual.contestacao == nil else { throw erro("contestacao_ja_aberta") }
        let protocolo = try novoProtocolo(.contestacao)
        suspensao = Suspensao(motivo: atual.motivo, desde: atual.desde, contestacao: protocolo)
        return protocolo
    }

    // MARK: Aplicativo e dispositivo

    public func configuracaoDoApp() async throws -> ConfiguracaoApp {
        try verificarRede()
        if cenario == .atualizacaoObrigatoria {
            return ConfiguracaoApp(versaoMinima: "99.0.0", versaoRecomendada: "99.0.0", mensagem: configuracao.mensagem, urlDaLoja: configuracao.urlDaLoja)
        }
        return configuracao
    }

    public func removerDispositivo(tokenFCM: String) async throws { try verificarRede() }

    public func sair(tokenFCM: String?) async {
        sessaoAtiva = false
        DestinoGuardado.limpar()
    }

    // MARK: Moderação

    /// Ocultar e reexibir uma vaga (contrato 0.2.23). Fica fora da porta `ApiCliente` de propósito:
    /// no backend é operação da Equipe Frila pela chave de serviço. Aqui serve aos testes e às prévias.
    public func moderar(vagaID: UUID, oculta: Bool) {
        guard let indice = vagas.firstIndex(where: { $0.id == vagaID }) else { return }
        vagas[indice] = Self.copia(vagas[indice], oculta: oculta)
    }

    // MARK: Apoio

    /// RN24: a vaga de seleção fecha 24 horas antes do início.
    private static let antecedenciaDaSelecao: TimeInterval = 24 * 60 * 60

    /// D06: aos 15 minutos do início sem check-in a posição está em atraso e pode ser reaberta.
    private static let toleranciaDeAtraso: TimeInterval = 15 * 60

    /// O que `privado.cancelar_uma_posicao` faz: a posição cancelada guarda de quem era, e a vaga,
    /// quando reabre, ganha uma posição nova e volta a `publicada`.
    private func cancelarTurno(em indice: Int, falta: Bool, reabrir: Bool) -> ResultadoCancelamento {
        let turno = turnos.remove(at: indice)
        turnosCancelados.append(turno)
        contatos[turno.id] = nil
        var nova: UUID?
        if reabrir, let daVaga = vagas.firstIndex(where: { $0.id == turno.vaga.id }) {
            let vaga = vagas[daVaga]
            let id = UUID()
            nova = id
            posicoesReabertas[vaga.id, default: []].append(id)
            vagas[daVaga] = Self.copia(
                vaga, posicoesAbertas: vaga.posicoesAbertas + 1, estado: vaga.estado == .preenchida ? .publicada : vaga.estado
            )
        }
        return ResultadoCancelamento(posicaoID: turno.posicaoID, falta: falta, reaberta: nova != nil, novaPosicaoID: nova)
    }

    /// Posição que o dublê conhece e que não tem turno confirmado: já cancelada, ou aberta por uma reabertura.
    private func conhecidaSemTurno(_ posicaoID: UUID) -> Bool {
        turnosCancelados.contains { $0.posicaoID == posicaoID } || posicoesReabertas.values.contains { $0.contains(posicaoID) }
    }

    private func validarMotivo(_ motivo: String) throws {
        guard motivo.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 else { throw erro("campo_obrigatorio", detalhes: "motivo") }
    }

    private func validarRelato(_ relato: String) throws {
        let limpo = relato.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpo.isEmpty else { throw erro("campo_obrigatorio", detalhes: "relato") }
        guard limpo.count >= 10 else { throw erro("campo_invalido", detalhes: "relato") }
    }

    /// O profissional de exemplo, que o painel mostra nas posições, ou uma casa que o dublê conhece.
    private func existe(_ alvo: Alvo) -> Bool {
        switch alvo.tipo {
        case .profissional: alvo.id == perfilPublicoDeExemplo.id
        case .estabelecimento: estabelecimentos.contains { $0.id == alvo.id } || vagas.contains { $0.estabelecimento.id == alvo.id }
        }
    }

    private func bloqueada(_ vaga: Vaga) -> Bool {
        bloqueios[Alvo(vaga.estabelecimento)] != nil
    }

    private func novoProtocolo(_ tipo: TipoDeProtocolo) throws -> Protocolo {
        let agora = relogio.agora
        guard let prazo = Self.prazoDeResposta(agora) else { throw ErroDaApi(codigo: .respostaInvalida) }
        return Protocolo(ocorrenciaID: UUID(), tipo: tipo, criadaEm: agora, prazoRespostaAte: prazo)
    }

    /// `privado.prazo_de_resposta` do backend: o quinto dia útil (segunda a sexta) contado do dia
    /// seguinte ao registro, no dia de São Paulo, sem calendário de feriados.
    private static func prazoDeResposta(_ instante: Date) -> DataCivil? {
        var calendario = Calendar(identifier: .gregorian)
        guard let fuso = TimeZone(identifier: "America/Sao_Paulo") else { return nil }
        calendario.timeZone = fuso
        var uteis = 0
        for dias in 1...14 {
            guard let dia = calendario.date(byAdding: .day, value: dias, to: instante) else { return nil }
            if calendario.isDateInWeekend(dia) { continue }
            uteis += 1
            if uteis == 5 { return DataCivil.deSaoPaulo(dia) }
        }
        return nil
    }

    /// O que os dois registros validam depois da idempotência, na ordem do backend
    /// (`privado.exigir_janela`). Diferenças declaradas: o backend tolera até 2 minutos no futuro
    /// e o dublê recusa qualquer instante no futuro; o backend é mais restritivo na janela do turno
    /// (`fora_da_janela` fora de início − 60 min até o fim), que o dublê não confere, então o
    /// dublê aceita registros que o backend recusaria; a exceção de janela da conta de
    /// demonstração também não é modelada.
    private func validarRegistro(distanciaMetros: Int?, registradoEm: Date) throws {
        guard registradoEm <= relogio.agora else { throw erro("registro_no_futuro") }
        if let distanciaMetros, distanciaMetros < 0 { throw erro("campo_invalido", detalhes: "distancia_m") }
    }

    private func doCatalogo(_ ids: [UUID]) throws -> [Funcao] {
        try ids.map { id in
            guard let funcao = catalogo.first(where: { $0.id == id }) else { throw erro("campo_invalido", detalhes: "funcoes") }
            return funcao
        }
    }

    private func perfilDo(_ estabelecimento: Estabelecimento) -> PerfilPublico {
        vagas.map(\.estabelecimento).first { $0.id == estabelecimento.id }
            ?? PerfilPublico(
                id: estabelecimento.id, tipo: .estabelecimento, nome: estabelecimento.nome,
                reputacao: Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0)
            )
    }

    private func verificarRede() throws {
        if cenario == .semRede { throw ErroDaApi(codigo: .semRede) }
    }

    private func verificarFalhaGeral() throws {
        try verificarRede()
        if cenario == .contaSuspensa { throw erro("sem_permissao", detalhes: "conta_suspensa") }
    }

    /// Erro montado a partir do envelope em `erros.json`, como o cliente real recebe.
    private func erro(_ codigo: String, detalhes: String? = nil) -> ErroDaApi {
        let envelope = envelopes.values.first { $0.code == codigo && (detalhes == nil || $0.details == detalhes) } ?? envelopes[codigo]
        return DecodificadorErroAPI.mapear(codigo: envelope?.code ?? codigo, detalhes: detalhes ?? envelope?.details)
    }

    private static func noFuturo(_ vaga: Vaga, agora: Date, inicioEm: TimeInterval = 24 * 60 * 60) throws -> Vaga {
        let inicio = agora.addingTimeInterval(inicioEm)
        let periodo = try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(vaga.periodo.fim.timeIntervalSince(vaga.periodo.inicio)))
        return copia(vaga, periodo: periodo, publicadoEm: agora)
    }

    private static func comPosicoesAbertas(_ abertas: Int, em vaga: Vaga) -> Vaga {
        copia(vaga, posicoesAbertas: abertas, estado: abertas == 0 ? .preenchida : vaga.estado)
    }

    /// A vaga com o que o dublê muda nela; o que não vier fica como está.
    private static func copia(
        _ vaga: Vaga, periodo: Periodo? = nil, posicoesAbertas: Int? = nil, estado: EstadoVaga? = nil, oculta: Bool? = nil,
        publicadoEm: Date? = nil
    ) -> Vaga {
        Vaga(
            id: vaga.id, estabelecimento: vaga.estabelecimento, funcao: vaga.funcao, periodo: periodo ?? vaga.periodo,
            local: vaga.local, regiaoAdministrativa: vaga.regiaoAdministrativa, ponto: vaga.ponto, distanciaKm: vaga.distanciaKm,
            valor: vaga.valor, posicoes: vaga.posicoes, posicoesAbertas: posicoesAbertas ?? vaga.posicoesAbertas,
            inclusos: vaga.inclusos, responsavelLocal: vaga.responsavelLocal, traje: vaga.traje,
            participaRateio: vaga.participaRateio, observacoes: vaga.observacoes, modo: vaga.modo,
            estado: estado ?? vaga.estado, oculta: oculta ?? vaga.oculta, publicadoEm: publicadoEm ?? vaga.publicadoEm
        )
    }
}

// MARK: - Exclusão de Conta (Porta ExclusaoDeContaPorta)

public enum CenarioExclusaoConta: Sendable, Equatable {
    case padrao
    case comTurnosCancelados(Int)
    case administradorUnico
    case semRede
}

private actor ArmazenamentoCenarioExclusao {
    static let compartilhado = ArmazenamentoCenarioExclusao()
    private var cenarios: [ObjectIdentifier: CenarioExclusaoConta] = [:]

    func definir(_ cenario: CenarioExclusaoConta, para cliente: ApiClienteEmMemoria) {
        cenarios[ObjectIdentifier(cliente)] = cenario
    }

    func consumir(para cliente: ApiClienteEmMemoria) -> CenarioExclusaoConta {
        cenarios.removeValue(forKey: ObjectIdentifier(cliente)) ?? .padrao
    }

    func limpar() {
        cenarios.removeAll()
    }
}

extension ApiClienteEmMemoria: ExclusaoDeContaPorta {
    public func configurarCenarioExclusao(_ cenario: CenarioExclusaoConta) async {
        await ArmazenamentoCenarioExclusao.compartilhado.definir(cenario, para: self)
    }

    public func excluirConta() async throws -> ExclusaoDeConta {
        let configurado = await ArmazenamentoCenarioExclusao.compartilhado.consumir(para: self)

        let argumentos = ProcessInfo.processInfo.arguments
        let cenarioEfetivo: CenarioExclusaoConta
        if configurado != .padrao {
            cenarioEfetivo = configurado
        } else if argumentos.contains("-FRILA_EXCLUSAO_ADMIN_UNICO") {
            cenarioEfetivo = .administradorUnico
        } else if argumentos.contains("-FRILA_EXCLUSAO_SEM_REDE") {
            cenarioEfetivo = .semRede
        } else if let idx = argumentos.firstIndex(of: "-FRILA_EXCLUSAO_TURNOS"), argumentos.indices.contains(idx + 1), let n = Int(argumentos[idx + 1]) {
            cenarioEfetivo = .comTurnosCancelados(n)
        } else {
            cenarioEfetivo = .padrao
        }

        if cenarioEfetivo == .semRede || cenario == .semRede {
            throw ErroDaApi(codigo: .semRede)
        }
        try verificarRede()

        if cenarioEfetivo == .administradorUnico {
            throw ErroDaApi(codigo: .administradorUnico, codigoOriginal: "administrador_unico")
        }

        let cancelados: Int
        switch cenarioEfetivo {
        case let .comTurnosCancelados(quantidade):
            cancelados = quantidade
        default:
            cancelados = turnos.count
        }

        turnos.removeAll()
        conta = nil
        perfilProfissional = nil
        estabelecimentos = []
        sessaoAtiva = false
        DestinoGuardado.limpar()

        let agora = relogio.agora
        let dataLimite = DataCivil.deSaoPaulo(agora, somandoDias: 15) ?? (try! DataCivil("2026-10-16"))
        return ExclusaoDeConta(
            perfilRemovidoEm: agora,
            dadosApagadosAte: dataLimite,
            turnosCancelados: cancelados
        )
    }

    // MARK: - Suporte a cenários de teste da suspensão (#41)

    public func reativarConta() {
        if let contaAtual = conta {
            conta = Conta(
                id: contaAtual.id,
                perfil: contaAtual.perfil,
                nome: contaAtual.nome,
                telefone: contaAtual.telefone,
                email: contaAtual.email,
                nascimento: contaAtual.nascimento,
                estado: .ativa
            )
        }
        suspensao = nil
    }

    public func definirContestacaoExistente(protocolo: Protocolo? = nil) throws {
        guard let atual = suspensao else { throw erro("sem_suspensao_ativa") }
        let prot = try protocolo ?? novoProtocolo(.contestacao)
        suspensao = Suspensao(motivo: atual.motivo, desde: atual.desde, contestacao: prot)
    }
}


