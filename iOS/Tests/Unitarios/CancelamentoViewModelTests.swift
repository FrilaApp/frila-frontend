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
    var falhar = false

    func enfileirar(_ acao: AcaoPendente) throws {
        if falhar { throw ErroDaApi(codigo: .desconhecido) }
        itens.append(acao)
    }

    func pendentes() throws -> [AcaoPendente] { itens }
    func remover(id: UUID) throws { itens.removeAll { $0.id == id } }
    func limpar() throws { itens.removeAll() }
    func fazerFalhar() { falhar = true }
}

/// Guarda o motivo que chegou e devolve o que o teste mandar.
private final class ChamadaEspiada: @unchecked Sendable {
    private let trava = NSLock()
    private var _motivos: [String] = []
    var resposta: Result<DesfechoDoCancelamento, ErroDaApi>
    init(_ resposta: Result<DesfechoDoCancelamento, ErroDaApi>) { self.resposta = resposta }
    var motivos: [String] { trava.withLock { _motivos } }
    func executar(_ motivo: String) throws -> DesfechoDoCancelamento {
        trava.withLock { _motivos.append(motivo) }
        return try resposta.get()
    }
}

/// O aviso da folha e o motivo obrigatório (#20, critérios 1 e 3), com relógio injetado.
@MainActor
@Suite struct CancelamentoViewModelTests {
    private let agora = Date(timeIntervalSince1970: 1_790_000_000)
    private let posicaoID = UUID()
    private let turnoID = UUID()

    private func periodo(inicioEm horas: Double) throws -> Periodo {
        let inicio = agora.addingTimeInterval(horas * 3600)
        return try Periodo(inicio: inicio, fim: inicio.addingTimeInterval(6 * 3600))
    }

    private func modelo(
        lado: LadoDoCancelamento = .profissional,
        alvo: AlvoDoCancelamento? = nil,
        inicioEm horas: Double,
        fila: (any FilaDeAcoes)? = nil,
        resposta: Result<DesfechoDoCancelamento, ErroDaApi> = .success(.posicao(ResultadoCancelamento(posicaoID: UUID(), falta: false, reaberta: true, novaPosicaoID: UUID()))),
        aoConcluir: @escaping @MainActor (DesfechoDoCancelamento) -> Void = { _ in }
    ) throws -> (CancelamentoViewModel, ChamadaEspiada) {
        let chamada = ChamadaEspiada(resposta)
        let viewModel = CancelamentoViewModel(
            lado: lado, alvo: alvo ?? .posicao(id: posicaoID, turnoID: turnoID), periodo: try periodo(inicioEm: horas),
            relogio: RelogioFixo(agora), fila: fila,
            executar: { try chamada.executar($0) }, aoConcluir: aoConcluir
        )
        return (viewModel, chamada)
    }

    // MARK: Aviso pela antecedência (critério 1)

    @Test func profissionalAMenosDe24HorasAvisaQueContaComoFalta() throws {
        let (viewModel, _) = try modelo(inicioEm: 10)
        #expect(viewModel.contaComoFalta)
        #expect(viewModel.vaiReabrir)
        #expect(viewModel.aviso.hasPrefix("Faltam 10 h para o início."))
        #expect(viewModel.aviso.contains("conta como falta na sua taxa de comparecimento"))
        #expect(viewModel.aviso.contains("A vaga volta a ser oferecida a outros profissionais."))
    }

    @Test func profissionalAMaisDe24HorasAvisaQueNaoAfetaATaxa() throws {
        let (viewModel, _) = try modelo(inicioEm: 30)
        #expect(!viewModel.contaComoFalta)
        #expect(viewModel.aviso.hasPrefix("Faltam 30 h para o início."))
        #expect(viewModel.aviso.contains("não afeta sua taxa de comparecimento"))
        #expect(!viewModel.aviso.contains("conta como falta"))
    }

    @Test func exatamente24HorasNaoContaComoFalta() throws {
        let (viewModel, _) = try modelo(inicioEm: 24)
        #expect(!viewModel.contaComoFalta)
        #expect(viewModel.aviso.hasPrefix("Faltam 24 h para o início."))
    }

