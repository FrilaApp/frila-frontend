import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import SwiftUI
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

// MARK: - Dado extremo vindo do servidor (robustez antes do TestFlight)

/// Textos que o servidor pode mandar e que o dublê não tem: relato de 2.000 caracteres, nome com
/// emoji composto (ZWJ) e com escrita da direita para a esquerda, nome vazio. Cada cartão é
/// renderizado de verdade (`ImageRenderer`): o teste pega o que derruba o layout, não só o modelo.
private enum DadoExtremo {
    static let longo = String(repeating: "Relato longo do turno, com acento, ç e emoji 🧑‍🍳. ", count: 40) // > 2.000 caracteres
    static let emojiERTL = "🧑🏽‍🍳👩🏿‍🍳 مطعم الأصيل · בית קפה · Bistrô Ipê 🇧🇷"
    static let vazio = ""
    static let casos = [longo, emojiERTL, vazio]
}

@Suite("Cartões com dado extremo do servidor: texto longo, emoji, RTL e vazio") @MainActor
struct CartoesComDadoExtremoTests {
    private func renderiza(_ view: some View) -> Bool {
        let renderizador = ImageRenderer(content: view.frame(width: 390))
        renderizador.scale = 1
        return renderizador.uiImage != nil
    }

    @Test("Cartão de vaga renderiza com função, local e nome do estabelecimento extremos", arguments: DadoExtremo.casos)
    func cartaoDeVaga(texto: String) async throws {
        let base = try #require(try await ApiClienteEmMemoria().vagasAbertas(.todas).first)
        let vaga = VagaNaLista(
            id: base.id,
            funcao: Funcao(id: base.funcao.id, nome: texto, categoria: texto),
            estabelecimento: PerfilPublico(id: base.estabelecimento.id, tipo: .estabelecimento, nome: texto, funcoes: [texto],
                                           reputacao: Reputacao(positivas: 7, total: 3, taxaComparecimento: -1, turnosConsiderados: 1, turnosRealizados: 9)),
            periodo: base.periodo, local: texto, regiaoAdministrativa: texto, distanciaKm: 12345.678,
            valor: Dinheiro(centavos: 999_999_999_99), posicoesAbertas: 200, inclusos: base.inclusos, modo: base.modo
        )
        #expect(renderiza(CartaoVaga(vaga)))
        #expect(!CartaoVaga(vaga).rotuloDeAcessibilidade.isEmpty)
    }

    @Test("Cartão de meu turno e cartão de candidatura renderizam com textos extremos", arguments: DadoExtremo.casos)
    func cartoesDeTurnoECandidatura(texto: String) throws {
        let inicio = Date(timeIntervalSince1970: 1_791_000_000)
        let vaga = VagaResumo(id: UUID(), funcao: texto, local: texto, regiaoAdministrativa: texto,
                              periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(6 * 3600)), valor: Dinheiro(centavos: 1))
        let contraparte = PerfilPublico(id: UUID(), tipo: .estabelecimento, nome: texto, funcoes: [],
                                        reputacao: Reputacao(positivas: 0, total: 0, taxaComparecimento: nil, turnosConsiderados: 0, turnosRealizados: 0))
        let whatsapp = try #require(URL(string: "https://wa.me/5561999990000"))
        let turno = Turno(
            id: UUID(), posicaoID: UUID(), vaga: vaga, contraparte: contraparte, contatoVisivelAte: inicio.addingTimeInterval(7 * 86_400),
            verificacao: .pendente, valorAcordado: Dinheiro(centavos: 1), podeAvaliar: true,
            contato: Contato(nome: texto, telefone: texto, whatsappURL: whatsapp, visivelAte: inicio.addingTimeInterval(7 * 86_400)),
            estado: .cancelada, cancelamento: CancelamentoDoTurno(causa: .outro, falta: true, canceladaEm: inicio)
        )
        #expect(renderiza(CartaoMeuTurno(turno: turno)))
        let candidatura = Candidatura(id: UUID(), vaga: vaga, estado: .aceita, criadaEm: inicio, turnoID: turno.id)
        #expect(renderiza(CartaoDaCandidatura(candidatura: candidatura, turno: turno)))
    }

    @Test("Selo de reputação e aviso renderizam com números incoerentes e texto de 2.000 caracteres")
    func seloEAviso() {
        #expect(renderiza(SeloReputacao(Reputacao(positivas: 7, total: 3, taxaComparecimento: 2.5, turnosConsiderados: -1, turnosRealizados: Int.max))))
        #expect(renderiza(SeloReputacao(Reputacao(positivas: Int.max, total: Int.max, taxaComparecimento: .nan, turnosConsiderados: 1, turnosRealizados: 1))))
        #expect(renderiza(AvisoFrila(verbatim: DadoExtremo.longo, tom: .erro)))
        #expect(renderiza(AvisoFrila(verbatim: DadoExtremo.emojiERTL, tom: .alerta)))
    }

    @Test("Formatador aguenta valor e distância extremos e instante distante")
    func formatador() {
        let formatador = FormatadorFrila()
        #expect(!formatador.dinheiro(Dinheiro(centavos: Int.max)).isEmpty)
        #expect(!formatador.distancia(.infinity).isEmpty)
        #expect(!formatador.distancia(.nan).isEmpty)
        #expect(!formatador.dataEHora(.distantFuture).isEmpty)
        #expect(!formatador.hora(.distantPast).isEmpty)
    }
}
