import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

/// Relógio que o teste avança: o atraso e a tolerância dependem do instante.
private final class RelogioDeTeste: Relogio, @unchecked Sendable {
    private let trava = NSLock()
    private var _agora: Date
    init(_ agora: Date) { _agora = agora }
    var agora: Date { trava.withLock { _agora } }
    func avancar(para instante: Date) { trava.withLock { _agora = instante } }
}

private actor Contador {
    private(set) var valor = 0
    /// Soma um e devolve o total, numa passada só: é o número de ordem da chamada.
    @discardableResult
    func somar() -> Int {
        valor += 1
        return valor
    }
}

/// Segura uma resposta até o teste liberar: é como uma leitura lenta chega depois de uma ação.
private actor Portao {
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

private let hora: TimeInterval = 3_600
private let minuto: TimeInterval = 60
private let agoraDoTeste = Date(timeIntervalSince1970: 1_800_000_000)

/// O dublê com uma vaga de quatro horas publicada pela casa e um turno confirmado nela, e o view
/// model lendo o painel dessa casa.
@MainActor
private struct Cena {
    let api: ApiClienteEmMemoria
    let relogio: RelogioDeTeste
    let viewModel: AcompanhamentoViewModel
    let mudancas: Contador
    let casaID: UUID
    let vagaID: UUID
    let turnoID: UUID
    let posicaoID: UUID
    let inicio: Date

    var fim: Date { inicio.addingTimeInterval(4 * hora) }

    static func montar(emHoras horas: Double = 2) async throws -> Cena {
        let relogio = RelogioDeTeste(agoraDoTeste)
        let api = ApiClienteEmMemoria(cenario: .contratante, relogio: relogio)
        let casa = try #require(try await api.meusEstabelecimentos().first)
        let funcao = try #require(try await api.funcoes().first)
        let inicio = agoraDoTeste.addingTimeInterval(horas * hora)
        let vagaID = try await api.publicarVaga(PublicacaoVaga(
            estabelecimentoID: casa.id, funcaoID: funcao.id,
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * hora)),
            local: "CLS 405, Asa Sul, Brasília - DF", regiaoAdministrativa: "Plano Piloto",
            ponto: try Coordenada(latitude: -15.8121, longitude: -47.8997), valor: Dinheiro(centavos: 12000),
            posicoes: 1, inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Marina", chave: UUID()
        )).vagaID
        let candidatura = try await api.candidatar(vagaID: vagaID)
        let mudancas = Contador()
        let viewModel = AcompanhamentoViewModel(
            api: api, estabelecimentoID: casa.id, agora: { relogio.agora }, aoMudar: { await mudancas.somar() }
        )
        return Cena(
            api: api, relogio: relogio, viewModel: viewModel, mudancas: mudancas, casaID: casa.id, vagaID: vagaID,
            turnoID: try #require(candidatura.turnoID), posicaoID: try #require(candidatura.posicaoID), inicio: inicio
        )
    }

    /// O turno como o view model o lê agora.
    func turno() throws -> TurnoAcompanhado {
        try #require(viewModel.turno(turnoID: turnoID))
    }

    /// Check-in sem localização no início do turno: manual, esperando a confirmação da casa.
    func checkinManual() async throws {
        relogio.avancar(para: inicio)
        _ = try await api.fazerCheckin(turnoID: turnoID, distanciaMetros: nil, registradoEm: inicio)
    }

    /// A posição como o servidor (o dublê) a guarda agora, fora do view model.
    func estadoNoServidor() async throws -> EstadoPosicao {
        let periodo = try Periodo(inicio: agoraDoTeste.addingTimeInterval(-hora), fim: agoraDoTeste.addingTimeInterval(120 * hora))
        let painel = try await api.painelEstabelecimento(id: casaID, periodo: periodo)
        return try #require(painel.vagas.flatMap(\.posicoes).first { $0.id == posicaoID }).estado
    }

    func carregarAos(_ minutos: Double) async {
        relogio.avancar(para: inicio.addingTimeInterval(minutos * minuto))
        await viewModel.carregar()
    }
}

/// Um painel montado à mão, para os casos em que a resposta da API é o que se quer controlar.
private enum PainelDeTeste {
    static let casa = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    static let turnoID = UUID(uuidString: "60000000-0000-0000-0000-000000000001")!
    static let posicaoID = UUID(uuidString: "50000000-0000-0000-0000-000000000001")!
    static let ana = PerfilPublico(
        id: UUID(uuidString: "80000000-0000-0000-0000-000000000001")!, tipo: .profissional, nome: "Ana Cunha",
        reputacao: Reputacao(positivas: 7, total: 7, taxaComparecimento: 1, turnosConsiderados: 7, turnosRealizados: 7)
    )

