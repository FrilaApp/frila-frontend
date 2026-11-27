package br.com.frila.app.seguranca

import android.app.Application
import br.com.frila.app.CacheVagasDaSessao
import br.com.frila.app.SessaoComCacheVagas
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.GestorClienteKtor
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import java.nio.file.Files
import java.util.concurrent.CyclicBarrier
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.launch
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * P3 do time do Cauê no #1091 (En8IkArK): o decorador [SessaoComCacheVagas] e a limpeza do [CoordenadorDeLogout] contra a troca de
 * conta. O apagar condicional roda sob o lock do decorador; a limpeza que vem depois (cache, corrotinas, cliente) roda fora dele.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class ApagarCondicionalConcorrenteTest {

    private val contaA = Sessao("access-a", "refresh-a", "bearer", 3_600L, vinculoId = "va")
    private val contaB = Sessao("access-b", "refresh-b", "bearer", 3_600L, vinculoId = "vb")

    private fun decorador(): SessaoComCacheVagas =
        SessaoComCacheVagas(ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(contaA) }, CacheVagasDaSessao(raiz = null))

    private fun emDuasThreads(primeira: () -> Unit, segunda: () -> Unit) {
        val largada = CyclicBarrier(2)
        val threads = listOf(primeira, segunda).map { passo -> Thread { largada.await(); passo() } }
        threads.forEach(Thread::start)
        threads.forEach(Thread::join)
    }

    @Test
    fun `no decorador, o apagar condicional da conta anterior nunca apaga a que entrou e conta um encerramento so quando apagou`() {
        repeat(REPETICOES) { volta ->
            val sessao = decorador()
            val antes = sessao.encerramentos.value
            val apagou = AtomicBoolean()

            emDuasThreads({ apagou.set(sessao.limparSeRefreshTokenIgual("refresh-a")) }, { sessao.salvarSessao(contaB) })

            assertEquals("volta $volta", contaB, sessao.obterSessao())
            assertEquals("volta $volta", if (apagou.get()) antes + 1 else antes, sessao.encerramentos.value)
        }
    }

    @Test
    fun `no decorador, o gravar condicional da renovacao nunca sobrescreve a conta que entrou`() {
        repeat(REPETICOES) { volta ->
            val sessao = decorador()

            emDuasThreads(
                { sessao.salvarSeRefreshTokenIgual("refresh-a", contaA.copy(accessToken = "access-a2", refreshToken = "refresh-a2")) },
                { sessao.salvarSessao(contaB) },
            )

            assertEquals("volta $volta", contaB, sessao.obterSessao())
        }
    }

    private class Aparelho(val armazenamento: ArmazenamentoDeSessao) {
        val raiz = Files.createTempDirectory("aparelho").toFile()
        val imagemDeB = raiz.resolve("cache/foto-de-b.png").apply { parentFile!!.mkdirs(); writeText("png") }
        val escopo = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        val trabalhoDeB = escopo.launch { awaitCancellation() }
        val gestor = GestorClienteKtor { ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste") }
        val clienteDeB = gestor.clienteAtual
        val coordenador = CoordenadorDeLogout(armazenamento, raiz.resolve("cache"), raiz.resolve("files"), escopo, gestor)

        fun deBIntacto() {
            assertTrue("a foto de B foi apagada", imagemDeB.exists())
            assertFalse("o trabalho de B foi cancelado", trabalhoDeB.isCancelled)
            assertSame("o cliente de B foi fechado", clienteDeB, gestor.clienteAtual)
        }
    }

    @Test
    fun `a limpeza da recusa nao toca no que e da conta que entrou depois do apagar`() {
        val sessao = decorador()
        val aparelho = Aparelho(sessao)
        assertTrue(sessao.limparSeRefreshTokenIgual("refresh-a"))
        sessao.salvarSessao(contaB)

        assertNull(aparelho.coordenador.encerrarAposRecusa())

        assertEquals(contaB, sessao.obterSessao())
        aparelho.deBIntacto()
    }

    @Test
    fun `o apagar condicional do coordenador tambem nao limpa a conta que entrou logo depois`() {
        val base = decorador()
        // B entra no instante seguinte ao apagar, antes da limpeza do coordenador.
        val comTrocaLogoDepois = object : ArmazenamentoDeSessao by base {
            override fun limparSeRefreshTokenIgual(esperado: String): Boolean =
                base.limparSeRefreshTokenIgual(esperado).also { apagou -> if (apagou) base.salvarSessao(contaB) }
        }
        val aparelho = Aparelho(comTrocaLogoDepois)

        assertTrue(aparelho.coordenador.limparSeRefreshTokenIgual("refresh-a"))

        assertEquals(contaB, base.obterSessao())
        aparelho.deBIntacto()
    }

    private companion object {
        const val REPETICOES = 1_000
    }
}
