import Foundation

/// Os dezoito avisos que o backend manda (`public.tipo_notificacao`). O valor é o `tipo` do payload.
public enum TipoDeAviso: String, CaseIterable, Sendable {
    case vaga
    case vagasAgrupadas = "vagas_agrupadas"
    case vagaSemElegiveis = "vaga_sem_elegiveis"
    case confirmacao
    case lembrete24h = "lembrete_24h"
    case lembrete3h = "lembrete_3h"
    case inicioSemCheckin = "inicio_sem_checkin"
    case atraso15min = "atraso_15min"
    case fimSemCheckout = "fim_sem_checkout"
    case vagaVazia = "vaga_vazia"
    case checkin
    case checkinManualPendente = "checkin_manual_pendente"
    case cancelamento
    case avaliacaoDisponivel = "avaliacao_disponivel"
    case suspensao
    case reativacao
    case candidaturaRecusada = "candidatura_recusada"
    case selecaoEncerrada = "selecao_encerrada"
}

/// O que o toque numa notificação traz. O servidor só deixa passar o `tipo`, quatro ids e `reaberta`
/// (RN15): nenhum nome, telefone ou endereço, e nada que diga de quem é o aviso. O que a tela mostra
/// vem do servidor, lido com a sessão de quem está no aparelho.
public struct AvisoDePush: Equatable, Sendable {
    public let tipo: TipoDeAviso
    public let vagaID: UUID?
    public let turnoID: UUID?
    public let posicaoID: UUID?

    public init(tipo: TipoDeAviso, vagaID: UUID? = nil, turnoID: UUID? = nil, posicaoID: UUID? = nil) {
        self.tipo = tipo
        self.vagaID = vagaID
        self.turnoID = turnoID
        self.posicaoID = posicaoID
    }

    /// Lê o `userInfo` da notificação: o FCM entrega os campos de `data` na raiz, todos como texto,
    /// ao lado do `aps` e das chaves dele. Sem `tipo`, ou com um tipo que este app não conhece, não
    /// há aviso; id que não é UUID é como id ausente.
    public init?(payload: [AnyHashable: Any]) {
        guard let texto = payload["tipo"] as? String, let tipo = TipoDeAviso(rawValue: texto) else { return nil }
        func id(_ chave: String) -> UUID? { (payload[chave] as? String).flatMap(UUID.init(uuidString:)) }
        self.init(tipo: tipo, vagaID: id("vaga_id"), turnoID: id("turno_id"), posicaoID: id("posicao_id"))
    }

    /// Os campos de `data` como o servidor os envia.
    public var payload: [String: String] {
        var campos = ["tipo": tipo.rawValue]
        campos["vaga_id"] = vagaID?.uuidString.lowercased()
        campos["turno_id"] = turnoID?.uuidString.lowercased()
        campos["posicao_id"] = posicaoID?.uuidString.lowercased()
        return campos
    }
}
