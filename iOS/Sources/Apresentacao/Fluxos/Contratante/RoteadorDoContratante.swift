import Foundation
import FrilaDominio
import Observation

/// Destinos do fluxo de quem contrata, a partir de Minhas vagas.
public enum RotaDoContratante: Hashable, Sendable {
    case vaga(UUID)
    case turno(turnoID: UUID)
}

/// Os avisos que chegam a quem opera a casa e a tela que cada um abre (contrato 0.2.14). O `payload`
/// do toque leva só o tipo e ids; o que a tela mostra vem do painel, lido com a sessão de quem está
/// no aparelho.
public enum AvisoDoContratante: Equatable, Sendable {
    /// `checkin_manual_pendente`: o profissional fez check-in manual e espera a confirmação.
    case checkinManualPendente(turnoID: UUID)
    /// `atraso_15min`: 15 minutos do início sem check-in.
    case atraso(turnoID: UUID)
    /// `vaga_vazia`: posição aberta dentro da janela crítica.
    case vagaVazia(vagaID: UUID)
    /// Os avisos que só informam sobre um turno: `confirmacao`, `lembrete_24h`, `lembrete_3h`,
    /// `checkin`, `fim_sem_checkout` e `avaliacao_disponivel`.
    case turno(turnoID: UUID)
    /// Os avisos que só informam sobre uma vaga: `vaga_sem_elegiveis`, `cancelamento` e
    /// `selecao_encerrada`.
    case vaga(vagaID: UUID)

    /// Lê o `tipo` e os ids como o servidor os envia. Aviso que não é para a casa, ou sem o id de
    /// que a tela precisa, não abre nada.
    public init?(tipo: String, payload: [String: String]) {
        func id(_ chave: String) -> UUID? { payload[chave].flatMap(UUID.init(uuidString:)) }
        switch TipoDeAviso(rawValue: tipo) {
        case .checkinManualPendente:
            guard let turnoID = id("turno_id") else { return nil }
            self = .checkinManualPendente(turnoID: turnoID)
        case .atraso15min:
            guard let turnoID = id("turno_id") else { return nil }
            self = .atraso(turnoID: turnoID)
        case .vagaVazia:
            guard let vagaID = id("vaga_id") else { return nil }
            self = .vagaVazia(vagaID: vagaID)
        case .confirmacao, .lembrete24h, .lembrete3h, .checkin, .fimSemCheckout, .avaliacaoDisponivel:
            guard let turnoID = id("turno_id") else { return nil }
            self = .turno(turnoID: turnoID)
        case .vagaSemElegiveis, .cancelamento, .selecaoEncerrada:
            guard let vagaID = id("vaga_id") else { return nil }
            self = .vaga(vagaID: vagaID)
        case .vaga, .vagasAgrupadas, .inicioSemCheckin, .candidaturaRecusada, .suspensao, .reativacao, nil:
            // Os quatro primeiros são do profissional; suspensão e reativação são da conta, e quem
            // as trata é o `RoteadorDePush`.
            return nil
        }
    }
}

/// Pilha de navegação do contratante. É a entrada que o push (#8) usa: `abrir` leva ao turno ou à
/// vaga do aviso e nunca confirma presença nem reabre vaga sozinho.
@MainActor @Observable
public final class RoteadorDoContratante {
    public var caminho: [RotaDoContratante] = []
    /// Conta os avisos abertos: a tela relê o painel a cada um, porque o aviso diz que algo mudou.
    public private(set) var avisosAbertos = 0

    public init() {}

    public func abrir(_ aviso: AvisoDoContratante) {
        switch aviso {
        case let .checkinManualPendente(turnoID), let .atraso(turnoID), let .turno(turnoID):
            caminho = [.turno(turnoID: turnoID)]
        case let .vagaVazia(vagaID), let .vaga(vagaID):
            caminho = [.vaga(vagaID)]
        }
        avisosAbertos += 1
    }

    public func abrirVaga(id: UUID) {
        caminho = [.vaga(id)]
    }

    public func voltarParaAsVagas() {
        caminho = []
    }
}
