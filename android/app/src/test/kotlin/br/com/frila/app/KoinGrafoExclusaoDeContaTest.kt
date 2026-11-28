package br.com.frila.app

import androidx.lifecycle.viewModelScope
import br.com.frila.app.seguranca.CoordenadorDeLogout
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.Sessao
import br.com.frila.feature.conta.ExclusaoDeContaViewModel
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.mockk
import java.util.Base64
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withTimeout
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.core.qualifier.named
import org.koin.dsl.module
import org.koin.test.KoinTest
import org.koin.test.get
import kotlinx.coroutines.CoroutineScope

private val moduloLocalizacaoDoGrafoDaExclusao = module {
    single<ProvedorDeLocalizacao> { mockk(relaxed = true) }
}

/**
 * F4owLsLH (item 213): o grafo real roda o pedido de exclusão num escopo de aplicação próprio. Sair da tela com o pedido no ar (o
 * `viewModelScope` cancelado, como o `clear()` da pilha faz) não o cancela, e um logout no meio (que cancela os filhos do escopo
 * da sessão) também não. O fim do pedido limpa a sessão local mesmo com a tela fora da pilha.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class KoinGrafoExclusaoDeContaTest : KoinTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val pedidoChegou = CompletableDeferred<Unit>()
    private val liberarOServidor = CompletableDeferred<Unit>()
    private val pedidosDeExclusao = java.util.concurrent.atomic.AtomicInteger(0)

    @BeforeEach
    fun antes() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        val cliente = clienteSupabaseDeTeste(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { request ->
                if (request.url.encodedPath.endsWith("excluir-conta")) {
                    pedidosDeExclusao.incrementAndGet()
                    pedidoChegou.complete(Unit)
                    liberarOServidor.await()
                    respond(
                        """{"perfil_removido_em":"2026-11-10T12:00:00Z","dados_apagados_ate":"2026-11-25","turnos_cancelados":2}""",
                        HttpStatusCode.OK,
                        json,
                    )
                } else {
                    respond("{}", HttpStatusCode.OK, json)
                }
            },
        )
        startKoin {
            modules(
                listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacaoDoGrafoDaExclusao, moduloFeatures) +
                    module { single { ServicoPerfil { cliente } } },
            )
        }
    }

    @AfterEach
    fun depois() {
        liberarOServidor.complete(Unit)
        encerrarOsClientesDoTeste()
        stopKoin()
        Dispatchers.resetMain()
    }

    private fun sessaoDe(pessoa: String): Sessao {
        val corpo = Base64.getUrlEncoder().withoutPadding().encodeToString("{\"sub\":\"$pessoa\"}".toByteArray())
        return Sessao("cabecalho.$corpo.assinatura-sintetica", "renovacao-teste", "bearer", 60, null)
    }

    private suspend fun esperar(descricao: String, condicao: () -> Boolean) {
        try { withTimeout(5_000) { while (!condicao()) delay(10) } } catch (_: Exception) { throw AssertionError("não chegou a: $descricao") }
    }

    private fun pedirAExclusao(): ExclusaoDeContaViewModel {
        get<ArmazenamentoDeSessao>().salvarSessao(sessaoDe("conta-a"))
        val vm = get<ExclusaoDeContaViewModel>()
        vm.alterarConfirmacao(true)
        vm.confirmarExclusao()
        return vm
    }

    @Test
    fun `o logout cancela os filhos do escopo da sessao e nao os do escopo da exclusao`() = runBlocking {
        val daSessao = get<CoroutineScope>(named(ESCOPO_DA_SESSAO)).launch { delay(60_000) }
        val daExclusao = get<CoroutineScope>(named(ESCOPO_DA_EXCLUSAO)).launch { delay(60_000) }

        get<CoordenadorDeLogout>().limparSessao()

        assertTrue(daSessao.isCancelled, "o logout cancela o escopo da sessao (controle)")
        assertTrue(daExclusao.isActive, "o pedido de exclusao nao pode ser cancelado pelo logout")
        daExclusao.cancel()
    }

    @Test
    fun `sair da tela com o pedido no ar nao o cancela, e a sessao local e limpa no fim`() = runBlocking {
        val vm = pedirAExclusao()
        withTimeout(5_000) { pedidoChegou.await() }
        assertTrue(get<ArmazenamentoDeSessao>().estaAutenticado())

        vm.viewModelScope.cancel() // a rota saiu da pilha: o clear() do ViewModel
        liberarOServidor.complete(Unit)

        esperar("o fim do pedido") { vm.estado.value.resultado != null }
        assertNotNull(vm.estado.value.resultado)
        esperar("a sessao local ser limpa") { !get<ArmazenamentoDeSessao>().estaAutenticado() }
        assertFalse(get<ArmazenamentoDeSessao>().estaAutenticado())
    }

    @Test
    fun `um logout no meio do pedido nao cancela a exclusao`() = runBlocking {
        val vm = pedirAExclusao()
        withTimeout(5_000) { pedidoChegou.await() }

        get<CoordenadorDeLogout>().limparSessao() // por exemplo, o Auth recusou o token por outro caminho
        liberarOServidor.complete(Unit)

        esperar("o fim do pedido") { vm.estado.value.resultado != null }
        assertNotNull(vm.estado.value.resultado)
    }

    // Wx0DhfEh (item 222): a tela reaberta com o pedido no ar é outro ViewModel do grafo; o pedido continua um só.
    @Test
    fun `a tela reaberta com o pedido no ar nao manda um segundo pedido`() = runBlocking {
        val primeira = pedirAExclusao()
        withTimeout(5_000) { pedidoChegou.await() }
        primeira.viewModelScope.cancel() // a tela saiu da pilha e voltou: o ViewModel novo
        val segunda = get<ExclusaoDeContaViewModel>()
        esperar("a tela nova nascer excluindo") { segunda.estado.value.excluindo }

        segunda.alterarConfirmacao(true)
        segunda.confirmarExclusao()
        delay(200)

        assertEquals(1, pedidosDeExclusao.get())
        liberarOServidor.complete(Unit)
        esperar("o fim do pedido") { primeira.estado.value.resultado != null }
        assertEquals(1, pedidosDeExclusao.get())
    }
}
