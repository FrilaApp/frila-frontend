import Foundation
import Observation

/// Destinos do fluxo de quem contrata, a partir de Minhas vagas.
public enum RotaDoContratante: Hashable, Sendable {
    case vaga(UUID)
    case turno(turnoID: UUID)
}

/// Os avisos da casa que abrem uma tela (contrato 0.2.14). O `payload` do toque leva só o tipo e
/// ids; o que a tela mostra vem do painel.
public enum AvisoDoContratante: Equatable, Sendable {
    /// `checkin_manual_pendente`: o profissional fez check-in manual e espera a confirmação.
    case checkinManualPendente(turnoID: UUID)
    /// `atraso_15min`: 15 minutos do início sem check-in.
    case atraso(turnoID: UUID)
    /// `vaga_vazia`: posição aberta dentro da janela crítica.
    case vagaVazia(vagaID: UUID)

    /// Lê o `tipo` e os ids como o servidor os envia. Aviso de outro tipo, ou sem o id de que a
    /// tela precisa, não abre nada.
    public init?(tipo: String, payload: [String: String]) {
        func id(_ chave: String) -> UUID? { payload[chave].flatMap(UUID.init(uuidString:)) }
        switch tipo {
        case "checkin_manual_pendente":
            guard let turnoID = id("turno_id") else { return nil }
            self = .checkinManualPendente(turnoID: turnoID)
        case "atraso_15min":
            guard let turnoID = id("turno_id") else { return nil }
            self = .atraso(turnoID: turnoID)
        case "vaga_vazia":
            guard let vagaID = id("vaga_id") else { return nil }
            self = .vagaVazia(vagaID: vagaID)
        default:
            return nil
        }
    }
}

/// Pilha de navegação do contratante. É a entrada que o push (S2 #8) vai usar: `abrir` leva ao
/// turno ou à vaga do aviso e nunca confirma presença nem reabre vaga sozinho.
@MainActor @Observable
public final class RoteadorDoContratante {
    public var caminho: [RotaDoContratante] = []

    public init() {}

    public func abrir(_ aviso: AvisoDoContratante) {
        switch aviso {
        case let .checkinManualPendente(turnoID), let .atraso(turnoID):
            caminho = [.turno(turnoID: turnoID)]
        case let .vagaVazia(vagaID):
            caminho = [.vaga(vagaID)]
        }
    }

    public func abrirVaga(id: UUID) {
        caminho = [.vaga(id)]
    }

    public func voltarParaAsVagas() {
        caminho = []
    }
}
