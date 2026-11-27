package br.com.frila.app

import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import java.util.Base64
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** Cartão 7567rGRH: as operações condicionais do decorador só limpam o cache e contam o encerramento quando gravam ou apagam. */
class SessaoComCacheVagasAtomicaTest {

    private fun sessao(conta: String, refresh: String) = Sessao(
        accessToken = "cabecalho.${Base64.getUrlEncoder().withoutPadding().encodeToString("""{"sub":"$conta"}""".toByteArray())}.assinatura",
        refreshToken = refresh,
        tokenType = "bearer",
        expiresIn = 3_600L,
    )

    private class Cenario {
        var limpezas = 0
        val origem = ArmazenamentoDeSessaoEmMemoria()
        val armazenamento = SessaoComCacheVagas(origem, CacheVagasDaSessao(null, limparTelemetria = { limpezas++ }))
    }

    @Test
    fun `salvar condicional de outra conta guardada nao grava nem limpa o cache`() {
        val c = Cenario()
        c.armazenamento.salvarSessao(sessao("b", "refresh-b"))
        val antes = c.limpezas

        assertFalse(c.armazenamento.salvarSeRefreshTokenIgual("refresh-a", sessao("a", "refresh-a2")))

        assertEquals(sessao("b", "refresh-b"), c.armazenamento.obterSessao())
        assertEquals(antes, c.limpezas)
    }

    @Test
    fun `salvar condicional da mesma conta grava e preserva o cache`() {
        val c = Cenario()
        c.armazenamento.salvarSessao(sessao("a", "refresh-a"))
        val antes = c.limpezas

        assertTrue(c.armazenamento.salvarSeRefreshTokenIgual("refresh-a", sessao("a", "refresh-a2")))

        assertEquals(sessao("a", "refresh-a2"), c.armazenamento.obterSessao())
        assertEquals(antes, c.limpezas)
    }

    @Test
    fun `limpar condicional de outra conta guardada nao apaga nem conta encerramento`() {
        val c = Cenario()
        c.armazenamento.salvarSessao(sessao("b", "refresh-b"))
        val antes = c.limpezas

        assertFalse(c.armazenamento.limparSeRefreshTokenIgual("refresh-a"))

        assertEquals(sessao("b", "refresh-b"), c.armazenamento.obterSessao())
        assertEquals(0, c.armazenamento.encerramentos.value)
        assertEquals(antes, c.limpezas)
    }

    @Test
    fun `limpar condicional da conta esperada apaga, limpa o cache e conta o encerramento`() {
        val c = Cenario()
        c.armazenamento.salvarSessao(sessao("a", "refresh-a"))
        val antes = c.limpezas

        assertTrue(c.armazenamento.limparSeRefreshTokenIgual("refresh-a"))

        assertNull(c.origem.obterSessao())
        assertEquals(1, c.armazenamento.encerramentos.value)
        assertEquals(antes + 1, c.limpezas)
    }
}
