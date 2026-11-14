import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import SwiftUI
import Testing

@MainActor
@Suite("Minhas vagas do contratante (#107)")
struct MinhasVagasTests {
    private let agora = Date(timeIntervalSince1970: 1_800_000_000)
    private let estabelecimentoID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    private var calendario: Calendar {
        var valor = Calendar(identifier: .gregorian)
        valor.timeZone = TimeZone(secondsFromGMT: 0)!
        return valor
    }

    private func estabelecimento() throws -> Estabelecimento {
        try Estabelecimento(
            id: estabelecimentoID, nome: "Bistrô", tipo: .foodService, endereco: "Rua das Flores, 10",
            regiaoAdministrativa: "Plano Piloto",
            ponto: Coordenada(latitude: -15.78, longitude: -47.93)
        )
    }

    private func vaga(
        id: String,
        inicioEm deslocamentoInicio: TimeInterval,
        duracao: TimeInterval = 3_600,
        estado: EstadoVaga = .publicada,
        alerta: Bool = false,
        posicoes: [PosicaoNoPainel] = []
    ) throws -> VagaNoPainel {
        let inicio = agora.addingTimeInterval(deslocamentoInicio)
        let periodo = try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(duracao))
        let resumo = VagaResumo(
            id: UUID(uuidString: id)!, funcao: "Garçom", local: "Rua das Flores, 10",
            regiaoAdministrativa: "Plano Piloto",
            periodo: periodo, valor: Dinheiro(centavos: 14_000)
        )
        return VagaNoPainel(vaga: resumo, modo: .urgencia, estado: estado, oculta: false, alertaVagaVazia: alerta, candidatosPendentes: 0, posicoes: posicoes)
    }

    private func viewModel(_ vagas: [VagaNoPainel], nova: UUID? = nil) throws -> MinhasVagasViewModel {
        let estabelecimento = try estabelecimento()
        let painel = Painel(estabelecimentoID: estabelecimentoID, vagas: vagas, checkinsPendentes: [])
        return MinhasVagasViewModel(
            estabelecimento: estabelecimento,
            vagaRecemPublicadaID: nova,
            agora: { agora },
            calendario: calendario
        ) { painel }
    }

    private func posicao(_ estado: EstadoPosicao) -> PosicaoNoPainel {
        PosicaoNoPainel(id: UUID(), estado: estado, profissional: nil, turnoID: nil, verificacao: nil, emAtraso: false)
    }

    /// E2E do Prod, 08/11/2026 (vaga e415fe59): o fechamento do backend marca como `encerrada` toda vaga
    /// cujo turno terminou, e as posições trabalhadas como `cumprida`. O detalhe dizia "Encerrada, ninguém
    /// aceitou" numa vaga preenchida e trabalhada.
    @Test("Vaga encerrada com a posição cumprida diz 'Vaga encerrada' e '1 de 1 posição preenchida', e não 'ninguém aceitou'")
    func encerradaComPosicaoCumprida() throws {
        let trabalhada = try vaga(id: "73000000-0000-0000-0000-000000000021", inicioEm: -7_200, estado: .encerrada,
                                  posicoes: [posicao(.cumprida)])
        let estado = TextosMinhasVagas.estadoDoDetalhe(trabalhada)
        #expect(estado.0 == "Vaga encerrada")
        #expect(estado.1 == "1 de 1 posição preenchida")
    }

    @Test("Vaga encerrada com parte das posições cumpridas conta as preenchidas no plural")
    func encerradaComParteCumprida() throws {
        let uma = try vaga(id: "73000000-0000-0000-0000-000000000022", inicioEm: -7_200, estado: .encerrada,
                           posicoes: [posicao(.cumprida), posicao(.cancelada)])
        #expect(TextosMinhasVagas.estadoDoDetalhe(uma).0 == "Vaga encerrada")
        #expect(TextosMinhasVagas.estadoDoDetalhe(uma).1 == "1 de 2 posições preenchidas")
        let duas = try vaga(id: "73000000-0000-0000-0000-000000000023", inicioEm: -7_200, estado: .encerrada,
                            posicoes: [posicao(.cumprida), posicao(.cumprida), posicao(.cancelada)])
        #expect(TextosMinhasVagas.estadoDoDetalhe(duas).1 == "2 de 3 posições preenchidas")
        let confirmadaAindaNaoFechada = try vaga(id: "73000000-0000-0000-0000-000000000026", inicioEm: -7_200, estado: .encerrada,
                                                posicoes: [posicao(.confirmada), posicao(.confirmada)])
        #expect(TextosMinhasVagas.estadoDoDetalhe(confirmadaAindaNaoFechada).1 == "2 de 2 posições preenchidas")
    }

    @Test("Vaga encerrada sem nenhuma posição confirmada ou cumprida (0 de N) continua 'Encerrada, ninguém aceitou'")
    func encerradaSemNinguem() throws {
        for posicoes in [[posicao(.cancelada)], [posicao(.cancelada), posicao(.cancelada)], []] {
            let vazia = try vaga(id: "73000000-0000-0000-0000-000000000024", inicioEm: -7_200, estado: .encerrada,
                                 posicoes: posicoes)
            let estado = TextosMinhasVagas.estadoDoDetalhe(vazia)
            #expect(estado.0 == "Encerrada, ninguém aceitou")
            #expect(estado.1 == nil)
        }
    }

    @Test("Os outros estados do detalhe não mudam")
    func outrosEstadosDoDetalhe() throws {
        let preenchida = try vaga(id: "73000000-0000-0000-0000-000000000027", inicioEm: 3_600, estado: .preenchida,
                                  posicoes: [posicao(.confirmada)])
        #expect(TextosMinhasVagas.estadoDoDetalhe(preenchida).0 == "Vaga preenchida")
        #expect(TextosMinhasVagas.estadoDoDetalhe(preenchida).1 == "Todas as posições foram confirmadas.")
        let aberta = try vaga(id: "73000000-0000-0000-0000-000000000025", inicioEm: 3_600,
                              posicoes: [posicao(.confirmada), posicao(.aberta)])
        #expect(TextosMinhasVagas.estadoDoDetalhe(aberta).0 == "1 de 2 posições confirmada")
        #expect(TextosMinhasVagas.estadoDoDetalhe(aberta).1 == "As posições abertas continuam na lista até o início do turno.")
        let ninguem = try vaga(id: "73000000-0000-0000-0000-000000000028", inicioEm: 3_600, posicoes: [posicao(.aberta)])
        #expect(TextosMinhasVagas.estadoDoDetalhe(ninguem).0 == TextosMinhasVagas.abertaNinguemAceitou)
        let cancelada = try vaga(id: "73000000-0000-0000-0000-000000000029", inicioEm: -7_200, estado: .cancelada,
                                 posicoes: [posicao(.cumprida)])
        #expect(TextosMinhasVagas.estadoDoDetalhe(cancelada).0 == TextosMinhasVagas.vagaCancelada)
    }

    @Test("Republicação no detalhe usa o relógio recebido pelo painel")
    func podeRepublicarComRelogioInjetado() throws {
        let futura = try vaga(id: "73000000-0000-0000-0000-000000000011", inicioEm: 3600)
        let terminada = try vaga(id: "73000000-0000-0000-0000-000000000012", inicioEm: -3600)
        let cancelada = try vaga(id: "73000000-0000-0000-0000-000000000013", inicioEm: 3600, estado: .cancelada)
        let vm = try viewModel([futura, terminada, cancelada])
        #expect(!vm.podeRepublicar(futura))
        #expect(vm.podeRepublicar(terminada))
        #expect(vm.podeRepublicar(cancelada))
    }

    @Test("Separa vagas em alerta, hoje, próximas e encerradas")
    func classificaQuatroSecoes() async throws {
        let alerta = try vaga(id: "73000000-0000-0000-0000-000000000011", inicioEm: 2 * 3_600, alerta: true)
        let hoje = try vaga(id: "73000000-0000-0000-0000-000000000012", inicioEm: 4 * 3_600)
        let proxima = try vaga(id: "73000000-0000-0000-0000-000000000013", inicioEm: 2 * 86_400)
        let encerrada = try vaga(id: "73000000-0000-0000-0000-000000000014", inicioEm: -86_400, estado: .encerrada)
        let vm = try viewModel([proxima, encerrada, hoje, alerta])

        await vm.carregar()

        #expect(vm.erro == nil)
        #expect(vm.vagas(na: .emAlerta).map(\.vaga.id) == [alerta.vaga.id])
        #expect(vm.vagas(na: .hoje).map(\.vaga.id) == [hoje.vaga.id])
        #expect(vm.vagas(na: .proximas).map(\.vaga.id) == [proxima.vaga.id])
        #expect(vm.vagas(na: .encerradas).map(\.vaga.id) == [encerrada.vaga.id])
        #expect(vm.tempoAteInicio(alerta) == "2 h 0 min")
    }

    @Test("Usa o dia civil de São Paulo mesmo que o calendário do aparelho esteja em UTC")
    func hojeSegueFusoDeSaoPaulo() async throws {
        let formatador = ISO8601DateFormatter()
        formatador.timeZone = TimeZone(secondsFromGMT: 0)
        let agoraEmUTC = try #require(formatador.date(from: "2026-02-02T01:30:00Z")) // 22:30 em São Paulo
        let inicioEmUTC = try #require(formatador.date(from: "2026-02-02T02:00:00Z")) // 23:00 em São Paulo
        var calendarioDoAparelho = Calendar(identifier: .gregorian)
        calendarioDoAparelho.timeZone = TimeZone(secondsFromGMT: 0)!
        #expect(calendarioDoAparelho.timeZone.secondsFromGMT() == 0)
        #expect(MinhasVagasViewModel.calendarioSaoPaulo.timeZone.identifier == "America/Sao_Paulo")

        let estabelecimento = try estabelecimento()
        let periodo = try Periodo(inicio: inicioEmUTC, fim: inicioEmUTC.addingTimeInterval(3_600))
        let resumo = VagaResumo(
            id: UUID(uuidString: "73000000-0000-0000-0000-000000000015")!, funcao: "Garçom",
            local: "Rua das Flores, 10", regiaoAdministrativa: "Plano Piloto",
            periodo: periodo, valor: Dinheiro(centavos: 14_000)
        )
        let vaga = VagaNoPainel(vaga: resumo, modo: .urgencia, estado: .publicada, oculta: false, alertaVagaVazia: false, candidatosPendentes: 0, posicoes: [])
        let painel = Painel(estabelecimentoID: estabelecimento.id, vagas: [vaga], checkinsPendentes: [])
        let vm = MinhasVagasViewModel(estabelecimento: estabelecimento, agora: { agoraEmUTC }) { painel }

        await vm.carregar()

        #expect(vm.vagas(na: .hoje).map(\.vaga.id) == [vaga.vaga.id])
        #expect(vm.vagas(na: .proximas).isEmpty)
    }

    @Test("A vaga publicada nesta sessão aparece antes das outras na sua seção")
    func promovePublicacaoRecente() async throws {
        let primeira = try vaga(id: "73000000-0000-0000-0000-000000000021", inicioEm: 2 * 86_400)
        let nova = try vaga(id: "73000000-0000-0000-0000-000000000022", inicioEm: 3 * 86_400)
        let vm = try viewModel([nova, primeira], nova: nova.vaga.id)

        await vm.carregar()

        #expect(vm.vagas(na: .proximas).map(\.vaga.id) == [nova.vaga.id, primeira.vaga.id])
    }

    @Test("Conta posições confirmadas e cumpridas, preservando abertas")
    func contaConfirmadas() async throws {
        let perfil = PerfilPublico(
            id: UUID(), tipo: .profissional, nome: "Joana Silva", funcoes: ["Garçom"],
            reputacao: Reputacao(positivas: 8, total: 10, taxaComparecimento: 0.9, turnosConsiderados: 20, turnosRealizados: 18)
        )
        let positions = [
            PosicaoNoPainel(id: UUID(), estado: .confirmada, profissional: perfil, turnoID: UUID(), verificacao: .verificado, emAtraso: false),
            PosicaoNoPainel(id: UUID(), estado: .cumprida, profissional: perfil, turnoID: UUID(), verificacao: .verificado, emAtraso: false),
            PosicaoNoPainel(id: UUID(), estado: .aberta, profissional: nil, turnoID: nil, verificacao: nil, emAtraso: false),
        ]
        let vagaConfirmada = try vaga(id: "73000000-0000-0000-0000-000000000031", inicioEm: 4 * 3_600, posicoes: positions)
        let vm = try viewModel([vagaConfirmada])
        await vm.carregar()

        #expect(vm.confirmadas(vagaConfirmada) == 2)
        #expect(vagaConfirmada.posicoes.count == 3)
        #expect(vagaConfirmada.posicoes[0].profissional?.reputacao.taxaComparecimento == 0.9)
    }

    @Test("Dublê retorna alerta_vaga_vazia e deixa visível o tempo até o início")
    func alertaDoDuble() async throws {
        let api = ApiClienteEmMemoria(cenario: .alertaVagaVazia, relogio: RelogioFixo(agora: agora))
        let vm = MinhasVagasViewModel(
            api: api, estabelecimento: try estabelecimento(), agora: { agora }, calendario: calendario
        )

        await vm.carregar()

        let alerta = try #require(vm.vagas(na: .emAlerta).first)
        #expect(vm.tempoAteInicio(alerta) == "2 h 0 min")
    }

    @Test("Painel vazio não inventa vagas e pode apresentar a orientação de primeira publicação")
    func painelVazio() async throws {
        let api = ApiClienteEmMemoria(cenario: .painelVazio, relogio: RelogioFixo(agora: agora))
        let vm = MinhasVagasViewModel(
            api: api, estabelecimento: try estabelecimento(), agora: { agora }, calendario: calendario
        )

        await vm.carregar()

        #expect(vm.erro == nil)
        #expect(vm.vagas.isEmpty)
        #expect(SecaoMinhasVagas.allCases.allSatisfy { vm.vagas(na: $0).isEmpty })
    }

    @Test("Dublê entrega perfil público e contato da posição confirmada")
    func confirmadoTemPerfilPublicoEContatoLiberado() async throws {
        let api = ApiClienteEmMemoria(cenario: .painelContratante, relogio: RelogioFixo(agora: agora))
        let estabelecimento = try estabelecimento()
        let periodo = try Periodo(inicio: agora.addingTimeInterval(-86_400), fim: agora.addingTimeInterval(365 * 86_400))
        let painel = try await api.painelEstabelecimento(id: estabelecimento.id, periodo: periodo)
        let posicao = try #require(painel.vagas.first?.posicoes.first(where: { $0.estado == .confirmada }))
        let perfil = try #require(posicao.profissional)
        let turnoID = try #require(posicao.turnoID)
        let contato = try await api.contatoDoTurno(id: turnoID)

        #expect(painel.vagas.first?.oculta == false)
        #expect(posicao.aCaminhoEm == nil)
        #expect(perfil.tipo == .profissional)
        #expect(perfil.nome == "Ana Cunha")
        #expect(perfil.reputacao.taxaComparecimento != nil)
        #expect(contato.nome == perfil.nome)
        #expect(contato.estaVisivel(em: agora))
    }

    @Test("Publicar e abrir o painel no mesmo dublê mostra a vaga nova no topo")
    func vagaPublicadaApareceNaHora() async throws {
        let api = ApiClienteEmMemoria(relogio: RelogioFixo(agora: agora))
        let periodo = try Periodo(inicio: agora.addingTimeInterval(2 * 86_400), fim: agora.addingTimeInterval(2 * 86_400 + 4 * 3_600))
        let funcoes = try await api.funcoes()
        let funcao = try #require(funcoes.first)
        let publicacao = PublicacaoVaga(
            estabelecimentoID: estabelecimentoID,
            funcaoID: funcao.id,
            periodo: periodo,
            local: "Rua das Flores, 10",
            regiaoAdministrativa: "Plano Piloto",
            ponto: try Coordenada(latitude: -15.78, longitude: -47.93),
            valor: Dinheiro(centavos: 14_000),
            posicoes: 2,
            inclusos: Inclusos(refeicao: false, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Renata no balcão",
            modo: .urgencia,
            alertaAntecedenciaMinutos: 180,
            chave: UUID()
        )
        let publicada = try await api.publicarVaga(publicacao)
        let vm = MinhasVagasViewModel(
            api: api, estabelecimento: try estabelecimento(), vagaRecemPublicadaID: publicada.vagaID,
            agora: { agora }, calendario: calendario
        )

        await vm.carregar()

        #expect(vm.vagas(na: .proximas).first?.vaga.id == publicada.vagaID)
    }

    @Test("Painel de um ano com 500 vagas: as seções somam todas, ordenadas, e a tela as lista em LazyVStack")
    func painelGrande() async throws {
        var vagas: [VagaNoPainel] = []
        for indice in 0..<500 {
            // Metade já encerrada no passado, metade espalhada pelos próximos 300 dias.
            let deslocamento: TimeInterval = indice.isMultiple(of: 2) ? -Double(indice + 1) * 86_400 : Double(indice) * 86_400 * 0.6 + 7_200
            vagas.append(try vaga(id: String(format: "73000000-0000-0000-0000-%012d", indice + 100), inicioEm: deslocamento))
        }
        let vm = try viewModel(vagas.shuffled())
        await vm.carregar()

        let porSecao = SecaoMinhasVagas.allCases.map { vm.vagas(na: $0) }
        #expect(porSecao.map(\.count).reduce(0, +) == 500)
        for secao in porSecao {
            #expect(secao == secao.sorted { $0.vaga.periodo.inicio < $1.vaga.periodo.inicio })
        }

        let tela = TelaMinhasVagas(viewModel: vm, api: ApiClienteEmMemoria())
        #expect(String(reflecting: type(of: tela.body)).contains("LazyVStack"), "as seções do painel precisam ser lazy")
    }

    @Test("Classifica vagas encerradas, canceladas ou com período terminado antes de agora")
    func classificarEncerradas() throws {
        let vm = try viewModel([])
        let encerrada = try vaga(id: "73000000-0000-0000-0000-000000000001", inicioEm: 3_600, estado: .encerrada)
        let cancelada = try vaga(id: "73000000-0000-0000-0000-000000000002", inicioEm: 3_600, estado: .cancelada)
        let passada = try vaga(id: "73000000-0000-0000-0000-000000000003", inicioEm: -7_200, duracao: 3_600)

        #expect(vm.classificar(encerrada) == .encerradas)
        #expect(vm.classificar(cancelada) == .encerradas)
        #expect(vm.classificar(passada) == .encerradas)
    }

    @Test("Classifica vaga com alerta de vaga vazia ativo na seção em alerta")
    func classificarEmAlerta() throws {
        let vm = try viewModel([])
        let alerta = try vaga(id: "73000000-0000-0000-0000-000000000004", inicioEm: 3_600, alerta: true)

        #expect(vm.classificar(alerta) == .emAlerta)
    }

    @Test("Classifica vagas com início ou término no mesmo dia civil na seção hoje")
    func classificarHoje() throws {
        let vm = try viewModel([])
        let inicioHoje = try vaga(id: "73000000-0000-0000-0000-000000000005", inicioEm: 7_200)
        let terminoHoje = try vaga(id: "73000000-0000-0000-0000-000000000006", inicioEm: -1_800, duracao: 3_600)

        #expect(vm.classificar(inicioHoje) == .hoje)
        #expect(vm.classificar(terminoHoje) == .hoje)
    }

    @Test("Classifica vagas futuras fora do dia civil atual na seção próximas")
    func classificarProximas() throws {
        let vm = try viewModel([])
        let proxima = try vaga(id: "73000000-0000-0000-0000-000000000007", inicioEm: 172_800)

        #expect(vm.classificar(proxima) == .proximas)
    }

    /// Puxar para atualizar cancela a tarefa da leitura: o URLError.cancelled chega como erro genérico e
    /// a tela mostrava "Não foi possível carregar suas vagas" com a lista boa embaixo.
    @Test("Leitura cancelada no meio (puxar para atualizar) não vira erro e a lista fica como estava")
    func leituraCanceladaNaoMostraErro() async throws {
        let estabelecimento = try estabelecimento()
        let conhecida = try vaga(id: "73000000-0000-0000-0000-000000000031", inicioEm: 7_200)
        let painel = Painel(estabelecimentoID: estabelecimentoID, vagas: [conhecida], checkinsPendentes: [])
        let leituras = ContadorDeLeituras()
        let portao = PortaoDeLeitura()
        let viewModel = MinhasVagasViewModel(estabelecimento: estabelecimento, agora: { agora }, calendario: calendario) {
            guard await leituras.somar() > 1 else { return painel }
            await portao.esperar()
            throw ErroDaApi(codigo: .desconhecido)
        }
        await viewModel.carregar()
        #expect(viewModel.vagas.count == 1)

        let leitura = Task { await viewModel.carregar() }
        while await leituras.valor < 2 { await Task.yield() }
        leitura.cancel()
        await portao.abrir()
        await leitura.value

        #expect(viewModel.erro == nil)
        #expect(viewModel.vagas.count == 1)
        #expect(!viewModel.carregando)
    }

    @Test("Leitura que falha de verdade, sem cancelamento, continua mostrando o erro")
    func leituraQueFalhaContinuaMostrandoErro() async throws {
        let estabelecimento = try estabelecimento()
        let viewModel = MinhasVagasViewModel(estabelecimento: estabelecimento, agora: { agora }, calendario: calendario) {
            throw ErroDaApi(codigo: .desconhecido)
        }
        await viewModel.carregar()
        #expect(viewModel.erro == TextosMinhasVagas.falha)
    }
}

private actor ContadorDeLeituras {
    private(set) var valor = 0
    func somar() -> Int {
        valor += 1
        return valor
    }
}

/// Segura a resposta da API até o teste liberar: a leitura fica em voo enquanto a tarefa é cancelada.
private actor PortaoDeLeitura {
    private var aberto = false
    private var esperando: [CheckedContinuation<Void, Never>] = []
    func esperar() async {
        guard !aberto else { return }
        await withCheckedContinuation { esperando.append($0) }
    }
    func abrir() {
        aberto = true
        esperando.forEach { $0.resume() }
        esperando = []
    }
}
