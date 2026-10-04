import Foundation
@testable import FrilaApresentacao
import FrilaDados
import FrilaDominio
import Testing

private struct RelogioFixo: Relogio {
    let agora: Date
    init(_ agora: Date) { self.agora = agora }
}

private actor FilaDeAcoesMemoria: FilaDeAcoes {
    func recusar(_ acao: AcaoPendente, codigo: CodigoErroAPI) async throws { try await remover(id: acao.id) }
    func recusadas() -> [AcaoRecusada] { [] }

    var itens: [AcaoPendente] = []
    func enfileirar(_ acao: AcaoPendente) throws { itens.append(acao) }
    func pendentes() throws -> [AcaoPendente] { itens }
    func remover(id: UUID) throws { itens.removeAll { $0.id == id } }
    func limpar() throws { itens.removeAll() }
}

/// O cancelamento do profissional contra o dublê do contrato (#20): o turno de Meu turno vira
/// cancelado sem reler a lista, o dublê devolve a regra das 24 h, e a fila reenvia depois.
@MainActor
@Suite struct CancelamentoDoTurnoTests {
    private let agora = Date(timeIntervalSince1970: 1_790_000_000)

    private func turnoConfirmado(_ api: ApiClienteEmMemoria) async throws -> Turno {
        try #require(try await api.meusTurnos().first { !$0.cancelado })
    }

    @Test func meuTurnoOfereceCancelarSoNaPosicaoConfirmadaAntesDoFim() async throws {
        let api = ApiClienteEmMemoria(cenario: .turnoConfirmadoLonge, relogio: RelogioFixo(agora))
        let turno = try await turnoConfirmado(api)
        let confirmado = MeuTurnoViewModel(turno: turno, api: api, relogio: RelogioFixo(agora))
        #expect(confirmado.podeCancelar)
        #expect(confirmado.criarCancelamentoViewModel() != nil)

        let depoisDoFim = MeuTurnoViewModel(turno: turno, api: api, relogio: RelogioFixo(turno.vaga.periodo.fim.addingTimeInterval(60)))
        #expect(!depoisDoFim.podeCancelar)
        #expect(depoisDoFim.criarCancelamentoViewModel() == nil)

        let cancelado = ApiClienteEmMemoria(cenario: .turnoCancelado, relogio: RelogioFixo(agora))
        let turnoCancelado = try #require(try await cancelado.meusTurnos().first)
        #expect(!MeuTurnoViewModel(turno: turnoCancelado, api: cancelado, relogio: RelogioFixo(agora)).podeCancelar)
    }

    @Test func cancelarAMenosDe24HorasViraCanceladoComFaltaEAtualizaALista() async throws {
        let api = ApiClienteEmMemoria(cenario: .turnoConfirmadoPerto, relogio: RelogioFixo(agora))
        let turno = try await turnoConfirmado(api)
        var listaAtualizada = 0
        let viewModel = MeuTurnoViewModel(turno: turno, api: api, relogio: RelogioFixo(agora), aoCancelar: { listaAtualizada += 1 })
        let folha = try #require(viewModel.criarCancelamentoViewModel())
        #expect(folha.contaComoFalta)
        #expect(folha.aviso.hasPrefix("Faltam 10 h para o início."))

        folha.motivo = .saude
        await folha.confirmar()

        let resultado = try #require(viewModel.desfechoDoCancelamento)
        #expect(resultado.falta)
        #expect(resultado.reaberta)
        #expect(resultado.novaPosicaoID != nil)
        #expect(viewModel.cancelado)
        #expect(!viewModel.permiteAcoesDoTurno)
        #expect(!viewModel.podeCancelar)
        #expect(viewModel.cancelamento?.causa == .profissional)
        #expect(viewModel.cancelamento?.falta == true)
        #expect(viewModel.causaDoCancelamento == "Você cancelou este turno.")
        #expect(viewModel.faltaNoCancelamento == "Este cancelamento contou como falta.")
        #expect(listaAtualizada == 1)

        // A lista relida mostra o mesmo turno cancelado, e a vaga ganhou a posição nova (RN12).
        let relido = try #require(try await api.meusTurnos().first { $0.id == turno.id })
        #expect(relido.cancelado)
        #expect(relido.cancelamento?.causa == .profissional)
        #expect(relido.cancelamento?.falta == true)
        let vaga = try await api.detalheDaVaga(id: turno.vaga.id)
        #expect(vaga.posicoesAbertas == 2)
    }

    @Test func cancelarAMaisDe24HorasNaoContaComoFalta() async throws {
        let api = ApiClienteEmMemoria(cenario: .turnoConfirmadoLonge, relogio: RelogioFixo(agora))
        let turno = try await turnoConfirmado(api)
        let viewModel = MeuTurnoViewModel(turno: turno, api: api, relogio: RelogioFixo(agora))
        let folha = try #require(viewModel.criarCancelamentoViewModel())
        #expect(!folha.contaComoFalta)
        #expect(folha.aviso.hasPrefix("Faltam 48 h para o início."))
        folha.motivo = .outroCompromisso
        await folha.confirmar()
        #expect(viewModel.desfechoDoCancelamento?.falta == false)
        #expect(viewModel.faltaNoCancelamento == "Este cancelamento não contou como falta.")
    }

