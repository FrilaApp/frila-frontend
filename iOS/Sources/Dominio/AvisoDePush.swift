import Foundation

/// Os 28 avisos que o backend manda (`public.tipo_notificacao`, contrato 0.2.62). O valor é o `tipo` do payload.
public enum TipoDeAviso: String, CaseIterable, Sendable {
    case chamadaRecebida = "chamada_recebida"
    case chamadaLembrete = "chamada_lembrete"
    case chamadaAceita = "chamada_aceita"
    case chamadaRecusada = "chamada_recusada"
    case chamadaExpirada = "chamada_expirada"
    case chamadaCancelada = "chamada_cancelada"
    case chamadaEncerrada = "chamada_encerrada"
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
    /// 0.2.38 (decisão D6): lembrete à casa, uma vez por vaga, a 6 h ou menos do prazo de escolha
    /// e só com candidatura pendente.
    case selecaoLembrete = "selecao_lembrete"
    /// 0.2.54: a foto de perfil não foi publicada (`recusada` ou `nao_publicada`). Só traz `tipo` e `midia_id`.
    case midiaRecusada = "midia_recusada"
    /// 0.2.62: presença no turno não confirmada dentro do prazo (RN15, RN22). Leva `turno_id`.
    case turnoNaoVerificado = "turno_nao_verificado"
    /// 0.2.77: lembrete à casa 30 minutos antes do fim do turno, para vaga com check-in pendente de confirmação. Leva `vaga_id`.
    case lembrete30minFimTurno = "lembrete_30min_fim_turno"
    /// 0.2.77: lembrete à casa no fim do turno, para vaga com check-in pendente de confirmação. Leva `vaga_id`.
    case lembreteFimTurno = "lembrete_fim_turno"
}

/// Paridade direta com o schema TipoNotificacao do contrato OpenAPI.
public typealias TipoNotificacao = TipoDeAviso

/// O que o toque numa notificação traz. O servidor só deixa passar o `tipo`, quatro ids e `reaberta`
/// (RN15): nenhum nome, telefone ou endereço, e nada que diga de quem é o aviso. O que a tela mostra
/// vem do servidor, lido com a sessão de quem está no aparelho.
public struct AvisoDePush: Equatable, Sendable {
    public let tipo: TipoDeAviso
    public let vagaID: UUID?
    public let turnoID: UUID?
    public let posicaoID: UUID?
    public let chamadaID: UUID?

    public init(tipo: TipoDeAviso, vagaID: UUID? = nil, turnoID: UUID? = nil, posicaoID: UUID? = nil, chamadaID: UUID? = nil) {
        self.tipo = tipo
        self.vagaID = vagaID
        self.turnoID = turnoID
        self.posicaoID = posicaoID
        self.chamadaID = chamadaID
    }

    /// Lê o `userInfo` da notificação: o FCM entrega os campos de `data` na raiz, todos como texto,
    /// ao lado do `aps` e das chaves dele. Sem `tipo`, ou com um tipo que este app não conhece, não
    /// há aviso; id que não é UUID é como id ausente.
    public init?(payload: [AnyHashable: Any]) {
        guard let texto = payload["tipo"] as? String, let tipo = TipoDeAviso(rawValue: texto) else { return nil }
        func id(_ chave: String) -> UUID? { (payload[chave] as? String).flatMap(UUID.init(uuidString:)) }
        self.init(tipo: tipo, vagaID: id("vaga_id"), turnoID: id("turno_id"), posicaoID: id("posicao_id"), chamadaID: id("chamada_id"))
    }

    /// Os campos de `data` como o servidor os envia.
    public var payload: [String: String] {
        var campos = ["tipo": tipo.rawValue]
        campos["vaga_id"] = vagaID?.uuidString.lowercased()
        campos["turno_id"] = turnoID?.uuidString.lowercased()
        campos["posicao_id"] = posicaoID?.uuidString.lowercased()
        campos["chamada_id"] = chamadaID?.uuidString.lowercased()
        return campos
    }
}
