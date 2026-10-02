import Foundation
import FrilaDominio
import Observation

@MainActor @Observable
public final class MeuTurnoViewModel {
    public let turno: Turno
    public private(set) var contato: Contato?
    public private(set) var contatoExpirado: Bool
    public private(set) var responsavelLocal: String?
    public private(set) var carregandoContato: Bool = false
    /// Check-in e check-out (#17). `nil` onde não há leitor de localização, como nas prévias.
    public let presenca: PresencaDoTurnoViewModel?

    private var avaliacaoEnviada: Avaliacao?

    public var cancelado: Bool { turno.cancelado }
    public var permiteAcoesDoTurno: Bool { !cancelado }

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
        presenca: PresencaDoTurnoViewModel? = nil
    ) {
        self.turno = turno
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
        if let avaliacao = avaliacaoEnviada ?? turno.avaliacao { return avaliacao.resposta }
        guard !turno.servidorInformaAvaliacao, let contaID else { return nil }
        return armazenamentoAvaliacoes.resposta(para: turno.id, contaID: contaID)
    }

    public var jaAvaliado: Bool {
        if avaliacaoEnviada != nil || turno.avaliacao != nil { return true }
        guard !turno.servidorInformaAvaliacao, let contaID else { return false }
        return armazenamentoAvaliacoes.jaRegistrada(para: turno.id, contaID: contaID) || (!turno.podeAvaliar && podeAvaliar)
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
            aoAvaliar: { [weak self] avaliacao in self?.avaliacaoEnviada = avaliacao }
        )
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

    public func carregar() async {
        guard permiteAcoesDoTurno else { return }
        await presenca?.restaurarPendentes()
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
