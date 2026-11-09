import Foundation
import FrilaDominio
import Observation

/// O código de chegada que a casa mostra (contrato 0.2.68, desenho do check-in por código). Chama
/// `gerar_codigo_checkin` ao abrir e de novo quando o código vence. A contagem parte de `segundos_restantes`,
/// que o servidor conta na resposta, e anda pelo relógio monotônico do aparelho: o relógio de parede, que o
/// usuário pode mudar, não entra. O código nunca vai a log.
@MainActor @Observable
public final class CodigoDaCasaViewModel {
    public enum Estado: Equatable, Sendable {
        case carregando
        case mostrando(codigo: String)
        /// `codigo_bloqueado` `encerrado`: o caminho do código fechou para o turno; vale a confirmação manual.
        case encerrado
        /// A presença já foi verificada (`checkin_ja_confirmado`): a tela do turno se atualiza sozinha.
        case jaVerificado
        /// A chave `checkin_por_codigo` está desligada para a casa do turno: o cartão some.
        case indisponivel
        case falhou
    }

    public let turnoID: UUID
    public private(set) var estado: Estado = .carregando
    public private(set) var segundosRestantes = 0
    /// O código venceu e outro está sendo gerado: a tela mostra isso em vez de um código que não vale.
    public private(set) var renovando = false

    private let api: any ApiCliente
    private let agora: @MainActor () -> ContinuousClock.Instant
    private var venceEm: ContinuousClock.Instant?

    public init(turnoID: UUID, api: any ApiCliente, agora: @escaping @MainActor () -> ContinuousClock.Instant = { .now }) {
        self.turnoID = turnoID
        self.api = api
        self.agora = agora
    }

    /// Pede o código ao servidor (o mesmo, dentro da validade; um novo, vencido).
    public func carregar() async {
        do {
            let codigo = try await api.gerarCodigoCheckin(turnoID: turnoID)
            venceEm = agora() + .seconds(codigo.segundosRestantes)
            segundosRestantes = codigo.segundosRestantes
            estado = .mostrando(codigo: codigo.codigo)
        } catch let erro as ErroDaApi {
            venceEm = nil
            estado = Self.estado(para: erro)
        } catch {
            venceEm = nil
            estado = .falhou
        }
        renovando = false
    }

    /// Um passo da contagem (a tela chama a cada segundo): recalcula o que resta e, no zero, renova o código.
    public func passo() async {
        guard case .mostrando = estado, let venceEm else { return }
        let restante = agora().duration(to: venceEm)
        segundosRestantes = max(0, Int((restante / .seconds(1)).rounded(.up)))
        if segundosRestantes == 0, !renovando {
            renovando = true
            await carregar()
        }
    }

    public func tentarDeNovo() async {
        estado = .carregando
        await carregar()
    }

    /// "4:32": minutos e segundos que faltam.
    public static func formatar(segundos: Int) -> String {
        let total = max(0, segundos)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private static func estado(para erro: ErroDaApi) -> Estado {
        if erro.recursoDesligado { return .indisponivel }
        if erro.bloqueioDoCodigo != nil { return .encerrado }
        if erro.codigo == .checkinJaConfirmado { return .jaVerificado }
        return .falhou
    }
}