    @Test func horasSaoInteirasParaBaixoEMenosDeUmaHoraTemTextoProprio() throws {
        let (meiaHora, _) = try modelo(inicioEm: 0.5)
        #expect(meiaHora.aviso.hasPrefix("Faltam menos de 1 h para o início."))
        let (quebrada, _) = try modelo(inicioEm: 9.8)
        #expect(quebrada.aviso.hasPrefix("Faltam 9 h para o início."))
    }

    @Test func emVoltaDas24HorasONumeroNuncaContradizAFalta() throws {
        // A 23 h 30 min conta como falta: o aviso não pode dizer "24 h".
        let (antes, _) = try modelo(inicioEm: 23.5)
        #expect(antes.contaComoFalta)
        #expect(antes.aviso.hasPrefix("Faltam 23 h para o início."))
        #expect(antes.aviso.contains("conta como falta"))
        // A 24 h 30 min não conta: "24 h" com "não afeta".
        let (depois, _) = try modelo(inicioEm: 24.5)
        #expect(!depois.contaComoFalta)
        #expect(depois.aviso.hasPrefix("Faltam 24 h para o início."))
        #expect(depois.aviso.contains("não afeta sua taxa"))
    }

    @Test func profissionalDepoisDoInicioAvisaFaltaETurnoDescoberto() throws {
        let (viewModel, _) = try modelo(inicioEm: -1)
        #expect(viewModel.turnoJaComecou)
        #expect(viewModel.contaComoFalta)
        #expect(!viewModel.vaiReabrir)
        #expect(viewModel.aviso.hasPrefix("O turno já começou."))
        #expect(viewModel.aviso.contains("A posição não será reaberta: o turno fica descoberto."))
    }

    @Test func contratanteNuncaAvisaFaltaEDizQueAPosicaoReabre() throws {
        let (perto, _) = try modelo(lado: .contratante, inicioEm: 10)
        #expect(!perto.contaComoFalta)
        #expect(perto.aviso.hasPrefix("Faltam 10 h para o início."))
        #expect(perto.aviso.contains("A posição volta a ser oferecida a outros profissionais"))
        #expect(perto.aviso.contains("Não conta como falta para o profissional."))

        let (comecado, _) = try modelo(lado: .contratante, inicioEm: -0.5)
        #expect(comecado.aviso.hasPrefix("O turno já começou."))
        #expect(comecado.aviso.contains("o turno fica descoberto"))
    }

    @Test func vagaInteiraAvisaTodasAsPosicoesSemFalta() throws {
        let (viewModel, _) = try modelo(lado: .contratante, alvo: .vaga(id: UUID()), inicioEm: 30)
        #expect(!viewModel.vaiReabrir)
        #expect(viewModel.aviso.contains("Todas as posições serão canceladas"))
        #expect(viewModel.aviso.contains("Não conta como falta para ninguém."))
        #expect(viewModel.motivos == MotivoDeCancelamento.opcoes(para: .contratante))
    }

    // MARK: Motivo obrigatório (critério 3)

    @Test func semMotivoNaoDaParaConfirmarENadaEChamado() async throws {
        let (viewModel, chamada) = try modelo(inicioEm: 30)
        #expect(!viewModel.podeConfirmar)
        #expect(viewModel.motivoCompleto == nil)
        await viewModel.confirmar()
        #expect(chamada.motivos.isEmpty)
        #expect(viewModel.estado == .pronto)
    }

    @Test func motivoEscolhidoVaiComoTextoEDetalheOpcionalDepoisDeDoisPontos() async throws {
        let (viewModel, chamada) = try modelo(inicioEm: 30)
        viewModel.motivo = .saude
        #expect(viewModel.podeConfirmar)
        #expect(viewModel.motivoCompleto == "Problema de saúde")
        viewModel.detalhes = "  Febre desde ontem  "
        #expect(viewModel.motivoCompleto == "Problema de saúde: Febre desde ontem")
        await viewModel.confirmar()
        #expect(chamada.motivos == ["Problema de saúde: Febre desde ontem"])
    }

