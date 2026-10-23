package br.com.frila.core.notificacoes

/** Resolve somente destinos autorizados para abertura a partir de uma notificação FCM. */
object ResolvedorDeDeepLinkPush {

    fun resolver(notificacao: NotificacaoParaExibir): String? {
        if (notificacao.neutralizada) return null

        notificacao.vagaId?.takeIf(String::isNotBlank)?.let { vagaId ->
            return "frila://vagas/$vagaId"
        }

        return if (notificacao.canal == GerenciadorDeCanais.CANAL_TURNOS) {
            "frila://meus_turnos"
        } else {
            null
        }
    }
}
