import Foundation
import FrilaDominio
import Observation

@MainActor @Observable
public final class MeuTurnoViewModel {
    /// A leitura de `meus_turnos` de quando a tela abriu; relida quando o fim previsto passa com a
    /// tela aberta (ver `aguardarLiberacaoDaAvaliacao`).
    public private(set) var turno: Turno
    public private(set) var recusasDaFila: [AcaoRecusada] = []
    public private(set) var responsavelLocal: String?
    /// O que a casa escreveu nas observações da vaga (entrada, ponto de referência). Vem do detalhe
    /// da vaga, sem campo novo no servidor, e alimenta o "Como chegar".
    public private(set) var observacoesDaVaga: String?
    /// A carga do detalhe da vaga terminou (com ou sem sucesso): fim da medição de abertura (#73).
    public private(set) var detalheCarregado: Bool = false
    /// Check-in e check-out (#17). `nil` onde não há leitor de localização, como nas prévias.
    public let presenca: PresencaDoTurnoViewModel?

    private var avaliacaoEnviada: Avaliacao?
    private var respostaPendente: Bool?
    /// Um só view model da avaliação por turno. O destino do `NavigationLink` é reavaliado a cada
    /// redesenho desta tela (detalhe que chega, fila que muda), e um view model novo a cada redesenho
    /// perdia a resposta escolhida e desabilitava o "Enviar" enquanto a pessoa ainda estava na tela.
    private var avaliacaoViewModel: AvaliacaoTurnoViewModel?
    /// UserDefaults não participa de Observation: a releitura invalida os derivados da reserva.
    private var revisaoDaReserva = 0
    /// O relógio não participa de Observation: quem espera o fim previsto muda este número para a
    /// tela reavaliar `podeAvaliar` e o aviso de espera.
    private var revisaoDoRelogio = 0
    private let aoAvaliar: (() -> Void)?
    private let aoCancelar: (() -> Void)?

    /// O cancelamento feito nesta tela (#20): o turno passa a cancelado sem reler a lista.
    public private(set) var cancelamentoLocal: CancelamentoDoTurno?
    /// O que `cancelar_posicao` devolveu agora, para a tela dizer se a vaga reabriu.
    public private(set) var desfechoDoCancelamento: ResultadoCancelamento?
    /// O cancelamento ficou na fila offline: a tela avisa e não oferece cancelar de novo.
    public private(set) var cancelamentoNaFila = false

    public var cancelado: Bool { turno.cancelado || cancelamentoLocal != nil }
    public var permiteAcoesDoTurno: Bool { !cancelado }
    public var cancelamento: CancelamentoDoTurno? { cancelamentoLocal ?? (cancelado ? turno.cancelamento : nil) }

    public var temCheckin: Bool {
        if let presenca {
            return presenca.checkin != .naoFeito || turno.checkin != nil
        }
        return turno.checkin != nil
    }

    /// Só a posição confirmada e antes do fim previsto pode ser cancelada (RN12). Depois do
    /// início ainda pode: o aviso da folha diz que o turno fica descoberto. Com check-in, a API
    /// recusa o cancelamento (409 posicao_nao_cancelavel).
    public var podeCancelar: Bool {
        guard permiteAcoesDoTurno, !cancelamentoNaFila else { return false }
        guard turno.estado == nil || turno.estado == .confirmada else { return false }
        guard !temCheckin else { return false }
        return turno.vaga.periodo.fim > relogio.agora
    }

    // MARK: - Estou a caminho (US14)

    public private(set) var avisoACaminhoLocal: Date?
    public private(set) var avisandoACaminho: Bool = false
    public private(set) var mensagemErroACaminho: String?
    public private(set) var podeTentarAvisarDeNovo: Bool = false

    public var aCaminhoEm: Date? {
        turno.aCaminhoEm ?? avisoACaminhoLocal
    }

    /// No turno confirmado, dentro da janela (de 3 h antes até 15 min depois do início),
    /// sem check-in e ainda sem aviso (US14, RF12).
    public var podeAvisarACaminho: Bool {
        guard permiteAcoesDoTurno else { return false }
        guard turno.estado == nil || turno.estado == .confirmada else { return false }
        guard aCaminhoEm == nil else { return false }
        guard !temCheckin else { return false }
        let agora = relogio.agora
        let inicio = turno.vaga.periodo.inicio
        let limiteInferior = inicio.addingTimeInterval(-3 * 60 * 60)
        let limiteSuperior = inicio.addingTimeInterval(15 * 60)
        return agora >= limiteInferior && agora <= limiteSuperior
    }

