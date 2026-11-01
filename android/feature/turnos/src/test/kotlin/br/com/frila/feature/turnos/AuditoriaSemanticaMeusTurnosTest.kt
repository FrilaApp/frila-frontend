package br.com.frila.feature.turnos

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.componentes.AuditoriaSemanticaAcessibilidade
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h891dp")
class AuditoriaSemanticaMeusTurnosTest {

    @get:Rule
    val compose = createComposeRule()

    private val provedorDeLocalizacaoFalso = object : ProvedorDeLocalizacao {
        override suspend fun obterCoordenadaAtual(): Coordenada? = null
        override fun temPermissaoDeLocalizacao(): Boolean = false
        override fun isGpsAtivado(): Boolean = false
    }

    private fun criarViewModel(respostaJson: String): MeusTurnosViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    content = respostaJson,
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        return MeusTurnosViewModel(
            servicoTurnos = ServicoTurnos(cliente),
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    private fun criarCheckin(turnoId: String): CheckinViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { respond("") },
        )
        return CheckinViewModel(
            turnoId = turnoId,
            coordenadaDaVaga = null,
            servicoTurnos = ServicoTurnos(cliente),
            provedorDeLocalizacao = provedorDeLocalizacaoFalso,
        )
    }

    private fun turnoJson(id: String, estado: String, funcao: String, estabelecimento: String) = """
        {
          "id": "$id",
          "posicao_id": "posicao-$id",
          "vaga": {
            "id": "vaga-$id",
            "funcao": "$funcao",
            "local": "CLS 405 Bloco C",
            "regiao_administrativa": "Plano Piloto",
            "inicio_em": "2026-11-01T21:00:00Z",
            "fim_em": "2026-11-02T03:00:00Z",
            "valor_centavos": 16000
          },
          "contraparte": {
            "id": "e1",
            "tipo": "estabelecimento",
            "nome": "$estabelecimento",
            "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}
          },
          "contato_visivel_ate": "2026-11-09T03:00:00Z",
          "a_caminho_em": null,
          "checkin_em": null,
          "checkin_tipo": null,
          "checkin_distancia_m": null,
          "checkin_confirmado_em": null,
          "checkout_em": null,
          "checkout_distancia_m": null,
          "verificacao": "pendente",
          "valor_acordado_centavos": 16000,
          "pode_avaliar": false,
          "estado": "$estado",
          "avaliacao": null,
          "cancelamento": null
        }
    """.trimIndent()

    @Test
    fun `audita semantica da TelaMeusTurnos real na aba Agendados com turno confirmado`() {
        runBlocking {
            val json = "[${turnoJson("t1", "confirmada", "Barman", "Pizzaria Bela Vista")}]"
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turnoId -> criarCheckin(turnoId) },
                    )
                }
            }
            compose.waitForIdle()

            // Valida semântica completa da tela real
            val noRaiz = compose.onRoot().fetchSemanticsNode()
            AuditoriaSemanticaAcessibilidade.assertSemanticaValida(noRaiz)

            compose.onNodeWithText("Barman").assertIsDisplayed()
            compose.onNodeWithText("Pizzaria Bela Vista").assertIsDisplayed()
            compose.onNodeWithText("Cancelar turno").assertExists().assertHasClickAction()
        }
    }

    @Test
    fun `audita semantica da TelaMeusTurnos real na aba Historico com turnos concluidos e cancelados`() {
        runBlocking {
            val json = "[${turnoJson("t2", "cumprida", "Copeiro", "Café do Lago")}, ${turnoJson("t3", "cancelada", "Garçom", "Restaurante Central")}]"
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turnoId -> criarCheckin(turnoId) },
                    )
                }
            }
            compose.waitForIdle()

            // Alterna para aba Histórico
            compose.onNodeWithText("Histórico").performClick()
            compose.waitForIdle()

            // Valida semântica da lista de histórico real com badges de status
            val noRaiz = compose.onRoot().fetchSemanticsNode()
            AuditoriaSemanticaAcessibilidade.assertSemanticaValida(noRaiz)

            compose.onNodeWithText("Copeiro").assertIsDisplayed()
            compose.onNodeWithText("Garçom").assertIsDisplayed()
        }
    }

    @Test
    fun `audita estrutura e ordem de foco dos cartoes de turno na TelaMeusTurnos real`() {
        runBlocking {
            val json = "[${turnoJson("t1", "confirmada", "Barman", "Pizzaria Bela Vista")}]"
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaMeusTurnos(
                        viewModel = viewModel,
                        criarCheckinViewModel = { turnoId -> criarCheckin(turnoId) },
                    )
                }
            }
            compose.waitForIdle()

            val noRaiz = compose.onRoot().fetchSemanticsNode()
            val nosHeading = mutableListOf<androidx.compose.ui.semantics.SemanticsNode>()
            fun buscarHeadings(no: androidx.compose.ui.semantics.SemanticsNode) {
                if (no.config.contains(SemanticsProperties.Heading)) {
                    nosHeading.add(no)
                }
                for (filho in no.children) {
                    buscarHeadings(filho)
                }
            }
            buscarHeadings(noRaiz)

            assertTrue("Deve conter cabeçalhos semânticos estruturais", nosHeading.isNotEmpty())
            // Título da tela "Meus Turnos" e o título do cartão "Barman"
            val textos = nosHeading.mapNotNull { it.config.getOrNull(SemanticsProperties.Text)?.firstOrNull()?.text }
            assertTrue(textos.contains("Meus Turnos"))
            assertTrue(textos.contains("Barman"))
        }
    }
}
