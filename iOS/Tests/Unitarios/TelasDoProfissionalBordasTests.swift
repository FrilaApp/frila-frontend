import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private struct ErroQualquer: Error {}

private struct RelogioFixo: Relogio {
    let agora: Date
}

private final class ApiDoPerfil: ApiClienteEncaminhador, @unchecked Sendable {
    var erroAoCarregar: Error?
    var erroAoSalvar: Error?
    override func funcoes() async throws -> [Funcao] {
        if let erroAoCarregar { throw erroAoCarregar }
        return try await super.funcoes()
    }
    override func meuPerfilProfissional() async throws -> PerfilProfissional {
        if let erroAoCarregar { throw erroAoCarregar }
        return try await super.meuPerfilProfissional()
    }
    override func criarPerfilProfissional(_ dados: DadosPerfilProfissional) async throws -> PerfilProfissional {
        if let erroAoSalvar { throw erroAoSalvar }
        return try await super.criarPerfilProfissional(dados)
    }
}

private final class ApiDeExportacao: ApiClienteEncaminhador, @unchecked Sendable {
    var resultado: Result<ResultadoExportacaoTurnos, Error> = .success(.arquivo(Data("a;b\n".utf8)))
    override func exportarTurnos(_ pedido: PedidoExportacaoTurnos) async throws -> ResultadoExportacaoTurnos {
        try resultado.get()
    }
}

/// Bordas das telas do profissional que as suítes vizinhas não exercitam: recomeçar a candidatura
/// depois de uma falha, a edição do perfil (carregar, janelas, erros) e a folha do histórico.
@MainActor
@Suite("Telas do profissional: candidatura, perfil e histórico nas bordas")
struct TelasDoProfissionalBordasTests {
    private let agora = Date(timeIntervalSince1970: 1_791_000_000)

    // MARK: Candidatura

    @Test("Erro que não é da API vira falha desconhecida com o nome do tipo, e recomeçar volta ao ocioso")
    func candidaturaComErroDesconhecidoERecomecar() async throws {
        let api = ApiClienteEmMemoria()
        let aberta = try #require(try await api.vagasAbertas(.todas).first)
        let vaga = try await api.detalheDaVaga(id: aberta.id)
        let vm = CandidaturaViewModel(vaga: vaga, candidatar: { _ in throw ErroQualquer() })

        await vm.candidatar()

        guard case let .concluida(.falha(erro)) = vm.estado else {
            Issue.record("esperava falha, veio \(vm.estado)")
            return
        }
        #expect(erro.codigo == .desconhecido)
        #expect(erro.codigoOriginal.contains("ErroQualquer"))

        vm.recomecar()
        #expect(vm.estado == .ocioso)
        #expect(!vm.enviando)
    }

    // MARK: Perfil profissional

    @Test("Carregar meu perfil entra em edição com as funções, o ponto base e as janelas gravadas")
    func carregarMeuPerfil() async throws {
        let api = ApiDoPerfil()
        let vm = PerfilProfissionalViewModel(api: api)
        let gravado = try await api.meuPerfilProfissional()

        await vm.carregarMeuPerfil()

        #expect(vm.modo == .edicao)
        #expect(vm.funcoesSelecionadas == Set(gravado.funcoes.map(\.id)))
        #expect(vm.pontoBase == gravado.pontoBase)
        #expect(vm.disponibilidades == gravado.disponibilidades)
        #expect(vm.descricaoPontoBase == TextosDoProfissional.Perfil.pontoBaseSalvo)
        #expect(vm.mensagemDeErro == nil)
    }

    @Test("Falha ao carregar: erro da API mostra a mensagem dele, erro desconhecido a de carregar")
    func falhaAoCarregar() async {
        let api = ApiDoPerfil()
        api.erroAoCarregar = ErroDaApi(codigo: .semRede)
        let semRede = PerfilProfissionalViewModel(api: api)
        await semRede.carregar()
        #expect(semRede.mensagemDeErro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .semRede)))
        #expect(!semRede.carregando)

        api.erroAoCarregar = ErroQualquer()
        let desconhecido = PerfilProfissionalViewModel(api: api)
        await desconhecido.carregar()
        #expect(desconhecido.mensagemDeErro == TextosDoProfissional.Perfil.erroCarregar)
    }