    static func vaga(
        id: UUID = UUID(), inicioEm deslocamento: TimeInterval = -20 * minuto, alerta: Bool = false, posicoes: [PosicaoNoPainel] = []
    ) throws -> VagaNoPainel {
        let inicio = agoraDoTeste.addingTimeInterval(deslocamento)
        let resumo = VagaResumo(
            id: id, funcao: "Garçom", local: "CLS 405", regiaoAdministrativa: "Plano Piloto",
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * hora)), valor: Dinheiro(centavos: 12000)
        )
        return VagaNoPainel(vaga: resumo, modo: .urgencia, estado: .publicada, alertaVagaVazia: alerta, candidatosPendentes: 0, posicoes: posicoes)
    }

    static func posicao(verificacao: Verificacao = .pendente, emAtraso: Bool = false, aCaminhoEm: Date? = nil) -> PosicaoNoPainel {
        PosicaoNoPainel(
            id: posicaoID, estado: .confirmada, profissional: ana, turnoID: turnoID, verificacao: verificacao,
            emAtraso: emAtraso, aCaminhoEm: aCaminhoEm
        )
    }

    /// Um turno com check-in manual pendente (`pendente: true`) ou em atraso.
    static func painel(
        pendente: Bool = false, emAtraso: Bool = false, aCaminhoEm: Date? = nil, verificacao: Verificacao = .pendente
    ) throws -> Painel {
        Painel(
            estabelecimentoID: casa,
            vagas: [try vaga(posicoes: [posicao(verificacao: verificacao, emAtraso: emAtraso, aCaminhoEm: aCaminhoEm)])],
            checkinsPendentes: pendente ? [turnoID] : []
        )
    }

    static let confirmado = ResultadoRegistro(
        turnoID: turnoID, tipo: .manual, verificacao: .verificado, registradoEm: agoraDoTeste, distanciaMetros: nil
    )
    static let reaberto = ResultadoCancelamento(posicaoID: posicaoID, falta: true, reaberta: true, novaPosicaoID: UUID())
}

@MainActor
@Suite("Acompanhamento do turno pelo contratante (#19)")
struct AcompanhamentoViewModelTests {
    // MARK: Critério 1 — confirmar presença

    @Test("Check-in manual pendente entra na lista de pendentes, com a chegada esperando confirmação")
    func pendenteAparece() async throws {
        let cena = try await Cena.montar()
        await cena.viewModel.carregar()
        #expect(cena.viewModel.pendentes.isEmpty)
        #expect(cena.viewModel.chegada(try cena.turno()) == .aguardando)

        try await cena.checkinManual()
        await cena.viewModel.carregar()

        #expect(cena.viewModel.pendentes.map(\.posicao.turnoID) == [cena.turnoID])
        #expect(cena.viewModel.podeConfirmar(try cena.turno()))
        #expect(cena.viewModel.chegada(try cena.turno()) == .manualPendente)
    }

    @Test("Confirmar presença muda o estado na hora e tira o turno da lista de pendentes")
    func confirmarPresenca() async throws {
        let cena = try await Cena.montar()
        try await cena.checkinManual()
        await cena.viewModel.carregar()

        await cena.viewModel.confirmarPresenca(try cena.turno())

        #expect(cena.viewModel.pendentes.isEmpty)
        #expect(cena.viewModel.chegada(try cena.turno()) == .verificada)
        #expect(!cena.viewModel.podeConfirmar(try cena.turno()))
        #expect(cena.viewModel.resultado == .presencaConfirmada)
        #expect(cena.viewModel.falha == nil)
        #expect(cena.viewModel.emAndamento.isEmpty)
        // Minhas vagas é avisada para reler o painel, e o servidor guardou a confirmação.
        #expect(await cena.mudancas.valor == 1)
        #expect(try await cena.api.confirmarCheckinManual(turnoID: cena.turnoID).verificacao == .verificado)
    }

    @Test("A confirmação vale na tela assim que a chamada responde, sem esperar nova leitura do painel")
    func confirmarSemReler() async throws {
        let leituras = Contador()
        let velho = try PainelDeTeste.painel(pendente: true)
        let viewModel = AcompanhamentoViewModel(
            buscarPainel: { await leituras.somar(); return velho },
            confirmar: { _ in PainelDeTeste.confirmado },
            reabrir: { _ in PainelDeTeste.reaberto }
        )
        await viewModel.carregar()
        let turno = try #require(viewModel.pendentes.first)

        await viewModel.confirmarPresenca(turno)

        #expect(viewModel.pendentes.isEmpty)
        #expect(viewModel.turno(turnoID: PainelDeTeste.turnoID)?.posicao.verificacao == .verificado)
        #expect(await leituras.valor == 1)
    }

