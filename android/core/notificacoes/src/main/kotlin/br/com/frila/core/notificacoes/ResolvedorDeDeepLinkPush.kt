package br.com.frila.core.notificacoes

/** Resolve somente destinos autorizados para abertura a partir de uma notificação FCM. */
object ResolvedorDeDeepLinkPush {

    private val UUID_REGEX = Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")

    fun resolver(notificacao: NotificacaoParaExibir): String? {
        if (notificacao.neutralizada) return null

        notificacao.chamadaId?.takeIf(String::isNotBlank)?.let { chamadaId ->
            return "frila://chamadas/$chamadaId"
        }

        notificacao.vagaId?.takeIf(String::isNotBlank)?.let { vagaId ->
            return "frila://vagas/$vagaId"
        }

        return if (notificacao.canal == GerenciadorDeCanais.CANAL_TURNOS) {
            val turnoIdValido = notificacao.turnoId?.trim()?.takeIf { UUID_REGEX.matches(it) }
            if (turnoIdValido != null) {
                "frila://meus_turnos/$turnoIdValido"
            } else {
                "frila://meus_turnos"
            }
        } else {
            null
        }
    }
}
