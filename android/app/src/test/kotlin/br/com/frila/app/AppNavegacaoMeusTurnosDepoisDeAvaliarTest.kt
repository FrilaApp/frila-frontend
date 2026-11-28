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

/**
 * Cartão AFZ5dhL7 (ressalva do Sharingan no #1170): `MeusTurnosDepoisDeAvaliarTest` monta o próprio `NavHost` com o
 * `LaunchedEffect`, e a rota real só era protegida por um teste que lê o texto de `AppNavegacao`. Aqui a pilha é a de
 * `AppNavegacao`: "Avaliar turno" abre `Rotas.AVALIACAO` pelo `aoAbrirAvaliacao` da rota, e o "Voltar" da barra de topo da
 * avaliação chama o `popBackStack()` da rota. Quem relê a lista ao voltar é o `LaunchedEffect(viewModel) { carregar() }` de
 * `Rotas.MEUS_TURNOS`.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = android.app.Application::class, qualifiers = "w411dp-h891dp")
class AppNavegacaoMeusTurnosDepoisDeAvaliarTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var navController: NavHostController

    private fun turnoJson(podeAvaliar: Boolean, funcao: String) = """
        [{
          "id": "t1", "posicao_id": "posicao-t1",
          "vaga": {"id": "vaga-t1", "funcao": "$funcao", "local": "CLS 405 Bloco C", "regiao_administrativa": "Plano Piloto",
                   "inicio_em": "2026-11-02T01:00:00Z", "fim_em": "2026-11-02T10:00:00Z", "valor_centavos": 16000},
          "contraparte": {"id": "e1", "tipo": "estabelecimento", "nome": "Bar do Zé",
                          "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}},
          "contato_visivel_ate": "2026-11-09T03:00:00Z", "a_caminho_em": "2026-11-02T00:30:00Z",
          "checkin_em": "2026-11-02T00:55:00Z", "checkin_tipo": "geolocalizado", "checkin_distancia_m": 80,
          "checkin_confirmado_em": null, "checkout_em": "2026-11-02T08:50:00Z", "checkout_distancia_m": null,
          "verificacao": "verificado", "valor_acordado_centavos": 16000, "pode_avaliar": $podeAvaliar,
          "estado": "confirmada", "avaliacao": null, "cancelamento": null
        }]
    """.trimIndent()

    @Test
    fun `na rota real, avaliar e voltar rele Meus turnos e o botao Avaliar turno some`() {
        val leituras = AtomicInteger(0)
        val avaliado = AtomicBoolean(false)
        val servicoTurnos = ServicoTurnos(
            ClienteSupabase(
                baseUrl = "https://frila.supabase.co",
                apiKey = "chave-teste",
                engine = MockEngine { request ->
                    if (request.url.encodedPath.endsWith("meus_turnos")) {
                        // O servidor: antes da avaliação pode_avaliar é true; depois, false (e outra função, para saber
                        // que a lista nova chegou). Pelo estado, não pela contagem: a tela de avaliação também lê meus_turnos.
                        leituras.incrementAndGet()
                        val depois = avaliado.get()
                        respond(
                            turnoJson(podeAvaliar = !depois, funcao = if (depois) "Barista" else "Garçom"),
                            headers = headersOf(HttpHeaders.ContentType, "application/json"),
                        )
                    } else {
                        respond("{}", headers = headersOf(HttpHeaders.ContentType, "application/json"))
                    }
                },
            ),
        )
        val provedor = object : ProvedorDeLocalizacao {
            override suspend fun obterCoordenadaAtual(): Coordenada? = null
            override fun temPermissaoDeLocalizacao(): Boolean = false
            override fun isGpsAtivado(): Boolean = false
        }
        val entradaVm = mockk<EntradaViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoEntrada())
        }
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
                        viewModel { entradaVm }
                        viewModel { MeusTurnosViewModel(servicoTurnos = servicoTurnos, escopo = CoroutineScope(Dispatchers.Unconfined)) }
                        viewModel { (turnoId: String, coordenadaDaVaga: Coordenada?) ->
                            CheckinViewModel(turnoId, coordenadaDaVaga, servicoTurnos, provedor)
                        }
                        viewModel { AvaliacaoViewModel(servicoTurnos) }
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

        // A resposta do servidor chega fora da composição: espera-se a condição, com limite (como no teste do #1170).
        aguardar { rule.onAllNodesWithText("Garçom").fetchSemanticsNodes().isNotEmpty() }
        assertEquals("a primeira leitura", 1, leituras.get())

        rule.onNodeWithText("Avaliar turno").performClick()
        rule.waitForIdle()
        assertEquals(Rotas.AVALIACAO, rule.runOnUiThread<String?> { navController.currentDestination?.route })
        // AvaliacaoViewModel lê meus_turnos para achar o turno (medido: a segunda leitura acontece com a avaliação no topo da
        // pilha). Espera-se essa leitura antes de o turno passar a avaliado no servidor.
        aguardar { leituras.get() == 2 }
        avaliado.set(true)

        rule.onNodeWithContentDescription("Voltar").performClick()

        // Só depois de a lista nova ("Barista") estar na tela é que a ausência do botão vale: durante a releitura a lista
        // some e o botão também, e isso não prova nada.
        aguardar { rule.onAllNodesWithText("Barista").fetchSemanticsNodes().isNotEmpty() }
        assertEquals(Rotas.MEUS_TURNOS, rule.runOnUiThread<String?> { navController.currentDestination?.route })
        assertEquals("ao abrir, na avaliação e ao voltar pela pilha", 3, leituras.get())
        rule.onNodeWithText("Avaliar turno").assertDoesNotExist()
    }

    private fun aguardar(condicao: () -> Boolean) = rule.waitUntil(10_000, condicao)
}
