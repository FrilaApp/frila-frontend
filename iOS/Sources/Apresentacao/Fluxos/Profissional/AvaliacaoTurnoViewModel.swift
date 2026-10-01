import Foundation
import FrilaDominio
import Observation

/// Persistência local para a resposta de avaliação dada por este aparelho (RN07 / Critério 2).
/// Garante que reabrir a tela mostre a resposta dada mesmo offline ou após reiniciar o app.
public protocol ArmazenamentoAvaliacoes: Sendable {
    func resposta(para turnoID: UUID) -> Bool?
    func salvar(resposta: Bool, para turnoID: UUID)
}

public final class UserDefaultsArmazenamentoAvaliacoes: ArmazenamentoAvaliacoes, @unchecked Sendable {
    private let defaults: UserDefaults
    private let prefixo = "frila_avaliacao_"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func resposta(para turnoID: UUID) -> Bool? {
        let chave = prefixo + turnoID.uuidString
        guard defaults.object(forKey: chave) != nil else { return nil }
        return defaults.bool(forKey: chave)
    }

    public func salvar(resposta: Bool, para turnoID: UUID) {
        let chave = prefixo + turnoID.uuidString
        defaults.set(resposta, forKey: chave)
    }
}

public final class ArmazenamentoAvaliacoesEmMemoria: ArmazenamentoAvaliacoes, @unchecked Sendable {
    private let trava = NSLock()
    private var valores: [UUID: Bool]

    public init(valores: [UUID: Bool] = [:]) {
        self.valores = valores
    }

    public func resposta(para turnoID: UUID) -> Bool? {
        trava.withLock { valores[turnoID] }
    }

    public func salvar(resposta: Bool, para turnoID: UUID) {
        trava.withLock { valores[turnoID] = resposta }
    }
}

@MainActor @Observable
public final class AvaliacaoTurnoViewModel {
    public let turnoID: UUID
    public let turno: Turno?
    public let pergunta: String

    public var resposta: Bool?
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

    public init(
        turnoID: UUID,
        turno: Turno? = nil,
        api: any ApiCliente,
        fila: (any FilaDeAcoes)? = nil,
        armazenamento: any ArmazenamentoAvaliacoes = UserDefaultsArmazenamentoAvaliacoes(),
        relogio: any Relogio = RelogioDoSistema(),
        pergunta: String? = nil
    ) {
        self.turnoID = turnoID
        self.turno = turno
        self.api = api
        self.fila = fila
        self.armazenamento = armazenamento
        self.relogio = relogio
        self.pergunta = pergunta ?? TextosDoProfissional.Avaliacao.perguntaProfissional

        if let gravada = armazenamento.resposta(para: turnoID) {
            self.resposta = gravada
            self.jaAvaliado = true
        } else if let turno, !turno.podeAvaliar {
            self.jaAvaliado = true
        } else {
            self.jaAvaliado = false
        }
    }

    public func carregar() async {
        if resposta == nil, let fila {
            if let pendente = try? await fila.pendentes().first(where: { $0.tipo == .avaliacao && $0.turnoID == turnoID }),
               let respostaPendente = pendente.resposta {
                self.resposta = respostaPendente
                self.jaAvaliado = true
                self.enfileiradoOffline = true
                self.armazenamento.salvar(resposta: respostaPendente, para: turnoID)
            }
        }
    }

    public func salvar() async -> Bool {
        guard !salvando else { return false }
        guard !jaAvaliado else { return false }
        guard let resposta else {
            mensagemDeErro = TextosDoProfissional.Avaliacao.erroSelecioneResposta
            return false
        }

        // Validação local quando o turno é conhecido (RN07)
        if let turno {
            if turno.verificacao != .verificado || turno.vaga.periodo.fim > relogio.agora {
                mensagemDeErro = TextosDoProfissional.Avaliacao.erroIndisponivel
                return false
            }
        }

        salvando = true
        mensagemDeErro = nil
        mensagemDeSucesso = nil
        defer { salvando = false }

        do {
            _ = try await api.avaliar(turnoID: turnoID, resposta: resposta)
            armazenamento.salvar(resposta: resposta, para: turnoID)
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
            armazenamento.salvar(resposta: resposta, para: turnoID)
            mensagemDeErro = TextosDoProfissional.Avaliacao.erroJaRegistrada
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
                instanteDoToque: relogio.agora,
                chave: UUID(),
                resposta: resposta
            )
            try await fila.enfileirar(acao)
            armazenamento.salvar(resposta: resposta, para: turnoID)
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
