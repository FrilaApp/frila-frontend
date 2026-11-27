package br.com.frila.core.notificacoes

import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.Sessao
import io.mockk.every
import io.mockk.mockk
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

/** O link do toque leva o tipo e os ids; a tela é o `:app` que escolhe (`RotaDoAvisoTest`). */
class ResolvedorDeDeepLinkPushTest {

    private val vaga = "40000000-0000-0000-0000-000000000001"
    private val turno = "60000000-0000-0000-0000-000000000001"
    private val posicao = "50000000-0000-0000-0000-000000000001"

    @Test
    fun `o link leva o tipo e todos os ids do payload`() {
        val notificacao = notificacao(tipo = "cancelamento", vagaId = vaga, turnoId = turno, posicaoId = posicao, chamadaId = "chamada-9")

        assertEquals(
            "frila://aviso?tipo=cancelamento&vaga_id=$vaga&turno_id=$turno&posicao_id=$posicao&chamada_id=chamada-9",
            ResolvedorDeDeepLinkPush.resolver(notificacao),
        )
    }

    @Test
    fun `o link nao escolhe destino pelo vaga_id nem pelo canal`() {
        // Antes o vaga_id vinha primeiro e a confirmação abria a vaga em vez do turno.
        val confirmacao = notificacao(tipo = "confirmacao", vagaId = vaga, turnoId = turno, canal = GerenciadorDeCanais.CANAL_TURNOS)

        assertEquals("frila://aviso?tipo=confirmacao&vaga_id=$vaga&turno_id=$turno", ResolvedorDeDeepLinkPush.resolver(confirmacao))
    }

    @Test
    fun `id ausente ou vazio fica fora do link, e valor e codificado`() {
        val notificacao = notificacao(tipo = "vaga", vagaId = "", turnoId = "a b&c")

        assertEquals("frila://aviso?tipo=vaga&turno_id=a+b%26c", ResolvedorDeDeepLinkPush.resolver(notificacao))
    }

    @Test
    fun `sem tipo nao ha link`() {
        assertNull(ResolvedorDeDeepLinkPush.resolver(notificacao(tipo = null, vagaId = vaga)))
        assertNull(ResolvedorDeDeepLinkPush.resolver(notificacao(tipo = " ", vagaId = vaga)))
    }

    @Test
    fun `push neutralizado por RN15 nunca emite link`() {
        val notificacao = notificacao(tipo = "confirmacao", vagaId = vaga, turnoId = turno, neutralizada = true)

        assertNull(ResolvedorDeDeepLinkPush.resolver(notificacao))
    }

    @Test
    fun `o processador entrega o tipo e o posicao_id ao link, e o push de outra conta nao tem link`() {
        val armazenamento = mockk<ArmazenamentoDeSessao>()
        every { armazenamento.obterSessao() } returns Sessao("t", "r", "bearer", 3600, vinculoId = "vinculo-abc")
        val processador = ProcessadorDePush(armazenamento)
        val payload = mapOf("tipo" to "cancelamento", "vaga_id" to vaga, "posicao_id" to posicao, "reaberta" to "false")

        val daConta = processador.processar(payload + ("vinculo_id" to "vinculo-abc"))
        val deOutraConta = processador.processar(payload + ("vinculo_id" to "vinculo-de-outra-conta"))

        assertEquals("frila://aviso?tipo=cancelamento&vaga_id=$vaga&posicao_id=$posicao", ResolvedorDeDeepLinkPush.resolver(daConta))
        assertNull(ResolvedorDeDeepLinkPush.resolver(deOutraConta))
    }

    private fun notificacao(
        tipo: String?,
        canal: String = GerenciadorDeCanais.CANAL_SISTEMA,
        vagaId: String? = null,
        neutralizada: Boolean = false,
        chamadaId: String? = null,
        turnoId: String? = null,
        posicaoId: String? = null,
    ) = NotificacaoParaExibir(
        canal = canal,
        titulo = "Frila",
        corpo = "Nova notificação",
        vagaId = vagaId,
        neutralizada = neutralizada,
        chamadaId = chamadaId,
        turnoId = turnoId,
        tipo = tipo,
        posicaoId = posicaoId,
    )
}
