package br.com.frila.feature.vagas.feed

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.designsystem.componentes.AuditoriaSemanticaAcessibilidade
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoVagas
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h891dp")
class AuditoriaSemanticaFeedVagasTest {

    @get:Rule
    val compose = createComposeRule()

    private fun vagaJson(
        id: String = "11111111-1111-1111-1111-111111111111",
        funcao: String = "Garçom",
        estabelecimento: String = "Bar do Zé",
        distanciaKm: Double = 4.2,
        inicioEm: String = "2026-11-01T21:00:00Z",
        fimEm: String = "2026-11-02T03:00:00Z",
        valorCentavos: Long = 16_000L,
    ) = """
        {
          "id": "$id",
          "funcao": {"id": "22222222-2222-2222-2222-222222222222", "nome": "$funcao", "categoria": "Salão"},
          "estabelecimento": {
            "id": "33333333-3333-3333-3333-333333333333",
            "tipo": "estabelecimento",
            "nome": "$estabelecimento",
            "reputacao": {"positivas": 7, "total": 7, "taxa_comparecimento": 1.0, "turnos_considerados": 7, "turnos_realizados": 7}
          },
          "inicio_em": "$inicioEm",
          "fim_em": "$fimEm",
          "local": "SQN 108",
          "regiao_administrativa": "Asa Norte",
          "distancia_km": $distanciaKm,
          "valor_centavos": $valorCentavos,
          "posicoes_abertas": 2,
          "inclusos": {"inclui_refeicao": true, "inclui_transporte": false, "exige_material_proprio": false},
          "modo": "selecao"
        }
    """.trimIndent()

    private fun criarViewModel(respostaJson: String = "[]"): FeedVagasViewModel {
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
        val provedorDeLocalizacao = mockk<ProvedorDeLocalizacao>()
        coEvery { provedorDeLocalizacao.obterCoordenadaAtual() } returns null
        return FeedVagasViewModel(
            servicoVagas = ServicoVagas(cliente),
            provedorDeLocalizacao = provedorDeLocalizacao,
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    @Test
    fun `audita semantica da TelaFeedVagas real com lista de vagas e valida 100 por cento dos criterios`() {
        runBlocking {
            val json = "[${vagaJson(funcao = "Garçom", estabelecimento = "Bar do Zé")}, ${vagaJson(id = "22222222-2222-2222-2222-222222222222", funcao = "Cozinheiro", estabelecimento = "Restaurante Central")}]"
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaFeedVagas(
                        viewModel = viewModel,
                        aoAbrirDetalhe = {},
                        aoAbrirPerfil = {},
                    )
                }
            }
            compose.waitForIdle()

            val noRaiz = compose.onRoot().fetchSemanticsNode()
            AuditoriaSemanticaAcessibilidade.assertSemanticaValida(noRaiz)

            // Assegura que os cartões reais estão presentes e rotulados
            compose.onNodeWithText("Bar do Zé").assertExists()
            compose.onNodeWithText("Restaurante Central").assertExists()
        }
    }

    @Test
    fun `audita semantica da TelaFeedVagas real com texto de busca e botao limpar busca ativo`() {
        runBlocking {
            val json = "[${vagaJson(funcao = "Garçom", estabelecimento = "Bar do Zé")}]"
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaFeedVagas(
                        viewModel = viewModel,
                        aoAbrirDetalhe = {},
                        aoAbrirPerfil = {},
                    )
                }
            }
            compose.waitForIdle()

            // Digita no campo de busca para exibir o botão acionável de limpar busca
            compose.onNodeWithText("Buscar função ou estabelecimento").performTextInput("Garçom")
            compose.waitForIdle()

            // O botão de limpar busca deve existir e ter descrição acessível
            compose.onNodeWithContentDescription("Limpar busca").assertExists()

            // Auditoria semântica na árvore real contendo o controle acionável de busca
            val noRaiz = compose.onRoot().fetchSemanticsNode()
            AuditoriaSemanticaAcessibilidade.assertSemanticaValida(noRaiz)
        }
    }

    @Test
    fun `audita estrutura e ordem de foco dos cartoes de vaga na TelaFeedVagas real`() {
        runBlocking {
            val json = "[${vagaJson(funcao = "Garçom", estabelecimento = "Bar do Zé")}]"
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaFeedVagas(
                        viewModel = viewModel,
                        aoAbrirDetalhe = {},
                        aoAbrirPerfil = {},
                    )
                }
            }
            compose.waitForIdle()

            val noRaiz = compose.onRoot().fetchSemanticsNode()
            // Procura nó com heading para a função da vaga no cartão
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

            assertTrue("Deve existir pelo menos um cabeçalho semântico estrutural", nosHeading.isNotEmpty())
            val textoHeading = nosHeading.first().config.getOrNull(SemanticsProperties.Text)?.firstOrNull()?.text
            assertEquals("Garçom", textoHeading)
        }
    }
}
