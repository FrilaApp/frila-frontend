package br.com.frila.app

import br.com.frila.core.rede.EventoDeTelemetria
import br.com.frila.core.rede.FilaDeTelemetria
import br.com.frila.core.rede.RegistradorDeTelemetria
import br.com.frila.core.rede.contaDaSessaoParaTelemetria
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.util.Base64
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class TelemetriaDaSessaoTest {
    private fun sessao(conta: String) = Sessao(
        "cabecalho.${Base64.getUrlEncoder().withoutPadding().encodeToString("""{"sub":"$conta"}""".toByteArray())}.assinatura",
        "refresh-sintetico", "bearer", 3600,
    )

    @Test
    fun `logout expiracao e troca de conta apagam a fila mas refresh preserva`() = runTest {
        val pasta = Files.createTempDirectory("telemetria-sessao").toFile()
        try {
            val arquivo = File(pasta, "eventos.json")
            val fila = FilaDeTelemetria(arquivo)
            val origem = ArmazenamentoDeSessaoEmMemoria()
            val armazenamento = SessaoComCacheVagas(origem, CacheVagasDaSessao(pasta, fila::limpar))
            val registrador = RegistradorDeTelemetria({ throw IOException() }, fila,
                { contaDaSessaoParaTelemetria(armazenamento.obterSessao()) }, { "a" }, backgroundScope)
            armazenamento.salvarSessao(sessao("a"))
            registrador.registrar(EventoDeTelemetria.APP_ABERTO)
            armazenamento.salvarSessao(sessao("a").copy(refreshToken = "novo-refresh-sintetico"))
            assertEquals(1, fila.eventosPendentes().size)
            armazenamento.limparSessao()
            assertFalse(arquivo.exists())
            assertTrue(fila.eventosPendentes().isEmpty())
            armazenamento.salvarSessao(sessao("a"))
            registrador.registrar(EventoDeTelemetria.APP_ABERTO)
            armazenamento.salvarSessao(sessao("b"))
            assertFalse(arquivo.exists())
            assertTrue(fila.eventosPendentes().isEmpty())
            registrador.registrar(EventoDeTelemetria.APP_ABERTO)
            origem.limparSessao() // Expiração no armazenamento seguro.
            assertNull(armazenamento.obterSessao())
            assertFalse(arquivo.exists())
            assertTrue(fila.eventosPendentes().isEmpty())
        } finally { pasta.deleteRecursively() }
    }

    @Test
    fun `identidade ausente ou malformada nunca ganha fila`() {
        assertNull(contaDaSessaoParaTelemetria(null))
        assertNull(contaDaSessaoParaTelemetria(sessao("a").copy(accessToken = "invalido")))
        assertNull(contaDaSessaoParaTelemetria(sessao("")))
        assertEquals("conta-sintetica", contaDaSessaoParaTelemetria(sessao("conta-sintetica")))
    }
}
