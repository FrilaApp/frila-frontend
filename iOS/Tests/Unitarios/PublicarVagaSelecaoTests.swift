import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private actor FilaDeTeste: FilaDeAcoes {
    func recusar(_ acao: AcaoPendente, codigo: CodigoErroAPI) async throws { try await remover(id: acao.id) }
    func recusadas() -> [AcaoRecusada] { [] }

    private var itens: [AcaoPendente] = []
    func enfileirar(_ acao: AcaoPendente) { itens.removeAll { $0.id == acao.id }; itens.append(acao) }
    func pendentes() -> [AcaoPendente] { itens }
    func remover(id: UUID) { itens.removeAll { $0.id == id } }
    func limpar() { itens.removeAll() }
}

private struct RelogioFixo: Relogio {
    let agora: Date
}

/// Critério 3 do cartão #10: modo seleção para vaga com menos de 24 horas é recusado. O contrato
/// (0.2.24) aceita só o início a **mais** de 24 horas, e responde `422 selecao_sem_antecedencia`
/// com 24 horas ou menos.
@MainActor
@Suite("Publicar vaga no modo seleção (#10)")
struct PublicarVagaSelecaoTests {
    private static let hora: TimeInterval = 3_600
    private let agora = Date(timeIntervalSince1970: 1_800_000_000)
    private let funcao = Funcao(id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!, nome: "Garçom", categoria: "Salão")

    private func estabelecimento() throws -> Estabelecimento {
        Estabelecimento(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!, nome: "Bistrô Ipê", tipo: .foodService,
            endereco: "CLS 405, Asa Sul, Brasília - DF", regiaoAdministrativa: "Plano Piloto",
            ponto: try Coordenada(latitude: -15.8121, longitude: -47.8997)
        )
    }

    /// O formulário preenchido, com o relógio do aparelho em `agora` e o início daqui a `horas`.
    private func modelo(
        fila: FilaDeTeste = FilaDeTeste(), inicioEmHoras horas: Double, modo: ModoPreenchimento,
        publicar: @escaping @Sendable (PublicacaoVaga) async throws -> VagaPublicada
    ) throws -> PublicarVagaViewModel {
        let fixo = agora
        let vm = PublicarVagaViewModel(estabelecimento: try estabelecimento(), funcoes: [funcao], fila: fila, agora: { fixo }, publicar: publicar)
        vm.funcaoID = funcao.id
        vm.inicio = agora.addingTimeInterval(horas * Self.hora)
        vm.fim = vm.inicio.addingTimeInterval(4 * Self.hora)
        vm.valorTexto = "12000"
        vm.posicoesTexto = "1"
        vm.responsavelLocal = "Marina"
        vm.modo = modo
        return vm
    }

    @Test("O formulário abre no modo urgência")
    func padrao() throws {
        let vm = try modelo(inicioEmHoras: 3, modo: .urgencia) { _ in throw ErroDaApi(codigo: .desconhecido) }
        #expect(PublicarVagaViewModel(estabelecimento: try estabelecimento(), fila: FilaDeTeste()) { _ in throw ErroDaApi(codigo: .desconhecido) }.modo == .urgencia)
        #expect(vm.validar())
    }

    @Test("Seleção com início a 24 horas ou menos é recusada no aparelho, no campo do início, sem chamar a API", arguments: [3.0, 23.99, 24.0])
    func semAntecedencia(horas: Double) async throws {
        let api = ApiClienteEmMemoria(relogio: RelogioFixo(agora: agora))
        let fila = FilaDeTeste()
        let vm = try modelo(fila: fila, inicioEmHoras: horas, modo: .selecao) { try await api.publicarVaga($0) }

        await vm.publicar()

        #expect(vm.erros == [.inicio: TextosRepublicarVaga.selecaoSemAntecedencia])
        #expect(vm.resultado == nil && vm.publicacaoPendente == nil)
        #expect(await api.chamadasAPublicarVaga == 0)
        #expect(await fila.pendentes().isEmpty)
    }

    @Test("A mesma vaga, no modo urgência, é publicada: a regra das 24 horas é só da seleção")
    func urgenciaNaoTemARegra() async throws {
        let api = ApiClienteEmMemoria(relogio: RelogioFixo(agora: agora))
        let vm = try modelo(inicioEmHoras: 3, modo: .urgencia) { try await api.publicarVaga($0) }

        await vm.publicar()

        #expect(vm.resultado != nil && vm.erros.isEmpty)
        #expect(await api.publicacoesRecebidas.last?.modo == .urgencia)
    }

    @Test("Seleção com início a mais de 24 horas é publicada com modo selecao, e a casa a vê no painel esperando candidatos")
    func comAntecedencia() async throws {
        let api = ApiClienteEmMemoria(relogio: RelogioFixo(agora: agora))
        let vm = try modelo(inicioEmHoras: 24.02, modo: .selecao) { try await api.publicarVaga($0) }

        await vm.publicar()

        let vagaID = try #require(vm.resultado?.vagaID)
        #expect(vm.erros.isEmpty && vm.mensagemErro == nil)
        #expect(await api.publicacoesRecebidas.last?.modo == .selecao)
        let casa = try estabelecimento()
        let painel = try await api.painelEstabelecimento(
            id: casa.id, periodo: try Periodo(inicio: agora, fim: agora.addingTimeInterval(72 * Self.hora))
        )
        let vaga = try #require(painel.vagas.first { $0.vaga.id == vagaID })
        #expect(vaga.modo == .selecao && vaga.estado == .publicada && vaga.candidatosPendentes == 0)
    }

