import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

@MainActor
@Suite("Por que recebo vagas: View Model (#18)")
struct PorQueReceboVagasViewModelTests {
    nonisolated private static let criterios = CriteriosDeNotificacao(
        funcoes: [Funcao(id: UUID(), nome: "Garçom", categoria: "Salão")],
        disponibilidades: [JanelaDeDisponibilidade(diaDaSemana: 5, inicio: try! HoraDoDia("18:00"), fim: try! HoraDoDia("02:00"))],
        distanciaMaximaKm: 15,
        equipesDeConfianca: [],
        notificacoesNoMaximoACadaMin: 30
    )

    nonisolated private static func protocolo() -> Protocolo {
        Protocolo(ocorrenciaID: UUID(), tipo: .revisaoDespacho, criadaEm: Date(), prazoRespostaAte: try! DataCivil("2026-10-16"))
    }

    /// Um view model com critérios prontos e o envio que o teste quiser.
    private static func pronto(pedirRevisao: @escaping @Sendable (String) async throws -> Protocolo) async -> PorQueReceboVagasViewModel {
        let vm = PorQueReceboVagasViewModel(criterios: { criterios }, pedirRevisao: pedirRevisao)
        await vm.carregar()
        return vm
    }

    @Test("Carrega os critérios reais do dublê: função, grade, 15 km, equipe e teto")
    func carregaDoDuble() async throws {
        let api = ApiClienteEmMemoria()
        let vm = PorQueReceboVagasViewModel(api: api)
        #expect(vm.estado == .carregando)

        await vm.carregar()

        let criterios = try #require(vm.criterios)
        #expect(criterios.funcoes.map(\.nome) == ["Garçom"])
        #expect(criterios.disponibilidades.count == 2)
        #expect(criterios.distanciaMaximaKm == 15)
        #expect(criterios.equipesDeConfianca.map(\.nome) == ["Bistrô Ipê"])
        #expect(criterios.notificacoesNoMaximoACadaMin == 30)
        #expect(vm.podeContestar)
    }

    @Test("Sem função, grade nem equipe é o estado vazio; sem perfil profissional também")
    func vazio() async {
        let semNada = CriteriosDeNotificacao(funcoes: [], disponibilidades: [], distanciaMaximaKm: 15, equipesDeConfianca: [], notificacoesNoMaximoACadaMin: 30)
        let vm = PorQueReceboVagasViewModel(criterios: { semNada }, pedirRevisao: { _ in Self.protocolo() })
        await vm.carregar()
        #expect(vm.estado == .vazio)

        let semPerfil = PorQueReceboVagasViewModel(criterios: { throw ErroDaApi(codigo: .naoEncontrado) }, pedirRevisao: { _ in Self.protocolo() })
        await semPerfil.carregar()
        #expect(semPerfil.estado == .vazio)
    }

    @Test("Sem rede e erro têm estado próprio, e recarregar volta ao conteúdo")
    func semRedeEErro() async {
        let vm = PorQueReceboVagasViewModel(criterios: { throw ErroDaApi(codigo: .semRede) }, pedirRevisao: { _ in Self.protocolo() })
        await vm.carregar()
        #expect(vm.estado == .semRede)

        let erro = PorQueReceboVagasViewModel(criterios: { throw ErroDaApi(codigo: .perfilIncompativel) }, pedirRevisao: { _ in Self.protocolo() })
        await erro.carregar()
        #expect(erro.estado == .erro)

        struct Falha: Error {}
        let outro = PorQueReceboVagasViewModel(criterios: { throw Falha() }, pedirRevisao: { _ in Self.protocolo() })
        await outro.carregar()
        #expect(outro.estado == .erro)
    }

    @Test("Contestar com sucesso pelo dublê mostra o protocolo de revisão, fecha o formulário e manda o relato aparado")
    func contestarComSucesso() async throws {
        let api = ApiClienteEmMemoria()
        let vm = PorQueReceboVagasViewModel(api: api)
        await vm.carregar()

        vm.abrirFormulario()
        #expect(vm.mostrarFormulario)
        vm.relato = "  Não recebi a vaga de sexta no Bistrô Ipê.  "
        #expect(vm.relatoValido)

        await vm.contestar()

        let protocolo = try #require(vm.protocolo)
        #expect(protocolo.tipo == .revisaoDespacho)
        #expect(!vm.mostrarFormulario)
        #expect(!vm.podeContestar)
        #expect(vm.mensagemErro == nil)
        #expect(!vm.enviando)
        #expect(await api.relatosDeRevisaoDespacho == ["Não recebi a vaga de sexta no Bistrô Ipê."])

        // Enviado, o botão não reabre o formulário.
        vm.abrirFormulario()
        #expect(!vm.mostrarFormulario)
    }

    @Test("409: fecha o formulário, explica a contestação existente sem inventar protocolo e impede reenvio")
    func contestacaoExistente() async {
        let vm = await Self.pronto { _ in throw ErroDaApi(codigo: .contestacaoJaAberta) }
        vm.abrirFormulario()
        vm.relato = "Não recebi a vaga de sexta à noite."
        await vm.contestar()
        #expect(vm.contestacaoJaAberta)
        #expect(vm.protocolo == nil)
        #expect(vm.mensagemErro == nil)
        #expect(!vm.mostrarFormulario)
        #expect(!vm.podeContestar)
        vm.cancelarFormulario()
        await vm.carregar()
        vm.abrirFormulario()
        #expect(!vm.mostrarFormulario)
        #expect(!vm.podeContestar)
    }

