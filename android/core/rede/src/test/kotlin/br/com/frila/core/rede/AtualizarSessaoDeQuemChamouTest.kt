package br.com.frila.core.rede

import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import java.util.Base64
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** Cartão O9aPbBR2: o dado de uma chamada de rede só vai para a sessão guardada se ela ainda é a de quem fez a chamada. */
class AtualizarSessaoDeQuemChamouTest {

    private fun jwtDa(conta: String) =
        "cab.${Base64.getUrlEncoder().withoutPadding().encodeToString("""{"sub":"$conta"}""".toByteArray())}.ass"

    private fun sessao(conta: String, refresh: String, vinculoId: String? = null) = Sessao(jwtDa(conta), refresh, "bearer", 3600, vinculoId = vinculoId)

    private val a = sessao("conta-a", "refresh-a")

    private fun comVinculo(v: String): (Sessao) -> Sessao = { it.copy(vinculoId = v) }

    @Test
    fun `grava quando a sessao guardada e a mesma de antes`() {
        val loja = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(a) }

        assertTrue(loja.atualizarSeASessaoDeQuemChamou(a, comVinculo("v1")))

        assertEquals(a.copy(vinculoId = "v1"), loja.obterSessao())
    }

    @Test
    fun `nao grava quando outra conta entrou`() {
        val b = sessao("conta-b", "refresh-b", vinculoId = "vinculo-de-b")
        val loja = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(b) }

        assertFalse(loja.atualizarSeASessaoDeQuemChamou(a, comVinculo("v1")))

        assertEquals(b, loja.obterSessao())
    }

    @Test
    fun `nao grava quando nao ha mais sessao`() {
        val loja = ArmazenamentoDeSessaoEmMemoria()

        assertFalse(loja.atualizarSeASessaoDeQuemChamou(a, comVinculo("v1")))

        assertNull(loja.obterSessao())
    }

    @Test
    fun `grava sobre a sessao renovada da mesma conta, sem desfazer a renovacao`() {
        val renovada = sessao("conta-a", "refresh-a-2")
        val loja = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(renovada) }

        assertTrue(loja.atualizarSeASessaoDeQuemChamou(a, comVinculo("v1")))

        assertEquals(renovada.copy(vinculoId = "v1"), loja.obterSessao())
    }

    @Test
    fun `sem JWT legivel nao da para provar que e a mesma conta e nao grava`() {
        val antes = Sessao("access", "refresh-x", "bearer", 3600)
        val outra = Sessao("access-2", "refresh-y", "bearer", 3600)
        val loja = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(outra) }

        assertFalse(loja.atualizarSeASessaoDeQuemChamou(antes, comVinculo("v1")))

        assertEquals(outra, loja.obterSessao())
    }

    /** Uma escrita entra entre a leitura e o `salvarSeRefreshTokenIgual`: o auxiliar relê e decide de novo. */
    private class ComEscritaNoMeio(private val interno: ArmazenamentoDeSessaoEmMemoria, private val aoEscreverNoMeio: (Int) -> Unit) :
        ArmazenamentoDeSessao by interno {
        var tentativas = 0
        override fun salvarSeRefreshTokenIgual(esperado: String, nova: Sessao): Boolean {
            tentativas++
            aoEscreverNoMeio(tentativas)
            return interno.salvarSeRefreshTokenIgual(esperado, nova)
        }
    }

    @Test
    fun `se a propria conta renova entre a leitura e a gravacao, tenta de novo e grava`() {
        val interno = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(a) }
        val loja = ComEscritaNoMeio(interno) { n -> if (n == 1) interno.salvarSessao(sessao("conta-a", "refresh-a-2")) }

        assertTrue(loja.atualizarSeASessaoDeQuemChamou(a, comVinculo("v1")))

        assertEquals(sessao("conta-a", "refresh-a-2", vinculoId = "v1"), interno.obterSessao())
        assertEquals(2, loja.tentativas)
    }

    @Test
    fun `se B entra entre a leitura e a gravacao, relê, ve que e outra conta e nao grava`() {
        val b = sessao("conta-b", "refresh-b")
        val interno = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(a) }
        val loja = ComEscritaNoMeio(interno) { n -> if (n == 1) { interno.limparSessao(); interno.salvarSessao(b) } }

        assertFalse(loja.atualizarSeASessaoDeQuemChamou(a, comVinculo("v1")))

        assertEquals(b, interno.obterSessao())
    }

    @Test
    fun `se a sessao muda a cada tentativa, desiste depois de poucas vezes e nao grava`() {
        val interno = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(a) }
        val loja = ComEscritaNoMeio(interno) { n -> interno.salvarSessao(sessao("conta-a", "refresh-a-${n + 1}")) }

        assertFalse(loja.atualizarSeASessaoDeQuemChamou(a, comVinculo("v1")))

        assertEquals(3, loja.tentativas, "limitado")
        assertNull(interno.obterSessao()?.vinculoId, "nada foi gravado")
    }
}
