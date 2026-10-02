import Foundation
import FrilaDominio
import Observation

/// Resposta local por conta e turno, disponível somente nesta instalação (RN07 / #22).
/// Chaves legadas sem autor não são reutilizadas.
public protocol ArmazenamentoAvaliacoes: Sendable {
    func resposta(para turnoID: UUID, contaID: UUID) -> Bool?
    func salvar(resposta: Bool, para turnoID: UUID, contaID: UUID)
    func jaRegistrada(para turnoID: UUID, contaID: UUID) -> Bool
    func registrarSemResposta(para turnoID: UUID, contaID: UUID)
    func limpar()
}

public final class UserDefaultsArmazenamentoAvaliacoes: ArmazenamentoAvaliacoes, @unchecked Sendable {
    private let defaults: UserDefaults
    private let prefixo = "frila_avaliacao_"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func resposta(para turnoID: UUID, contaID: UUID) -> Bool? {
        let chave = prefixo + contaID.uuidString + "_" + turnoID.uuidString
        return defaults.object(forKey: chave) as? Bool
    }

    public func salvar(resposta: Bool, para turnoID: UUID, contaID: UUID) {
        let chave = prefixo + contaID.uuidString + "_" + turnoID.uuidString
        defaults.set(resposta, forKey: chave)
    }

    public func jaRegistrada(para turnoID: UUID, contaID: UUID) -> Bool {
        defaults.object(forKey: prefixo + contaID.uuidString + "_" + turnoID.uuidString) != nil
    }

    public func registrarSemResposta(para turnoID: UUID, contaID: UUID) {
        defaults.set("registrada-sem-resposta", forKey: prefixo + contaID.uuidString + "_" + turnoID.uuidString)
    }

    public func limpar() {
        for chave in defaults.dictionaryRepresentation().keys where chave.hasPrefix(prefixo) {
            defaults.removeObject(forKey: chave)
        }
    }
}

public final class ArmazenamentoAvaliacoesEmMemoria: ArmazenamentoAvaliacoes, @unchecked Sendable {
    private let trava = NSLock()
    private var semResposta: [UUID: Set<UUID>] = [:]
    private var valores: [UUID: [UUID: Bool]]

    public init(valores: [UUID: [UUID: Bool]] = [:]) {
        self.valores = valores
    }

    public func resposta(para turnoID: UUID, contaID: UUID) -> Bool? {
        trava.withLock { valores[contaID]?[turnoID] }
    }

    public func salvar(resposta: Bool, para turnoID: UUID, contaID: UUID) {
        trava.withLock {
            valores[contaID, default: [:]][turnoID] = resposta
            semResposta[contaID]?.remove(turnoID)
        }
    }

    public func jaRegistrada(para turnoID: UUID, contaID: UUID) -> Bool {
        trava.withLock { valores[contaID]?[turnoID] != nil || semResposta[contaID]?.contains(turnoID) == true }
    }

    public func registrarSemResposta(para turnoID: UUID, contaID: UUID) {
        trava.withLock {
            valores[contaID]?[turnoID] = nil
            semResposta[contaID, default: []].insert(turnoID)
        }
    }

    public func limpar() {
        trava.withLock {
            valores.removeAll()
            semResposta.removeAll()
        }
    }
}

@MainActor @Observable
public final class AvaliacaoTurnoViewModel {
    public let turnoID: UUID
    public let contaID: UUID
    public let turno: Turno?
    public let pergunta: String

    private var respostaAtual: Bool?
    public var resposta: Bool? {
        get { respostaAtual }
        set {
            guard !jaAvaliado, !salvando else { return }
            respostaAtual = newValue
        }
    }
    public private(set) var jaAvaliado: Bool
    public private(set) var salvando: Bool = false
    public private(set) var sucesso: Bool = false
    public private(set) var enfileiradoOffline: Bool = false
    public private(set) var mensagemDeErro: String?
    public private(set) var mensagemDeSucesso: String?

    private let api: any ApiCliente
    private let fila: (any FilaDeAcoes)?
    private let armazenamento: any ArmazenamentoAvaliacoes
    private let relogio: any Relogio
    private let aoAvaliar: ((Avaliacao) -> Void)?

    public init(
        turnoID: UUID,
        contaID: UUID,
        turno: Turno? = nil,
        api: any ApiCliente,
        fila: (any FilaDeAcoes)? = nil,
        armazenamento: any ArmazenamentoAvaliacoes = UserDefaultsArmazenamentoAvaliacoes(),
        relogio: any Relogio = RelogioDoSistema(),
        pergunta: String? = nil,
        aoAvaliar: ((Avaliacao) -> Void)? = nil
    ) {
        self.turnoID = turnoID
        self.contaID = contaID
        self.turno = turno
        self.api = api
        self.fila = fila
        self.armazenamento = armazenamento
        self.relogio = relogio
        self.aoAvaliar = aoAvaliar
        self.pergunta = pergunta ?? TextosDoProfissional.Avaliacao.perguntaProfissional

        if let avaliacao = turno?.avaliacao {
            self.respostaAtual = avaliacao.resposta
            self.jaAvaliado = true
        } else if turno?.servidorInformaAvaliacao == true {
            self.jaAvaliado = false
        } else if let gravada = armazenamento.resposta(para: turnoID, contaID: contaID) {
            self.respostaAtual = gravada
            self.jaAvaliado = true
        } else if armazenamento.jaRegistrada(para: turnoID, contaID: contaID) || turno?.podeAvaliar == false {
            self.jaAvaliado = true
        } else {
            self.jaAvaliado = false
        }
    }