    @Test("Reabrir a folha com o mesmo modelo conserva o protocolo; outro modelo recebe 409 do dublê")
    func reabrirDepoisDeEnviar() async throws {
        let api = ApiClienteEmMemoria()
        let vm = PorQueReceboVagasViewModel(api: api)
        vm.relato = "Não recebi a vaga de sexta à noite."
        await vm.contestar()
        let protocolo = try #require(vm.protocolo)
        await vm.carregar()
        vm.abrirFormulario()
        #expect(vm.protocolo == protocolo)
        #expect(!vm.mostrarFormulario)
        let reaberto = PorQueReceboVagasViewModel(api: api)
        reaberto.relato = vm.relato
        await reaberto.contestar()
        #expect(reaberto.contestacaoJaAberta)
        #expect(!reaberto.podeContestar)
        #expect(await api.relatosDeRevisaoDespacho.count == 1)
    }

    @Test("Relato vazio ou curto é barrado antes de enviar, com a mensagem do campo")
    func relatoInvalidoNaTela() async {
        let vm = await Self.pronto { _ in
            Issue.record("relato inválido não deveria chegar à API")
            return Self.protocolo()
        }
        vm.abrirFormulario()

        vm.relato = "   "
        #expect(!vm.relatoValido)
        await vm.contestar()
        #expect(vm.mensagemErro == TextosPorQueReceboVagas.relatoObrigatorio)

        vm.relato = "curto"
        await vm.contestar()
        #expect(vm.mensagemErro == TextosPorQueReceboVagas.relatoMinimo)

        #expect(vm.protocolo == nil)
    }

    @Test("Cada recusa do contrato tem mensagem própria: campo, conta suspensa, limite, rede", arguments: [
        (ErroDaApi(codigo: .campoObrigatorio, detalhes: "relato"), TextosPorQueReceboVagas.relatoObrigatorio),
        (ErroDaApi(codigo: .campoInvalido, detalhes: "relato"), TextosPorQueReceboVagas.relatoMinimo),
        (ErroDaApi(codigo: .semPermissao, detalhes: "conta_suspensa"), TextosPorQueReceboVagas.contaSuspensa),
        (ErroDaApi(codigo: .contaSuspensa), TextosPorQueReceboVagas.contaSuspensa),
        (ErroDaApi(codigo: .limiteExcedido), TextosPorQueReceboVagas.limiteExcedido),
        (ErroDaApi(codigo: .semRede), TextosPorQueReceboVagas.erroSemRede),
        (ErroDaApi(codigo: .semPermissao), TextosPorQueReceboVagas.erroEnviar),
        (ErroDaApi(codigo: .perfilIncompativel), TextosPorQueReceboVagas.erroEnviar),
        (ErroDaApi(codigo: .desconhecido), TextosPorQueReceboVagas.erroEnviar),
    ])
    func recusas(erro: ErroDaApi, mensagem: String) async {
        let vm = await Self.pronto { _ in throw erro }
        vm.abrirFormulario()
        vm.relato = "Não recebi a vaga de sexta à noite."

        await vm.contestar()

        #expect(vm.mensagemErro == mensagem)
        #expect(vm.protocolo == nil)
        #expect(vm.mostrarFormulario)
        #expect(!vm.enviando)
        #expect(vm.podeContestar)
    }

    @Test("Erro que não é da API vira o erro genérico de envio")
    func erroDesconhecido() async {
        struct Falha: Error {}
        let vm = await Self.pronto { _ in throw Falha() }
        vm.abrirFormulario()
        vm.relato = "Não recebi a vaga de sexta à noite."
        await vm.contestar()
        #expect(vm.mensagemErro == TextosPorQueReceboVagas.erroEnviar)
    }

    @Test("A conta suspensa do dublê vê a mensagem própria ao contestar")
    func contaSuspensaNoDuble() async {
        let vm = PorQueReceboVagasViewModel(api: ApiClienteEmMemoria(cenario: .contaSuspensa))
        await vm.carregar()
        #expect(vm.criterios != nil)
        vm.abrirFormulario()
        vm.relato = "Não recebi a vaga de sexta à noite."
        await vm.contestar()
        #expect(vm.mensagemErro == TextosPorQueReceboVagas.contaSuspensa)
    }

    @Test("Abrir e cancelar o formulário limpa a mensagem de erro")
    func abrirECancelar() async {
        let vm = await Self.pronto { _ in Self.protocolo() }
        vm.abrirFormulario()
        vm.relato = "curto"
        await vm.contestar()
        #expect(vm.mensagemErro != nil)

        vm.cancelarFormulario()
        #expect(vm.mensagemErro == nil)
        #expect(!vm.mostrarFormulario)

        vm.abrirFormulario()
        #expect(vm.mensagemErro == nil)
        #expect(vm.mostrarFormulario)
    }

    @Test("A grade sai como em Funções e horários, com o dia seguinte quando atravessa a meia-noite")
    func descricaoDaJanela() throws {
        let noite = JanelaDeDisponibilidade(diaDaSemana: 5, inicio: try HoraDoDia("18:00"), fim: try HoraDoDia("02:00"))
        #expect(PorQueReceboVagasViewModel.descricao(noite) == "Sexta-feira: 18:00 às 02:00 (dia seguinte)")
        let tarde = JanelaDeDisponibilidade(diaDaSemana: 0, inicio: try HoraDoDia("12:00"), fim: try HoraDoDia("16:00"))
        #expect(PorQueReceboVagasViewModel.descricao(tarde) == "Domingo: 12:00 às 16:00")
    }

    @Test("A distância sai sem casas quando inteira e com vírgula quando não")
    func descricaoDaDistancia() {
        #expect(PorQueReceboVagasViewModel.descricaoDistancia(15) == "Até 15 km do seu ponto base.")
        #expect(PorQueReceboVagasViewModel.descricaoDistancia(7.5) == "Até 7,5 km do seu ponto base.")
    }
}
