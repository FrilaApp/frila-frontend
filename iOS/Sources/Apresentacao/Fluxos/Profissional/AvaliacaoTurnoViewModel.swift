import Foundation
import FrilaDominio
import Observation

/// Resposta local por conta e turno, disponível somente nesta instalação (RN07 / #22).
/// Chaves legadas sem autor não são reutilizadas.
public protocol ArmazenamentoAvaliacoes: Sendable {
    func resposta(para turnoID: UUID, contaID: UUID) -> Bool?
    func registradaEm(para turnoID: UUID, contaID: UUID) -> Date?
    func salvar(resposta: Bool, para turnoID: UUID, contaID: UUID)
    func jaRegistrada(para turnoID: UUID, contaID: UUID) -> Bool
    func registrarSemResposta(para turnoID: UUID, contaID: UUID)
    func remover(para turnoID: UUID, contaID: UUID)
    func limpar()
}

public extension ArmazenamentoAvaliacoes {
    func registradaEm(para turnoID: UUID, contaID: UUID) -> Date? { nil }

    func podeUsarReserva(para turno: Turno?, contaID: UUID) -> Bool {
        guard let turno, turno.servidorInformaAvaliacao else { return true }
        guard let leitura = turno.avaliacaoLidaEm else { return true }
        guard let voto = registradaEm(para: turno.id, contaID: contaID) else { return false }
        return voto > leitura
    }
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

    public func registradaEm(para turnoID: UUID, contaID: UUID) -> Date? {
        defaults.object(forKey: prefixo + contaID.uuidString + "_" + turnoID.uuidString + "_instante") as? Date
    }

    public func salvar(resposta: Bool, para turnoID: UUID, contaID: UUID) {
        let chave = prefixo + contaID.uuidString + "_" + turnoID.uuidString
        defaults.set(resposta, forKey: chave)
        defaults.set(Date(), forKey: chave + "_instante")
    }

    public func jaRegistrada(para turnoID: UUID, contaID: UUID) -> Bool {
        defaults.object(forKey: prefixo + contaID.uuidString + "_" + turnoID.uuidString) != nil
    }

    public func registrarSemResposta(para turnoID: UUID, contaID: UUID) {
        let chave = prefixo + contaID.uuidString + "_" + turnoID.uuidString
        defaults.set("registrada-sem-resposta", forKey: chave)
        defaults.set(Date(), forKey: chave + "_instante")
    }

    public func remover(para turnoID: UUID, contaID: UUID) {
        let chave = prefixo + contaID.uuidString + "_" + turnoID.uuidString
        defaults.removeObject(forKey: chave)
        defaults.removeObject(forKey: chave + "_instante")
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
    private var instantes: [UUID: [UUID: Date]] = [:]
    private var valores: [UUID: [UUID: Bool]]

    public init(valores: [UUID: [UUID: Bool]] = [:]) {
        self.valores = valores
    }

    public func resposta(para turnoID: UUID, contaID: UUID) -> Bool? {
        trava.withLock { valores[contaID]?[turnoID] }
    }

    public func registradaEm(para turnoID: UUID, contaID: UUID) -> Date? {
        trava.withLock { instantes[contaID]?[turnoID] }
    }

    public func salvar(resposta: Bool, para turnoID: UUID, contaID: UUID) {
        trava.withLock {
            valores[contaID, default: [:]][turnoID] = resposta
            instantes[contaID, default: [:]][turnoID] = Date()
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
            instantes[contaID, default: [:]][turnoID] = Date()
        }
    }

    public func remover(para turnoID: UUID, contaID: UUID) {
        trava.withLock {
            valores[contaID]?[turnoID] = nil
            instantes[contaID]?[turnoID] = nil
            semResposta[contaID]?.remove(turnoID)
        }
    }

    public func limpar() {
        trava.withLock {
            valores.removeAll()
            instantes.removeAll()
            semResposta.removeAll()
        }
    }
}

@MainActor @Observable
public final class AvaliacaoTurnoViewModel {
    public let turnoID: UUID
    public let contaID: UUID
    public private(set) var turno: Turno?
    public let pergunta: String
    public let explicacao: String

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
    private let repositorioTurnos: (any TurnoRepositorio)?
    private let aoEnfileirar: ((Bool) -> Void)?
    private let aoAvaliar: ((Avaliacao) -> Void)?
    private var acaoOfflineID: UUID?
    private var recusaExibidaID: UUID?