    public var podeExibirBotaoACaminho: Bool {
        podeAvisarACaminho && !podeTentarAvisarDeNovo
    }

    public func avisarACaminho() async {
        guard !avisandoACaminho, podeAvisarACaminho || podeTentarAvisarDeNovo else { return }
        avisandoACaminho = true
        mensagemErroACaminho = nil
        podeTentarAvisarDeNovo = false
        defer { avisandoACaminho = false }

        do {
            let resultado = try await api.avisarACaminho(turnoID: turno.id)
            avisoACaminhoLocal = resultado.aCaminhoEm
        } catch let erro as ErroDaApi where erro.codigo == .aCaminhoForaDaJanela {
            mensagemErroACaminho = TextosDoProfissional.Turnos.erroACaminhoForaDaJanela
            podeTentarAvisarDeNovo = false
        } catch let erro as ErroDaApi where erro.codigo == .semRede {
            mensagemErroACaminho = TextosDoProfissional.Turnos.erroACaminhoSemRede
            podeTentarAvisarDeNovo = true
        } catch {
            mensagemErroACaminho = TextosDoProfissional.Turnos.erroACaminhoGenerico
            podeTentarAvisarDeNovo = true
        }
    }
    public var causaDoCancelamento: String? {
        cancelamento.map { TextosDoProfissional.Turnos.causaDoCancelamento($0.causa) }
    }
    public var faltaNoCancelamento: String? {
        cancelamento.map {
            $0.falta ? TextosDoProfissional.Turnos.cancelamentoComFalta : TextosDoProfissional.Turnos.cancelamentoSemFalta
        }
    }

    private let contaID: UUID?
    public let api: any ApiCliente
    private let filaDeAcoes: (any FilaDeAcoes)?
    private let armazenamentoAvaliacoes: any ArmazenamentoAvaliacoes
    private let relogio: any Relogio
    private let telemetria: RegistradorDeTelemetria?
    private var cacheLocal: (any CacheLocal)? { filaDeAcoes as? any CacheLocal }

    private let cache: CacheDeLeituras?

    public init(
        turno: Turno,
        api: any ApiCliente,
        contaID: UUID? = nil,
        fila: (any FilaDeAcoes)? = nil,
        armazenamentoAvaliacoes: any ArmazenamentoAvaliacoes = UserDefaultsArmazenamentoAvaliacoes(),
        relogio: any Relogio = RelogioDoSistema(),
        presenca: PresencaDoTurnoViewModel? = nil,
        aoAvaliar: (() -> Void)? = nil,
        aoCancelar: (() -> Void)? = nil,
        telemetria: RegistradorDeTelemetria? = nil,
        cache: CacheDeLeituras? = nil
    ) {
        self.cache = cache
        self.turno = turno
        self.aoAvaliar = aoAvaliar
        self.aoCancelar = aoCancelar
        self.api = api
        self.contaID = contaID
        self.filaDeAcoes = fila
        self.armazenamentoAvaliacoes = armazenamentoAvaliacoes
        self.relogio = relogio
        self.presenca = turno.cancelado ? nil : presenca
        self.telemetria = telemetria ?? RegistradorDeTelemetria(api: api)
    }

    public var podeAvaliar: Bool {
        _ = revisaoDoRelogio
        // Critério 1: a avaliação só aparece depois do fim previsto e com presença verificada (RN07).
        guard permiteAcoesDoTurno, contaID != nil else { return false }
        guard verificacaoDaPresenca == .verificado else { return false }
        guard turno.vaga.periodo.fim <= relogio.agora else { return false }
        return !turno.servidorInformaAvaliacao || turno.podeAvaliar || jaAvaliado
    }

    /// A presença como a tela a vê agora: o check-in feito aqui vale antes de o turno ser relido.
    private var verificacaoDaPresenca: Verificacao { presenca?.verificacao ?? turno.verificacao }

