package br.com.frila.app

import android.app.Application
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.feature.turnos.CheckinViewModel
import br.com.frila.feature.turnos.MeusTurnosViewModel
import br.com.frila.feature.turnos.TelaMeusTurnos
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.headersOf
import java.io.File
import java.time.Instant
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Item 119 (cartão): depois de avaliar o turno e voltar, Meus turnos não pode seguir com "Avaliar turno". `aoAbrirAvaliacao` só navega e
 * `AvaliacaoViewModel` volta com `popBackStack()` sem sinal; quem corrige a lista é a releitura da rota (`LaunchedEffect(viewModel) {
 * viewModel.carregar() }` em `AppNavegacao`), que roda de novo quando a tela volta à composição. Medido com uma pilha de verdade
 * (1 leitura ao abrir, 2 ao voltar, e o botão some). O `NavHost` daqui repete a fiação da rota, e por isso o teste do texto da rota
 * confere que ela ainda está em `AppNavegacao`.
 */
@RunWith(RobolectricTestRunner::class)
// Janela alta: o cartão do turno agendado ganhou a linha "Quem recebe" (QpgRwPFM) e, na janela padrão do Robolectric (470 dp), o botão
// "Avaliar turno" ficava fora da tela e o toque não o alcançava. Medido: sem a linha o teste passava; com ela e a janela alta, também.
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h1200dp")
class MeusTurnosDepoisDeAvaliarTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private fun turnoJson(podeAvaliar: Boolean, funcao: String = "Garçom") = """
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
    fun `avaliar e voltar pela pilha rele os turnos e o botao Avaliar turno some`() {
        val leituras = AtomicInteger(0)
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                // O servidor: antes da avaliação pode_avaliar é true; depois, false.
                val n = leituras.incrementAndGet()
                respond(turnoJson(podeAvaliar = n == 1, funcao = if (n == 1) "Garçom" else "Barista"), headers = headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        val vm = MeusTurnosViewModel(servicoTurnos = ServicoTurnos(cliente), escopo = CoroutineScope(Dispatchers.Unconfined))
        val provedor = object : ProvedorDeLocalizacao {
            override suspend fun obterCoordenadaAtual(): Coordenada? = null
            override fun temPermissaoDeLocalizacao(): Boolean = false
            override fun isGpsAtivado(): Boolean = false
        }
        rule.setContent {
            FrilaTheme {
                val nav = rememberNavController()
                NavHost(nav, startDestination = "turnos") {
                    composable("turnos") {
                        LaunchedEffect(vm) { vm.carregar() }
                        TelaMeusTurnos(
                            viewModel = vm,
                            criarCheckinViewModel = { turno ->
                                CheckinViewModel(
                                    turnoId = turno.turnoId, coordenadaDaVaga = null,
                                    servicoTurnos = ServicoTurnos(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "k", engine = MockEngine { respond("") })),
                                    provedorDeLocalizacao = provedor,
                                )
                            },
                            aoAbrirAvaliacao = { nav.navigate("avaliar") },
                            relogio = { Instant.parse("2026-11-02T11:00:00Z") },
                            comTitulo = false,
                        )
                    }
                    composable("avaliar") { Button(onClick = { nav.popBackStack() }) { Text("Enviar avaliação") } }
                }
            }
        }
        // A resposta do servidor chega fora da composição: `waitForIdle` não a espera (na CI, o botão ainda não estava na tela).
        // Espera-se a condição, com limite, e as asserções seguem as mesmas.
        aguardar { rule.onAllNodesWithText("Garçom").fetchSemanticsNodes().isNotEmpty() }
        assertEquals("a primeira leitura", 1, leituras.get())
        rule.onNodeWithText("Avaliar turno").assertExists()

        rule.onNodeWithText("Avaliar turno").performClick()
        aguardar { rule.onAllNodesWithText("Enviar avaliação").fetchSemanticsNodes().isNotEmpty() }
        rule.onNodeWithText("Enviar avaliação").performClick()

        // Só depois de a lista nova (outra função, "Barista") estar na tela é que a ausência do botão vale: durante a
        // releitura a lista some e o botão também, e isso não prova nada.
        aguardar { rule.onAllNodesWithText("Barista").fetchSemanticsNodes().isNotEmpty() }
        assertEquals("voltar pela pilha relê os turnos", 2, leituras.get())
        rule.onNodeWithText("Avaliar turno").assertDoesNotExist()
    }

    private fun aguardar(condicao: () -> Boolean) = rule.waitUntil(10_000, condicao)

    @Test
    fun `a rota de Meus turnos continua relendo ao voltar - o LaunchedEffect de carregar esta em AppNavegacao`() {
        val relativo = "src/main/kotlin/br/com/frila/app/AppNavegacao.kt"
        val fonte = listOf(File(relativo), File("app/$relativo")).first { it.exists() }.readText()
        val inicio = fonte.indexOf("route = Rotas.MEUS_TURNOS,")
        val bloco = fonte.substring(inicio, fonte.indexOf("composable(Rotas.AVALIACAO)", inicio))
        assertTrue(
            "Meus turnos precisa reler quando a tela volta à composição (avaliar, cancelar)",
            bloco.contains("LaunchedEffect(viewModel) { viewModel.carregar() }"),
        )
    }
}
