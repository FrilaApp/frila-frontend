import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private final class RelogioDeTeste: Relogio, @unchecked Sendable {
    private let trava = NSLock()
    private var _agora: Date
    init(_ agora: Date) { _agora = agora }
    var agora: Date { trava.withLock { _agora } }
    func avancar(para instante: Date) { trava.withLock { _agora = instante } }
}

private actor Contador {
    private(set) var valor = 0
    func somar() { valor += 1 }
}

private actor FilaDeAcoesMemoria: FilaDeAcoes {
    var itens: [AcaoPendente] = []
    func enfileirar(_ acao: AcaoPendente) throws { itens.append(acao) }
    func pendentes() throws -> [AcaoPendente] { itens }
    func remover(id: UUID) throws { itens.removeAll { $0.id == id } }
    func limpar() throws { itens.removeAll() }
}

/// `cancelar_posicao` sem rede, com o resto do dublê respondendo: é o que a fila offline precisa.
private final class ApiSemRedeNoCancelamento: ApiClienteEncaminhador, @unchecked Sendable {
    override func cancelarPosicao(id: UUID, motivo: String) async throws -> ResultadoCancelamento { throw ErroDaApi(codigo: .semRede) }
    override func cancelarVaga(id: UUID, motivo: String) async throws -> VagaCancelada { throw ErroDaApi(codigo: .semRede) }
}

private let hora: TimeInterval = 3_600
private let agoraDoTeste = Date(timeIntervalSince1970: 1_800_000_000)

/// A casa do dublê com uma vaga de duas posições, uma delas confirmada, e o view model lendo o painel.
@MainActor
private struct Cena {
    let api: any ApiCliente
    let base: ApiClienteEmMemoria
    let relogio: RelogioDeTeste
    let viewModel: AcompanhamentoViewModel
    let mudancas: Contador
    let fila: FilaDeAcoesMemoria
    let casaID: UUID
    let vagaID: UUID
    let posicaoID: UUID
    let inicio: Date

