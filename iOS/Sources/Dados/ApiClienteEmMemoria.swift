import Foundation
import FrilaDominio

public actor ApiClienteEmMemoria: ApiCliente {
    public enum Cenario: String, CaseIterable, Sendable {
        case sucesso = "success"
        case vagaPreenchida = "vaga-preenchida"
        case inelegivel
        case semRede = "sem-rede"
        case contaSuspensa = "conta-suspensa"
    }

    private let cenario: Cenario
    private var vagas: [Vaga]
    private var turnos: [Turno] = []
    private var estabelecimentos: [Estabelecimento]
    private let funcao: Funcao
    private let sessao = SessaoUsuario(
        usuarioID: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
        perfil: .profissional
    )

    public init(cenario: Cenario = .sucesso) {
        self.cenario = cenario
        let dados = Self.fixtures()
        funcao = dados.funcao
        estabelecimentos = [dados.estabelecimento]
        vagas = [dados.vaga]
    }

    public static func pelosArgumentos(_ argumentos: [String] = ProcessInfo.processInfo.arguments) -> ApiClienteEmMemoria {
        guard let indice = argumentos.firstIndex(of: "-FRILA_SCENARIO"), argumentos.indices.contains(indice + 1),
              let cenario = Cenario(rawValue: argumentos[indice + 1]) else {
            return ApiClienteEmMemoria()
        }
        return ApiClienteEmMemoria(cenario: cenario)
    }

    public func solicitarCodigo(email: String) async throws { try verificarFalhaGeral() }

    public func verificarCodigo(email: String, codigo: String) async throws -> SessaoUsuario {
        try verificarFalhaGeral()
        return sessao
    }

    public func criarConta(_ cadastro: CadastroConta) async throws -> SessaoUsuario {
        try verificarFalhaGeral()
        return SessaoUsuario(usuarioID: sessao.usuarioID, perfil: cadastro.perfil)
    }

    public func funcoes() async throws -> [Funcao] {
        try verificarFalhaGeral()
        return [funcao]
    }

    public func cadastrarEstabelecimento(_ estabelecimento: Estabelecimento) async throws -> Estabelecimento {
        try verificarFalhaGeral()
        estabelecimentos.append(estabelecimento)
        return estabelecimento
    }

    public func meusEstabelecimentos() async throws -> [Estabelecimento] {
        try verificarFalhaGeral()
        return estabelecimentos
    }

    public func publicarVaga(_ publicacao: PublicacaoVaga) async throws -> VagaPublicada {
        try verificarFalhaGeral()
        let estabelecimento = estabelecimentos.first { $0.id == publicacao.estabelecimentoID } ?? Self.fixtures().estabelecimento
        let vaga = Vaga(
            id: UUID(),
            estabelecimento: estabelecimento,
            funcao: funcao,
            periodo: publicacao.periodo,
            local: publicacao.local,
            ponto: publicacao.ponto,
            valor: publicacao.valor,
            posicoes: publicacao.posicoes,
            posicoesAbertas: publicacao.posicoes,
            inclusos: publicacao.inclusos,
            responsavelLocal: publicacao.responsavelLocal,
            modo: publicacao.modo,
            estado: .publicada
        )
        vagas.append(vaga)
        return VagaPublicada(vagaID: vaga.id, posicoes: (0..<publicacao.posicoes).map { _ in UUID() })
    }

    public func republicarVaga(id: UUID, periodo: Periodo, chave: UUID) async throws -> VagaPublicada {
        guard let original = vagas.first(where: { $0.id == id }) else { throw ErroDaApi(codigo: .naoEncontrado) }
        return try await publicarVaga(
            PublicacaoVaga(
                estabelecimentoID: original.estabelecimento.id,
                funcaoID: original.funcao.id,
                periodo: periodo,
                local: original.local,
                ponto: original.ponto,
                valor: original.valor,
                posicoes: original.posicoes,
                inclusos: original.inclusos,
                responsavelLocal: original.responsavelLocal,
                modo: original.modo,
                chave: chave
            )
        )
    }

    public func vagasAbertas() async throws -> [Vaga] {
        try verificarFalhaGeral()
        return vagas.filter { $0.estado == .publicada }
    }

    public func detalheDaVaga(id: UUID) async throws -> Vaga {
        try verificarFalhaGeral()
        guard let vaga = vagas.first(where: { $0.id == id }) else { throw ErroDaApi(codigo: .naoEncontrado) }
        return vaga
    }

    public func candidatar(vagaID: UUID) async throws -> ResultadoCandidatura {
        try verificarFalhaGeral()
        if cenario == .vagaPreenchida { throw ErroDaApi(codigo: .posicaoJaPreenchida) }
        if cenario == .inelegivel { throw ErroDaApi(codigo: .inelegivel, detalhes: "turno_sobreposto") }
        guard let vaga = vagas.first(where: { $0.id == vagaID }) else { throw ErroDaApi(codigo: .naoEncontrado) }
        let turnoID = UUID()
        let contato = Contato(
            nome: "Bistrô Ipê",
            telefone: "+5561999990000",
            whatsappURL: URL(string: "https://wa.me/5561999990000")!,
            visivelAte: vaga.periodo.fim.addingTimeInterval(7 * 24 * 60 * 60)
        )
        let turno = Turno(
            id: turnoID,
            posicaoID: UUID(),
            vaga: vaga,
            verificacao: .pendente,
            valorAcordado: vaga.valor,
            contato: contato
        )
        turnos.append(turno)
        return ResultadoCandidatura(
            estado: .confirmada,
            candidaturaID: UUID(),
            posicaoID: turno.posicaoID,
            turnoID: turnoID,
            contato: contato
        )
    }

    public func meusTurnos() async throws -> [Turno] {
        try verificarFalhaGeral()
        return turnos
    }

    public func contatoDoTurno(id: UUID) async throws -> Contato {
        try verificarFalhaGeral()
        guard let contato = turnos.first(where: { $0.id == id })?.contato else { throw ErroDaApi(codigo: .contatoExpirado) }
        return contato
    }

    public func fazerCheckin(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date, chave: UUID) async throws {
        try verificarFalhaGeral()
    }

    public func fazerCheckout(turnoID: UUID, distanciaMetros: Int?, registradoEm: Date, chave: UUID) async throws {
        try verificarFalhaGeral()
    }

    public func avaliar(turnoID: UUID, resposta: Bool, chave: UUID) async throws -> Avaliacao {
        try verificarFalhaGeral()
        return Avaliacao(turnoID: turnoID, resposta: resposta, criadaEm: .now)
    }

    public func configuracaoDoApp() async throws -> ConfiguracaoApp {
        if cenario == .semRede { throw ErroDaApi(codigo: .semRede) }
        let minima = cenario == .contaSuspensa ? "99.0.0" : "0.1.0"
        return ConfiguracaoApp(
            versaoMinimaIOS: minima,
            mensagem: "Atualize o Frila para continuar.",
            urlDaLoja: URL(string: "https://apps.apple.com/app/id6815311991")!
        )
    }

    public func removerDispositivo(tokenFCM: String) async throws { try verificarFalhaGeral() }
    public func sair(tokenFCM: String?) async {}

    private func verificarFalhaGeral() throws {
        if cenario == .semRede { throw ErroDaApi(codigo: .semRede) }
        if cenario == .contaSuspensa { throw ErroDaApi(codigo: .semPermissao, detalhes: "conta_suspensa") }
    }

    private static func fixtures() -> (funcao: Funcao, estabelecimento: Estabelecimento, vaga: Vaga) {
        let funcao = Funcao(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
            nome: "Garçom",
            categoria: "Salão"
        )
        guard let ponto = try? Coordenada(latitude: -15.7942, longitude: -47.8822) else {
            preconditionFailure("Fixture contém coordenada inválida")
        }
        let estabelecimento = Estabelecimento(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
            nome: "Bistrô Ipê",
            documento: "12.345.678/0001-90",
            tipo: .foodService,
            endereco: "Asa Sul, Brasília - DF",
            ponto: ponto
        )
        let inicio = Date.now.addingTimeInterval(24 * 60 * 60)
        guard let periodo = try? Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * 60 * 60)) else {
            preconditionFailure("Fixture contém período inválido")
        }
        let vaga = Vaga(
            id: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!,
            estabelecimento: estabelecimento,
            funcao: funcao,
            periodo: periodo,
            local: estabelecimento.endereco,
            ponto: ponto,
            valor: Dinheiro(centavos: 12000),
            posicoes: 2,
            posicoesAbertas: 2,
            inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Marina",
            modo: .urgencia,
            estado: .publicada
        )
        return (funcao, estabelecimento, vaga)
    }
}
