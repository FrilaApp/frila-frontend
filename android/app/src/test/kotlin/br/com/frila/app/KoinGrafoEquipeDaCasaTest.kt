package br.com.frila.app

import br.com.frila.core.dominio.modelo.PapelMembro
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.feature.equipe.casa.EquipeDaCasaViewModel
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
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
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.core.parameter.parametersOf
import org.koin.dsl.module
import org.koin.test.KoinTest
import org.koin.test.get

/**
 * Parecer do Lince Codex no #998: o link do convite tem de apontar para a web do MESMO ambiente do app (debug fala com o
 * Supabase DEV e abre a web DEV; release fala com o Prod e abre a web Prod). O teste monta o grafo real de produção e
 * gera um convite pelo ViewModel que o Koin entrega, então cobre a ligação e não só a função com uma origem de mentira.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class KoinGrafoEquipeDaCasaTest : KoinTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")

    // Token sintético de teste (64 hex), não é segredo.
    private val token = "ef".repeat(32)

    private val moduloLocalizacaoFalso = module { single<ProvedorDeLocalizacao> { mockk(relaxed = true) } }

    private fun cliente() = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-teste",
        engine = MockEngine { request ->
            when {
                request.url.encodedPath.endsWith("/convidar_membro") ->
                    respond("""{"convite_id":"c1","token":"$token","expira_em":"2026-11-25T15:00:00Z"}""", HttpStatusCode.OK, json)
                else -> respond("[]", HttpStatusCode.OK, json)
            }
        },
    )

    @BeforeEach
    fun antes() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        startKoin {
            modules(
                listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacaoFalso, moduloFeatures) + module {
                    single { ServicoPerfil(cliente()) }
                    single { ServicoMembros(cliente()) }
                    single { ServicoVagas(cliente()) }
                },
            )
        }
    }

    @AfterEach
    fun depois() {
        stopKoin()
        Dispatchers.resetMain()
    }

    private fun linkGeradoPeloGrafo(): String = runBlocking {
        val viewModel = get<EquipeDaCasaViewModel> { parametersOf("casa-1", PapelMembro.ADMINISTRADOR) }
        viewModel.editarEmail("novo@bar.com")
        viewModel.gerarConvite().join()
        viewModel.estado.value.convite!!.link
    }

    @Test
    fun `o link do convite do grafo aponta para a web do ambiente do build`() {
        val link = linkGeradoPeloGrafo()

        val origemEsperada = if (BuildConfig.DEBUG) OrigemDaWeb.DEV else OrigemDaWeb.PRODUCAO
        assertEquals("$origemEsperada/convite#$token", link)
    }

    @Test
    fun `o debug nunca gera link para a web de producao e o release nunca para a de dev`() {
        val link = linkGeradoPeloGrafo()

        if (BuildConfig.DEBUG) {
            assertFalse(link.startsWith("https://frilabr.com/"), link)
        } else {
            assertFalse(link.contains("workers.dev"), link)
            assertEquals("https://frilabr.com/app/convite#$token", link)
        }
        assertNotNull(OrigemDaWeb.doAmbiente(debug = true))
        assertEquals("https://frila-web-dev.frilabr.workers.dev/app", OrigemDaWeb.doAmbiente(debug = true))
        assertEquals("https://frilabr.com/app", OrigemDaWeb.doAmbiente(debug = false))
    }
}
