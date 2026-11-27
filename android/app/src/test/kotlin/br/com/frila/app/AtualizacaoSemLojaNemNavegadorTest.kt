package br.com.frila.app

import android.app.Application
import android.content.Context
import android.content.Intent
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import br.com.frila.app.desempenho.MedidorDeColdStart
import br.com.frila.core.designsystem.componentes.TextosAtualizacaoObrigatoria
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.MonitorDeConectividade
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.StatusPerfil
import br.com.frila.feature.vagas.feed.EstadoFeed
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.StatusFeed
import io.ktor.client.engine.mock.MockEngine
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.After
import org.junit.AfterClass
import org.junit.BeforeClass
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * Cartão bepD1DEV: na tela de atualização obrigatória, o botão "Atualizar" abre a loja e, se isso falha, o navegador. O segundo
 * `startActivity` ficava sem proteção dentro do `catch` do primeiro: num aparelho sem loja e sem navegador ele lançava
 * `ActivityNotFoundException` e derrubava o app justo na tela que impede o uso. O teste abre a `MainActivity` de verdade (a
 * composição de produção), com uma configuração guardada de versão mínima alta, e faz o sistema recusar todo intent.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h2400dp")
class AtualizacaoSemLojaNemNavegadorTest {

    @get:Rule
    val rule = createEmptyComposeRule()

    private var cena: ActivityScenario<MainActivity>? = null
    private val contexto: Context get() = ApplicationProvider.getApplicationContext()

    @After
    fun depois() {
        cena?.close()
        rule.waitForIdle()
        contexto.deleteSharedPreferences("configuracao_do_app")
        MedidorDeColdStart.resetarParaTestes()
    }

    /** Abre o app com a mínima 99.0.0 guardada (a tela de atualização sai na hora) e a chamada de configuração travada. */
    private fun abrirNaTelaDeAtualizacao() {
        CacheDeConfiguracaoDoAppPreferencias(contexto).gravar(
            versaoApp = BuildConfig.VERSION_NAME,
            configuracao = ConfiguracaoDoAppDto(plataforma = "android", versaoMinima = "99.0.0"),
        )
        MedidorDeColdStart.iniciar()
        cena = ActivityScenario.launch(
            Intent(contexto, MainActivity::class.java).putExtra(PoliticaDaAbertura.EXTRA_PULAR_ABERTURA, true),
        )
        rule.waitUntil(15_000) { telaDeAtualizacaoVisivel() }
    }

    private fun telaDeAtualizacaoVisivel() =
        runCatching { rule.onNodeWithText(TextosAtualizacaoObrigatoria.TITULO).assertExists() }.isSuccess

    @Test
    fun `sem loja e sem navegador o botao Atualizar nao derruba o app e mostra o endereco da loja para copiar`() {
        // O sistema recusa todo intent implícito: market:// e https:// lançam ActivityNotFoundException.
        shadowOf(contexto as Application).checkActivities(true)
        abrirNaTelaDeAtualizacao()

        rule.onNodeWithText(TextosAtualizacaoObrigatoria.BOTAO_ATUALIZAR).performClick()
        rule.waitForIdle()

        rule.onNodeWithTag("aviso-abertura-externa").assertIsDisplayed()
        val endereco = "https://play.google.com/store/apps/details?id=${contexto.packageName}"
        rule.onNodeWithTag("aviso-abertura-externa-endereco").assertIsDisplayed()
        rule.onNodeWithText(endereco).assertIsDisplayed()
        rule.onNodeWithText(TextosAtualizacaoObrigatoria.TITULO).assertIsDisplayed() // a tela de atualização segue lá
    }

    companion object {
        /** Um Koin só para a classe (ver [AberturaSemEsperaDaConfiguracaoTest]). */
        @JvmStatic @BeforeClass fun iniciarKoin() {
            EscopoPadraoDoKoinCompose.reiniciar()
            val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
                every { estaAutenticado() } returns false
                every { isBiometriaAtivada() } returns false
            }
            val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
            val perfil = mockk<PerfilViewModel>(relaxed = true) {
                every { estado } returns MutableStateFlow(EstadoPerfil(status = StatusPerfil.SUCESSO))
            }
            val feed = mockk<FeedVagasViewModel>(relaxed = true) {
                every { estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.SUCESSO))
            }
            startKoin {
                modules(
                    module {
                        factory {
                            ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = MockEngine { awaitCancellation() })
                        }
                        single<ArmazenamentoDeSessao> { sessao }
                        single<MonitorDeConectividade> { MonitorDeConectividadeFalso() }
                        viewModel { entrada }
                        viewModel { perfil }
                        viewModel { feed }
                    },
                )
            }
        }

        @JvmStatic @AfterClass fun pararKoin() {
            stopKoin()
            EscopoPadraoDoKoinCompose.reiniciar()
        }
    }
}
