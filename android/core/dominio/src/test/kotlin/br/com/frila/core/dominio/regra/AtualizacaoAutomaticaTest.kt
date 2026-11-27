package br.com.frila.core.dominio.regra

import br.com.frila.core.dominio.regra.ListaAtualizavel.MEUS_TURNOS
import br.com.frila.core.dominio.regra.ListaAtualizavel.MINHAS_VAGAS
import br.com.frila.core.dominio.regra.ListaAtualizavel.VAGAS
import java.time.Duration
import java.time.Instant
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicReference
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** O ponto central (porte de `AtualizacaoAutomaticaTests` do iOS): relógio e espera injetados; o tempo é conduzido pelo teste. */
@OptIn(ExperimentalCoroutinesApi::class)
class AtualizacaoAutomaticaTest {

    private val inicio = Instant.parse("2026-11-27T12:00:00Z")
    private val agora = AtomicReference(inicio)
    private val esperas = CopyOnWriteArrayList<Duration>()
    private val conta = AtomicReference<String?>("vinculo-1")

    private fun avancar(segundos: Long) = agora.updateAndGet { it.plusSeconds(segundos) }

    private fun atualizacao() = AtualizacaoAutomatica(
        sessao = { conta.get() },
        relogio = { agora.get() },
        esperar = { duracao ->
            esperas += duracao
            agora.updateAndGet { it.plus(duracao) }
        },
    )

    @Test
    fun `sem conta na tela a recarga nao e chamada, com conta e`() = runTest {
        val a = atualizacao()
        var vezes = 0
        conta.set(null)
        a.pedir(VAGAS) { vezes++ }
        assertEquals(0, vezes)
        conta.set("vinculo-1")
        a.pedir(VAGAS) { vezes++ }
        assertEquals(1, vezes)
    }

    @Test
    fun `voltar do segundo plano depois de 30 s rele e antes de 30 s nao`() = runTest {
        val a = atualizacao()
        a.registrarCarga(VAGAS)
        var vezes = 0
        avancar(10)
        a.pedir(VAGAS) { vezes++ }
        assertEquals(0, vezes, "antes de 30 s não relê")
        avancar(20)
        a.pedir(VAGAS) { vezes++ }
        assertEquals(1, vezes, "com 30 s relê")
    }

    @Test
    fun `dois pedidos ao mesmo tempo fazem uma recarga so`() = runTest(StandardTestDispatcher()) {
        val a = atualizacao()
        var vezes = 0
        val soltar = CompletableDeferred<Unit>()
        val primeira = launch { a.pedir(VAGAS) { vezes++; soltar.await() } }
        advanceUntilIdle()
        a.pedir(VAGAS) { vezes++ }
        assertEquals(1, vezes)
        soltar.complete(Unit)
        primeira.join()
        assertEquals(1, vezes)
        assertFalse(a.emVoo(VAGAS))
        avancar(10)
        a.pedir(VAGAS) { vezes++ }
        assertEquals(1, vezes, "dentro do intervalo, nada")
        avancar(30)
        a.pedir(VAGAS) { vezes++ }
        assertEquals(2, vezes)
    }

    @Test
    fun `push rele a lista e passa por cima dos 30 s`() = runTest {
        val a = atualizacao()
        a.registrarCarga(VAGAS)
        avancar(10)
        a.avisoChegou()
        assertEquals(1, a.avisos.value)
        var vezes = 0
        a.pedir(VAGAS) { vezes++ }
        assertEquals(1, vezes)
        // O mesmo aviso, já atendido, não fura de novo.
        avancar(1)
        a.pedir(VAGAS) { vezes++ }
        assertEquals(1, vezes)
    }

    @Test
    fun `push com a recarga em voo rele de novo depois dos 3 s`() = runTest(StandardTestDispatcher()) {
        val a = atualizacao()
        var vezes = 0
        val soltar = CompletableDeferred<Unit>()
        val primeira = launch { a.pedir(MINHAS_VAGAS) { vezes++; if (vezes == 1) soltar.await() } }
        advanceUntilIdle()
        a.avisoChegou()
        a.pedir(MINHAS_VAGAS) { vezes++ }
        assertEquals(1, vezes, "o pedido com a recarga em voo não abre outra")
        soltar.complete(Unit)
        primeira.join()
        assertEquals(2, vezes, "lida mais uma vez")
        assertEquals(listOf(Duration.ofSeconds(3)), esperas.toList())
        assertFalse(a.emVoo(MINHAS_VAGAS))
    }

    @Test
    fun `cinco pushes logo depois da carga da tela fazem uma espera e uma releitura`() = runTest(StandardTestDispatcher()) {
        val a = atualizacao()
        a.registrarCarga(VAGAS)
        avancar(1)
        var vezes = 0
        val pedidos = (1..5).map {
            a.avisoChegou()
            launch { a.pedir(VAGAS) { vezes++ } }
        }
        advanceUntilIdle()
        pedidos.forEach { it.join() }
        assertEquals(1, vezes)
        assertEquals(listOf(Duration.ofSeconds(2)), esperas.toList())
        assertFalse(a.emVoo(VAGAS))
    }

    @Test
    fun `recarga cancelada porque a tela saiu nao segura a proxima`() = runTest(StandardTestDispatcher()) {
        val a = atualizacao()
        val travada = CompletableDeferred<Unit>()
        val tarefa = launch { a.pedir(MEUS_TURNOS) { travada.await() } }
        advanceUntilIdle()
        assertTrue(a.emVoo(MEUS_TURNOS))
        tarefa.cancel()
        advanceUntilIdle()
        assertFalse(a.emVoo(MEUS_TURNOS))
        var depois = 0
        a.pedir(MEUS_TURNOS) { depois++ }
        assertEquals(1, depois, "a cancelada não conta para o intervalo")
    }

    @Test
    fun `falha na recarga libera a vez da lista`() = runTest {
        val a = atualizacao()
        runCatching { a.pedir(VAGAS) { error("rede") } }
        assertFalse(a.emVoo(VAGAS))
        var depois = 0
        a.pedir(VAGAS) { depois++ }
        assertEquals(1, depois)
    }

    @Test
    fun `trocar de conta esquece os intervalos e os avisos da anterior`() = runTest {
        val a = atualizacao()
        var vezes = 0
        a.pedir(VAGAS) { vezes++ }
        avancar(1)
        a.pedir(VAGAS) { vezes++ }
        assertEquals(1, vezes, "dentro do intervalo da conta 1")
        conta.set("vinculo-2")
        a.pedir(VAGAS) { vezes++ }
        assertEquals(2, vezes, "a conta nova não herda o intervalo")
    }
}
