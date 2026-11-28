package br.com.frila.app

import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ServicoConfianca
import br.com.frila.feature.suporte.BloqueioDeAlvoViewModel
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import io.mockk.mockk
import java.util.concurrent.CopyOnWriteArrayList
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.core.parameter.parametersOf
import org.koin.dsl.module
import org.koin.test.KoinTest
import org.koin.test.get

private val moduloLocalizacaoDoGrafoDoBloqueio = module {
    single<ProvedorDeLocalizacao> { mockk(relaxed = true) }
}

/**
 * GpINsbhj: o grafo real liga `BloqueioDeAlvoViewModel` ao `ServicoConfianca.bloquear`. Os testes de navegação registram o view model
 * no próprio módulo; este é o que prova a fiação do `ModulosKoin`: o tipo e o id chegam ao `POST /rpc/bloquear`.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class KoinGrafoBloqueioDeAlvoTest : KoinTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val pedidos = CopyOnWriteArrayList<Pair<String, String?>>()

    @BeforeEach
    fun antes() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        val cliente = clienteSupabaseDeTeste(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { request ->
                pedidos += request.url.encodedPath to (request.body as? TextContent)?.text
                respond("""{"alvo_tipo":"estabelecimento","alvo_id":"casa-1","criado_em":"2026-11-10T12:00:00Z"}""", HttpStatusCode.OK, json)
            },
        )
        startKoin {
            modules(
                listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacaoDoGrafoDoBloqueio, moduloFeatures) +
                    module { single { ServicoConfianca(cliente) } },
            )
        }
    }

    @AfterEach
    fun depois() {
        encerrarOsClientesDoTeste()
        stopKoin()
        Dispatchers.resetMain()
    }

    @Test
    fun `o grafo resolve o bloqueio avulso e confirmar manda o tipo e o id ao rpc bloquear`() {
        val vm = get<BloqueioDeAlvoViewModel> { parametersOf(TipoDeAlvo.ESTABELECIMENTO, "casa-1") }

        vm.abrirDialogo()
        vm.confirmar()
        val limite = System.currentTimeMillis() + 5_000
        while (!vm.estado.value.bloqueado && vm.estado.value.erro == null && System.currentTimeMillis() < limite) Thread.sleep(20)

        assertTrue(vm.estado.value.bloqueado, "estado: ${vm.estado.value}")
        assertEquals(1, pedidos.size)
        assertTrue(pedidos.single().first.endsWith("rpc/bloquear"))
        val corpo = pedidos.single().second.orEmpty()
        assertTrue(corpo.contains("\"alvo_tipo\":\"estabelecimento\"") && corpo.contains("\"alvo_id\":\"casa-1\""), corpo)
    }
}
