package br.com.frila.core.notificacoes

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

class ResolvedorDeDeepLinkPushTest {

    @Test
    fun `push de vaga emite deep link para o detalhe`() {
        val notificacao = notificacao(
            canal = GerenciadorDeCanais.CANAL_URGENCIA,
            vagaId = "vaga-123",
        )

        assertEquals("frila://vagas/vaga-123", ResolvedorDeDeepLinkPush.resolver(notificacao))
    }

    @Test
    fun `push de turno emite deep link para meus turnos`() {
        val notificacao = notificacao(canal = GerenciadorDeCanais.CANAL_TURNOS)

        assertEquals("frila://meus_turnos", ResolvedorDeDeepLinkPush.resolver(notificacao))
    }

    @Test
    fun `push neutralizado por RN15 nunca emite link sensivel`() {
        val notificacao = notificacao(
            canal = GerenciadorDeCanais.CANAL_URGENCIA,
            vagaId = "vaga-de-outra-conta",
            neutralizada = true,
        )

        assertNull(ResolvedorDeDeepLinkPush.resolver(notificacao))
    }

    private fun notificacao(
        canal: String,
        vagaId: String? = null,
        neutralizada: Boolean = false,
    ) = NotificacaoParaExibir(
        canal = canal,
        titulo = "Frila",
        corpo = "Nova notificação",
        vagaId = vagaId,
        neutralizada = neutralizada,
    )
}