    @Test("Passado o início, o erro é o do horário, e não o das 24 horas")
    func inicioNoPassado() throws {
        let vm = try modelo(inicioEmHoras: -1, modo: .selecao) { _ in throw ErroDaApi(codigo: .desconhecido) }
        #expect(!vm.validar())
        #expect(vm.erros[.inicio] != nil && vm.erros[.inicio] != TextosRepublicarVaga.selecaoSemAntecedencia)
    }

    @Test("O 422 selecao_sem_antecedencia do servidor aponta o início, destrava o formulário e não deixa publicação na fila")
    func recusaDoServidor() async throws {
        // O relógio do servidor está duas horas à frente do aparelho: para ele faltam 23 h, e não 25.
        let api = ApiClienteEmMemoria(relogio: RelogioFixo(agora: agora.addingTimeInterval(2 * Self.hora)))
        let fila = FilaDeTeste()
        let vm = try modelo(fila: fila, inicioEmHoras: 25, modo: .selecao) { try await api.publicarVaga($0) }

        await vm.publicar()

        #expect(await api.chamadasAPublicarVaga == 1)
        #expect(vm.resultado == nil)
        #expect(vm.erros[.inicio] == TextosRepublicarVaga.selecaoSemAntecedencia)
        #expect(vm.mensagemErro == TextosRepublicarVaga.selecaoSemAntecedencia)
        // Recusa definitiva: repetir a mesma chave não mudaria a resposta. A pessoa corrige e envia outra.
        #expect(vm.publicacaoPendente == nil && !vm.camposBloqueados)
        #expect(await fila.pendentes().isEmpty)
        #expect(await api.vagasCriadas == 0)

        // Com a data corrigida, a nova tentativa sai com outra chave e é publicada.
        vm.inicio = agora.addingTimeInterval(30 * Self.hora)
        vm.fim = vm.inicio.addingTimeInterval(4 * Self.hora)
        await vm.publicar()
        #expect(vm.resultado != nil && vm.erros.isEmpty)
        #expect(Set(await api.chavesPublicacaoRecebidas).count == 2)
        #expect(await api.vagasCriadas == 1)
    }

    @Test("A opção Seleção só é oferecida com o início a mais de 24 horas (MS-RF01)", arguments: [(3.0, false), (24.0, false), (24.02, true), (48.0, true)])
    func selecaoDisponivel(horas: Double, disponivel: Bool) throws {
        let vm = try modelo(inicioEmHoras: horas, modo: .urgencia) { _ in throw ErroDaApi(codigo: .desconhecido) }
        #expect(vm.selecaoDisponivel == disponivel)
    }

    @Test("Se o início muda para 24 horas ou menos com a seleção escolhida, o modo volta a urgência")
    func modoVoltaAUrgencia() throws {
        let vm = try modelo(inicioEmHoras: 48, modo: .selecao) { _ in throw ErroDaApi(codigo: .desconhecido) }
        vm.ajustarModoAoInicio()
        #expect(vm.modo == .selecao)

        vm.inicio = agora.addingTimeInterval(3 * Self.hora)
        vm.ajustarModoAoInicio()
        #expect(vm.modo == .urgencia && !vm.selecaoDisponivel && vm.prazoDeEscolha == nil)
        #expect(vm.validar(), "em urgência a vaga de daqui a 3 horas é válida")
    }

    @Test("O prazo de escolha é 24 horas antes do início, só no modo seleção; com menos de 12 horas de janela o formulário avisa (D2)")
    func prazoDeEscolha() throws {
        let longa = try modelo(inicioEmHoras: 48, modo: .selecao) { _ in throw ErroDaApi(codigo: .desconhecido) }
        #expect(longa.prazoDeEscolha == agora.addingTimeInterval(24 * Self.hora))
        #expect(!longa.janelaDeEscolhaCurta)

        let curta = try modelo(inicioEmHoras: 30, modo: .selecao) { _ in throw ErroDaApi(codigo: .desconhecido) }
        #expect(curta.prazoDeEscolha == agora.addingTimeInterval(6 * Self.hora))
        #expect(curta.janelaDeEscolhaCurta)

        let urgencia = try modelo(inicioEmHoras: 48, modo: .urgencia) { _ in throw ErroDaApi(codigo: .desconhecido) }
        #expect(urgencia.prazoDeEscolha == nil && !urgencia.janelaDeEscolhaCurta)
    }

    @Test("Servidor que ainda recusa o modo seleção (campo_invalido em modo) aponta o campo do modo")
    func modoRecusadoPeloServidor() async throws {
        let fila = FilaDeTeste()
        let vm = try modelo(fila: fila, inicioEmHoras: 48, modo: .selecao) { _ in
            throw ErroDaApi(codigo: .campoInvalido, detalhes: "modo")
        }

        await vm.publicar()

        #expect(vm.erros[.modo] != nil && vm.erros[.modo] == vm.mensagemErro)
        #expect(vm.publicacaoPendente == nil)
        #expect(await fila.pendentes().isEmpty)
    }
}