    @Test("Dois toques em Confirmar presença fazem uma chamada só")
    func confirmarDuasVezes() async throws {
        let chamadas = Contador()
        let velho = try PainelDeTeste.painel(pendente: true)
        let viewModel = AcompanhamentoViewModel(
            buscarPainel: { velho },
            confirmar: { _ in
                await chamadas.somar()
                try await Task.sleep(for: .milliseconds(50))
                return PainelDeTeste.confirmado
            },
            reabrir: { _ in PainelDeTeste.reaberto }
        )
        await viewModel.carregar()
        let turno = try #require(viewModel.pendentes.first)

        async let primeiro: Void = viewModel.confirmarPresenca(turno)
        async let segundo: Void = viewModel.confirmarPresenca(turno)
        _ = await (primeiro, segundo)

        #expect(await chamadas.valor == 1)
        #expect(viewModel.pendentes.isEmpty)
    }

    @Test("Sem rede, o turno continua pendente e a tela mostra a falha")
    func confirmarSemRede() async throws {
        let velho = try PainelDeTeste.painel(pendente: true)
        let viewModel = AcompanhamentoViewModel(
            buscarPainel: { velho },
            confirmar: { _ in throw ErroDaApi(codigo: .semRede) },
            reabrir: { _ in PainelDeTeste.reaberto }
        )
        await viewModel.carregar()

        await viewModel.confirmarPresenca(try #require(viewModel.pendentes.first))

        #expect(viewModel.falha == .api(ErroDaApi(codigo: .semRede)))
        #expect(viewModel.resultado == nil)
        #expect(viewModel.pendentes.count == 1)
        #expect(viewModel.emAndamento.isEmpty)
    }

    @Test("Painel velho: o check-in já estava confirmado ou sumiu, e a tela relê o painel", arguments: [
        CodigoErroAPI.checkinJaConfirmado, .checkinPendente,
    ])
    func confirmarComPainelVelho(codigo: CodigoErroAPI) async throws {
        let leituras = Contador()
        let velho = try PainelDeTeste.painel(pendente: true)
        let novo = try PainelDeTeste.painel(pendente: false)
        let viewModel = AcompanhamentoViewModel(
            buscarPainel: {
                await leituras.somar()
                return await leituras.valor == 1 ? velho : novo
            },
            confirmar: { _ in throw ErroDaApi(codigo: codigo) },
            reabrir: { _ in PainelDeTeste.reaberto }
        )
        await viewModel.carregar()

        await viewModel.confirmarPresenca(try #require(viewModel.pendentes.first))

        #expect(viewModel.falha == .situacaoMudou)
        #expect(viewModel.pendentes.isEmpty)
        #expect(await leituras.valor == 2)
    }

    @Test("Uma leitura que saiu antes da confirmação e chega depois não traz a pendência de volta")
    func leituraAntigaNaoDesfazConfirmacao() async throws {
        let leituras = Contador()
        let portao = Portao()
        let velho = try PainelDeTeste.painel(pendente: true)
        let novo = try PainelDeTeste.painel(verificacao: .verificado)
        let viewModel = AcompanhamentoViewModel(
            buscarPainel: {
                switch await leituras.somar() {
                case 1: return velho
                case 2:
                    // Saiu antes da confirmação e só chega depois dela, ainda com a pendência.
                    await portao.esperar()
                    return velho
                default: return novo
                }
            },
            confirmar: { _ in PainelDeTeste.confirmado },
            reabrir: { _ in PainelDeTeste.reaberto }
        )
        await viewModel.carregar()
        let turno = try #require(viewModel.pendentes.first)
        let releitura = Task { await viewModel.carregar() }
        while await leituras.valor < 2 { await Task.yield() }

        await viewModel.confirmarPresenca(turno)
        #expect(viewModel.pendentes.isEmpty)
        await portao.abrir()
        await releitura.value

        #expect(viewModel.pendentes.isEmpty)
        #expect(viewModel.chegada(try #require(viewModel.turno(turnoID: PainelDeTeste.turnoID))) == .verificada)
        #expect(viewModel.resultado == .presencaConfirmada)
        // A resposta antiga foi descartada, e o painel, lido de novo.
        #expect(await leituras.valor == 3)
        #expect(!viewModel.carregando)
    }

    @Test("Confirmar presença não chama a API se o check-in não está pendente no painel de agora")
    func confirmarSemPendencia() async throws {
        let chamadas = Contador()
        let leituras = Contador()
        let pendente = try PainelDeTeste.painel(pendente: true)
        let semPendencia = try PainelDeTeste.painel(verificacao: .verificado)
        let viewModel = AcompanhamentoViewModel(
            buscarPainel: { await leituras.somar() == 1 ? pendente : semPendencia },
            confirmar: { _ in
                await chamadas.somar()
                return PainelDeTeste.confirmado
            },
            reabrir: { _ in PainelDeTeste.reaberto }
        )
        await viewModel.carregar()
        let guardadoPelaTela = try #require(viewModel.pendentes.first)
        await viewModel.carregar()
        #expect(viewModel.pendentes.isEmpty)

        // A tela ainda tem o turno de antes da releitura; o que vale é o painel de agora.
        await viewModel.confirmarPresenca(guardadoPelaTela)

        #expect(await chamadas.valor == 0)
        #expect(viewModel.resultado == nil)
        #expect(viewModel.falha == nil)
    }

    @Test("Recusa na confirmação com falha na releitura: a tela se diz desatualizada e não oferece confirmar de novo")
    func confirmarRecusadoSemReler() async throws {
        let leituras = Contador()
        let velho = try PainelDeTeste.painel(pendente: true)
        let novo = try PainelDeTeste.painel(verificacao: .verificado)
        let viewModel = AcompanhamentoViewModel(
            buscarPainel: {
                switch await leituras.somar() {
                case 1: return velho
                case 2: throw ErroDaApi(codigo: .semRede)
                default: return novo
                }
            },
            confirmar: { _ in throw ErroDaApi(codigo: .checkinJaConfirmado) },
            reabrir: { _ in PainelDeTeste.reaberto }
        )
        await viewModel.carregar()
        let turno = try #require(viewModel.pendentes.first)

        await viewModel.confirmarPresenca(turno)

        #expect(viewModel.falha == .situacaoMudou)
        #expect(viewModel.falhouAoCarregar)
        #expect(!viewModel.podeConfirmar(turno))
        #expect(TextosDoAcompanhamento.falha(.situacaoMudou, desatualizado: viewModel.falhouAoCarregar) == "A situação deste turno mudou.")

        await viewModel.carregar()
        #expect(!viewModel.falhouAoCarregar)
        #expect(viewModel.pendentes.isEmpty)
        #expect(TextosDoAcompanhamento.falha(.situacaoMudou, desatualizado: viewModel.falhouAoCarregar) == "A situação deste turno mudou. Atualizamos a tela.")
    }

    // MARK: Critério 3 — reabrir a vaga

    @Test("Reabrir não aparece antes de 15 minutos de atraso, e pedir a reabertura não faz nada")
    func reabrirSoDepoisDe15Minutos() async throws {
        let cena = try await Cena.montar()

        await cena.carregarAos(14.9)
        #expect(!cena.viewModel.podeReabrir(try cena.turno()))
        #expect(cena.viewModel.emAtraso.isEmpty)
        #expect(cena.viewModel.chegada(try cena.turno()) == .aguardando)
        cena.viewModel.pedirReabertura(try cena.turno())
        #expect(cena.viewModel.reaberturaEmConfirmacao == nil)

        await cena.carregarAos(15)
        #expect(cena.viewModel.podeReabrir(try cena.turno()))
        #expect(cena.viewModel.emAtraso.map(\.id) == [cena.posicaoID])
        #expect(cena.viewModel.chegada(try cena.turno()) == .emAtraso)
    }

    @Test("Com check-in feito não há atraso nem reabertura, mesmo depois dos 15 minutos")
    func semAtrasoComCheckin() async throws {
        let cena = try await Cena.montar()
        try await cena.checkinManual()
        await cena.carregarAos(30)
        #expect(!cena.viewModel.podeReabrir(try cena.turno()))
        #expect(cena.viewModel.emAtraso.isEmpty)
    }

    @Test("Reabrir vaga pede confirmação: sem ela, nada é enviado; desistir não muda o turno")
    func reabrirPedeConfirmacao() async throws {
        let cena = try await Cena.montar()
        await cena.carregarAos(16)

        cena.viewModel.pedirReabertura(try cena.turno())

        #expect(cena.viewModel.reaberturaEmConfirmacao?.id == cena.posicaoID)
        #expect(cena.viewModel.chegada(try cena.turno()) == .emAtraso)
        #expect(try await cena.estadoNoServidor() == .confirmada)

        cena.viewModel.desistirDaReabertura()
        #expect(cena.viewModel.reaberturaEmConfirmacao == nil)
        // Confirmar sem pedido em aberto também não envia nada.
        await cena.viewModel.confirmarReabertura()?.value
        #expect(cena.viewModel.resultado == nil)
        #expect(try await cena.estadoNoServidor() == .confirmada)
        #expect(await cena.mudancas.valor == 0)
    }

    @Test("Confirmada a reabertura, a posição fica cancelada, a vaga ganha posição aberta e o atraso some")
    func reabrirConfirmado() async throws {
        let cena = try await Cena.montar()
        await cena.carregarAos(16)
        cena.viewModel.pedirReabertura(try cena.turno())

        await cena.viewModel.confirmarReabertura()?.value

        #expect(cena.viewModel.reaberturaEmConfirmacao == nil)
        #expect(cena.viewModel.resultado == .vagaReaberta)
        #expect(cena.viewModel.falha == nil)
        #expect(cena.viewModel.chegada(try cena.turno()) == .cancelada)
        #expect(cena.viewModel.emAtraso.isEmpty)
        #expect(!cena.viewModel.podeReabrir(try cena.turno()))
        let vaga = try #require(cena.viewModel.vaga(id: cena.vagaID))
        #expect(vaga.posicoes.map(\.estado).sorted { $0.rawValue < $1.rawValue } == [.aberta, .cancelada])
        #expect(await cena.mudancas.valor == 1)
        #expect(try await cena.estadoNoServidor() == .cancelada)
    }

    @Test("O alerta que fecha logo depois do toque em Reabrir vaga não desfaz a reabertura confirmada")
    func alertaFechaDepoisDeConfirmar() async throws {
        let cena = try await Cena.montar()
        await cena.carregarAos(16)
        cena.viewModel.pedirReabertura(try cena.turno())

        // A ordem da tela: o botão confirma, e o alerta, ao sair, avisa que não há mais pedido.
        let tarefa = cena.viewModel.confirmarReabertura()
        cena.viewModel.desistirDaReabertura()
        await tarefa?.value

        #expect(cena.viewModel.resultado == .vagaReaberta)
        #expect(try await cena.estadoNoServidor() == .cancelada)
    }

    @Test("A menos de 1 hora do fim, a reabertura registra a falta e avisa que a vaga não reabriu")
    func reabrirPertoDoFim() async throws {
        let cena = try await Cena.montar()
        await cena.carregarAos(3.5 * 60)
        cena.viewModel.pedirReabertura(try cena.turno())

        await cena.viewModel.confirmarReabertura()?.value

        #expect(cena.viewModel.resultado == .faltaSemReabertura)
        #expect(cena.viewModel.vaga(id: cena.vagaID)?.posicoes.map(\.estado) == [.cancelada])
    }

    @Test("A reabertura vale na tela mesmo se a nova leitura do painel falhar")
    func reabrirSemReler() async throws {
        let leituras = Contador()
        let velho = try PainelDeTeste.painel(emAtraso: true)
        let viewModel = AcompanhamentoViewModel(
            buscarPainel: {
                await leituras.somar()
                guard await leituras.valor == 1 else { throw ErroDaApi(codigo: .semRede) }
                return velho
            },
            confirmar: { _ in PainelDeTeste.confirmado },
            reabrir: { _ in PainelDeTeste.reaberto }
        )
        await viewModel.carregar()
        viewModel.pedirReabertura(try #require(viewModel.emAtraso.first))

        await viewModel.confirmarReabertura()?.value

        #expect(viewModel.resultado == .vagaReaberta)
        #expect(viewModel.emAtraso.isEmpty)
        let posicoes = try #require(viewModel.painel?.vagas.first?.posicoes)
        #expect(posicoes.map(\.estado) == [.cancelada, .aberta])
        #expect(posicoes.last?.id == PainelDeTeste.reaberto.novaPosicaoID)
    }

    @Test("O servidor decide a tolerância e o check-in: a recusa vira aviso, e a tela relê o painel", arguments: [
        (CodigoErroAPI.reaberturaAntesDaTolerancia, FalhaDoAcompanhamento.antesDaTolerancia),
        (.posicaoNaoCancelavel, .situacaoMudou),
    ])
    func reabrirRecusado(codigo: CodigoErroAPI, esperado: FalhaDoAcompanhamento) async throws {
        let leituras = Contador()
        let velho = try PainelDeTeste.painel(emAtraso: true)
        let novo = try PainelDeTeste.painel(emAtraso: false)
        let viewModel = AcompanhamentoViewModel(
            buscarPainel: {
                await leituras.somar()
                return await leituras.valor == 1 ? velho : novo
            },
            confirmar: { _ in PainelDeTeste.confirmado },
            reabrir: { _ in throw ErroDaApi(codigo: codigo) }
        )
        await viewModel.carregar()
        viewModel.pedirReabertura(try #require(viewModel.emAtraso.first))

        await viewModel.confirmarReabertura()?.value

        #expect(viewModel.falha == esperado)
        #expect(viewModel.resultado == nil)
        #expect(viewModel.emAtraso.isEmpty)
        #expect(viewModel.turno(turnoID: PainelDeTeste.turnoID)?.posicao.estado == .confirmada)
        #expect(await leituras.valor == 2)
    }

    @Test("Recusa na reabertura com falha na releitura: o atraso continua na tela, marcada como desatualizada, sem oferecer reabrir")
    func reabrirRecusadoSemReler() async throws {
        let leituras = Contador()
        let chamadas = Contador()
        let velho = try PainelDeTeste.painel(emAtraso: true)
        let viewModel = AcompanhamentoViewModel(
            buscarPainel: {
                // A terceira leitura dá certo e ainda traz o atraso: o servidor é quem diz.
                guard await leituras.somar() != 2 else { throw ErroDaApi(codigo: .semRede) }
                return velho
            },
            confirmar: { _ in PainelDeTeste.confirmado },
            reabrir: { _ in
                await chamadas.somar()
                throw ErroDaApi(codigo: .posicaoNaoCancelavel, detalhes: "checkin_registrado")
            }
        )
        await viewModel.carregar()
        let turno = try #require(viewModel.emAtraso.first)
        viewModel.pedirReabertura(turno)

        await viewModel.confirmarReabertura()?.value

        #expect(viewModel.falha == .situacaoMudou)
        #expect(viewModel.falhouAoCarregar)
        #expect(TextosDoAcompanhamento.falha(.situacaoMudou, desatualizado: viewModel.falhouAoCarregar) == "A situação deste turno mudou.")
        // O painel velho ainda mostra o atraso, mas a reabertura não é oferecida nem aceita.
        #expect(viewModel.emAtraso.count == 1)
        #expect(!viewModel.podeReabrir(turno))
        viewModel.pedirReabertura(turno)
        #expect(viewModel.reaberturaEmConfirmacao == nil)
        #expect(await chamadas.valor == 1)

        // Relido com sucesso, vale de novo o que o servidor disser.
        await viewModel.carregar()
        #expect(!viewModel.falhouAoCarregar)
        #expect(viewModel.podeReabrir(try #require(viewModel.emAtraso.first)))
    }

    @Test("Uma leitura que saiu antes da reabertura e chega depois não traz o atraso de volta")
    func leituraAntigaNaoDesfazReabertura() async throws {
        let leituras = Contador()
        let portao = Portao()
        let velho = try PainelDeTeste.painel(emAtraso: true)
        let viewModel = AcompanhamentoViewModel(
            buscarPainel: {
                switch await leituras.somar() {
                case 1: return velho
                case 2:
                    await portao.esperar()
                    return velho
                default: throw ErroDaApi(codigo: .semRede)
                }
            },
            confirmar: { _ in PainelDeTeste.confirmado },
            reabrir: { _ in PainelDeTeste.reaberto }
        )
        await viewModel.carregar()
        let releitura = Task { await viewModel.carregar() }
        while await leituras.valor < 2 { await Task.yield() }
        viewModel.pedirReabertura(try #require(viewModel.emAtraso.first))

        await viewModel.confirmarReabertura()?.value
        await portao.abrir()
        await releitura.value

        #expect(viewModel.resultado == .vagaReaberta)
        #expect(viewModel.emAtraso.isEmpty)
        #expect(viewModel.painel?.vagas.first?.posicoes.map(\.estado) == [.cancelada, .aberta])
    }

    // MARK: Leitura

    @Test("Com o painel na tela, a leitura que falha mantém o painel e marca a tela como desatualizada")
    func falhaAoAtualizar() async throws {
        let leituras = Contador()
        let painel = try PainelDeTeste.painel(pendente: true)
        let viewModel = AcompanhamentoViewModel(
            buscarPainel: {
                guard await leituras.somar() != 2 else { throw ErroDaApi(codigo: .semRede) }
                return painel
            },
            confirmar: { _ in PainelDeTeste.confirmado }, reabrir: { _ in PainelDeTeste.reaberto }
        )
        await viewModel.carregar()
        await viewModel.carregar()
        #expect(viewModel.falhouAoCarregar)
        #expect(viewModel.painel == painel)

        await viewModel.carregar()
        #expect(!viewModel.falhouAoCarregar)
    }

    @Test("A chegada mostra o aviso de a caminho enquanto não há check-in nem atraso")
    func aCaminho() async throws {
        let desde = agoraDoTeste.addingTimeInterval(-30 * minuto)
        let painel = try PainelDeTeste.painel(aCaminhoEm: desde)
        let viewModel = AcompanhamentoViewModel(
            buscarPainel: { painel }, confirmar: { _ in PainelDeTeste.confirmado }, reabrir: { _ in PainelDeTeste.reaberto }
        )
        await viewModel.carregar()
        #expect(viewModel.chegada(try #require(viewModel.turno(turnoID: PainelDeTeste.turnoID))) == .aCaminho(desde: desde))
    }

    @Test("Falha na leitura do painel fica registrada, e a leitura seguinte limpa a falha")
    func falhaAoCarregar() async throws {
        let leituras = Contador()
        let painel = try PainelDeTeste.painel()
        let viewModel = AcompanhamentoViewModel(
            buscarPainel: {
                await leituras.somar()
                guard await leituras.valor > 1 else { throw ErroDaApi(codigo: .semRede) }
                return painel
            },
            confirmar: { _ in PainelDeTeste.confirmado }, reabrir: { _ in PainelDeTeste.reaberto }
        )
        await viewModel.carregar()
        #expect(viewModel.falhouAoCarregar)
        #expect(viewModel.painel == nil)

        await viewModel.carregar()
        #expect(!viewModel.falhouAoCarregar)
        #expect(viewModel.painel == painel)
    }
}

@MainActor
@Suite("Roteador do contratante: avisos da casa (#19)")
struct RoteadorDoContratanteTests {
    // MARK: Critério 2 — o alerta de vaga vazia abre a vaga certa

    @Test("O alerta de vaga vazia abre a vaga certa, entre as vagas do painel")
    func vagaVaziaAbreAVagaCerta() async throws {
        let outra = try PainelDeTeste.vaga(inicioEm: 26 * hora)
        let vazia = try PainelDeTeste.vaga(inicioEm: 2 * hora, alerta: true)
        let painel = Painel(estabelecimentoID: PainelDeTeste.casa, vagas: [outra, vazia], checkinsPendentes: [])
        let viewModel = AcompanhamentoViewModel(
            buscarPainel: { painel }, confirmar: { _ in PainelDeTeste.confirmado }, reabrir: { _ in PainelDeTeste.reaberto }
        )
        await viewModel.carregar()
        let roteador = RoteadorDoContratante()
        // O payload que o backend envia em `vaga_vazia`: a vaga e a posição aberta.
        let aviso = try #require(AvisoDoContratante(
            tipo: "vaga_vazia", payload: ["vaga_id": vazia.vaga.id.uuidString, "posicao_id": UUID().uuidString]
        ))

        roteador.abrir(aviso)

        #expect(roteador.caminho == [.vaga(vazia.vaga.id)])
        guard case let .vaga(vagaID) = try #require(roteador.caminho.last) else {
            Issue.record("o aviso de vaga vazia não abriu uma vaga")
            return
        }
        let aberta = try #require(viewModel.vaga(id: vagaID))
        #expect(aberta == vazia)
        #expect(aberta.alertaVagaVazia)
    }

    @Test("Check-in manual pendente e atraso de 15 minutos abrem o turno do aviso", arguments: [
        ("checkin_manual_pendente", "vaga_id"), ("atraso_15min", "posicao_id"),
    ])
    func avisosDoTurno(tipo: String, outraChave: String) async throws {
        let painel = try PainelDeTeste.painel(pendente: true)
        let viewModel = AcompanhamentoViewModel(
            buscarPainel: { painel }, confirmar: { _ in PainelDeTeste.confirmado }, reabrir: { _ in PainelDeTeste.reaberto }
        )
        await viewModel.carregar()
        let roteador = RoteadorDoContratante()
        let aviso = try #require(AvisoDoContratante(
            tipo: tipo, payload: ["turno_id": PainelDeTeste.turnoID.uuidString, outraChave: UUID().uuidString]
        ))

        roteador.abrir(aviso)

        #expect(roteador.caminho == [.turno(turnoID: PainelDeTeste.turnoID)])
        #expect(viewModel.turno(turnoID: PainelDeTeste.turnoID)?.posicao.id == PainelDeTeste.posicaoID)
    }