    static func montar(emHoras horas: Double = 30, semRede: Bool = false) async throws -> Cena {
        let relogio = RelogioDeTeste(agoraDoTeste)
        let base = ApiClienteEmMemoria(cenario: .contratante, relogio: relogio)
        let api: any ApiCliente = semRede ? ApiSemRedeNoCancelamento(base: base) : base
        let casa = try #require(try await base.meusEstabelecimentos().first)
        let funcao = try #require(try await base.funcoes().first)
        let inicio = agoraDoTeste.addingTimeInterval(horas * hora)
        let vagaID = try await base.publicarVaga(PublicacaoVaga(
            estabelecimentoID: casa.id, funcaoID: funcao.id,
            periodo: try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(4 * hora)),
            local: "CLS 405, Asa Sul, Brasília - DF", regiaoAdministrativa: "Plano Piloto",
            ponto: try Coordenada(latitude: -15.8121, longitude: -47.8997), valor: Dinheiro(centavos: 12000),
            posicoes: 2, inclusos: Inclusos(refeicao: true, transporte: false, exigeMaterialProprio: false),
            responsavelLocal: "Marina", chave: UUID()
        )).vagaID
        let candidatura = try await base.candidatar(vagaID: vagaID)
        let mudancas = Contador()
        let fila = FilaDeAcoesMemoria()
        let viewModel = AcompanhamentoViewModel(
            api: api, estabelecimentoID: casa.id, agora: { relogio.agora }, fila: fila, aoMudar: { await mudancas.somar() }
        )
        await viewModel.carregar()
        return Cena(
            api: api, base: base, relogio: relogio, viewModel: viewModel, mudancas: mudancas, fila: fila, casaID: casa.id,
            vagaID: vagaID, posicaoID: try #require(candidatura.posicaoID), inicio: inicio
        )
    }

    func vaga() throws -> VagaNoPainel { try #require(viewModel.vaga(id: vagaID)) }
    func turno() throws -> TurnoAcompanhado {
        let vaga = try vaga()
        return TurnoAcompanhado(vaga: vaga.vaga, posicao: try #require(vaga.posicoes.first { $0.id == posicaoID }))
    }
}

/// Cancelamento com motivo pelo contratante (#20): a posição no painel do turno e a vaga em Minhas vagas.
@MainActor
@Suite struct CancelamentoDoContratanteTests {
    @Test func soAPosicaoConfirmadaAntesDoFimPodeSerCancelada() async throws {
        let cena = try await Cena.montar()
        #expect(cena.viewModel.podeCancelar(try cena.turno()))
        #expect(cena.viewModel.podeCancelarVaga(try cena.vaga()))
        let aberta = try #require(try cena.vaga().posicoes.first { $0.estado == .aberta })
        #expect(!cena.viewModel.podeCancelar(TurnoAcompanhado(vaga: try cena.vaga().vaga, posicao: aberta)))

        cena.relogio.avancar(para: cena.inicio.addingTimeInterval(5 * hora))
        #expect(!cena.viewModel.podeCancelar(try cena.turno()))
        #expect(!cena.viewModel.podeCancelarVaga(try cena.vaga()))
        #expect(cena.viewModel.criarCancelamento(de: try cena.turno()) == nil)
        #expect(cena.viewModel.criarCancelamento(da: try cena.vaga()) == nil)
    }

    @Test func folhaDaPosicaoNaoFalaEmFaltaEAplicaOCancelamentoNaHora() async throws {
        let cena = try await Cena.montar(emHoras: 10)
        let folha = try #require(cena.viewModel.criarCancelamento(de: try cena.turno()))
        #expect(folha.lado == .contratante)
        #expect(!folha.contaComoFalta)
        #expect(folha.aviso.hasPrefix("Faltam 10 h para o início."))
        #expect(folha.aviso.contains("Não conta como falta para o profissional."))
        #expect(!folha.podeConfirmar)

        folha.motivo = .movimentoMenor
        await folha.confirmar()

        guard case let .concluido(.posicao(resultado)) = folha.estado else { Issue.record("esperava posição cancelada: \(folha.estado)"); return }
        #expect(!resultado.falta)
        #expect(resultado.reaberta)
        // O painel da tela já mostra a posição cancelada e a nova aberta, antes da releitura.
        #expect(cena.viewModel.resultado == .posicaoCancelada(reaberta: true))
        let posicoes = try cena.vaga().posicoes
        #expect(posicoes.first { $0.id == cena.posicaoID }?.estado == .cancelada)
        #expect(posicoes.filter { $0.estado == .aberta }.count == 2)
        #expect(!cena.viewModel.podeCancelar(try cena.turno()))

        await cena.viewModel.releituraAposCancelamento?.value
        #expect(await cena.mudancas.valor == 1)
        let relida = try cena.vaga()
        let cancelada = try #require(relida.posicoes.first { $0.id == cena.posicaoID })
        #expect(cancelada.estado == .cancelada)
        #expect(cancelada.cancelamento?.causa == .estabelecimento)
        #expect(cancelada.cancelamento?.falta == false)
        #expect(cancelada.cancelamento?.motivo == "Movimento menor que o esperado")
    }

    @Test func depoisDoInicioAPosicaoNaoReabreEOAvisoDizTurnoDescoberto() async throws {
        let cena = try await Cena.montar(emHoras: 2)
        cena.relogio.avancar(para: cena.inicio.addingTimeInterval(hora))
        let folha = try #require(cena.viewModel.criarCancelamento(de: try cena.turno()))
        #expect(folha.aviso.hasPrefix("O turno já começou."))
        #expect(folha.aviso.contains("o turno fica descoberto"))
        folha.motivo = .problemaNoLocal
        await folha.confirmar()
        #expect(cena.viewModel.resultado == .posicaoCancelada(reaberta: false))
        #expect(TextosDoAcompanhamento.resultado(.posicaoCancelada(reaberta: false)).contains("O turno ficou descoberto"))
        #expect(try cena.vaga().posicoes.filter { $0.estado == .aberta }.count == 1)
    }

    @Test func cancelarAVagaFechaTodasAsPosicoesEMoveAVagaParaEncerradas() async throws {
        let cena = try await Cena.montar()
        let folha = try #require(cena.viewModel.criarCancelamento(da: try cena.vaga()))
        #expect(folha.aviso.contains("Todas as posições serão canceladas"))
        folha.motivo = .mudancaDePlanos
        folha.detalhes = "O evento foi adiado"
        await folha.confirmar()

        guard case let .concluido(.vaga(cancelada)) = folha.estado else { Issue.record("esperava vaga cancelada: \(folha.estado)"); return }
        #expect(cancelada.estado == .cancelada)
        #expect(cancelada.posicoesCanceladas == 2)
        #expect(cena.viewModel.resultado == .vagaCancelada)
        let vaga = try cena.vaga()
        #expect(vaga.estado == .cancelada)
        #expect(vaga.posicoes.allSatisfy { $0.estado == .cancelada })
        #expect(!vaga.alertaVagaVazia)
        #expect(!cena.viewModel.podeCancelarVaga(vaga))

        await cena.viewModel.releituraAposCancelamento?.value
        let relida = try cena.vaga()
        #expect(relida.estado == .cancelada)
        #expect(relida.posicoes.first { $0.id == cena.posicaoID }?.cancelamento?.motivo == "O evento ou o turno mudou: O evento foi adiado")
        // Minhas vagas classifica a vaga cancelada como encerrada (critério 2).
        let lista = MinhasVagasViewModel(api: cena.api, estabelecimentoID: cena.casaID, nomeEstabelecimento: "Casa", agora: { agoraDoTeste })
        await lista.carregar()
        #expect(lista.vagas(na: .encerradas).map(\.vaga.id) == [cena.vagaID])
        // A vaga das fixtures do dublê continua em Próximas; só a cancelada saiu de lá.
        #expect(!lista.vagas(na: .proximas).contains { $0.vaga.id == cena.vagaID })
    }

    @Test func semRedeOCancelamentoEntraNaFilaEATelaNaoOfereceDeNovo() async throws {
        let cena = try await Cena.montar(semRede: true)
        let folha = try #require(cena.viewModel.criarCancelamento(de: try cena.turno()))
        folha.motivo = .posicaoPreenchidaFora
        await folha.confirmar()

        #expect(folha.estado == .concluido(.naFila))
        #expect(cena.viewModel.resultado == .cancelamentoNaFila)
        #expect(!cena.viewModel.podeCancelar(try cena.turno()))
        // A posição continua confirmada no painel: quem a cancela é o reenvio.
        #expect(try cena.turno().posicao.estado == .confirmada)
        let acao = try #require(await cena.fila.itens.first)
        #expect(acao.tipo == .cancelamentoPosicao)
        #expect(acao.alvoID == cena.posicaoID)
        #expect(acao.motivo == "A posição foi preenchida de outra forma")

        // A tela reaberta lê a fila e segue sem oferecer; o reenvio cancela no servidor e esvazia a fila.
        let reaberto = AcompanhamentoViewModel(api: cena.api, estabelecimentoID: cena.casaID, agora: { cena.relogio.agora }, fila: cena.fila)
        await reaberto.carregar()
        #expect(!reaberto.podeCancelar(try cena.turno()))
        await SincronizadorAcoes(fila: cena.fila, api: cena.base).sincronizar()
        #expect(await cena.fila.itens.isEmpty)
        await reaberto.carregar()
        #expect(reaberto.vaga(id: cena.vagaID)?.posicoes.first { $0.id == cena.posicaoID }?.estado == .cancelada)
    }

    @Test func vagaSemRedeEntraNaFilaComoCancelamentoDeVaga() async throws {
        let cena = try await Cena.montar(semRede: true)
        let folha = try #require(cena.viewModel.criarCancelamento(da: try cena.vaga()))
        folha.motivo = .movimentoMenor
        await folha.confirmar()
        #expect(folha.estado == .concluido(.naFila))
        #expect(!cena.viewModel.podeCancelarVaga(try cena.vaga()))
        let acao = try #require(await cena.fila.itens.first)
        #expect(acao.tipo == .cancelamentoVaga)
        #expect(acao.alvoID == cena.vagaID)
        await SincronizadorAcoes(fila: cena.fila, api: cena.base).sincronizar()
        #expect(await cena.fila.itens.isEmpty)
        await cena.viewModel.carregar()
        #expect(try cena.vaga().estado == .cancelada)
    }

    @Test func posicaoJaCanceladaNoServidorRecebeMensagemPropria() async throws {
        let cena = try await Cena.montar()
        _ = try await cena.base.cancelarPosicao(id: cena.posicaoID, motivo: "Cancelada por outro membro")
        let folha = try #require(cena.viewModel.criarCancelamento(de: try cena.turno()))
        folha.motivo = .movimentoMenor
        await folha.confirmar()
        #expect(folha.estado == .falha(TextosDoCancelamento.posicaoNaoCancelavel))
        #expect(cena.viewModel.resultado == nil)
    }
}