    @Test("Remover janela por índice e por valor; janela igual não entra duas vezes e a lista fica ordenada")
    func janelas() throws {
        let vm = PerfilProfissionalViewModel(api: ApiDoPerfil())
        let sabado = JanelaDeDisponibilidade(diaDaSemana: 6, inicio: try HoraDoDia(hora: 18, minuto: 0), fim: try HoraDoDia(hora: 23, minuto: 0))
        let sextaCedo = JanelaDeDisponibilidade(diaDaSemana: 5, inicio: try HoraDoDia(hora: 8, minuto: 0), fim: try HoraDoDia(hora: 12, minuto: 0))
        let sextaTarde = JanelaDeDisponibilidade(diaDaSemana: 5, inicio: try HoraDoDia(hora: 14, minuto: 0), fim: try HoraDoDia(hora: 18, minuto: 0))

        vm.adicionarJanela(diaDaSemana: 6, inicio: sabado.inicio, fim: sabado.fim)
        vm.adicionarJanela(diaDaSemana: 5, inicio: sextaTarde.inicio, fim: sextaTarde.fim)
        vm.adicionarJanela(diaDaSemana: 5, inicio: sextaCedo.inicio, fim: sextaCedo.fim)
        vm.adicionarJanela(diaDaSemana: 5, inicio: sextaCedo.inicio, fim: sextaCedo.fim)
        #expect(vm.disponibilidades == [sextaCedo, sextaTarde, sabado])

        vm.removerJanela(em: IndexSet(integer: 0))
        #expect(vm.disponibilidades == [sextaTarde, sabado])

        vm.removerJanela(sabado)
        #expect(vm.disponibilidades == [sextaTarde])

        vm.adicionarJanela(diaDaSemana: 7, inicio: sabado.inicio, fim: sabado.fim)
        #expect(vm.disponibilidades == [sextaTarde], "dia fora de 0...6 não entra")
    }

    @Test("Falha ao salvar: erro da API mostra a mensagem dele, erro desconhecido a de salvar; nada fica como salvo")
    func falhaAoSalvar() async throws {
        let api = ApiDoPerfil()
        func modelo() async throws -> PerfilProfissionalViewModel {
            let vm = PerfilProfissionalViewModel(api: api)
            await vm.carregar()
            vm.alternarFuncao(try #require(vm.funcoesDisponiveis.first?.id))
            vm.definirPontoBase(try Coordenada(latitude: -15.8267, longitude: -47.9218))
            return vm
        }

        api.erroAoSalvar = ErroDaApi(codigo: .semRede)
        let semRede = try await modelo()
        #expect(await semRede.salvar() == false)
        #expect(semRede.mensagemDeErro == MensagemDoErroAPI.texto(ErroDaApi(codigo: .semRede)))
        #expect(semRede.perfilSalvo == nil)
        #expect(!semRede.sucesso)

        api.erroAoSalvar = ErroQualquer()
        let desconhecido = try await modelo()
        #expect(await desconhecido.salvar() == false)
        #expect(desconhecido.mensagemDeErro == TextosDoProfissional.Perfil.erroSalvar)
        #expect(!desconhecido.salvando)
    }

    // MARK: Histórico de turnos

    @Test("401 e 403 na exportação não são repetíveis; outro erro da API e erro desconhecido são")
    func errosDaExportacao() async throws {
        let diretorio = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: diretorio, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: diretorio) }
        let api = ApiDeExportacao()
        func exportar() async -> HistoricoDeTurnosViewModel {
            let vm = HistoricoDeTurnosViewModel(api: api, relogio: RelogioFixo(agora: agora), diretorioTemporario: diretorio)
            await vm.exportar()
            return vm
        }

        api.resultado = .failure(ErroDaApi(codigo: .naoAutenticado))
        #expect(await exportar().estado == .erro(mensagem: MensagemDoErroAPI.texto(ErroDaApi(codigo: .naoAutenticado)), repetivel: false))

        api.resultado = .failure(ErroDaApi(codigo: .semPermissao))
        #expect(await exportar().estado == .erro(mensagem: MensagemDoErroAPI.texto(ErroDaApi(codigo: .semPermissao)), repetivel: false))

        api.resultado = .failure(ErroDaApi(codigo: .semRede))
        let semRede = await exportar()
        #expect(semRede.estado == .erro(mensagem: MensagemDoErroAPI.texto(ErroDaApi(codigo: .semRede)), repetivel: true))
        #expect(semRede.estado.ehErro)

        api.resultado = .failure(ErroQualquer())
        #expect(await exportar().estado == .erro(mensagem: MensagemDoErroAPI.texto(ErroDaApi(codigo: .desconhecido)), repetivel: true))
        #expect(!HistoricoDeTurnosViewModel.Estado.ocioso.ehErro)
    }

    @Test("Atividade de compartilhar concluída apaga o arquivo; cancelada, mantém até a folha fechar")
    func atividadeConcluidaApagaOArquivo() async throws {
        let diretorio = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: diretorio, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: diretorio) }
        let vm = HistoricoDeTurnosViewModel(api: ApiDeExportacao(), relogio: RelogioFixo(agora: agora), diretorioTemporario: diretorio)
        #expect(vm.agora == agora)

        await vm.exportar()
        let url = try #require(vm.arquivoParaCompartilhar)
        #expect(FileManager.default.fileExists(atPath: url.path))

        vm.atividadeCompartilhamentoConcluida(concluida: false)
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(vm.mostrarFolhaCompartilhamento)

        vm.atividadeCompartilhamentoConcluida(concluida: true)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(vm.arquivoParaCompartilhar == nil)
        #expect(!vm.mostrarFolhaCompartilhamento)
    }
}