    @Test("O aviso substitui a pilha: abre o destino dele, e não uma tela por cima da outra")
    func avisoSubstituiAPilha() {
        let roteador = RoteadorDoContratante()
        roteador.caminho = [.vaga(UUID()), .turno(turnoID: UUID())]
        let vagaID = UUID()

        roteador.abrir(.vagaVazia(vagaID: vagaID))
        #expect(roteador.caminho == [.vaga(vagaID)])

        roteador.voltarParaAsVagas()
        #expect(roteador.caminho.isEmpty)
    }

    @Test("Aviso que não é para a casa, sem o id ou com id inválido não abre nada", arguments: [
        ("vaga_vazia", ["posicao_id": "50000000-0000-0000-0000-000000000001"]),
        ("vaga_vazia", ["vaga_id": "não é uuid"]),
        ("atraso_15min", ["posicao_id": "50000000-0000-0000-0000-000000000001"]),
        ("checkin_manual_pendente", [:]),
        ("vaga", ["vaga_id": "40000000-0000-0000-0000-000000000001"]),
        ("inicio_sem_checkin", ["turno_id": "60000000-0000-0000-0000-000000000001"]),
        ("tipo_que_nao_existe", ["vaga_id": "40000000-0000-0000-0000-000000000001"]),
    ] as [(String, [String: String])])
    func avisoQueNaoAbre(tipo: String, payload: [String: String]) {
        #expect(AvisoDoContratante(tipo: tipo, payload: payload) == nil)
    }

