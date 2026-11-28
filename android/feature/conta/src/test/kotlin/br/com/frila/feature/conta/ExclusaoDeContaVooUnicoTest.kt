package br.com.frila.feature.conta

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ExclusaoDeContaDto
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.cancelChildren
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Wx0DhfEh (item 222): o pedido de exclusão roda num escopo que sobrevive à tela. Reabrir a tela com o pedido no ar cria outro ViewModel; ele
 * não pode mandar um segundo pedido, e a trava que o impede tem de soltar sempre, ou o botão ficaria desabilitado em silêncio.
 */
class ExclusaoDeContaVooUnicoTest {

    private val sucesso = ExclusaoDeContaDto(perfilRemovidoEm = "2026-11-10T12:00:00Z", dadosApagadosAte = "2026-11-25", turnosCancelados = 0)
    private val escopoDoPedido = CoroutineScope(SupervisorJob() + Dispatchers.Unconfined)

    @AfterEach fun depois() { escopoDoPedido.cancel() }

    private fun tela(
        emVoo: ExclusaoEmVoo,
        excluir: suspend () -> ExclusaoDeContaDto,
        aoConcluir: () -> Unit = {},
    ) = ExclusaoDeContaViewModel(
        excluir = excluir,
        aoConcluir = aoConcluir,
        escopo = CoroutineScope(Dispatchers.Unconfined),
        escopoDoPedido = escopoDoPedido,
        emVoo = emVoo,
    )

    private fun recusa() = ErroDaApi(codigo = CodigoErroAPI.ADMINISTRADOR_UNICO, codigoOriginal = "administrador_unico", detalhes = null, mensagemCrua = "x")

    @Test
    fun `duas telas, um pedido so`() = runBlocking {
        val emVoo = ExclusaoEmVoo()
        val liberar = CompletableDeferred<Unit>()
        var pedidos = 0
        var concluiu = 0
        val excluir: suspend () -> ExclusaoDeContaDto = { pedidos++; liberar.await(); sucesso }
        val primeira = tela(emVoo, excluir, aoConcluir = { concluiu++ })
        primeira.alterarConfirmacao(true)
        primeira.confirmarExclusao()

        val segunda = tela(emVoo, excluir, aoConcluir = { concluiu++ })
        segunda.alterarConfirmacao(true)
        segunda.confirmarExclusao() // o segundo toque, na tela reaberta

        assertEquals(1, pedidos)
        liberar.complete(Unit)
        assertEquals(1, pedidos)
        assertEquals(1, concluiu)
    }

    // O espelho do "excluindo" é eventual; quem decide é a trava, atômica. Uma tela cujo espelho ainda não propagou (o coletor não rodou)
    // enxerga "parado", mas o toque dela não pode mandar o segundo pedido.
    @Test
    fun `tela cujo espelho ainda nao propagou nao manda o segundo pedido`() = runBlocking {
        val emVoo = ExclusaoEmVoo()
        val liberar = CompletableDeferred<Unit>()
        var pedidos = 0
        val primeira = tela(emVoo, { pedidos++; liberar.await(); sucesso })
        primeira.alterarConfirmacao(true)
        primeira.confirmarExclusao()
        val atrasada = ExclusaoDeContaViewModel(
            excluir = { pedidos++; sucesso },
            escopo = CoroutineScope(kotlinx.coroutines.test.StandardTestDispatcher()), // o coletor do espelho nunca roda
            escopoDoPedido = escopoDoPedido,
            emVoo = emVoo,
        )
        atrasada.alterarConfirmacao(true)
        assertTrue(atrasada.estado.value.podeExcluir, "o espelho atrasou: a tela ainda se enxerga parada")

        atrasada.confirmarExclusao()

        liberar.complete(Unit)
        assertEquals(1, pedidos)
    }

    @Test
    fun `a tela reaberta ja nasce excluindo, sem poder pedir de novo`() {
        val emVoo = ExclusaoEmVoo()
        val liberar = CompletableDeferred<Unit>()
        val primeira = tela(emVoo, { liberar.await(); sucesso })
        primeira.alterarConfirmacao(true)
        primeira.confirmarExclusao()

        val segunda = tela(emVoo, { sucesso })
        segunda.alterarConfirmacao(true)

        assertTrue(segunda.estado.value.excluindo)
        assertFalse(segunda.estado.value.podeExcluir)
        liberar.complete(Unit)
    }

    @Test
    fun `recusado o pedido, a trava solta e a tela reaberta volta a poder excluir`() = runBlocking {
        val emVoo = ExclusaoEmVoo()
        val liberar = CompletableDeferred<Unit>()
        var pedidos = 0
        val primeira = tela(emVoo, { pedidos++; liberar.await(); throw recusa() })
        primeira.alterarConfirmacao(true)
        primeira.confirmarExclusao()
        val segunda = tela(emVoo, { pedidos++; sucesso })
        assertTrue(segunda.estado.value.excluindo)

        liberar.complete(Unit)

        assertFalse(emVoo.ativa.value)
        assertFalse(segunda.estado.value.excluindo)
        segunda.alterarConfirmacao(true)
        segunda.confirmarExclusao()
        assertEquals(2, pedidos)
    }

    @Test
    fun `pedido cancelado no meio solta a trava`() = runBlocking {
        val emVoo = ExclusaoEmVoo()
        val primeira = tela(emVoo, { CompletableDeferred<Unit>().await(); sucesso })
        primeira.alterarConfirmacao(true)
        primeira.confirmarExclusao()
        assertTrue(emVoo.ativa.value)

        escopoDoPedido.coroutineContext.cancelChildren()

        assertFalse(emVoo.ativa.value, "o job morreu: a trava tem de soltar, ou o botao fica desabilitado em silencio")
        val segunda = tela(emVoo, { sucesso })
        assertFalse(segunda.estado.value.excluindo)
    }

    @Test
    fun `excecao que nao e ErroDaApi tambem solta a trava`() = runBlocking {
        val emVoo = ExclusaoEmVoo()
        val primeira = tela(emVoo, { error("corpo ilegivel") })
        primeira.alterarConfirmacao(true)

        primeira.confirmarExclusao().join()

        assertFalse(emVoo.ativa.value)
    }

    @Test
    fun `escopo cancelado antes de o pedido comecar nao deixa a trava presa`() = runBlocking {
        val emVoo = ExclusaoEmVoo()
        val primeira = tela(emVoo, { sucesso })
        primeira.alterarConfirmacao(true)
        escopoDoPedido.cancel()

        primeira.confirmarExclusao().join()

        assertFalse(emVoo.ativa.value, "o job nasceu cancelado e nunca rodou o corpo: a trava solta mesmo assim")
    }

    @Test
    fun `sem confirmar, o toque nao pega a trava`() {
        val emVoo = ExclusaoEmVoo()
        val primeira = tela(emVoo, { sucesso })

        primeira.confirmarExclusao()

        assertFalse(emVoo.ativa.value)
    }
}
