package br.com.frila.app

import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ServicoChamadaDireta
import br.com.frila.feature.chamadas.casa.AcompanharChamadasViewModel
import br.com.frila.feature.chamadas.casa.BuscaDeProfissionaisViewModel
import br.com.frila.feature.chamadas.casa.ChamadaDiretaViewModel
import br.com.frila.feature.chamadas.casa.EstadoPerfilPublico
import br.com.frila.feature.chamadas.casa.PerfilPublicoViewModel
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.core.parameter.parametersOf
import org.koin.dsl.module
import org.koin.test.KoinTest
import org.koin.test.get

private val moduloLocalizacaoDoTesteDaCasa = module {
    single<ProvedorDeLocalizacao> { mockk(relaxed = true) }
}

/** O grafo real monta os ViewModels do lado da casa na chamada direta, e cada um chega à rota do contrato. */
@OptIn(ExperimentalCoroutinesApi::class)
class KoinGrafoChamadaCasaTest : KoinTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val pedidos = mutableListOf<Pair<String, String?>>()
    private val reputacao = """{"positivas":7,"total":8,"turnos_considerados":8,"turnos_realizados":8}"""

    private fun clienteQueResponde(corpo: String) = clienteSupabaseDeTeste(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-teste",
        engine = MockEngine { request ->
            pedidos += request.url.encodedPath to (request.body as? TextContent)?.text
            respond(corpo, HttpStatusCode.OK, json)
        },
    )

    @BeforeEach
    fun antes() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @AfterEach
    fun depois() {
        encerrarOsClientesDoTeste()
        stopKoin()
        Dispatchers.resetMain()
    }

    private fun iniciar(respostaDoServico: String? = null) = startKoin {
        val base = listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacaoDoTesteDaCasa, moduloFeatures)
        modules(
            if (respostaDoServico == null) base
            else base + module { single { ServicoChamadaDireta(clienteQueResponde(respostaDoServico)) } },
        )
    }

    @Test
    fun `grafo resolve os quatro ViewModels do lado da casa com os parametros da rota`() {
        iniciar()

        assertNotNull(get<PerfilPublicoViewModel> { parametersOf("22222222-2222-2222-2222-222222222222") })
        assertNotNull(get<ChamadaDiretaViewModel> { parametersOf("22222222-2222-2222-2222-222222222222", "11111111-1111-1111-1111-111111111111", null) })
        assertNotNull(get<ChamadaDiretaViewModel> { parametersOf("22222222-2222-2222-2222-222222222222", "11111111-1111-1111-1111-111111111111", 7) })
        assertNotNull(get<AcompanharChamadasViewModel> { parametersOf("55555555-5555-5555-5555-555555555555") })
        assertNotNull(get<BuscaDeProfissionaisViewModel> { parametersOf("11111111-1111-1111-1111-111111111111") })
    }

    @Test
    fun `perfil publico e acompanhar chamam a rota do contrato que lhes cabe`() {
        iniciar("""{"id":"22222222-2222-2222-2222-222222222222","tipo":"profissional","nome":"Maria S.","reputacao":$reputacao}""")

        runBlocking {
            val perfil = get<PerfilPublicoViewModel> { parametersOf("22222222-2222-2222-2222-222222222222") }
            perfil.carregar().join()
            assertEquals("/rest/v1/rpc/perfil_publico", pedidos.single().first)
            assertTrue(perfil.estado.value is EstadoPerfilPublico.Carregado)
        }
        pedidos.clear()
        stopKoin()
        iniciar("""{"itens":[],"proximo_cursor":null}""")
        runBlocking {
            val acompanhar = get<AcompanharChamadasViewModel> { parametersOf("55555555-5555-5555-5555-555555555555") }
            acompanhar.carregar().join()
            assertEquals(listOf("/rest/v1/rpc/minhas_chamadas"), pedidos.map { it.first })
        }
    }
}
