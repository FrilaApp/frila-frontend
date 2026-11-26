package br.com.frila.app

import android.app.Application
import android.content.Context
import android.content.Intent
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithText
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
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.After
import org.junit.AfterClass
import org.junit.BeforeClass
import org.junit.Assert.assertFalse
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão cC95bSf8 (#795, item 1): a primeira tela do app não pode ficar presa a uma chamada de `configuracao_do_app` lenta ou sem
 * resposta. O teste abre a `MainActivity` de verdade (a composição de produção: o portão de versão envolvendo a navegação) com um
 * motor HTTP que segura a chamada, e espera em tempo real até a interface ficar pronta. Sem a correção a abertura esperava o prazo
 * inteiro da chamada (10 s); com ela, o portão abre em até 2 s com o que estiver guardado, e a resposta, quando chega, ainda vale
 * (inclusive para bloquear uma versão abaixo da mínima).
 *
 * O item 2 da issue (se a chamada direta tem a mesma trava no backend) não é coberto aqui: não foi determinado.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h2400dp")
class AberturaSemEsperaDaConfiguracaoTest {

    @get:Rule
    val rule = createEmptyComposeRule()

    private var cena: ActivityScenario<MainActivity>? = null

    /** Instante (tempo real) em que a Activity começou a abrir: o prazo do teste conta daqui, não de quando a espera começa. */
    private var abertoEm = 0L
    private val contexto: Context get() = ApplicationProvider.getApplicationContext()

    @After
    fun depois() {
        cena?.close()
        rule.waitForIdle()
        contexto.deleteSharedPreferences("configuracao_do_app")
        MedidorDeColdStart.resetarParaTestes()
    }

    private val jsonSemMinimaAlta = """{"plataforma":"android","versao_minima":"1.0.0","recursos":{}}"""
    private val jsonComMinimaAlta = """{"plataforma":"android","versao_minima":"99.0.0","recursos":{}}"""
    private val cabecalhoJson = headersOf(HttpHeaders.ContentType, "application/json")

    /** Abre a `MainActivity` com o cliente que usa o [motor] dado (o Koin da classe entrega o cliente do momento). */
    private fun abrirApp(motor: MockEngine) {
        motorDoMomento = motor
        MedidorDeColdStart.iniciar()
        abertoEm = System.nanoTime()
        cena = ActivityScenario.launch(
            Intent(contexto, MainActivity::class.java).putExtra(PoliticaDaAbertura.EXTRA_PULAR_ABERTURA, true),
        )
    }

    private fun chamadaTravada() = MockEngine { awaitCancellation() }

    private fun guardarConfiguracaoComMinimaAlta() {
        CacheDeConfiguracaoDoAppPreferencias(contexto).gravar(
            versaoApp = BuildConfig.VERSION_NAME,
            configuracao = ConfiguracaoDoAppDto(plataforma = "android", versaoMinima = "99.0.0"),
        )
    }

    /** Espera [condicao] até [limiteMs] contados da abertura da Activity (o que a pessoa vive), não de quando a espera começa. */
    private fun esperarDesdeAAbertura(limiteMs: Long, condicao: () -> Boolean) {
        val restante = limiteMs - (System.nanoTime() - abertoEm) / 1_000_000
        rule.waitUntil(restante.coerceAtLeast(1), condicao)
    }

    private fun esperarInterfacePronta(limiteMs: Long = LIMITE_DO_TESTE_MS) =
        esperarDesdeAAbertura(limiteMs) { MedidorDeColdStart.interfaceProntaConcluida }

    private fun telaDeAtualizacaoVisivel() =
        runCatching { rule.onNodeWithText(TextosAtualizacaoObrigatoria.TITULO).assertExists() }.isSuccess

    private fun esperarTelaDeAtualizacao(limiteMs: Long = LIMITE_DO_TESTE_MS) = esperarDesdeAAbertura(limiteMs, ::telaDeAtualizacaoVisivel)

    @Test
    fun `com a chamada de configuracao travada a primeira tela abre dentro do limite`() {
        abrirApp(chamadaTravada())

        esperarInterfacePronta()
    }

    @Test
    fun `resposta que chega depois de a primeira tela abrir ainda bloqueia a versao abaixo da minima`() {
        val liberar = CompletableDeferred<Unit>()
        abrirApp(
            MockEngine {
                liberar.await()
                respond(jsonComMinimaAlta, HttpStatusCode.OK, cabecalhoJson)
            },
        )
        esperarInterfacePronta()
        rule.onNodeWithText(TextosAtualizacaoObrigatoria.TITULO).assertDoesNotExist()

        liberar.complete(Unit)

        rule.waitUntil(5_000, ::telaDeAtualizacaoVisivel)
    }

    @Test
    fun `configuracao guardada com minima alta vale na abertura mesmo com a chamada travada`() {
        guardarConfiguracaoComMinimaAlta()
        abrirApp(chamadaTravada())

        esperarTelaDeAtualizacao()
        assertFalse("o app não pode abrir por baixo da mínima guardada", MedidorDeColdStart.interfaceProntaConcluida)
    }

    @Test
    fun `resposta imediata com minima alta mostra a tela de atualizacao e nunca o app`() {
        abrirApp(MockEngine { respond(jsonComMinimaAlta, HttpStatusCode.OK, cabecalhoJson) })

        esperarTelaDeAtualizacao()
        assertFalse(MedidorDeColdStart.interfaceProntaConcluida)
    }

    @Test
    fun `resposta imediata sem minima alta abre a primeira tela`() {
        abrirApp(MockEngine { respond(jsonSemMinimaAlta, HttpStatusCode.OK, cabecalhoJson) })

        esperarInterfacePronta()
    }

    @Test
    fun `guardada com mensagem A e resposta atrasada com mensagem nula volta para a mensagem padrao`() {
        CacheDeConfiguracaoDoAppPreferencias(contexto).gravar(
            versaoApp = BuildConfig.VERSION_NAME,
            configuracao = ConfiguracaoDoAppDto(
                plataforma = "android",
                versaoMinima = "99.0.0",
                mensagem = "Mensagem antiga A",
            ),
        )
        val liberar = CompletableDeferred<Unit>()
        abrirApp(
            MockEngine {
                liberar.await()
                respond("""{"plataforma":"android","versao_minima":"99.0.0","mensagem":null,"recursos":{}}""", HttpStatusCode.OK, cabecalhoJson)
            },
        )
        esperarDesdeAAbertura(LIMITE_DO_TESTE_MS) {
            runCatching { rule.onNodeWithText("Mensagem antiga A").assertExists() }.isSuccess
        }

        liberar.complete(Unit)

        rule.waitUntil(5_000) {
            runCatching { rule.onNodeWithText(TextosAtualizacaoObrigatoria.MENSAGEM_PADRAO).assertExists() }.isSuccess
        }
        rule.onNodeWithText("Mensagem antiga A").assertDoesNotExist()
    }

    companion object {
        /** Tempo real, a partir da abertura da Activity. Sem a correção a primeira tela com a chamada travada sai em cerca de 10 s
         * (o prazo da chamada); com ela, em 2 s mais a partida da Activity. A folga cobre a partida fria do Robolectric. */
        private const val LIMITE_DO_TESTE_MS = 6_000L

        @Volatile private var motorDoMomento: MockEngine = MockEngine { awaitCancellation() }

        /**
         * Um Koin só para a classe: o escopo padrão do `koinInject` da `AppNavegacao` fica preso ao primeiro Koin do processo (ver
         * [EscopoPadraoDoKoinCompose]), então um Koin novo por teste deixava os testes seguintes com um escopo fechado.
         */
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
                        factory { ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = motorDoMomento) }
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
