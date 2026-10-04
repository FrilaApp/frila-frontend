import Foundation
import FrilaDominio
import Observation

@MainActor @Observable
public final class MeuTurnoViewModel {
    public let turno: Turno
    public private(set) var recusasDaFila: [AcaoRecusada] = []
    public private(set) var contato: Contato?
    public private(set) var contatoExpirado: Bool
    public private(set) var responsavelLocal: String?
    public private(set) var carregandoContato: Bool = false
    /// Check-in e check-out (#17). `nil` onde não há leitor de localização, como nas prévias.
    public let presenca: PresencaDoTurnoViewModel?

    private var avaliacaoEnviada: Avaliacao?
    private var respostaPendente: Bool?
    /// UserDefaults não participa de Observation: a releitura invalida os derivados da reserva.
    private var revisaoDaReserva = 0
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

    /// Só a posição confirmada e antes do fim previsto pode ser cancelada (RN12). Depois do
    /// início ainda pode: o aviso da folha diz que o turno fica descoberto.
    public var podeCancelar: Bool {
        guard permiteAcoesDoTurno, !cancelamentoNaFila else { return false }
        guard turno.estado == nil || turno.estado == .confirmada else { return false }
        return turno.vaga.periodo.fim > relogio.agora
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
    private let api: any ApiCliente
    private let filaDeAcoes: (any FilaDeAcoes)?
    private let armazenamentoAvaliacoes: any ArmazenamentoAvaliacoes
    private let relogio: any Relogio

    public init(
        turno: Turno,
        api: any ApiCliente,
        contaID: UUID? = nil,
        fila: (any FilaDeAcoes)? = nil,
        armazenamentoAvaliacoes: any ArmazenamentoAvaliacoes = UserDefaultsArmazenamentoAvaliacoes(),
        relogio: any Relogio = RelogioDoSistema(),
        presenca: PresencaDoTurnoViewModel? = nil,
        aoAvaliar: (() -> Void)? = nil,
        aoCancelar: (() -> Void)? = nil
    ) {
        self.turno = turno
        self.aoAvaliar = aoAvaliar
        self.aoCancelar = aoCancelar
        self.api = api
        self.contaID = contaID
        self.filaDeAcoes = fila
        self.armazenamentoAvaliacoes = armazenamentoAvaliacoes
        self.relogio = relogio
        self.presenca = turno.cancelado ? nil : presenca

        if turno.cancelado {
            self.contato = nil
            self.contatoExpirado = false
        } else if let c = turno.contato {
            let visivel = c.estaVisivel(em: relogio.agora) && turno.contatoVisivel(em: relogio.agora)
            self.contato = visivel ? c : nil
            self.contatoExpirado = !visivel
        } else {
            let visivel = turno.contatoVisivel(em: relogio.agora)
            self.contato = nil
            self.contatoExpirado = !visivel
        }
    }

    public var podeAvaliar: Bool {
        // Critério 1: a avaliação só aparece depois do fim previsto e com presença verificada (RN07).
        guard permiteAcoesDoTurno, contaID != nil else { return false }
        guard turno.verificacao == .verificado else { return false }
        guard turno.vaga.periodo.fim <= relogio.agora else { return false }
        return !turno.servidorInformaAvaliacao || turno.podeAvaliar || jaAvaliado
    }

    public var respostaAvaliacao: Bool? {
        _ = revisaoDaReserva
        if let avaliacao = avaliacaoEnviada ?? turno.avaliacao { return avaliacao.resposta }
        if let respostaPendente { return respostaPendente }
        guard let contaID, armazenamentoAvaliacoes.podeUsarReserva(para: turno, contaID: contaID) else { return nil }
        return armazenamentoAvaliacoes.resposta(para: turno.id, contaID: contaID)
    }

    public var jaAvaliado: Bool {
        _ = revisaoDaReserva
        if avaliacaoEnviada != nil || turno.avaliacao != nil || respostaPendente != nil { return true }
        guard let contaID, armazenamentoAvaliacoes.podeUsarReserva(para: turno, contaID: contaID) else { return false }
        return armazenamentoAvaliacoes.jaRegistrada(para: turno.id, contaID: contaID) || (!turno.servidorInformaAvaliacao && !turno.podeAvaliar && podeAvaliar)
    }

    public func criarAvaliacaoViewModel() -> AvaliacaoTurnoViewModel? {
        guard permiteAcoesDoTurno, let contaID else { return nil }
        return AvaliacaoTurnoViewModel(
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
        if let nome = contato?.nome, !nome.isEmpty {
            return nome
        }
        return turno.contraparte.nome
    }

    public var urlWhatsApp: URL? {
        guard permiteAcoesDoTurno, let contato = contato, !contatoExpirado else { return nil }
        let formatador = FormatadorFrila()
        let dataFormatada = formatador.intervalo(turno.vaga.periodo)
        let mensagem = String(
            localized: "Olá! Sou o profissional do turno de \(turno.vaga.funcao) em \(dataFormatada) no \(turno.vaga.local).",
            bundle: bundleApresentacao
        )
        var componentes = URLComponents(url: contato.whatsappURL, resolvingAgainstBaseURL: false)
        componentes?.queryItems = [URLQueryItem(name: "text", value: mensagem)]
        return componentes?.url ?? contato.whatsappURL
    }

    public var urlMapas: URL? {
        var componentes = URLComponents(string: "https://maps.apple.com/")
        componentes?.queryItems = [URLQueryItem(name: "q", value: turno.vaga.local)]
        return componentes?.url
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
        if !turno.contatoVisivel(em: relogio.agora) {
            contato = nil
            contatoExpirado = true
            return
        }

        carregandoContato = true
        defer { carregandoContato = false }

        do {
            let novoContato = try await api.contatoDoTurno(id: turno.id)
            if novoContato.estaVisivel(em: relogio.agora) && turno.contatoVisivel(em: relogio.agora) {
                self.contato = novoContato
                self.contatoExpirado = false
            } else {
                self.contato = nil
                self.contatoExpirado = true
            }
        } catch let erro as ErroDaApi where erro.codigo == .contatoExpirado {
            self.contato = nil
            self.contatoExpirado = true
        } catch let erro as ErroDaApi where erro.codigo == .semRede {
            // Em modo avião, mantém o contato se ainda estiver dentro do prazo (RN10 / RNF06).
            if let c = self.contato ?? turno.contato, c.estaVisivel(em: relogio.agora), turno.contatoVisivel(em: relogio.agora) {
                self.contato = c
                self.contatoExpirado = false
            } else {
                self.contato = nil
                self.contatoExpirado = true
            }
        } catch {
            // Se houver outro erro, preserva o contato atual se ainda visível
            if let c = self.contato ?? turno.contato, !c.estaVisivel(em: relogio.agora) || !turno.contatoVisivel(em: relogio.agora) {
                self.contato = nil
                self.contatoExpirado = true
            }
        }

        // Tenta obter o responsável local detalhado da vaga
        if responsavelLocal == nil {
            if let vagaDetalhe = try? await api.detalheDaVaga(id: turno.vaga.id) {
                self.responsavelLocal = vagaDetalhe.responsavelLocal
                presenca?.definir(pontoDaVaga: vagaDetalhe.ponto)
            }
        }
    }
}
