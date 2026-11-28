package br.com.frila.feature.suporte

import br.com.frila.core.rede.BloqueioDto
import br.com.frila.core.rede.ItemBloqueioDto
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * CLD9Yg3e (item 228): puxar para atualizar a lista de bloqueados (iOS `.refreshable`). Com a lista na tela, a recarga a mantém, mostra o
 * indicador e troca pela lista nova; uma recarga e um desbloqueio não correm juntos, para a lista velha não trazer de volta quem acabou de sair.
 */
class BloqueiosAtualizarTest {

    private fun item(id: String, nome: String) = ItemBloqueioDto(alvoTipo = "profissional", alvoId = id, nome = nome, criadoEm = "2026-11-10T12:00:00Z")
    private val ana = item("a", "Ana")
    private val beto = item("b", "Beto")
    private val caio = item("c", "Caio")
    private val ok = BloqueioDto(alvoTipo = "profissional", alvoId = "a", criadoEm = "2026-11-10T12:00:00Z")

    private fun criar(listar: suspend () -> List<ItemBloqueioDto>, desfazer: suspend (String, String) -> BloqueioDto = { _, _ -> ok }) =
        BloqueiosViewModel(listar = listar, desfazer = desfazer, escopo = CoroutineScope(Dispatchers.Unconfined))

    private fun itens(vm: BloqueiosViewModel) = (vm.estado.value.estado as? EstadoBloqueios.Conteudo)?.itens

    @Test
    fun `atualizar com a lista na tela mostra o indicador, mantem a lista e troca pela nova`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        var leituras = 0
        val vm = criar(listar = { leituras++; if (leituras == 1) listOf(ana, beto) else { liberar.await(); listOf(ana, beto, caio) } })
        vm.carregar().join()
        assertEquals(listOf(ana, beto), itens(vm))

        val job = vm.atualizar()

        assertTrue(vm.estado.value.atualizando)
        assertEquals(listOf(ana, beto), itens(vm), "a lista fica na tela durante a recarga")
        liberar.complete(Unit)
        job.join()
        assertFalse(vm.estado.value.atualizando)
        assertEquals(listOf(ana, beto, caio), itens(vm))
    }

    @Test
    fun `a carga de abertura nao e uma atualizacao`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        val vm = criar(listar = { liberar.await(); listOf(ana) })

        val job = vm.carregar()

        assertFalse(vm.estado.value.atualizando)
        liberar.complete(Unit)
        job.join()
        assertFalse(vm.estado.value.atualizando)
    }

    @Test
    fun `atualizar que falha mantem a lista, avisa e solta o indicador`() = runBlocking {
        var leituras = 0
        val vm = criar(listar = { if (leituras++ == 0) listOf(ana, beto) else error("rede caiu") })
        vm.carregar().join()

        vm.atualizar().join()

        assertEquals(listOf(ana, beto), itens(vm))
        assertEquals(TextosBloqueios.ERRO_CARREGAR, vm.estado.value.mensagemErro)
        assertFalse(vm.estado.value.atualizando)
    }

    @Test
    fun `duas atualizacoes seguidas leem uma vez so`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        var leituras = 0
        val vm = criar(listar = { leituras++; if (leituras == 1) listOf(ana) else { liberar.await(); listOf(ana, beto) } })
        vm.carregar().join()

        val primeira = vm.atualizar()
        vm.atualizar()
        liberar.complete(Unit)
        primeira.join()

        assertEquals(2, leituras)
    }

    @Test
    fun `atualizar durante um desbloqueio nao faz nada, para a lista velha nao trazer o item de volta`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        var leituras = 0
        val vm = criar(listar = { leituras++; listOf(ana, beto) }, desfazer = { _, _ -> liberar.await(); ok })
        vm.carregar().join()
        val desbloqueio = vm.desbloquear(ana)

        vm.atualizar().join()

        assertEquals(1, leituras, "a lista não é relida com o desbloqueio no ar")
        assertFalse(vm.estado.value.atualizando)
        liberar.complete(Unit)
        desbloqueio.join()
        assertEquals(listOf(beto), itens(vm))
    }

    @Test
    fun `desbloquear durante uma atualizacao nao faz nada`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        var leituras = 0
        var desfeitos = 0
        val vm = criar(
            listar = { leituras++; if (leituras == 1) listOf(ana, beto) else { liberar.await(); listOf(ana, beto) } },
            desfazer = { _, _ -> desfeitos++; ok },
        )
        vm.carregar().join()
        val recarga = vm.atualizar()

        vm.desbloquear(ana).join()

        assertEquals(0, desfeitos)
        assertNull(vm.estado.value.desbloqueando)
        liberar.complete(Unit)
        recarga.join()
        assertEquals(listOf(ana, beto), itens(vm))
    }
}
