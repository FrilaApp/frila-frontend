package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import br.com.frila.core.designsystem.componentes.TextosAtualizacaoObrigatoria
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.MonitorDeConectividade
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.vagas.feed.EstadoFeed
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.StatusFeed
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.dsl.module
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.concurrent.atomic.AtomicInteger

/**
 * Teste de integração do portão de atualização na [MainActivity] (P2-02 do Lince, PR #649).
 * Prova que a inicialização real do app consulta `/rpc/configuracao_do_app?plataforma=android`
 * e bloqueia a navegação quando a versão instalada for inferior à versão mínima exigida.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class MainActivityAtualizacaoIntegracaoTest {

    @get:Rule
    val rule = createComposeRule()

    @After
    fun tearDown() {
        stopKoin()
    }

    @Test
    fun `quando versao instalada for inferior a versao minima remota mainActivity consulta api e exibe tela de atualizacao`() {
        stopKoin()
        val chamadas = AtomicInteger()
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.invalid",
            apiKey = "chave-ficticia",
            engine = MockEngine {
                chamadas.incrementAndGet()
                respond(
                    content = """{"plataforma":"android","versao_minima":"99.0.0","versao_recomendada":"99.0.0","url_da_loja":"https://play.google.com/store/apps/details?id=br.com.frila.app"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        val feed = mockk<FeedVagasViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.VAZIO))
        }

        startKoin {
            modules(
                module {
                    single<ClienteSupabase> { cliente }
                    single<ArmazenamentoDeSessao> {
                        mockk(relaxed = true) {
                            every { estaAutenticado() } returns true
                            every { isBiometriaAtivada() } returns false
                        }
                    }
                    single<MonitorDeConectividade> { MonitorDeConectividadeFalso() }
                    viewModel { feed }
                },
            )
        }

        val controller = Robolectric.buildActivity(MainActivity::class.java)
        try {
            controller.create().start().postCreate(null).resume().visible()
            rule.waitForIdle()

            assertEquals("A abertura deve consultar a configuracao publica de versao", 1, chamadas.get())
            rule.onNodeWithText(TextosAtualizacaoObrigatoria.TITULO).assertIsDisplayed()
        } finally {
            controller.pause().stop().destroy()
            cliente.http.close()
        }
    }

    @Test
    fun `quando versao minima for compativel mainActivity libera o app normalmente`() {
        stopKoin()
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.invalid",
            apiKey = "chave-ficticia",
            engine = MockEngine {
                respond(
                    content = """{"plataforma":"android","versao_minima":"1.0.0","versao_recomendada":"1.1.0","url_da_loja":"https://play.google.com/store/apps/details?id=br.com.frila.app"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        val feed = mockk<FeedVagasViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.VAZIO))
        }

        startKoin {
            modules(
                module {
                    single<ClienteSupabase> { cliente }
                    single<ArmazenamentoDeSessao> {
                        mockk(relaxed = true) {
                            every { estaAutenticado() } returns true
                            every { isBiometriaAtivada() } returns false
                        }
                    }
                    single<MonitorDeConectividade> { MonitorDeConectividadeFalso() }
                    viewModel { feed }
                },
            )
        }

        val controller = Robolectric.buildActivity(MainActivity::class.java)
        try {
            controller.create().start().postCreate(null).resume().visible()
            rule.waitForIdle()

            rule.onNodeWithText(TextosAtualizacaoObrigatoria.TITULO).assertDoesNotExist()
        } finally {
            controller.pause().stop().destroy()
            cliente.http.close()
        }
    }
}
