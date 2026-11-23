package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import java.util.UUID
import kotlinx.serialization.Serializable

/** As ações que entram na fila sem rede (espelha `TipoAcaoPendente` do iOS, `Dominio/Cache.swift`). */
@Serializable
enum class TipoAcaoPendente {
    CHECKIN, CHECKOUT, AVALIACAO, PUBLICACAO_VAGA, REPUBLICACAO_VAGA, CANCELAMENTO_POSICAO, CANCELAMENTO_VAGA,
}

/**
 * Uma ação guardada para reenviar quando a rede voltar. [chave] é a de idempotência: nasce com a ação e vai igual em
 * todo reenvio. [instanteDoToque] é o ISO-8601 UTC do toque, não o do reenvio. [contaId] é a conta que criou a ação:
 * outra conta nunca a envia. Os campos opcionais são os de cada tipo (turno e distância no check-in/out, resposta
 * na avaliação, publicação, republicação, alvo e motivo nos cancelamentos).
 */
@Serializable
data class AcaoPendente(
    val tipo: TipoAcaoPendente,
    val contaId: String,
    val instanteDoToque: String,
    val id: String = UUID.randomUUID().toString(),
    val chave: String = UUID.randomUUID().toString(),
    val turnoId: String? = null,
    val distanciaMetros: Int? = null,
    val resposta: Boolean? = null,
    val publicacao: NovaVagaDto? = null,
    val republicacao: RepublicarVagaDto? = null,
    /** A posição (`CANCELAMENTO_POSICAO`) ou a vaga (`CANCELAMENTO_VAGA`) que o cancelamento mira. */
    val alvoId: String? = null,
    val motivo: String? = null,
)

/** Registro mínimo da recusa: sem formulário, sem localização e sem os detalhes do servidor. */
@Serializable
data class AcaoRecusada(
    val id: String,
    val tipo: TipoAcaoPendente,
    val contaId: String,
    val codigo: CodigoErroAPI,
    val turnoId: String? = null,
    val vagaId: String? = null,
    val estabelecimentoId: String? = null,
    val avisoReconhecido: Boolean = false,
) {
    constructor(acao: AcaoPendente, codigo: CodigoErroAPI) : this(
        id = acao.id, tipo = acao.tipo, contaId = acao.contaId, codigo = codigo, turnoId = acao.turnoId,
        vagaId = if (acao.tipo == TipoAcaoPendente.CANCELAMENTO_VAGA) acao.alvoId else acao.republicacao?.vagaId,
        estabelecimentoId = acao.publicacao?.estabelecimentoId,
    )
}
