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
                if cenario == .contratante {
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
            estabelecimentos = conta == nil ? [] : [try FixturesDoContrato.carregar("estabelecimento", como: ContratoAPI.EstabelecimentoDTO.self).dominio()]
            if let vagas {
                self.vagas = vagas
            } else {
                let vaga = try FixturesDoContrato.carregar("vaga", como: ContratoAPI.VagaDTO.self).dominio()
                let ateInicio: TimeInterval = cenario == .alertaVagaVazia ? 2 * 60 * 60 : 24 * 60 * 60
                self.vagas = [try Self.noFuturo(vaga, agora: relogio.agora, inicioEm: ateInicio)]
            }
            if cenario == .painelVazio { self.vagas = [] }
            if cenario == .painelContratante, let vaga = self.vagas.first {
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
                    verificacao: .verificado, valorAcordado: vaga.valor, podeAvaliar: false
                )]
                contatos[turnoID] = contato
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
                let confirmadas = turnos.filter { $0.vaga.id == vaga.id }.map { turno in
                    PosicaoNoPainel(
                        id: turno.posicaoID, estado: .confirmada, profissional: perfilPublicoDeExemplo, turnoID: turno.id,
                        verificacao: turno.verificacao, emAtraso: false, aCaminhoEm: turno.aCaminhoEm
                    )
                }
                let abertas = (0..<vaga.posicoesAbertas).map { _ in
                    PosicaoNoPainel(id: UUID(), estado: .aberta, profissional: nil, turnoID: nil, verificacao: nil, emAtraso: false)
                }
                let vazia = vaga.posicoesAbertas == vaga.posicoes && vaga.periodo.inicio.timeIntervalSince(agora) < 3 * 60 * 60
                return VagaNoPainel(
                    vaga: vaga.resumo, modo: vaga.modo, estado: vaga.estado, oculta: vaga.oculta, alertaVagaVazia: vazia,
                    candidatosPendentes: candidaturasPendentes[vaga.id] == nil ? 0 : 1, posicoes: confirmadas + abertas
                )
            },
            checkinsPendentes: []
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
        guard let vaga = vagas.first(where: { $0.id == id }) else { throw erro("nao_encontrado") }
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
        guard !vaga.oculta else { throw erro("nao_encontrado") }
        // Chegar depois da última posição é o funcionamento normal do modo urgência (RN19).
        guard vaga.estado != .preenchida, vaga.posicoesAbertas > 0 else { throw erro("posicao_ja_preenchida") }
        guard vaga.estado == .publicada else { throw erro("vaga_encerrada") }
        // Contrato 0.2.19: início já passado é vaga encerrada. A exceção é a posição reaberta por
        // atraso, que o dublê não tem (a porta não traz `reabrir_por_atraso`).
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
        let turno = Turno(
            id: UUID(), posicaoID: UUID(), vaga: vaga.resumo, contraparte: vaga.estabelecimento, contatoVisivelAte: visivelAte,
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
    /// registro gravado. Tipo e verificação vêm do check-in gravado no dublê; no backend a
    /// verificação é a atual do turno, que o `confirmar_checkin_manual` muda (operação que a
    /// porta `ApiCliente` e o dublê não têm).
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

    // MARK: Aplicativo e dispositivo

    public func configuracaoDoApp() async throws -> ConfiguracaoApp {
        try verificarRede()
        guard cenario == .contaSuspensa else { return configuracao }
        return ConfiguracaoApp(versaoMinima: "99.0.0", versaoRecomendada: "99.0.0", mensagem: configuracao.mensagem, urlDaLoja: configuracao.urlDaLoja)
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
}