    @Test func dubleRecusaMotivoCurtoEPosicaoJaCancelada() async throws {
        let api = ApiClienteEmMemoria(cenario: .turnoConfirmadoLonge, relogio: RelogioFixo(agora))
        let turno = try await turnoConfirmado(api)
        await #expect(throws: ErroDaApi(codigo: .campoObrigatorio, detalhes: "motivo")) {
            try await api.cancelarPosicao(id: turno.posicaoID, motivo: "ab")
        }
        _ = try await api.cancelarPosicao(id: turno.posicaoID, motivo: "Imprevisto pessoal")
        await #expect(throws: ErroDaApi(codigo: .posicaoNaoCancelavel)) {
            try await api.cancelarPosicao(id: turno.posicaoID, motivo: "Imprevisto pessoal")
        }
    }

    @Test func semRedeGuardaNaFilaEOSincronizadorEnviaDepois() async throws {
        let semRede = ApiClienteEmMemoria(cenario: .cancelarSemRede, relogio: RelogioFixo(agora))
        let turno = try await turnoConfirmado(semRede)
        let fila = FilaDeAcoesMemoria()
        let viewModel = MeuTurnoViewModel(turno: turno, api: semRede, fila: fila, relogio: RelogioFixo(agora))
        let folha = try #require(viewModel.criarCancelamentoViewModel())
        folha.motivo = .deslocamento
        await folha.confirmar()

        #expect(folha.estado == .concluido(.naFila))
        #expect(viewModel.cancelamentoNaFila)
        #expect(!viewModel.podeCancelar)
        // A tela reaberta lê a fila e continua sem oferecer cancelar.
        let reaberta = MeuTurnoViewModel(turno: turno, api: semRede, fila: fila, relogio: RelogioFixo(agora))
        #expect(reaberta.podeCancelar)
        await reaberta.carregar()
        #expect(reaberta.cancelamentoNaFila)
        #expect(!reaberta.podeCancelar)

        // A rede voltou: o mesmo turno existe num dublê que responde, e a fila é esvaziada.
        let comRede = ApiClienteEmMemoria(cenario: .turnoConfirmadoLonge, relogio: RelogioFixo(agora))
        let turnoComRede = try await turnoConfirmado(comRede)
        let acao = try #require(await fila.itens.first)
        try await fila.remover(id: acao.id)
        try await fila.enfileirar(AcaoPendente(
            tipo: acao.tipo, turnoID: turnoComRede.id, instanteDoToque: acao.instanteDoToque, chave: acao.chave,
            alvoID: turnoComRede.posicaoID, motivo: acao.motivo
        ))
        await SincronizadorAcoes(fila: fila, api: comRede).sincronizar()
        #expect(await fila.itens.isEmpty)
        let relido = try #require(try await comRede.meusTurnos().first { $0.id == turnoComRede.id })
        #expect(relido.cancelado)
        #expect(relido.cancelamento?.causa == .profissional)
    }

    @Test func sincronizadorDescartaCancelamentoJaFeitoEMantemOQueFalhouPorRede() async throws {
        let api = ApiClienteEmMemoria(cenario: .turnoConfirmadoLonge, relogio: RelogioFixo(agora))
        let turno = try await turnoConfirmado(api)
        _ = try await api.cancelarPosicao(id: turno.posicaoID, motivo: "Imprevisto pessoal")
        let fila = FilaDeAcoesMemoria()
        try await fila.enfileirar(AcaoPendente(
            tipo: .cancelamentoPosicao, turnoID: turno.id, instanteDoToque: agora, chave: UUID(),
            alvoID: turno.posicaoID, motivo: "Imprevisto pessoal"
        ))
        await SincronizadorAcoes(fila: fila, api: api).sincronizar()
        #expect(await fila.itens.isEmpty)

        let aindaSemRede = ApiClienteEmMemoria(cenario: .cancelarSemRede, relogio: RelogioFixo(agora))
        let outro = try await turnoConfirmado(aindaSemRede)
        try await fila.enfileirar(AcaoPendente(
            tipo: .cancelamentoPosicao, turnoID: outro.id, instanteDoToque: agora, chave: UUID(),
            alvoID: outro.posicaoID, motivo: "Imprevisto pessoal"
        ))
        await SincronizadorAcoes(fila: fila, api: aindaSemRede).sincronizar()
        #expect(await fila.itens.count == 1)
    }

    @Test func acaoPendenteDeCancelamentoSobreviveAoCodec() throws {
        let acao = AcaoPendente(
            tipo: .cancelamentoVaga, instanteDoToque: agora, chave: UUID(), alvoID: UUID(), motivo: "Movimento menor que o esperado"
        )
        let dados = try JSONEncoder().encode(acao)
        let lida = try JSONDecoder().decode(AcaoPendente.self, from: dados)
        #expect(lida == acao)
        // Um registro antigo, sem os campos novos, continua legível.
        let antiga = AcaoPendente(tipo: .checkin, turnoID: UUID(), instanteDoToque: agora, chave: UUID())
        let lidaAntiga = try JSONDecoder().decode(AcaoPendente.self, from: try JSONEncoder().encode(antiga))
        #expect(lidaAntiga.alvoID == nil)
        #expect(lidaAntiga.motivo == nil)
    }
}
