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
    fun `push de turno sem id emite deep link para meus turnos`() {
        val notificacao = notificacao(canal = GerenciadorDeCanais.CANAL_TURNOS)

        assertEquals("frila://meus_turnos", ResolvedorDeDeepLinkPush.resolver(notificacao))
    }

    @Test
    fun `push de turno com id UUID valido emite deep link para o turno especifico`() {
        val uuid = "de698e95-c9a0-4e4e-b01e-4b7fe31a4ef6"
        val notificacao = notificacao(
            canal = GerenciadorDeCanais.CANAL_TURNOS,
            turnoId = uuid,
        )

        assertEquals("frila://meus_turnos/$uuid", ResolvedorDeDeepLinkPush.resolver(notificacao))
    }

    @Test
    fun `push de turno com id invalido nao UUID emite fallback para meus turnos`() {
        val notificacao = notificacao(
            canal = GerenciadorDeCanais.CANAL_TURNOS,
            turnoId = "id-invalido-123",
        )

        assertEquals("frila://meus_turnos", ResolvedorDeDeepLinkPush.resolver(notificacao))
    }

    @Test
    fun `push de turno neutralizado por RN15 nunca emite link sensivel mesmo com turnoId`() {
        val notificacao = notificacao(
            canal = GerenciadorDeCanais.CANAL_TURNOS,
            turnoId = "de698e95-c9a0-4e4e-b01e-4b7fe31a4ef6",
            neutralizada = true,
        )

        assertNull(ResolvedorDeDeepLinkPush.resolver(notificacao))
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

    /** C0-10: o link que o manifesto e a rota `RotasChamadaProfissional.DEEP_LINK_RECEBIDA` aceitam. */
    @Test
    fun `push de chamada emite deep link para a chamada recebida`() {
        val notificacao = notificacao(canal = GerenciadorDeCanais.CANAL_SISTEMA, chamadaId = "chamada-9")

        assertEquals("frila://chamadas/chamada-9", ResolvedorDeDeepLinkPush.resolver(notificacao))
    }

    private fun notificacao(
        canal: String,
        vagaId: String? = null,
        neutralizada: Boolean = false,
        chamadaId: String? = null,
        turnoId: String? = null,
    ) = NotificacaoParaExibir(
        canal = canal,
        titulo = "Frila",
        corpo = "Nova notificação",
        vagaId = vagaId,
        neutralizada = neutralizada,
        chamadaId = chamadaId,
        turnoId = turnoId,
    )
}
