package br.com.frila.feature.turnos

import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
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
@Config(sdk = [35])
class TelaAvaliacaoTest {

    @get:Rule
    val compose = createComposeRule()

    private val turnoId = "11111111-1111-1111-1111-111111111111"

    private fun criarViewModel(
        respostaJson: String = """{"turno_id":"$turnoId","resposta":true,"criada_em":"2026-11-02T04:00:00Z"}""",
        statusHttp: HttpStatusCode = HttpStatusCode.OK,
    ): AvaliacaoViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    content = respostaJson,
                    status = statusHttp,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        return AvaliacaoViewModel(
            servicoTurnos = ServicoTurnos(cliente),
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    @Test
    fun `tela inicial exibe pergunta, explicacao e botoes com alvo minimo de 48dp`() {
        val viewModel = criarViewModel()

        compose.setContent {
            FrilaTheme {
                TelaAvaliacao(turnoId = turnoId, viewModel = viewModel)
            }
        }

        compose.onNodeWithText("Você trabalharia nesse local de novo?").assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))

        compose.onNodeWithText("A avaliação é só sim ou não, e é anônima para o estabelecimento.")
            .assertIsDisplayed()

        compose.onNodeWithText("Sim, trabalharia")
            .assertIsDisplayed()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)

        compose.onNodeWithText("Não trabalharia")
            .assertIsDisplayed()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
    }

    @Test
    fun `ao avaliar positivamente exibe confirmacao com liveRegion polite e botao voltar`() {
        runBlocking {
            var voltou = false
            val viewModel = criarViewModel(
                respostaJson = """{"turno_id":"$turnoId","resposta":true,"criada_em":"2026-11-02T04:00:00Z"}""",
            )

            compose.setContent {
                FrilaTheme {
                    TelaAvaliacao(turnoId = turnoId, viewModel = viewModel, aoVoltar = { voltou = true })
                }
            }

            compose.onNodeWithText("Sim, trabalharia").performClick()
            compose.waitUntil(5000) { viewModel.estado.value.status == StatusAvaliacao.SUCESSO }
            compose.waitForIdle()

            assertEquals(StatusAvaliacao.SUCESSO, viewModel.estado.value.status)
            assertEquals(true, viewModel.estado.value.respostaRegistrada)

            compose.onNodeWithText("Avaliação registrada").assertIsDisplayed()
                .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))

            compose.onNodeWithText("Você recomendou este local.").assertIsDisplayed()

            compose.onNode(
                SemanticsMatcher.expectValue(SemanticsProperties.LiveRegion, LiveRegionMode.Polite),
                useUnmergedTree = true,
            ).assertIsDisplayed()

            compose.onNodeWithText("Voltar")
                .assertIsDisplayed()
                .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
                .performClick()

            assertTrue(voltou)
        }
    }

    @Test
    fun `ao avaliar negativamente exibe mensagem correspondente com liveRegion polite`() {
        runBlocking {
            val viewModel = criarViewModel(
                respostaJson = """{"turno_id":"$turnoId","resposta":false,"criada_em":"2026-11-02T04:00:00Z"}""",
            )

            compose.setContent {
                FrilaTheme {
                    TelaAvaliacao(turnoId = turnoId, viewModel = viewModel)
                }
            }

            compose.onNodeWithText("Não trabalharia").performClick()
            compose.waitUntil(5000) { viewModel.estado.value.status == StatusAvaliacao.SUCESSO }
            compose.waitForIdle()

            assertEquals(StatusAvaliacao.SUCESSO, viewModel.estado.value.status)
            assertEquals(false, viewModel.estado.value.respostaRegistrada)

            compose.onNodeWithText("Você não recomendou este local.").assertIsDisplayed()

            compose.onNode(
                SemanticsMatcher.expectValue(SemanticsProperties.LiveRegion, LiveRegionMode.Polite),
                useUnmergedTree = true,
            ).assertIsDisplayed()
        }
    }

    @Test
    fun `em caso de erro exibe mensagem com liveRegion assertiva e opcoes de nova tentativa`() {
        runBlocking {
            val viewModel = criarViewModel(
                respostaJson = """{"code":"avaliacao_indisponivel","message":"Turno ainda em andamento"}""",
                statusHttp = HttpStatusCode.UnprocessableEntity,
            )

            compose.setContent {
                FrilaTheme {
                    TelaAvaliacao(turnoId = turnoId, viewModel = viewModel)
                }
            }

            compose.onNodeWithText("Sim, trabalharia").performClick()
            compose.waitUntil(5000) { viewModel.estado.value.status == StatusAvaliacao.ERRO }
            compose.waitForIdle()

            assertEquals(StatusAvaliacao.ERRO, viewModel.estado.value.status)

            compose.onNode(
                SemanticsMatcher.expectValue(SemanticsProperties.LiveRegion, LiveRegionMode.Assertive),
                useUnmergedTree = true,
            ).assertIsDisplayed()

            compose.onNodeWithText("Você trabalharia nesse local de novo?")
                .assertIsDisplayed()
                .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))

            compose.onNodeWithText("Sim, trabalharia")
                .assertIsDisplayed()
                .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)

            compose.onNodeWithText("Não trabalharia")
                .assertIsDisplayed()
                .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
        }
    }
    @Test fun `fila mostra aviso acessivel e voltar na avaliacao do profissional`() = conferirFila(false)

    @Test fun `fila mostra o mesmo aviso na avaliacao do contratante`() = conferirFila(true)

    private fun conferirFila(contratante: Boolean) {
        val fila = br.com.frila.core.rede.FilaDeAcoes(null)
        fila.enfileirar(br.com.frila.core.rede.AcaoPendente(
            br.com.frila.core.rede.TipoAcaoPendente.AVALIACAO, "conta", "2026-11-23T12:00:00Z",
            turnoId = turnoId, resposta = false,
        ))
        val cliente = ClienteSupabase("https://sintetico.supabase.invalid", "chave-sintetica", engine = MockEngine {
            error("a tela reaberta deve ler a fila sem pedido de rede")
        })
        val escopo = CoroutineScope(Dispatchers.Unconfined + kotlinx.coroutines.SupervisorJob())
        try {
            val vm = AvaliacaoViewModel(ServicoTurnos(cliente), escopo, filaDeAcoes = fila, contaAtual = { "conta" })
            var voltou = false
            compose.setContent {
                FrilaTheme {
                    if (contratante) br.com.frila.feature.turnos.contratante.TelaAvaliacaoDoContratante(turnoId, vm, { voltou = true })
                    else TelaAvaliacao(turnoId, vm, { voltou = true })
                }
            }
            compose.onNodeWithText("Avaliação guardada").assertIsDisplayed()
            compose.onNodeWithText(TextosDaFilaDeAvaliacao.NA_FILA).assertIsDisplayed()
                .assert(SemanticsMatcher.expectValue(SemanticsProperties.LiveRegion, LiveRegionMode.Polite))
            compose.onNodeWithText("Voltar").assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()
            assertTrue(voltou)
            assertEquals(1, fila.pendentes().size)
        } finally { escopo.coroutineContext[kotlinx.coroutines.Job]?.cancel(); cliente.close() }
    }

    // MO7DkVA2: o 409 avaliacao_ja_registrada deixa a tela em "já avaliado": sem botões de avaliar, com a resposta gravada relida do turno.
    private fun viewModelComConflito(gravada: Boolean?): AvaliacaoViewModel {
        val turno = """
            [{"id": "$turnoId", "posicao_id": "p1",
              "vaga": {"id": "v1", "funcao": "garçom", "local": "CLS 405", "regiao_administrativa": "Plano Piloto",
                       "inicio_em": "2026-11-01T21:00:00Z", "fim_em": "2026-11-02T03:00:00Z", "valor_centavos": 16000},
              "contraparte": {"id": "c1", "tipo": "estabelecimento", "nome": "Bar do Zé",
                              "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}},
              "verificacao": "verificado", "valor_acordado_centavos": 16000, "pode_avaliar": false, "estado": "cumprida",
              "avaliacao": ${gravada?.let { """{"turno_id": "$turnoId", "resposta": $it, "criada_em": "2026-11-02T04:00:00Z"}""" } ?: "null"},
              "cancelamento": null}]
        """.trimIndent()
        val cabecalho = headersOf(HttpHeaders.ContentType, "application/json")
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { request ->
                if (request.url.encodedPath.endsWith("/avaliar")) {
                    respond("""{"code":"avaliacao_ja_registrada","message":"sintetico"}""", HttpStatusCode.Conflict, cabecalho)
                } else {
                    respond(turno, HttpStatusCode.OK, cabecalho)
                }
            },
        )
        return AvaliacaoViewModel(servicoTurnos = ServicoTurnos(cliente), escopo = CoroutineScope(Dispatchers.Default))
    }

    @Test
    fun `409 avaliacao_ja_registrada mostra turno ja avaliado com a resposta gravada e sem botoes de avaliar`() {
        val viewModel = viewModelComConflito(gravada = true)

        compose.setContent { FrilaTheme { TelaAvaliacao(turnoId = turnoId, viewModel = viewModel) } }

        compose.onNodeWithText("Não trabalharia").performClick()
        compose.waitUntil(5000) { viewModel.estado.value.status == StatusAvaliacao.JA_AVALIADO }
        compose.waitForIdle()

        compose.onNodeWithText("Turno já avaliado").assertIsDisplayed()
        compose.onNodeWithText("A avaliação registrada: você recomendou este local.").assertIsDisplayed()
        compose.onNodeWithText("Sim, trabalharia").assertDoesNotExist()
        compose.onNodeWithText("Não trabalharia").assertDoesNotExist()
        compose.onNodeWithText("Voltar").assertIsDisplayed()
    }

    @Test
    fun `409 sem a resposta na releitura mostra turno ja avaliado sem afirmar a resposta`() {
        val viewModel = viewModelComConflito(gravada = null)

        compose.setContent { FrilaTheme { TelaAvaliacao(turnoId = turnoId, viewModel = viewModel) } }

        compose.onNodeWithText("Sim, trabalharia").performClick()
        compose.waitUntil(5000) { viewModel.estado.value.status == StatusAvaliacao.JA_AVALIADO }
        compose.waitForIdle()

        compose.onNodeWithText("Este turno já tem uma avaliação registrada.").assertIsDisplayed()
        compose.onNodeWithText("Sim, trabalharia").assertDoesNotExist()
        compose.onNodeWithText("Não trabalharia").assertDoesNotExist()
    }
}

