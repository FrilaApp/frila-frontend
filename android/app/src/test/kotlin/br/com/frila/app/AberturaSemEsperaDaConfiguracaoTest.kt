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
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.client.request.HttpResponseData
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
import org.junit.Assert.assertTrue
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

    /**
     * Instante (tempo real) em que o app fez a chamada de `configuracao_do_app`, que é quando o prazo da abertura começa a correr no
     * código de produção (o `delay` de [TEMPO_MAXIMO_ABERTURA_MS] e a chamada nascem juntos no mesmo efeito). O prazo do teste conta
     * daqui e não da abertura da Activity: no primeiro teste da classe, com a JVM e o Robolectric frios, o `ActivityScenario.launch`
     * levou de 0,7 a 3,1 s e a primeira tela ficou pronta de 2,6 a 5,2 s depois da abertura (debug, 10 rodadas, sem carga), contra
     * ~1,5 s nos testes seguintes. Esse custo é da partida do teste e comia o limite de 6 s contado da abertura (falha na CI do #1092).
     */
    @Volatile private var chamadaEm = 0L
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
        chamadaEm = 0L
        cena = ActivityScenario.launch(
            Intent(contexto, MainActivity::class.java).putExtra(PoliticaDaAbertura.EXTRA_PULAR_ABERTURA, true),
        )
    }

    /** Motor HTTP falso que anota o instante da primeira chamada (ver [chamadaEm]) antes de responder como [resposta] manda. */
    private fun motor(resposta: suspend MockRequestHandleScope.(HttpRequestData) -> HttpResponseData) = MockEngine { pedido ->
        if (chamadaEm == 0L) chamadaEm = System.nanoTime()
        resposta(pedido)
    }

    private fun chamadaTravada() = motor { awaitCancellation() }

    private fun guardarConfiguracaoComMinimaAlta() {
        CacheDeConfiguracaoDoAppPreferencias(contexto).gravar(
            versaoApp = BuildConfig.VERSION_NAME,
            configuracao = ConfiguracaoDoAppDto(plataforma = "android", versaoMinima = "99.0.0"),
        )
    }

    /**
     * Espera [condicao] e afirma que ela ficou verdadeira em até [limiteMs] contados da chamada de configuração (ver [chamadaEm]).
     * Antes, espera a chamada acontecer, sem contar esse tempo: se o app nunca a fizer, o teste falha aqui, por [ESPERA_DA_CHAMADA_MS].
     * A espera do Compose ([ESPERA_DA_CONDICAO_MS]) é separada do limite afirmado: na CI carregada a falha diz quanto levou, em vez de
     * um `ComposeTimeoutException` sem número (cartão mysEoQxG).
     */
    private fun esperarDesdeAChamada(limiteMs: Long, condicao: () -> Boolean) {
        rule.waitUntil(ESPERA_DA_CHAMADA_MS) { chamadaEm != 0L }
        rule.waitUntil(ESPERA_DA_CONDICAO_MS, condicao)
        val levou = (System.nanoTime() - chamadaEm) / 1_000_000
        assertTrue("levou $levou ms desde a chamada de configuração; o limite é $limiteMs ms", levou <= limiteMs)
    }

    private fun esperarInterfacePronta(limiteMs: Long = LIMITE_DO_TESTE_MS) =
        esperarDesdeAChamada(limiteMs) { MedidorDeColdStart.interfaceProntaConcluida }

    private fun telaDeAtualizacaoVisivel() =
        runCatching { rule.onNodeWithText(TextosAtualizacaoObrigatoria.TITULO).assertExists() }.isSuccess

    private fun esperarTelaDeAtualizacao(limiteMs: Long = LIMITE_DO_TESTE_MS) = esperarDesdeAChamada(limiteMs, ::telaDeAtualizacaoVisivel)

    @Test
    fun `com a chamada de configuracao travada a primeira tela abre dentro do limite`() {
        abrirApp(chamadaTravada())

        esperarInterfacePronta()
    }

    @Test
    fun `resposta que chega depois de a primeira tela abrir ainda bloqueia a versao abaixo da minima`() {
        val liberar = CompletableDeferred<Unit>()
        abrirApp(
            motor {
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
        abrirApp(motor { respond(jsonComMinimaAlta, HttpStatusCode.OK, cabecalhoJson) })

        esperarTelaDeAtualizacao()
        assertFalse(MedidorDeColdStart.interfaceProntaConcluida)
    }

    @Test
    fun `resposta imediata sem minima alta abre a primeira tela`() {
        abrirApp(motor { respond(jsonSemMinimaAlta, HttpStatusCode.OK, cabecalhoJson) })

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
            motor {
                liberar.await()
                respond("""{"plataforma":"android","versao_minima":"99.0.0","mensagem":null,"recursos":{}}""", HttpStatusCode.OK, cabecalhoJson)
            },
        )
        esperarDesdeAChamada(LIMITE_DO_TESTE_MS) {
            runCatching { rule.onNodeWithText("Mensagem antiga A").assertExists() }.isSuccess
        }

        liberar.complete(Unit)

        rule.waitUntil(5_000) {
            runCatching { rule.onNodeWithText(TextosAtualizacaoObrigatoria.MENSAGEM_PADRAO).assertExists() }.isSuccess
        }
        rule.onNodeWithText("Mensagem antiga A").assertDoesNotExist()
    }

    companion object {
        /**
         * Tempo real, a partir da chamada de configuração. Com a correção, a primeira tela sai em 2 s ([TEMPO_MAXIMO_ABERTURA_MS]) mais a
         * composição; sem ela, no prazo da chamada (10 s), que dá de 7,7 a 8,8 s contados da chamada (medido). Medido com a correção, da
         * chamada até a tela: até 2,4 s sem carga e 2,6 s com a CPU toda ocupada (Mac, 10 núcleos); na CI com vários PRs, passou de 4 s
         * (run 45984586405 do #1150, cartão mysEoQxG). 6 s dá folga para a CI e segue reprovando o prazo inteiro da chamada.
         */
        private const val LIMITE_DO_TESTE_MS = 6_000L

        /** Quanto o Compose espera a condição: só a rede de proteção para não pendurar; o que o teste afirma é [LIMITE_DO_TESTE_MS]. */
        private const val ESPERA_DA_CONDICAO_MS = 30_000L

        /** Quanto o teste espera o app fazer a chamada (a Activity abrir): não entra no limite acima. */
        private const val ESPERA_DA_CHAMADA_MS = 30_000L

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
