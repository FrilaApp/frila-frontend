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

    public init(cenario: Cenario = .sucesso, relogio: any Relogio = RelogioDoSistema()) {
        self.cenario = cenario
        self.relogio = relogio
        do {
            envelopes = try FixturesDoContrato.erros()
            catalogo = try FixturesDoContrato.carregar("funcoes", como: [ContratoAPI.FuncaoDTO].self).map { $0.dominio() }
            configuracao = try FixturesDoContrato.carregar("configuracao-do-app", como: ContratoAPI.ConfiguracaoDoAppDTO.self).dominio()
            contatoDeExemplo = try FixturesDoContrato.carregar("contato", como: ContratoAPI.ContatoDTO.self).dominio()
            perfilPublicoDeExemplo = try FixturesDoContrato.carregar("perfil-publico", como: ContratoAPI.PerfilPublicoDTO.self).dominio()
            let usuario = try FixturesDoContrato.carregar("usuario", como: ContratoAPI.UsuarioDTO.self).dominio()
            conta = cenario == .primeiroAcesso ? nil : usuario
            perfilProfissional = try FixturesDoContrato.carregar("perfil-profissional", como: ContratoAPI.PerfilProfissionalDTO.self).dominio()
            estabelecimentos = [try FixturesDoContrato.carregar("estabelecimento", como: ContratoAPI.EstabelecimentoDTO.self).dominio()]
            let vaga = try FixturesDoContrato.carregar("vaga", como: ContratoAPI.VagaDTO.self).dominio()
            vagas = [try Self.noFuturo(vaga, agora: relogio.agora)]
        } catch {
            preconditionFailure("Fixture do contrato ilegível: \(error)")
        }
    }

    public static func pelosArgumentos(_ argumentos: [String] = ProcessInfo.processInfo.arguments) -> ApiClienteEmMemoria {
        guard let indice = argumentos.firstIndex(of: "-FRILA_SCENARIO"), argumentos.indices.contains(indice + 1),
              let cenario = Cenario(rawValue: argumentos[indice + 1]) else {
            return ApiClienteEmMemoria()
        }
        return ApiClienteEmMemoria(cenario: cenario)
    }

    // MARK: Entrada

    public func solicitarCodigo(email: String) async throws { try verificarRede() }

    public func verificarCodigo(email: String, codigo: String) async throws {
        try verificarRede()
        sessaoAtiva = true
    }

    public func possuiSessao() async -> Bool { sessaoAtiva }

    public func entrarDemonstracao(email: String, codigo: String) async throws {
        try verificarRede()
        guard !codigo.isEmpty else { throw erro("nao_encontrado") }
        sessaoAtiva = true
    }

    // MARK: Conta e perfil

    public func minhaConta() async throws -> Conta {
        try verificarRede()
        guard let conta else { throw erro("nao_encontrado") }
        return conta
    }

    public func criarConta(_ cadastro: CadastroConta) async throws -> Conta {
        try verificarRede()
        guard conta == nil else { throw erro("conta_existente") }
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
        guard !estabelecimentos.contains(where: { $0.documento == cadastro.documento }) else { throw erro("documento_ja_cadastrado") }
        let novo = Estabelecimento(
            id: UUID(), nome: cadastro.nome, documento: cadastro.documento, tipo: cadastro.tipo,
            endereco: cadastro.endereco, ponto: cadastro.ponto, papel: .administrador
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
                    PosicaoNoPainel(id: turno.posicaoID, estado: .confirmada, profissional: perfilPublicoDeExemplo, turnoID: turno.id, verificacao: turno.verificacao, emAtraso: false)
                }
                let abertas = (0..<vaga.posicoesAbertas).map { _ in
                    PosicaoNoPainel(id: UUID(), estado: .aberta, profissional: nil, turnoID: nil, verificacao: nil, emAtraso: false)
                }
                let vazia = vaga.posicoesAbertas == vaga.posicoes && vaga.periodo.inicio.timeIntervalSince(agora) < 3 * 60 * 60
                return VagaNoPainel(vaga: vaga.resumo, modo: vaga.modo, estado: vaga.estado, alertaVagaVazia: vazia, candidatosPendentes: 0, posicoes: confirmadas + abertas)
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
        try verificarFalhaGeral()
        guard let estabelecimento = estabelecimentos.first(where: { $0.id == publicacao.estabelecimentoID }) else { throw erro("sem_permissao") }
        guard let funcao = catalogo.first(where: { $0.id == publicacao.funcaoID }) else { throw erro("campo_invalido", detalhes: "funcao_id") }
        let vaga = Vaga(
            id: UUID(), estabelecimento: perfilDo(estabelecimento), funcao: funcao, periodo: publicacao.periodo,
            local: publicacao.local, ponto: publicacao.ponto, valor: publicacao.valor, posicoes: publicacao.posicoes,
            posicoesAbertas: publicacao.posicoes, inclusos: publicacao.inclusos, responsavelLocal: publicacao.responsavelLocal,
            traje: publicacao.traje, participaRateio: publicacao.participaRateio, observacoes: publicacao.observacoes,
            modo: publicacao.modo, estado: .publicada, publicadoEm: relogio.agora
        )
        vagas.append(vaga)
        return VagaPublicada(vagaID: vaga.id, posicoes: (0..<publicacao.posicoes).map { _ in UUID() })
    }

    public func republicarVaga(id: UUID, periodo: Periodo, chave: UUID) async throws -> VagaPublicada {
        guard let original = vagas.first(where: { $0.id == id }) else { throw erro("nao_encontrado") }
        return try await publicarVaga(
            PublicacaoVaga(
                estabelecimentoID: original.estabelecimento.id, funcaoID: original.funcao.id, periodo: periodo,
                local: original.local, ponto: original.ponto, valor: original.valor, posicoes: original.posicoes,
                inclusos: original.inclusos, responsavelLocal: original.responsavelLocal, traje: original.traje,
                participaRateio: original.participaRateio, observacoes: original.observacoes, modo: original.modo, chave: chave
            )
        )
    }

    public func vagasAbertas(_ filtro: FiltroVagas) async throws -> [VagaNaLista] {
        try verificarFalhaGeral()
        let referencia = filtro.referencia ?? perfilProfissional?.pontoBase
        return vagas
            .filter { $0.estado == .publicada && (filtro.funcaoID == nil || $0.funcao.id == filtro.funcaoID) }
            .map { vaga in
                let distancia = referencia.map { vaga.ponto.distancia(emMetrosDe: $0) / 1_000 } ?? 0
                return VagaNaLista(
                    id: vaga.id, funcao: vaga.funcao, estabelecimento: vaga.estabelecimento, periodo: vaga.periodo,
                    local: vaga.local, distanciaKm: distancia, valor: vaga.valor, posicoesAbertas: vaga.posicoesAbertas,
                    inclusos: vaga.inclusos, modo: vaga.modo
                )
            }
            .filter { vaga in filtro.distanciaMaximaKm.map { vaga.distanciaKm <= $0 } ?? true }
            .sorted { $0.distanciaKm < $1.distanciaKm }
    }

    public func detalheDaVaga(id: UUID) async throws -> Vaga {
        try verificarFalhaGeral()
        guard let vaga = vagas.first(where: { $0.id == id }) else { throw erro("nao_encontrado") }
        return vaga
    }

    public func candidatar(vagaID: UUID) async throws -> ResultadoCandidatura {
        try verificarFalhaGeral()
        if cenario == .vagaPreenchida { throw erro("posicao_ja_preenchida") }
        if cenario == .inelegivel { throw erro("inelegivel") }
        guard let indice = vagas.firstIndex(where: { $0.id == vagaID }) else { throw erro("nao_encontrado") }
        let vaga = vagas[indice]
        // Chegar depois da última posição é o funcionamento normal do modo urgência (RN19).
        guard vaga.estado != .preenchida, vaga.posicoesAbertas > 0 else { throw erro("posicao_ja_preenchida") }
        guard vaga.estado == .publicada else { throw erro("vaga_encerrada") }

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

    public func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        try registrar(turnoID: turnoID, distanciaMetros: distanciaMetros, registradoEm: registradoEm)
    }

    public func fazerCheckout(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) async throws -> ResultadoRegistro {
        try registrar(turnoID: turnoID, distanciaMetros: distanciaMetros, registradoEm: registradoEm)
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
    public func sair(tokenFCM: String?) async { sessaoAtiva = false }

    // MARK: Apoio

    private func registrar(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date) throws -> ResultadoRegistro {
        try verificarFalhaGeral()
        guard turnos.contains(where: { $0.id == turnoID }) else { throw erro("nao_encontrado") }
        guard registradoEm <= relogio.agora else { throw erro("registro_no_futuro") }
        let perto = distanciaMetros.map { $0 <= 200 } ?? false
        return ResultadoRegistro(
            turnoID: turnoID, tipo: perto ? .geolocalizado : .manual, verificacao: perto ? .verificado : .pendente,
            registradoEm: registradoEm, distanciaMetros: distanciaMetros
        )
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

    private static func noFuturo(_ vaga: Vaga, agora: Date) throws -> Vaga {
        let inicio = agora.addingTimeInterval(24 * 60 * 60)
        let periodo = try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(vaga.periodo.fim.timeIntervalSince(vaga.periodo.inicio)))
        return Vaga(
            id: vaga.id, estabelecimento: vaga.estabelecimento, funcao: vaga.funcao, periodo: periodo, local: vaga.local,
            ponto: vaga.ponto, distanciaKm: vaga.distanciaKm, valor: vaga.valor, posicoes: vaga.posicoes,
            posicoesAbertas: vaga.posicoesAbertas, inclusos: vaga.inclusos, responsavelLocal: vaga.responsavelLocal,
            traje: vaga.traje, participaRateio: vaga.participaRateio, observacoes: vaga.observacoes, modo: vaga.modo,
            estado: vaga.estado, publicadoEm: agora
        )
    }

    private static func comPosicoesAbertas(_ abertas: Int, em vaga: Vaga) -> Vaga {
        Vaga(
            id: vaga.id, estabelecimento: vaga.estabelecimento, funcao: vaga.funcao, periodo: vaga.periodo, local: vaga.local,
            ponto: vaga.ponto, distanciaKm: vaga.distanciaKm, valor: vaga.valor, posicoes: vaga.posicoes,
            posicoesAbertas: abertas, inclusos: vaga.inclusos, responsavelLocal: vaga.responsavelLocal, traje: vaga.traje,
            participaRateio: vaga.participaRateio, observacoes: vaga.observacoes, modo: vaga.modo,
            estado: abertas == 0 ? .preenchida : vaga.estado, publicadoEm: vaga.publicadoEm
        )
    }
}