    @Test("Posição cancelada com campos da 0.2.31 mantém estado e mapeia textos de causa e falta")
    func cancelamentoComCampos0231() async throws {
        let cancelamento = CancelamentoDaPosicao(
            causa: .profissional,
            falta: true,
            motivo: "Imprevisto de saúde",
            canceladaEm: agoraDoTeste
        )
        let posicao = PosicaoNoPainel(
            id: PainelDeTeste.posicaoID,
            estado: .cancelada,
            profissional: nil,
            turnoID: PainelDeTeste.turnoID,
            verificacao: .naoVerificado,
            emAtraso: false,
            cancelamento: cancelamento
        )
        let painel = Painel(
            estabelecimentoID: PainelDeTeste.casa,
            vagas: [try PainelDeTeste.vaga(posicoes: [posicao])],
            checkinsPendentes: []
        )
        let viewModel = AcompanhamentoViewModel(
            buscarPainel: { painel }, confirmar: { _ in PainelDeTeste.confirmado }, reabrir: { _ in PainelDeTeste.reaberto }
        )
        await viewModel.carregar()

        let turno = try #require(viewModel.turno(turnoID: PainelDeTeste.turnoID))
        #expect(viewModel.chegada(turno) == .cancelada)
        #expect(turno.posicao.cancelamento?.motivo == "Imprevisto de saúde")
        #expect(turno.posicao.cancelamento?.falta == true)

        #expect(TextosDoAcompanhamento.textoDaCausa(.profissional) == "Cancelado pelo profissional.")
        #expect(TextosDoAcompanhamento.textoDaCausa(.estabelecimento) == "Cancelado pelo estabelecimento.")
        #expect(TextosDoAcompanhamento.textoDaCausa(.reaberturaPorAtraso) == "Reabertura por atraso.")
        #expect(TextosDoAcompanhamento.textoDaCausa(.noShowSemCheckin) == "Turno encerrado sem check-in.")
        #expect(TextosDoAcompanhamento.textoDaCausa(.outro) == "Posição cancelada.")

        #expect(TextosDoAcompanhamento.textoDaFalta(true) == "Contou como falta para o profissional.")
        #expect(TextosDoAcompanhamento.textoDaFalta(false) == "Não contou como falta.")

        #expect(TextosDoAcompanhamento.detalheDoCheckin(em: "20:00", tipo: .geolocalizado) == "Check-in no local às 20:00.")
        #expect(TextosDoAcompanhamento.detalheDoCheckin(em: "20:00", tipo: .manual) == "Check-in manual às 20:00.")
        #expect(TextosDoAcompanhamento.detalheDoCheckin(em: "20:00", tipo: nil) == "Check-in às 20:00.")
    }

