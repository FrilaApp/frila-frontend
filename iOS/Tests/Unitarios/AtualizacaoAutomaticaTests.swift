import Foundation
@testable import FrilaApresentacao
@testable import FrilaDados
import FrilaDominio
import Testing

private let inicio = Date(timeIntervalSince1970: 1_800_000_000)

private final class RelogioAjustavel: Relogio, @unchecked Sendable {
    private let trava = NSLock()
    private var _agora: Date
    init(_ agora: Date) { _agora = agora }
    var agora: Date { trava.withLock { _agora } }
    func avancar(_ segundos: TimeInterval) { trava.withLock { _agora = _agora.addingTimeInterval(segundos) } }
}

/// Liga e desliga a falha da fonte entre uma leitura e outra.
private final class Interruptor: @unchecked Sendable {
    private let trava = NSLock()
    private var _falhar = false
    var falhar: Bool {
        get { trava.withLock { _falhar } }
        set { trava.withLock { _falhar = newValue } }
    }
}

/// Segura a recarga até o teste liberar, para outro pedido chegar com ela em voo.
@MainActor
private final class RecargaSegura {
    private(set) var vezes = 0
    private var liberar: CheckedContinuation<Void, Never>?
    private var chegou: CheckedContinuation<Void, Never>?

    func recarregar() async {
        vezes += 1
        chegou?.resume()
        chegou = nil
        await withCheckedContinuation { liberar = $0 }
    }

    func esperarChegada() async {
        if liberar != nil { return }
        await withCheckedContinuation { chegou = $0 }
    }

    func soltar() {
        liberar?.resume()
        liberar = nil
    }
}

@MainActor
private final class Contagem {
    var vezes = 0
}

/// A pausa do intervalo curto do push, sem esperar de verdade: anota e avança o relógio.
private final class Esperas: @unchecked Sendable {
    private let trava = NSLock()
    private var _pedidas: [TimeInterval] = []
    private let relogio: RelogioAjustavel
    init(relogio: RelogioAjustavel) { self.relogio = relogio }
    var pedidas: [TimeInterval] { trava.withLock { _pedidas } }

    func esperar(_ segundos: TimeInterval) async {
        trava.withLock { _pedidas.append(segundos) }
        relogio.avancar(segundos)
    }
}

@Suite("Atualização automática das listas: a regra")
struct ControleDaAtualizacaoTests {
    private func controleComSessao() -> ControleDaAtualizacao {
        var controle = ControleDaAtualizacao(intervaloMinimo: 30)
        controle.mudarSessao(ativa: true)
        return controle
    }