    @Test func outroMotivoExigeDetalheDePeloMenosTresCaracteres() throws {
        let (viewModel, _) = try modelo(inicioEm: 30)
        viewModel.motivo = .outro
        #expect(!viewModel.podeConfirmar)
        viewModel.detalhes = "ab"
        #expect(!viewModel.podeConfirmar)
        viewModel.detalhes = " abc "
        #expect(viewModel.podeConfirmar)
        #expect(viewModel.motivoCompleto == "abc")
    }

    @Test func motivosDoProfissionalEDoContratanteSaoDiferentesETerminamEmOutro() throws {
        let (profissional, _) = try modelo(inicioEm: 30)
        let (contratante, _) = try modelo(lado: .contratante, inicioEm: 30)
        #expect(profissional.motivos.last == .outro)
        #expect(contratante.motivos.last == .outro)
        #expect(Set(profissional.motivos).intersection(contratante.motivos) == [.outro])
    }

    // MARK: Desfecho

    @Test func respostaDoServidorViraConcluidoEAvisaQuemAbriu() async throws {
        let resultado = ResultadoCancelamento(posicaoID: posicaoID, falta: true, reaberta: false, novaPosicaoID: nil)
        var recebido: DesfechoDoCancelamento?
        let (viewModel, _) = try modelo(inicioEm: 10, resposta: .success(.posicao(resultado))) { recebido = $0 }
        viewModel.motivo = .deslocamento
        await viewModel.confirmar()
        #expect(viewModel.estado == .concluido(.posicao(resultado)))
        #expect(recebido == .posicao(resultado))
        #expect(!viewModel.podeConfirmar)
        #expect(TextosDoCancelamento.desfecho(.posicao(resultado), lado: .profissional).contains("O turno ficou descoberto"))
        #expect(!TextosDoCancelamento.desfecho(.posicao(resultado), lado: .profissional).lowercased().contains("notifica"))
    }

    @Test func desfechoReabertoDizQueAVagaVoltouAFila() throws {
        let reaberto = ResultadoCancelamento(posicaoID: posicaoID, falta: false, reaberta: true, novaPosicaoID: UUID())
        #expect(TextosDoCancelamento.desfecho(.posicao(reaberto), lado: .profissional) == "Turno cancelado. A vaga voltou a ser oferecida a outros profissionais.")
        #expect(TextosDoCancelamento.desfecho(.posicao(reaberto), lado: .contratante) == "Posição cancelada. Ela voltou a ser oferecida a outros profissionais.")
        let vaga = VagaCancelada(vagaID: UUID(), estado: .cancelada, posicoesCanceladas: 2)
        #expect(TextosDoCancelamento.desfecho(.vaga(vaga), lado: .contratante) == "Vaga cancelada. Os profissionais confirmados foram avisados.")
    }

    @Test func posicaoNaoCancelavelEVagaEncerradaTemMensagemPropria() async throws {
        let (posicao, _) = try modelo(inicioEm: 30, resposta: .failure(ErroDaApi(codigo: .posicaoNaoCancelavel)))
        posicao.motivo = .saude
        await posicao.confirmar()
        #expect(posicao.estado == .falha(TextosDoCancelamento.posicaoNaoCancelavel))
        // A falha não trava a folha: dá para tentar de novo.
        #expect(posicao.podeConfirmar)

        let (vaga, _) = try modelo(lado: .contratante, alvo: .vaga(id: UUID()), inicioEm: 30, resposta: .failure(ErroDaApi(codigo: .vagaEncerrada)))
        vaga.motivo = .movimentoMenor
        await vaga.confirmar()
        #expect(vaga.estado == .falha(TextosDoCancelamento.vagaJaFechada))
    }