    public func carregar() async {
        if let avaliacao = turno?.avaliacao {
            respostaAtual = avaliacao.resposta
            jaAvaliado = true
            enfileiradoOffline = false
            mensagemDeSucesso = nil
            return
        }
        // A consulta ocorre também com resposta local: pendente não é confirmação do servidor.
        let pendentes = try? await fila?.pendentes()
        enfileiradoOffline = false
        if turno?.servidorInformaAvaliacao != true,
           armazenamento.jaRegistrada(para: turnoID, contaID: contaID),
           armazenamento.resposta(para: turnoID, contaID: contaID) == nil {
            // Um 409 no reenvio não pode ser sobrescrito pela resposta recusada da fila.
            respostaAtual = nil
            jaAvaliado = true
            mensagemDeSucesso = nil
        } else if let pendente = pendentes?.first(where: {
            $0.tipo == .avaliacao && $0.turnoID == turnoID && $0.contaID == contaID
        }), let respostaPendente = pendente.resposta {
            respostaAtual = respostaPendente
            jaAvaliado = true
            enfileiradoOffline = true
            mensagemDeSucesso = TextosDoProfissional.Avaliacao.avaliadoOffline
            armazenamento.salvar(resposta: respostaPendente, para: turnoID, contaID: contaID)
        } else if (turno?.servidorInformaAvaliacao != true || sucesso),
                  let gravada = armazenamento.resposta(para: turnoID, contaID: contaID) {
            respostaAtual = gravada
            jaAvaliado = true
            mensagemDeSucesso = nil
        }
    }

    public func salvar() async -> Bool {
        guard !salvando else { return false }
        salvando = true
        defer { salvando = false }
        await carregar()
        guard !jaAvaliado else { return false }
        guard let resposta else {
            mensagemDeErro = TextosDoProfissional.Avaliacao.erroSelecioneResposta
            return false
        }

        // Validação local quando o turno é conhecido (RN07)
        if let turno {
            if turno.cancelado || turno.verificacao != .verificado || turno.vaga.periodo.fim > relogio.agora {
                mensagemDeErro = TextosDoProfissional.Avaliacao.erroIndisponivel
                return false
            }
        }

        mensagemDeErro = nil
        mensagemDeSucesso = nil

        do {
            let avaliacao = try await api.avaliar(turnoID: turnoID, resposta: resposta)
            respostaAtual = avaliacao.resposta
            aoAvaliar?(avaliacao)
            armazenamento.salvar(resposta: avaliacao.resposta, para: turnoID, contaID: contaID)
            jaAvaliado = true
            sucesso = true
            mensagemDeSucesso = TextosDoProfissional.Avaliacao.avaliadoSucesso
            return true
        } catch let erro as ErroDaApi where erro.codigo == .semRede {
            return await enfileirarOfflineSePossivel(resposta: resposta, erroOriginal: erro)
        } catch is URLError {
            return await enfileirarOfflineSePossivel(resposta: resposta, erroOriginal: ErroDaApi(codigo: .semRede))
        } catch let erro as ErroDaApi where erro.codigo == .avaliacaoJaRegistrada {
            jaAvaliado = true
            respostaAtual = nil
            armazenamento.registrarSemResposta(para: turnoID, contaID: contaID)
            mensagemDeErro = nil
            return false
        } catch let erro as ErroDaApi where erro.codigo == .avaliacaoIndisponivel {
            mensagemDeErro = TextosDoProfissional.Avaliacao.erroIndisponivel
            return false
        } catch let erro as ErroDaApi {
            mensagemDeErro = MensagemDoErroAPI.texto(erro)
            return false
        } catch {
            mensagemDeErro = TextosDoProfissional.Avaliacao.erroGenerico
            return false
        }
    }

    private func enfileirarOfflineSePossivel(resposta: Bool, erroOriginal: ErroDaApi) async -> Bool {
        guard let fila else {
            mensagemDeErro = MensagemDoErroAPI.texto(erroOriginal)
            return false
        }
        do {
            let acao = AcaoPendente(
                tipo: .avaliacao,
                turnoID: turnoID,
                contaID: contaID,
                instanteDoToque: relogio.agora,
                chave: UUID(),
                resposta: resposta
            )
            try await fila.enfileirar(acao)
            // Se outro modelo enfileirou antes, prevalece a primeira resposta da fila.
            let primeira = try await fila.pendentes().first(where: {
                $0.tipo == .avaliacao && $0.turnoID == turnoID && $0.contaID == contaID
            })?.resposta ?? resposta
            respostaAtual = primeira
            armazenamento.salvar(resposta: primeira, para: turnoID, contaID: contaID)
            jaAvaliado = true
            sucesso = true
            enfileiradoOffline = true
            mensagemDeSucesso = TextosDoProfissional.Avaliacao.avaliadoOffline
            return true
        } catch {
            mensagemDeErro = MensagemDoErroAPI.texto(erroOriginal)
            return false
        }
    }
}
