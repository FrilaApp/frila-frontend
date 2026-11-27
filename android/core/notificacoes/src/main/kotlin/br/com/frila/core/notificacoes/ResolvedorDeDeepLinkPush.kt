package br.com.frila.core.notificacoes

import java.net.URLEncoder

/**
 * Monta o link que o toque numa notificação FCM abre: `frila://aviso?tipo=...` com os ids do payload. Não decide a
 * tela: quem decide é o `:app` no toque, com o papel da conta (como o `RoteadorDePush` do iOS).
 */
object ResolvedorDeDeepLinkPush {

    fun resolver(notificacao: NotificacaoParaExibir): String? {
        if (notificacao.neutralizada) return null
        val tipo = notificacao.tipo?.takeIf(String::isNotBlank) ?: return null
        val campos = listOf(
            "tipo" to tipo,
            "vaga_id" to notificacao.vagaId,
            "turno_id" to notificacao.turnoId,
            "posicao_id" to notificacao.posicaoId,
            "chamada_id" to notificacao.chamadaId,
        ).mapNotNull { (chave, valor) -> valor?.takeIf(String::isNotBlank)?.let { "$chave=${URLEncoder.encode(it, "UTF-8")}" } }
        return "frila://aviso?" + campos.joinToString("&")
    }
}