    public init(
        turnoID: UUID,
        contaID: UUID,
        turno: Turno? = nil,
        api: any ApiCliente,
        fila: (any FilaDeAcoes)? = nil,
        armazenamento: any ArmazenamentoAvaliacoes = UserDefaultsArmazenamentoAvaliacoes(),
        relogio: any Relogio = RelogioDoSistema(),
        pergunta: String? = nil,
        explicacao: String? = nil,
        aoAvaliar: ((Avaliacao) -> Void)? = nil,
        aoEnfileirar: ((Bool) -> Void)? = nil,
        repositorioTurnos: (any TurnoRepositorio)? = nil
    ) {
        self.turnoID = turnoID
        self.contaID = contaID
        self.turno = turno
        self.api = api
        self.fila = fila
        self.armazenamento = armazenamento
        self.relogio = relogio
        self.aoAvaliar = aoAvaliar
        self.aoEnfileirar = aoEnfileirar
        self.repositorioTurnos = repositorioTurnos
        self.pergunta = pergunta ?? TextosDoProfissional.Avaliacao.perguntaProfissional
        self.explicacao = explicacao ?? TextosDoProfissional.Avaliacao.explicacao

        if let avaliacao = turno?.avaliacao {
            self.respostaAtual = avaliacao.resposta
            self.jaAvaliado = true
        } else if !armazenamento.podeUsarReserva(para: turno, contaID: contaID) {
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
        if turno == nil, let repositorioTurnos {
            turno = try? await repositorioTurnos.ler().turnos.first { $0.id == turnoID }
            if turno?.servidorInformaAvaliacao == true {
                respostaAtual = nil
                jaAvaliado = false
            }
        }
        if let avaliacao = turno?.avaliacao {
            respostaAtual = avaliacao.resposta
            jaAvaliado = true
            enfileiradoOffline = false
            mensagemDeSucesso = nil
            return
        }
        // A consulta ocorre também com resposta local: pendente não é confirmação do servidor.
        let pendentes = try? await fila?.pendentes()
        let estavaEnfileirado = enfileiradoOffline
        let recusa = try? await fila?.recusadas().first {
            $0.tipo == .avaliacao && $0.turnoID == turnoID
                && ($0.contaID == contaID || $0.id == acaoOfflineID)
        }
        enfileiradoOffline = false
        if armazenamento.podeUsarReserva(para: turno, contaID: contaID),
           armazenamento.jaRegistrada(para: turnoID, contaID: contaID),
           armazenamento.resposta(para: turnoID, contaID: contaID) == nil {
            // Um 409 no reenvio não pode ser sobrescrito pela resposta recusada da fila.
            respostaAtual = nil
            jaAvaliado = true
            mensagemDeSucesso = nil
        } else if let pendente = pendentes?.first(where: {
            $0.tipo == .avaliacao && $0.turnoID == turnoID && $0.contaID == contaID
        }), let respostaPendente = pendente.resposta {
            acaoOfflineID = pendente.id
            respostaAtual = respostaPendente
            jaAvaliado = true
            enfileiradoOffline = true
            mensagemDeSucesso = TextosDoProfissional.Avaliacao.avaliadoOffline
            if armazenamento.resposta(para: turnoID, contaID: contaID) == nil {
                armazenamento.salvar(resposta: respostaPendente, para: turnoID, contaID: contaID)
            }
        } else if let recusa {
            // A reserva pode ainda aguardar o callback do sincronizador. O recibo vale também
            // em um modelo novo; reler o mesmo aviso não apaga uma nova seleção da pessoa.
            if recusaExibidaID != recusa.id { respostaAtual = nil }
            recusaExibidaID = recusa.id
            jaAvaliado = turno?.podeAvaliar == false
            sucesso = false
            mensagemDeSucesso = nil
            mensagemDeErro = TextosDaFila.texto(.avaliacao)
        } else if (armazenamento.podeUsarReserva(para: turno, contaID: contaID) || sucesso),
                  let gravada = armazenamento.resposta(para: turnoID, contaID: contaID) {
            respostaAtual = gravada
            jaAvaliado = true
            mensagemDeSucesso = nil
        } else if !armazenamento.jaRegistrada(para: turnoID, contaID: contaID),
                  estavaEnfileirado || !sucesso {
            if estavaEnfileirado { respostaAtual = nil }
            jaAvaliado = turno?.podeAvaliar == false
            sucesso = false
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
            acaoOfflineID = nil
            respostaAtual = avaliacao.resposta
            aoAvaliar?(avaliacao)
            armazenamento.salvar(resposta: avaliacao.resposta, para: turnoID, contaID: contaID)
            jaAvaliado = true
            sucesso = true
            mensagemDeSucesso = TextosDoProfissional.Avaliacao.avaliadoSucesso
            try? await fila?.resolverRecusas(AcaoPendente(
                tipo: .avaliacao, turnoID: turnoID, contaID: contaID,
                instanteDoToque: relogio.agora, chave: UUID()
            ))
            return true
        } catch let erro as ErroDaApi where erro.codigo == .semRede {
            return await enfileirarOfflineSePossivel(resposta: resposta, erroOriginal: erro)
        } catch is URLError {
            return await enfileirarOfflineSePossivel(resposta: resposta, erroOriginal: ErroDaApi(codigo: .semRede))
        } catch let erro as ErroDaApi where erro.codigo == .avaliacaoJaRegistrada {
            jaAvaliado = true
            // O conflito não apaga uma resposta conhecida, nem grava a tentativa recusada.
            respostaAtual = armazenamento.resposta(para: turnoID, contaID: contaID)
            if let conhecida = respostaAtual {
                armazenamento.salvar(resposta: conhecida, para: turnoID, contaID: contaID)
            } else {
                armazenamento.registrarSemResposta(para: turnoID, contaID: contaID)
            }
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
            let primeiraAcao = try await fila.pendentes().first(where: {
                $0.tipo == .avaliacao && $0.turnoID == turnoID && $0.contaID == contaID
            })
            let primeira = primeiraAcao?.resposta ?? resposta
            acaoOfflineID = primeiraAcao?.id ?? acao.id
            respostaAtual = primeira
            aoEnfileirar?(primeira)
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