    @Test("AcompanhamentoViewModel expõe a api fornecida no inicializador")
    func exposicaoDaApi() {
        let api = ApiClienteEmMemoria()
        let vm = AcompanhamentoViewModel(api: api, estabelecimentoID: UUID())
        #expect(vm.api != nil)
    }
}

@Suite("Textos do acompanhamento no catálogo (#19)")
struct TextosDoAcompanhamentoTests {
    @Test("Todo texto da tela do turno do contratante está no catálogo pt-BR")
    func textosNoCatalogo() throws {
        let raiz = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fonte = try String(
            contentsOf: raiz.appending(path: "Sources/Apresentacao/Fluxos/Contratante/TelaTurnoDoContratante.swift"), encoding: .utf8
        )
        let literais = fonte.matches(of: /String\(localized: "([^"]+)", bundle: bundleApresentacao\)/).map { String($0.output.1) }
        #expect(literais.count >= 25, "os textos da tela não foram encontrados na fonte")

        let catalogo = try JSONSerialization.jsonObject(
            with: Data(contentsOf: raiz.appending(path: "Resources/Localizable.xcstrings"))
        ) as? [String: Any]
        let chaves = try #require(catalogo?["strings"] as? [String: Any])
        let fora = literais.filter { chaves[$0] == nil }
        #expect(fora.isEmpty, "textos fora do catálogo: \(fora)")
    }
}