    @Test("Sem sessão nenhum pedido passa, e o aviso de push não conta")
    func semSessao() {
        var controle = ControleDaAtualizacao(intervaloMinimo: 30)
        do { let passou = controle.pedir(.vagas, em: inicio); #expect(passou == .ignorar) }
        controle.avisoChegou()
        #expect(controle.avisos == 0)
        #expect(!controle.emVoo(.vagas))
    }

    @Test("Intervalo mínimo entre recargas da mesma lista, contado do fim da anterior")
    func intervaloMinimo() {
        var controle = controleComSessao()
        do { let passou = controle.pedir(.vagas, em: inicio); #expect(passou == .recarregar) }
        do { let passou = controle.concluir(.vagas, em: inicio.addingTimeInterval(2)); #expect(passou == .ignorar) }
        do { let passou = controle.pedir(.vagas, em: inicio.addingTimeInterval(20)); #expect(passou == .ignorar) }
        do { let passou = controle.pedir(.vagas, em: inicio.addingTimeInterval(31)); #expect(passou == .ignorar) }
        do { let passou = controle.pedir(.vagas, em: inicio.addingTimeInterval(32)); #expect(passou == .recarregar) }
    }

    @Test("A carga da própria tela conta como recarga para o intervalo")
    func cargaDaTela() {
        var controle = controleComSessao()
        controle.registrarCarga(.meusTurnos, em: inicio)
        do { let passou = controle.pedir(.meusTurnos, em: inicio.addingTimeInterval(10)); #expect(passou == .ignorar) }
        do { let passou = controle.pedir(.meusTurnos, em: inicio.addingTimeInterval(30)); #expect(passou == .recarregar) }
    }

    @Test("Com uma recarga em voo, o segundo pedido da mesma lista não abre outra")
    func naoReentrante() {
        var controle = controleComSessao()
        do { let passou = controle.pedir(.minhasVagas, em: inicio); #expect(passou == .recarregar) }
        #expect(controle.emVoo(.minhasVagas))
        do { let passou = controle.pedir(.minhasVagas, em: inicio.addingTimeInterval(60)); #expect(passou == .ignorar) }
        do { let passou = controle.concluir(.minhasVagas, em: inicio.addingTimeInterval(61)); #expect(passou == .ignorar) }
        #expect(!controle.emVoo(.minhasVagas))
    }

    @Test("Cada lista tem a própria vez e o próprio intervalo")
    func listasIndependentes() {
        var controle = controleComSessao()
        do { let passou = controle.pedir(.vagas, em: inicio); #expect(passou == .recarregar) }
        do { let passou = controle.pedir(.minhasCandidaturas, em: inicio); #expect(passou == .recarregar) }
        _ = controle.concluir(.vagas, em: inicio)
        do { let passou = controle.pedir(.meusTurnos, em: inicio.addingTimeInterval(1)); #expect(passou == .recarregar) }
    }

    @Test("O aviso de push passa por cima do intervalo, uma vez por aviso")
    func avisoFuraIntervalo() {
        var controle = controleComSessao()
        controle.registrarCarga(.vagas, em: inicio)
        controle.avisoChegou()
        do { let passou = controle.pedir(.vagas, em: inicio.addingTimeInterval(5)); #expect(passou == .recarregar) }
        do { let passou = controle.concluir(.vagas, em: inicio.addingTimeInterval(6)); #expect(passou == .ignorar) }
        // O mesmo aviso, já atendido, não fura de novo.
        do { let passou = controle.pedir(.vagas, em: inicio.addingTimeInterval(7)); #expect(passou == .ignorar) }
    }

    @Test("Aviso que chega com a recarga em voo faz a lista ser lida mais uma vez, e só uma, depois dos 3 s")
    func avisoDuranteVoo() {
        var controle = controleComSessao()
        do { let passou = controle.pedir(.vagas, em: inicio); #expect(passou == .recarregar) }
        controle.avisoChegou()
        do { let passou = controle.pedir(.vagas, em: inicio.addingTimeInterval(1)); #expect(passou == .ignorar) }
        controle.avisoChegou()
        do { let passou = controle.pedir(.vagas, em: inicio.addingTimeInterval(1)); #expect(passou == .ignorar) }
        // A repetição não sai colada na recarga que acabou: espera o intervalo curto do push.
        do { let passou = controle.concluir(.vagas, em: inicio.addingTimeInterval(2)); #expect(passou == .esperar(3)) }
        #expect(controle.emVoo(.vagas))
        do { let passou = controle.retomar(.vagas, em: inicio.addingTimeInterval(5)); #expect(passou == .recarregar) }
        do { let passou = controle.concluir(.vagas, em: inicio.addingTimeInterval(6)); #expect(passou == .ignorar) }
        #expect(!controle.emVoo(.vagas))
    }

    @Test("Rajada de pushes logo depois de uma recarga: no máximo uma releitura a cada 3 s")
    func rajadaDePushes() {
        var controle = controleComSessao()
        do { let passou = controle.pedir(.vagas, em: inicio); #expect(passou == .recarregar) }
        do { let passou = controle.concluir(.vagas, em: inicio); #expect(passou == .ignorar) }

        // Primeiro push, 1 s depois: passa por cima dos 30 s, mas espera o que falta dos 3 s.
        controle.avisoChegou()
        do { let passou = controle.pedir(.vagas, em: inicio.addingTimeInterval(1)); #expect(passou == .esperar(2)) }
        #expect(controle.emVoo(.vagas))
        // Mais pushes durante a espera: nenhum abre outra recarga nem outra espera.
        for _ in 0..<4 {
            controle.avisoChegou()
            let passou = controle.pedir(.vagas, em: inicio.addingTimeInterval(2))
            #expect(passou == .ignorar)
        }
        // Retomar cedo demais espera o resto.
        do { let passou = controle.retomar(.vagas, em: inicio.addingTimeInterval(2.5)); #expect(passou == .esperar(0.5)) }
        // A releitura que sai atende todos os avisos da rajada: ao concluir, nada de repetição.
        do { let passou = controle.retomar(.vagas, em: inicio.addingTimeInterval(3)); #expect(passou == .recarregar) }
        do { let passou = controle.concluir(.vagas, em: inicio.addingTimeInterval(4)); #expect(passou == .ignorar) }
        #expect(!controle.emVoo(.vagas))
        // Um push novo 1 s depois espera de novo os 3 s; não relê colado.
        controle.avisoChegou()
        do { let passou = controle.pedir(.vagas, em: inicio.addingTimeInterval(5)); #expect(passou == .esperar(2)) }
    }

    @Test("Saída da tela durante a espera do push libera a vez")
    func desistirNaEspera() {
        var controle = controleComSessao()
        controle.registrarCarga(.minhasVagas, em: inicio)
        controle.avisoChegou()
        do { let passou = controle.pedir(.minhasVagas, em: inicio.addingTimeInterval(1)); #expect(passou == .esperar(2)) }
        controle.desistir(.minhasVagas)
        #expect(!controle.emVoo(.minhasVagas))
        // O aviso continua sem atender: na volta da tela, relê.
        do { let passou = controle.pedir(.minhasVagas, em: inicio.addingTimeInterval(2)); #expect(passou == .recarregar) }
    }

    @Test("A lista escondida atende o aviso quando volta a pedir, mesmo dentro do intervalo")
    func avisoComListaEscondida() {
        var controle = controleComSessao()
        controle.registrarCarga(.meusTurnos, em: inicio)
        controle.avisoChegou()
        // Nenhum pedido enquanto escondida; ao reaparecer, 10 s depois:
        do { let passou = controle.pedir(.meusTurnos, em: inicio.addingTimeInterval(10)); #expect(passou == .recarregar) }
    }

    @Test("Troca de conta esquece os intervalos da anterior; sair corta os pedidos")
    func trocaDeSessao() {
        var controle = controleComSessao()
        do { let passou = controle.pedir(.vagas, em: inicio); #expect(passou == .recarregar) }
        _ = controle.concluir(.vagas, em: inicio)
        controle.mudarSessao(ativa: false)
        do { let passou = controle.pedir(.vagas, em: inicio.addingTimeInterval(100)); #expect(passou == .ignorar) }
        controle.mudarSessao(ativa: true)
        do { let passou = controle.pedir(.vagas, em: inicio.addingTimeInterval(1)); #expect(passou == .recarregar) }
    }

    @Test("Recarga cancelada libera a vez e não conta para o intervalo")
    func desistir() {
        var controle = controleComSessao()
        do { let passou = controle.pedir(.equipeDeConfianca, em: inicio); #expect(passou == .recarregar) }
        controle.desistir(.equipeDeConfianca)
        #expect(!controle.emVoo(.equipeDeConfianca))
        do { let passou = controle.pedir(.equipeDeConfianca, em: inicio.addingTimeInterval(1)); #expect(passou == .recarregar) }
    }
}

@MainActor
@Suite("Atualização automática das listas: o ponto central")
struct AtualizacaoAutomaticaTests {
    @Test("Sem conta na tela, a recarga não é chamada")
    func soComSessao() async {
        let atualizacao = AtualizacaoAutomatica(relogio: RelogioAjustavel(inicio))
        var vezes = 0
        await atualizacao.pedir(.vagas) { vezes += 1 }
        #expect(vezes == 0)

        atualizacao.mudarSessao(ativa: true)
        await atualizacao.pedir(.vagas) { vezes += 1 }
        #expect(vezes == 1)
    }

    @Test("Dois pedidos ao mesmo tempo (volta do segundo plano e reaparição) fazem uma recarga só")
    func umaPorVez() async {
        let relogio = RelogioAjustavel(inicio)
        let atualizacao = AtualizacaoAutomatica(relogio: relogio)
        atualizacao.mudarSessao(ativa: true)
        let recarga = RecargaSegura()

        let primeira = Task { await atualizacao.pedir(.vagas, recarregar: recarga.recarregar) }
        await recarga.esperarChegada()
        await atualizacao.pedir(.vagas, recarregar: recarga.recarregar)
        #expect(recarga.vezes == 1)

        recarga.soltar()
        await primeira.value
        #expect(recarga.vezes == 1)
        #expect(!atualizacao.controle.emVoo(.vagas))

        // Dentro do intervalo, nada; depois dele, de novo.
        var depois = 0
        relogio.avancar(10)
        await atualizacao.pedir(.vagas) { depois += 1 }
        #expect(depois == 0)
        relogio.avancar(30)
        await atualizacao.pedir(.vagas) { depois += 1 }
        #expect(depois == 1)
    }

    @Test("Push com a recarga em voo: a lista é lida de novo quando ela volta, depois dos 3 s")
    func pushDuranteRecarga() async {
        let relogio = RelogioAjustavel(inicio)
        let esperas = Esperas(relogio: relogio)
        let atualizacao = AtualizacaoAutomatica(relogio: relogio, esperar: esperas.esperar)
        atualizacao.mudarSessao(ativa: true)
        let recarga = RecargaSegura()

        let primeira = Task { await atualizacao.pedir(.minhasVagas, recarregar: recarga.recarregar) }
        await recarga.esperarChegada()
        atualizacao.avisoChegou()
        #expect(atualizacao.avisos == 1)
        await atualizacao.pedir(.minhasVagas, recarregar: recarga.recarregar)

        recarga.soltar()
        await recarga.esperarChegada()
        #expect(recarga.vezes == 2)
        recarga.soltar()
        await primeira.value
        #expect(recarga.vezes == 2)
        #expect(esperas.pedidas == [3])
        #expect(!atualizacao.controle.emVoo(.minhasVagas))
    }

    @Test("Cinco pushes logo depois da carga da tela: uma espera e uma releitura só")
    func rajadaNoPontoCentral() async {
        let relogio = RelogioAjustavel(inicio)
        let esperas = Esperas(relogio: relogio)
        let atualizacao = AtualizacaoAutomatica(relogio: relogio, esperar: esperas.esperar)
        atualizacao.mudarSessao(ativa: true)
        atualizacao.registrarCarga(.vagas)
        relogio.avancar(1)

        let contagem = Contagem()
        var pedidos: [Task<Void, Never>] = []
        for _ in 0..<5 {
            atualizacao.avisoChegou()
            pedidos.append(Task { await atualizacao.pedir(.vagas) { contagem.vezes += 1 } })
        }
        for pedido in pedidos { await pedido.value }
        #expect(contagem.vezes == 1)
        #expect(esperas.pedidas == [2])
        #expect(!atualizacao.controle.emVoo(.vagas))
    }

    @Test("Recarga cancelada (a tela saiu) não segura a próxima")
    func canceladaNaoPrende() async {
        let atualizacao = AtualizacaoAutomatica(relogio: RelogioAjustavel(inicio))
        atualizacao.mudarSessao(ativa: true)
        let recarga = RecargaSegura()

        let tarefa = Task { await atualizacao.pedir(.meusTurnos, recarregar: recarga.recarregar) }
        await recarga.esperarChegada()
        tarefa.cancel()
        recarga.soltar()
        await tarefa.value
        #expect(!atualizacao.controle.emVoo(.meusTurnos))

        var depois = 0
        await atualizacao.pedir(.meusTurnos) { depois += 1 }
        #expect(depois == 1)
    }
}

@MainActor
@Suite("Atualização automática das listas: a releitura em silêncio de cada tela")
struct ReleituraEmSilencioTests {
    private func vagasDoDuble() async throws -> [VagaNaLista] {
        try await ApiClienteEmMemoria().vagasAbertas(.todas)
    }

    private func outraVaga(como vaga: VagaNaLista) -> VagaNaLista {
        VagaNaLista(
            id: UUID(), funcao: vaga.funcao, estabelecimento: vaga.estabelecimento, periodo: vaga.periodo,
            local: vaga.local, regiaoAdministrativa: vaga.regiaoAdministrativa, distanciaKm: vaga.distanciaKm,
            valor: vaga.valor, posicoesAbertas: vaga.posicoesAbertas, inclusos: vaga.inclusos, modo: vaga.modo
        )
    }

    @Test("Vagas: a falha deixa a lista na tela, e o sucesso a troca sem passar por carregando")
    func vagas() async throws {
        let vagas = try await vagasDoDuble()
        let interruptor = Interruptor()
        let fonte: [VagaNaLista] = vagas
        let vm = FeedVagasViewModel(
            buscarVagas: { _ in
                if interruptor.falhar { throw ErroDaApi(codigo: .semRede) }
                return fonte
            },
            buscarFuncoes: { [] }
        )

        // Antes da primeira carga, a releitura automática não faz nada: quem carrega é a tela.
        await vm.atualizarEmSilencio()
        #expect(vm.estado == .ociosa)

        await vm.carregar()
        #expect(vm.estado == .carregada(vagas))

        interruptor.falhar = true
        await vm.atualizarEmSilencio()
        #expect(vm.estado == .carregada(vagas))

        // A lista continua paginável depois da falha silenciosa.
        interruptor.falhar = false
        await vm.atualizarEmSilencio()
        #expect(vm.estado == .carregada(vagas))
    }

    @Test("Vagas: com mais de uma página na tela, não relê (a rolagem não se perde)")
    func vagasComVariasPaginas() async throws {
        let primeira = try #require(try await vagasDoDuble().first)
        let vagas = [primeira, outraVaga(como: primeira)]
        let leituras = Interruptor()
        let vm = FeedVagasViewModel(
            buscarVagas: { filtro in
                if leituras.falhar { Issue.record("Não devia reler com duas páginas na tela") }
                return filtro.deslocamento == 0 ? [vagas[0]] : [vagas[1]]
            },
            buscarFuncoes: { [] },
            tamanhoDaPagina: 1
        )
        await vm.carregar()
        await vm.carregarMais()
        guard case let .carregada(lista) = vm.estado else { Issue.record("lista não carregou"); return }
        #expect(lista.count == 2)

        leituras.falhar = true
        await vm.atualizarEmSilencio()
        #expect(vm.estado == .carregada(lista))
    }

    @Test("Meus turnos: a falha deixa os turnos na tela")
    func meusTurnos() async throws {
        let api = ApiClienteEmMemoria()
        let turnos = try await api.meusTurnos()
        let repositorio = RepositorioAlternavel(turnos: turnos)
        let vm = MeusTurnosViewModel(repositorio: repositorio)

        await vm.atualizarEmSilencio()
        #expect(vm.estado == .ociosa)

        await vm.carregar()
        let carregado = vm.estado
        #expect(carregado == .carregada(turnos: turnos, origem: .rede))

        repositorio.interruptor.falhar = true
        await vm.atualizarEmSilencio()
        #expect(vm.estado == carregado)
    }

    @Test("Candidaturas: a falha silenciosa não marca a lista como desatualizada")
    func candidaturas() async {
        let interruptor = Interruptor()
        let vm = MinhasCandidaturasViewModel(buscar: {
            if interruptor.falhar { throw ErroDaApi(codigo: .semRede) }
            return []
        })
        await vm.carregar()
        #expect(vm.estado == .carregadas([]))

        interruptor.falhar = true
        await vm.atualizarEmSilencio()
        #expect(vm.estado == .carregadas([]))
        #expect(!vm.desatualizada)

        // O puxar para atualizar continua avisando.
        await vm.atualizar()
        #expect(vm.desatualizada)
    }

    @Test("Minhas vagas: a falha silenciosa não mostra erro nem tira as vagas")
    func minhasVagas() async throws {
        let api = ApiQueFalhaNoPainel()
        let casa = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        let vm = MinhasVagasViewModel(api: api, estabelecimentoID: casa, nomeEstabelecimento: "Bistrô Ipê")
        await vm.carregar()
        let vagas = vm.vagas.map(\.vaga.id)
        #expect(vm.erro == nil)

        api.interruptor.falhar = true
        await vm.atualizarEmSilencio()
        #expect(vm.erro == nil)
        #expect(vm.vagas.map(\.vaga.id) == vagas)
        #expect(!vm.carregando)
    }

    @Test("Equipe de confiança: a falha deixa a equipe na tela, sem carregando nem erro")
    func equipe() async {
        let casa = UUID()
        let ana = PerfilPublico(id: UUID(), tipo: .profissional, nome: "Ana", funcoes: ["Garçom"],
                                reputacao: Reputacao(positivas: 1, total: 1, taxaComparecimento: 1, turnosConsiderados: 1, turnosRealizados: 1))
        let interruptor = Interruptor()
        let vm = EquipeDeConfiancaViewModel(
            estabelecimentoID: casa,
            listar: { _ in
                if interruptor.falhar { throw ErroDaApi(codigo: .semRede) }
                return [ana]
            },
            remover: { $0 }
        )
        // Antes da primeira carga (estado inicial "carregando"), não relê.
        await vm.atualizarEmSilencio()
        #expect(vm.estado == .carregando)

        await vm.carregar()
        #expect(vm.estado == .conteudo([ana]))

        interruptor.falhar = true
        await vm.atualizarEmSilencio()
        #expect(vm.estado == .conteudo([ana]))
        #expect(vm.mensagemErro == nil)
    }
}

private final class RepositorioAlternavel: TurnoRepositorio, @unchecked Sendable {
    let interruptor = Interruptor()
    private let turnos: [Turno]
    init(turnos: [Turno]) { self.turnos = turnos }

    func meusTurnos() async throws -> [Turno] {
        if interruptor.falhar { throw ErroDaApi(codigo: .desconhecido) }
        return turnos
    }

    func ler() async throws -> LeituraDeTurnos {
        LeituraDeTurnos(turnos: try await meusTurnos(), origem: .rede)
    }
}

private final class ApiQueFalhaNoPainel: ApiClienteEncaminhador, @unchecked Sendable {
    let interruptor = Interruptor()

    override func painelEstabelecimento(id: UUID, periodo: Periodo) async throws -> Painel {
        if interruptor.falhar { throw ErroDaApi(codigo: .semRede) }
        return try await super.painelEstabelecimento(id: id, periodo: periodo)
    }
}
