import Foundation
import FrilaDominio
import Observation

@MainActor @Observable
public final class ContaSuspensaViewModel: Identifiable {
    public private(set) var situacao: SituacaoDaConta?
    public private(set) var protocolo: Protocolo?
    public private(set) var carregando = false
    public var mostrarFormularioContestacao = false
    public var relato = ""
    public private(set) var enviandoContestacao = false
    public private(set) var mensagemErro: String?
    public private(set) var avisoExplicacao409: String?
    public private(set) var bloqueadoPor409 = false
    public private(set) var contaReativada = false

    private let relogio: any Relogio
    public let enderecos: EnderecosOficiais
    private let obterSituacao: @Sendable () async throws -> SituacaoDaConta
    private let enviarContestacaoAcao: @Sendable (String) async throws -> Protocolo
    private let aoReativar: () -> Void
    private let sair: () -> Void

    public var motivo: String {
        situacao?.suspensao?.motivo ?? ""
    }

    public var dataSuspensao: Date? {
        situacao?.suspensao?.desde
    }

    public var emAnalise: Bool {
        guard let protocolo, let hoje = DataCivil.deSaoPaulo(relogio.agora) else { return false }
        return hoje <= protocolo.prazoRespostaAte
    }

    public var mensagemDoProtocolo: String {
        emAnalise ? TextosContaSuspensa.mensagemEmAnalise : TextosContaSuspensa.mensagemAposPrazo(email: enderecos.emailSuporte)
    }

    public var podeContestar: Bool {
        protocolo == nil && !bloqueadoPor409 && !enviandoContestacao && !contaReativada
    }

    public var relatoValido: Bool {
        relato.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    public init(
        situacao: SituacaoDaConta? = nil,
        relogio: any Relogio = RelogioDoSistema(),
        enderecos: EnderecosOficiais = .padrao,
        obterSituacao: @escaping @Sendable () async throws -> SituacaoDaConta,
        enviarContestacaoAcao: @escaping @Sendable (String) async throws -> Protocolo,
        aoReativar: @escaping () -> Void = {},
        sair: @escaping () -> Void = {}
    ) {
        self.relogio = relogio
        self.enderecos = enderecos
        self.situacao = situacao
        self.protocolo = situacao?.suspensao?.contestacao
        self.obterSituacao = obterSituacao
        self.enviarContestacaoAcao = enviarContestacaoAcao
        self.aoReativar = aoReativar
        self.sair = sair
    }

    public convenience init(
        situacao: SituacaoDaConta? = nil,
        api: any ApiCliente,
        relogio: any Relogio = RelogioDoSistema(),
        enderecos: EnderecosOficiais = .padrao,
        aoReativar: @escaping () -> Void = {},
        sair: @escaping () -> Void = {}
    ) {
        self.init(
            situacao: situacao,
            relogio: relogio,
            enderecos: enderecos,
            obterSituacao: { try await api.situacaoDaConta() },
            enviarContestacaoAcao: { relato in try await api.contestarSuspensao(relato: relato) },
            aoReativar: aoReativar,
            sair: sair
        )
    }

    public func carregar() async {
        carregando = true
        defer { carregando = false }
        do {
            let novaSituacao = try await obterSituacao()
            self.situacao = novaSituacao
            if novaSituacao.estado == .ativa {
                contaReativada = true
                aoReativar()
                return
            }
            if let contestacao = novaSituacao.suspensao?.contestacao {
                self.protocolo = contestacao
                mostrarFormularioContestacao = false
            }
        } catch let erroApi as ErroDaApi {
            if erroApi.codigo == .semRede {
                mensagemErro = TextosContaSuspensa.erroSemRede
            } else {
                mensagemErro = TextosContaSuspensa.erroGenerico
            }
        } catch {
            mensagemErro = TextosContaSuspensa.erroGenerico
        }
    }

    public func abrirFormularioContestacao() {
        guard podeContestar else { return }
        mostrarFormularioContestacao = true
        mensagemErro = nil
    }

    public func cancelarFormularioContestacao() {
        mostrarFormularioContestacao = false
        mensagemErro = nil
    }

    public func enviarContestacao() async {
        let relatoLimpo = relato.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !relatoLimpo.isEmpty else {
            mensagemErro = TextosContaSuspensa.relatoObrigatorio
            return
        }
        guard relatoLimpo.count >= 10 else {
            mensagemErro = TextosContaSuspensa.relatoMinimo
            return
        }
        guard podeContestar else { return }

        enviandoContestacao = true
        mensagemErro = nil
        do {
            let novoProtocolo = try await enviarContestacaoAcao(relatoLimpo)
            self.protocolo = novoProtocolo
            self.mostrarFormularioContestacao = false
            enviandoContestacao = false
        } catch let erroApi as ErroDaApi {
            enviandoContestacao = false
            switch erroApi.codigo {
            case .contestacaoJaAberta:
                bloqueadoPor409 = true
                mostrarFormularioContestacao = false
                avisoExplicacao409 = TextosContaSuspensa.contestacaoJaExiste
                await carregar()
            case .semSuspensaoAtiva:
                contaReativada = true
                aoReativar()
            case .campoInvalido:
                mensagemErro = TextosContaSuspensa.relatoMinimo
            case .campoObrigatorio:
                mensagemErro = TextosContaSuspensa.relatoObrigatorio
            case .semRede:
                mensagemErro = TextosContaSuspensa.erroSemRede
            default:
                mensagemErro = TextosContaSuspensa.erroGenerico
            }
        } catch {
            enviandoContestacao = false
            mensagemErro = TextosContaSuspensa.erroGenerico
        }
    }

    public func executarSair() {
        sair()
    }
}