    @Test func motivoRecusadoPeloFiltroPedeParaReescrever() async throws {
        let recusa = ErroDaApi(codigo: .campoInvalido, detalhes: "motivo")
        let (posicao, _) = try modelo(inicioEm: 30, resposta: .failure(recusa))
        posicao.motivo = .saude
        await posicao.confirmar()
        #expect(posicao.estado == .falha(TextosDoCancelamento.motivoRecusado))
        #expect(posicao.podeConfirmar)

        let (vaga, _) = try modelo(lado: .contratante, alvo: .vaga(id: UUID()), inicioEm: 30, resposta: .failure(recusa))
        vaga.motivo = .movimentoMenor
        await vaga.confirmar()
        #expect(vaga.estado == .falha(TextosDoCancelamento.motivoRecusado))

        // O mesmo código em outro campo continua na mensagem geral.
        #expect(TextosDoCancelamento.falha(ErroDaApi(codigo: .campoInvalido, detalhes: "posicao_id")) != TextosDoCancelamento.motivoRecusado)
    }

    // MARK: Sem rede (critério 5)

    @Test func semRedeEntraNaFilaComMotivoEAlvoEADizQueSeraEnviado() async throws {
        let fila = FilaDeAcoesMemoria()
        var recebido: DesfechoDoCancelamento?
        let (viewModel, _) = try modelo(inicioEm: 30, fila: fila, resposta: .failure(ErroDaApi(codigo: .semRede))) { recebido = $0 }
        viewModel.motivo = .imprevistoPessoal
        await viewModel.confirmar()
        #expect(viewModel.estado == .concluido(.naFila))
        #expect(recebido == .naFila)
        #expect(TextosDoCancelamento.desfecho(.naFila, lado: .profissional) == "Sem conexão. O cancelamento será enviado quando a internet voltar.")

        let pendentes = await fila.itens
        #expect(pendentes.count == 1)
        let acao = try #require(pendentes.first)
        #expect(acao.tipo == .cancelamentoPosicao)
        #expect(acao.alvoID == posicaoID)
        #expect(acao.turnoID == turnoID)
        #expect(acao.motivo == "Imprevisto pessoal")
        #expect(acao.instanteDoToque == agora)
        #expect(await CancelamentoViewModel.pendenteNaFila(fila, alvo: .posicao(id: posicaoID, turnoID: turnoID)))
        #expect(await !CancelamentoViewModel.pendenteNaFila(fila, alvo: .vaga(id: posicaoID)))
    }

    @Test func vagaSemRedeEntraNaFilaComoCancelamentoDeVaga() async throws {
        let fila = FilaDeAcoesMemoria()
        let vagaID = UUID()
        let (viewModel, _) = try modelo(lado: .contratante, alvo: .vaga(id: vagaID), inicioEm: 30, fila: fila, resposta: .failure(ErroDaApi(codigo: .semRede)))
        viewModel.motivo = .mudancaDePlanos
        await viewModel.confirmar()
        #expect(viewModel.estado == .concluido(.naFila))
        let acao = try #require(await fila.itens.first)
        #expect(acao.tipo == .cancelamentoVaga)
        #expect(acao.alvoID == vagaID)
        #expect(acao.turnoID == nil)
    }

    @Test func semRedeESemFilaAvisaQueNaoFoiEnviado() async throws {
        let (viewModel, _) = try modelo(inicioEm: 30, resposta: .failure(ErroDaApi(codigo: .semRede)))
        viewModel.motivo = .saude
        await viewModel.confirmar()
        #expect(viewModel.estado == .falha(TextosDoCancelamento.semRedeSemFila))
    }

    @Test func filaQueFalhaAoGuardarAvisaEFicaPronta() async throws {
        let fila = FilaDeAcoesMemoria()
        await fila.fazerFalhar()
        let (viewModel, _) = try modelo(inicioEm: 30, fila: fila, resposta: .failure(ErroDaApi(codigo: .semRede)))
        viewModel.motivo = .saude
        await viewModel.confirmar()
        #expect(viewModel.estado == .falha(TextosDoCancelamento.falhaAoGuardar))
    }
}