    private var checkoutFeito: Bool {
        if let presenca { return presenca.checkout != .naoFeito || turno.checkout != nil }
        return turno.checkout != nil
    }

    /// Quando a avaliação libera (o `fim` previsto), enquanto isso ainda está no futuro: presença
    /// verificada, check-out feito e nada avaliado por este lado. Sem presença verificada é `nil`,
    /// para não prometer o que não vai abrir. A tela mostra "A avaliação libera às HH:mm" no lugar
    /// do cartão.
    public var liberacaoDaAvaliacao: Date? {
        _ = revisaoDoRelogio
        guard permiteAcoesDoTurno, contaID != nil else { return nil }
        guard verificacaoDaPresenca == .verificado, checkoutFeito else { return nil }
        guard turno.avaliacao == nil, avaliacaoEnviada == nil, respostaPendente == nil else { return nil }
        let fim = turno.vaga.periodo.fim
        return fim > relogio.agora ? fim : nil
    }

    /// Espera o `fim` previsto com a tela aberta e então reavalia `podeAvaliar` e relê o turno, para
    /// o servidor confirmar `pode_avaliar`: o cartão aparece sem reabrir a tela. Cancelada com a tela
    /// (`.task`). `dormir` existe para o teste não esperar de verdade.
    public func aguardarLiberacaoDaAvaliacao(
        dormir: @Sendable (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) }
    ) async {
        guard permiteAcoesDoTurno, contaID != nil else { return }
        let espera = turno.vaga.periodo.fim.timeIntervalSince(relogio.agora)
        guard espera > 0 else { return }
        await dormir(espera)
        guard !Task.isCancelled else { return }
        revisaoDoRelogio += 1
        await reler()
    }

    /// Troca o turno pela leitura mais nova. Sem rede ou sem o turno na resposta, fica o que havia.
    private func reler() async {
        guard let lidos = try? await api.meusTurnos(), let atualizado = lidos.first(where: { $0.id == turno.id }) else { return }
        turno = atualizado
        revisaoDoRelogio += 1
    }

    public var respostaAvaliacao: Bool? {
        _ = revisaoDaReserva
        if let avaliacao = avaliacaoEnviada ?? turno.avaliacao { return avaliacao.resposta }
        if let respostaPendente { return respostaPendente }
        if avaliacaoDaFilaRecusada { return nil }
        guard let contaID, armazenamentoAvaliacoes.podeUsarReserva(para: turno, contaID: contaID) else { return nil }
        return armazenamentoAvaliacoes.resposta(para: turno.id, contaID: contaID)
    }

    public var jaAvaliado: Bool {
        _ = revisaoDaReserva
        if avaliacaoEnviada != nil || turno.avaliacao != nil || respostaPendente != nil { return true }
        if avaliacaoDaFilaRecusada { return false }
        guard let contaID, armazenamentoAvaliacoes.podeUsarReserva(para: turno, contaID: contaID) else { return false }
        return armazenamentoAvaliacoes.jaRegistrada(para: turno.id, contaID: contaID) || (!turno.servidorInformaAvaliacao && !turno.podeAvaliar && podeAvaliar)
    }

    private var avaliacaoDaFilaRecusada: Bool {
        recusasDaFila.contains { $0.tipo == .avaliacao && ($0.contaID == nil || $0.contaID == contaID) }
    }

    public func criarAvaliacaoViewModel() -> AvaliacaoTurnoViewModel? {
        guard permiteAcoesDoTurno, let contaID else { return nil }
        if let avaliacaoViewModel { return avaliacaoViewModel }
        let novo = AvaliacaoTurnoViewModel(
            turnoID: turno.id,
            contaID: contaID,
            turno: avaliacaoEnviada.map { turno.com(avaliacao: $0) } ?? turno,
            api: api,
            fila: filaDeAcoes,
            armazenamento: armazenamentoAvaliacoes,
            relogio: relogio,
            aoAvaliar: { [weak self] avaliacao in
                self?.avaliacaoEnviada = avaliacao
                self?.aoAvaliar?()
            },
            aoEnfileirar: { [weak self] resposta in self?.respostaPendente = resposta }
        )
        avaliacaoViewModel = novo
        return novo
    }

    /// A folha de cancelamento deste turno (#20). O desfecho volta para cá: a tela vira "Turno
    /// cancelado" na hora, e a lista é atualizada por `aoCancelar`.
    public func criarCancelamentoViewModel() -> CancelamentoViewModel? {
        guard podeCancelar else { return nil }
        return CancelamentoViewModel(
            lado: .profissional, posicaoID: turno.posicaoID, turnoID: turno.id, periodo: turno.vaga.periodo,
            api: api, relogio: relogio, fila: filaDeAcoes,
            aoConcluir: { [weak self] desfecho in self?.aplicar(desfecho) }
        )
    }

    private func aplicar(_ desfecho: DesfechoDoCancelamento) {
        switch desfecho {
        case let .posicao(resultado):
            desfechoDoCancelamento = resultado
            cancelamentoLocal = CancelamentoDoTurno(causa: .profissional, falta: resultado.falta, canceladaEm: relogio.agora)
            aoCancelar?()
        case .naFila:
            cancelamentoNaFila = true
        case .vaga:
            break
        }
    }

    public var quemRecebeExibicao: String {
        if let resp = responsavelLocal, !resp.isEmpty {
            return resp
        }
        return turno.contraparte.nome
    }

    public var urlMapas: URL? {
        var componentes = URLComponents(string: "https://maps.apple.com/")
        componentes?.queryItems = [URLQueryItem(name: "q", value: turno.vaga.local)]
        return componentes?.url
    }

    public func fecharAvisoDaFila(id: UUID) async {
        guard let filaDeAcoes else { return }
        do {
            let recusa = recusasDaFila.first { $0.id == id }
            try await filaDeAcoes.reconhecerRecusa(id: id)
            if recusa?.tipo == .avaliacao, let contaID, recusa?.contaID == contaID,
               avaliacaoEnviada == nil, turno.avaliacao == nil, respostaPendente == nil {
                armazenamentoAvaliacoes.remover(para: turno.id, contaID: contaID)
            }
            await carregarRecusasDaFila()
        } catch { /* Mantém o aviso se o reconhecimento não foi gravado. */ }
    }

    public func carregarRecusasDaFila() async {
        recusasDaFila = (try? await filaDeAcoes?.recusadas().filter { $0.turnoID == turno.id }) ?? []
        if let contaID, turno.avaliacao == nil {
            respostaPendente = try? await filaDeAcoes?.pendentes().first {
                $0.tipo == .avaliacao && $0.turnoID == turno.id && $0.contaID == contaID
            }?.resposta
        }
        await presenca?.restaurarPendentes()
        revisaoDaReserva += 1
    }

    public func carregar() async {
        await carregarRecusasDaFila()
        guard permiteAcoesDoTurno else { return }
        if await CancelamentoViewModel.pendenteNaFila(filaDeAcoes, alvo: .posicao(id: turno.posicaoID, turnoID: turno.id)) {
            cancelamentoNaFila = true
        }
        // O app não chama mais `contato_do_turno` nem lê o contato: o que o servidor ainda guardou de
        // aberturas antigas sai do aparelho (Fase 1 do contato fora do app).
        try? await cacheLocal?.removerContato(doTurno: turno.id)

        // O detalhe da vaga traz o responsável, o ponto e as observações do "Como chegar".
        let api = self.api
        let cache = self.cache
        let vagaID = turno.vaga.id
        let buscarDetalhe: Task<Vaga?, Never>? = responsavelLocal == nil
            ? Task {
                let buscar: @Sendable () async throws -> Vaga = { try await api.detalheDaVaga(id: vagaID) }
                return if let cache { try? await cache.detalhe(id: vagaID, buscar: buscar) } else { try? await buscar() }
            }
            : nil

        // Tenta obter o responsável local detalhado da vaga
        if responsavelLocal == nil {
            if let vagaDetalhe = await buscarDetalhe?.value {
                self.responsavelLocal = vagaDetalhe.responsavelLocal
                let texto = vagaDetalhe.observacoes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                self.observacoesDaVaga = texto.isEmpty ? nil : texto
                presenca?.definir(pontoDaVaga: vagaDetalhe.ponto)
            }
        }
        detalheCarregado = true
    }
}
