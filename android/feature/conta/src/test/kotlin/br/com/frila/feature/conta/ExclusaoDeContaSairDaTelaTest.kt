package br.com.frila.feature.conta

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ExclusaoDeContaDto
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withTimeout
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test

/**
 * F4owLsLH (item 213): sair da tela com o pedido de exclusão em voo limpa o ViewModel (a rota saiu da pilha: voltar na janela de um
 * quadro, deep link, toque em push). O pedido não pode morrer junto: o servidor já pode ter anonimizado a conta, e a sessão local
 * precisa sair. O ViewModel vai para um `ViewModelStore` de verdade, e o `clear()` do store é o que a pilha de navegação faz.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ExclusaoDeContaSairDaTelaTest {

    private val sucesso = ExclusaoDeContaDto(perfilRemovidoEm = "2026-11-10T12:00:00Z", dadosApagadosAte = "2026-11-25", turnosCancelados = 2)
    private val escopoDoPedido = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    @BeforeEach fun antes() { Dispatchers.setMain(UnconfinedTestDispatcher()) }

    @AfterEach fun depois() {
        escopoDoPedido.cancel()
        Dispatchers.resetMain()
    }

    /** O ViewModel nasce como na rota: sem `escopo` (viewModelScope), guardado num store que o teste limpa ao "sair da tela". */
    private fun naPilha(
        excluir: suspend () -> ExclusaoDeContaDto,
        aoConcluir: () -> Unit = {},
        consultarTurnos: (suspend () -> ConsultaDeTurnosDaExclusao)? = null,
        escopoDoPedidoDoVm: CoroutineScope? = escopoDoPedido,
    ): Pair<ViewModelStore, ExclusaoDeContaViewModel> {
        val store = ViewModelStore()
        val fabrica = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T = ExclusaoDeContaViewModel(
                excluir = excluir,
                aoConcluir = aoConcluir,
                consultarTurnos = consultarTurnos,
                escopoDoPedido = escopoDoPedidoDoVm,
            ) as T
        }
        return store to ViewModelProvider(store, fabrica)[ExclusaoDeContaViewModel::class.java]
    }

    private suspend fun esperar(descricao: String, condicao: () -> Boolean) {
        try { withTimeout(5_000) { while (!condicao()) delay(10) } } catch (_: Exception) { throw AssertionError("não chegou a: $descricao") }
    }

    @Test
    fun `sair da tela com o pedido em voo nao cancela a exclusao, e a sessao e limpa uma vez`() = runBlocking {
        val noServidor = CompletableDeferred<Unit>()
        val liberar = CompletableDeferred<Unit>()
        var concluiu = 0
        val (store, vm) = naPilha(excluir = { noServidor.complete(Unit); liberar.await(); sucesso }, aoConcluir = { concluiu++ })
        vm.alterarConfirmacao(true)
        vm.confirmarExclusao()
        withTimeout(5_000) { noServidor.await() }

        store.clear() // a rota saiu da pilha com o pedido no ar
        liberar.complete(Unit)

        esperar("o aoConcluir rodar") { concluiu == 1 }
        assertEquals(1, concluiu)
        assertEquals(sucesso, vm.estado.value.resultado)
    }

    @Test
    fun `sair da tela e o servidor recusar nao conclui nem derruba o app`() = runBlocking {
        val noServidor = CompletableDeferred<Unit>()
        val liberar = CompletableDeferred<Unit>()
        var concluiu = 0
        val (store, vm) = naPilha(
            excluir = {
                noServidor.complete(Unit)
                liberar.await()
                throw ErroDaApi(codigo = CodigoErroAPI.ADMINISTRADOR_UNICO, codigoOriginal = "administrador_unico", detalhes = null, mensagemCrua = "x")
            },
            aoConcluir = { concluiu++ },
        )
        vm.alterarConfirmacao(true)
        vm.confirmarExclusao()
        withTimeout(5_000) { noServidor.await() }

        store.clear()
        liberar.complete(Unit)

        esperar("o pedido terminar com a recusa") { !vm.estado.value.excluindo }
        assertEquals(0, concluiu)
        assertNull(vm.estado.value.resultado)
        assertEquals(TextosExclusaoDeConta.ERRO_ADMIN_UNICO, vm.estado.value.mensagemErro)
    }

    @Test
    fun `ler os turnos continua preso a tela, e sair cancela a leitura`() = runBlocking {
        val leituraComecou = CompletableDeferred<Unit>()
        var leituraCancelada = false
        val (store, vm) = naPilha(
            excluir = { sucesso },
            consultarTurnos = {
                leituraComecou.complete(Unit)
                try { CompletableDeferred<Unit>().await(); ConsultaDeTurnosDaExclusao(emptyList(), false) } catch (e: kotlinx.coroutines.CancellationException) {
                    leituraCancelada = true
                    throw e
                }
            },
        )
        vm.carregarTurnos()
        withTimeout(5_000) { leituraComecou.await() }

        store.clear()

        esperar("a leitura ser cancelada") { leituraCancelada }
        assertTrue(leituraCancelada)
    }
}
