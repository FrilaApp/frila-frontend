package br.com.frila.app

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.ServicoConta
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.StatusConectividade
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.turnos.AvaliacaoViewModel
import br.com.frila.feature.turnos.CheckinViewModel
import br.com.frila.feature.turnos.MeusTurnosViewModel
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.headersOf
import io.mockk.every
import io.mockk.mockk
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import br.com.frila.core.dominio.modelo.AlvoBloqueado
import br.com.frila.core.dominio.modelo.BloqueiosDaSessao
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.feature.turnos.TextosMeusTurnos

/**
 * I1PonzKJ, fatia 3: Meus turnos lê o conjunto da sessão. O turno de um estabelecimento que o profissional bloqueou diz
 * "Você bloqueou este estabelecimento" (iOS: `TelaMeuTurno.rodapeSeguranca`); bloquear com a lista aberta também o mostra.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = android.app.Application::class, qualifiers = "w411dp-h2400dp")
class AppNavegacaoMeusTurnosBloqueadoTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var navController: NavHostController
    private val bloqueios = BloqueiosDaSessao()

    private val turnoJson = """
        [{
          "id": "t1", "posicao_id": "posicao-t1",
          "vaga": {"id": "vaga-t1", "funcao": "Garçom", "local": "CLS 405 Bloco C", "regiao_administrativa": "Plano Piloto",
                   "inicio_em": "2099-11-02T01:00:00Z", "fim_em": "2099-11-02T10:00:00Z", "valor_centavos": 16000},
          "contraparte": {"id": "e1", "tipo": "estabelecimento", "nome": "Bar do Zé",
                          "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}},
          "contato_visivel_ate": "2099-11-09T03:00:00Z", "a_caminho_em": null, "checkin_em": null, "checkin_tipo": null,
          "checkin_distancia_m": null, "checkin_confirmado_em": null, "checkout_em": null, "checkout_distancia_m": null,
          "verificacao": "pendente", "valor_acordado_centavos": 16000, "pode_avaliar": false,
          "estado": "confirmada", "avaliacao": null, "cancelamento": null
        }]
    """.trimIndent()

    private fun montar(registrarOConjunto: Boolean = true) {
        val servicoTurnos = ServicoTurnos(
            ClienteSupabase(
                baseUrl = "https://frila.supabase.co", apiKey = "chave-teste",
                engine = MockEngine { request ->
                    if (request.url.encodedPath.endsWith("meus_turnos")) respond(turnoJson, headers = headersOf(HttpHeaders.ContentType, "application/json"))
                    else respond("{}", headers = headersOf(HttpHeaders.ContentType, "application/json"))
                },
            ),
        )
        val provedor = object : ProvedorDeLocalizacao {
            override suspend fun obterCoordenadaAtual(): Coordenada? = null
            override fun temPermissaoDeLocalizacao(): Boolean = false
            override fun isGpsAtivado(): Boolean = false
        }
        val entradaVm = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        val armazenamento = mockk<ArmazenamentoDeSessao>(relaxed = true)
        every { armazenamento.estaAutenticado() } returns false
        every { armazenamento.isBiometriaAtivada() } returns false

        rule.setContent {
            navController = rememberNavController()
            KoinApplication(application = {
                modules(
                    module {
                        single { mockk<ServicoAutenticacao>(relaxed = true) }
                        single { mockk<ServicoPerfil>(relaxed = true) }
                        single { servicoTurnos }
                        single { mockk<ServicoVagas>(relaxed = true) }
                        single { mockk<ServicoConta>(relaxed = true) }
                        single { armazenamento }
                        if (registrarOConjunto) single { bloqueios }
                        viewModel { entradaVm }
                        viewModel { MeusTurnosViewModel(servicoTurnos = servicoTurnos, escopo = CoroutineScope(Dispatchers.Unconfined)) }
                        viewModel { (turnoId: String, coordenadaDaVaga: Coordenada?) ->
                            CheckinViewModel(turnoId, coordenadaDaVaga, servicoTurnos, provedor)
                        }
                    },
                )
            }) {
                AppNavegacao(
                    armazenamentoDeSessao = armazenamento,
                    monitorDeConectividade = MonitorDeConectividadeFalso(StatusConectividade.CONECTADO),
                    navController = navController,
                    servicoMembros = null,
                )
            }
        }
        rule.waitForIdle()
        rule.runOnUiThread { navController.navigate(Rotas.MEUS_TURNOS) }
        rule.waitUntil(10_000) { rule.onAllNodesWithText("Bar do Zé").fetchSemanticsNodes().isNotEmpty() }
    }

    private fun avisoVisivel() = rule.onAllNodesWithText(TextosMeusTurnos.VOCE_BLOQUEOU_ESTABELECIMENTO).fetchSemanticsNodes().isNotEmpty()

    @Test
    fun `estabelecimento ja bloqueado na sessao, o turno diz que foi bloqueado`() {
        bloqueios.registrar(AlvoBloqueado(TipoDeAlvo.ESTABELECIMENTO, "e1"))
        montar()

        rule.waitUntil(5_000) { avisoVisivel() }
    }

    @Test
    fun `sem bloqueio, o turno nao diz isso`() {
        montar()

        assertEquals(false, avisoVisivel())
    }

    @Test
    fun `bloquear com a lista aberta mostra o aviso sem recarregar`() {
        montar()
        assertEquals(false, avisoVisivel())

        rule.runOnIdle { bloqueios.registrar(AlvoBloqueado(TipoDeAlvo.ESTABELECIMENTO, "e1")) }

        rule.waitUntil(5_000) { avisoVisivel() }
    }

    @Test
    fun `o mesmo id com outro tipo nao conta`() {
        bloqueios.registrar(AlvoBloqueado(TipoDeAlvo.PROFISSIONAL, "e1"))
        montar()

        assertEquals(false, avisoVisivel())
    }

    @Test
    fun `um grafo sem o conjunto registrado segue mostrando o turno sem aviso`() {
        montar(registrarOConjunto = false)

        assertEquals(false, avisoVisivel())
    }
}
