package br.com.frila.feature.vagas.feed

import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.hasScrollToIndexAction
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertWidthIsAtLeast
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.EventoDeTelemetria
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoVagas
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
// RF10: a nova linha de chips "Ordenar por:" aumenta a altura de LinhaDeFiltros — qualifiers
// maior evita que conteúdo abaixo (erro/lista) saia da janela virtual pequena padrão do
// Robolectric, sem mudar nada da tela de verdade (viewport maior, não layout diferente).
@Config(sdk = [35], qualifiers = "w411dp-h891dp")
class TelaFeedVagasTest {

    @get:Rule
    val compose = createComposeRule()

    private fun vagaJson(
        id: String = "11111111-1111-1111-1111-111111111111",
        funcao: String = "garçom",
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

    private fun criarViewModel(
        respostaJson: String = "[]",
        status: HttpStatusCode = HttpStatusCode.OK,
        registrarEvento: (EventoDeTelemetria, String?, String?) -> Unit = { _, _, _ -> },
    ): FeedVagasViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    content = respostaJson,
                    status = status,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        return FeedVagasViewModel(
            servicoVagas = ServicoVagas(cliente),
            escopo = CoroutineScope(Dispatchers.Default),
            registrarEvento = registrarEvento,
        )
    }

    @Test
    fun `telemetria de vaga vista nao duplica ao rolar a lista e voltar`() = runBlocking {
        val eventos = mutableListOf<String?>()
        val json = (0 until 24).joinToString(prefix = "[", postfix = "]") {
            vagaJson(id = "vaga-$it", estabelecimento = "Casa sintetica $it")
        }
        val vm = criarViewModel(json, registrarEvento = { evento, vaga, turno ->
            assertEquals(EventoDeTelemetria.VAGA_VISTA, evento)
            assertEquals(null, turno)
            eventos += vaga
        })
        vm.carregar().join()
        compose.setContent { FrilaTheme { TelaFeedVagas(vm, aoAbrirDetalhe = {}) } }
        compose.waitForIdle()
        val antesDeRolar = eventos.toSet()
        compose.onNode(hasScrollToIndexAction() and SemanticsMatcher.keyIsDefined(SemanticsProperties.VerticalScrollAxisRange)).performScrollToIndex(22)
        compose.waitForIdle()
        compose.onNode(hasScrollToIndexAction() and SemanticsMatcher.keyIsDefined(SemanticsProperties.VerticalScrollAxisRange)).performScrollToIndex(0)
        compose.waitForIdle()
        compose.runOnIdle {
            assertEquals(1, eventos.count { it == "vaga-0" })
            assertEquals(eventos.distinct(), eventos)
            org.junit.Assert.assertTrue(eventos.any { it !in antesDeRolar })
        }
    }

    @Test
    fun `tela raiz - o feed abre com Vagas abertas e sem atalhos para Meus turnos e Perfil, que viraram abas`() {
        val viewModel = criarViewModel()

        compose.setContent { FrilaTheme { TelaFeedVagas(viewModel = viewModel, aoAbrirDetalhe = {}) } }

        compose.onNodeWithText("Vagas abertas").assertIsDisplayed()
        compose.onNodeWithText("Meus turnos").assertDoesNotExist()
        compose.onNodeWithContentDescription("Meu perfil").assertDoesNotExist()
    }

    @Test
    fun `quando feed esta vazio exibe mensagem de estado vazio`() {
        runBlocking {
            val viewModel = criarViewModel("[]")
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaFeedVagas(
                        viewModel = viewModel,
                        aoAbrirDetalhe = {},
                    )
                }
            }

            compose.waitForIdle()
            compose.onNodeWithText("Nenhuma vaga encontrada com esses filtros.").assertIsDisplayed()
        }
    }

    @Test
    fun `sem ponto base o feed explica o que falta e o botao leva a defini-lo`() {
        runBlocking {
            val semPontoBase = """{"code":"campo_obrigatorio","message":"sem ponto de referência","details":"latitude"}"""
            val viewModel = criarViewModel(semPontoBase, HttpStatusCode.UnprocessableEntity)
            viewModel.carregar().join()
            var abriu = 0

            compose.setContent {
                FrilaTheme {
                    TelaFeedVagas(viewModel = viewModel, aoAbrirDetalhe = {}, aoDefinirPontoBase = { abriu++ })
                }
            }

            compose.waitForIdle()
            compose.onNodeWithText("Falta o seu ponto base").assertIsDisplayed()
            compose.onNodeWithText("Definir ponto base").assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()
            assertEquals(1, abriu)
        }
    }

    @Test
    fun `conta de contratante ve o aviso da lista e nao ve o botao tentar novamente`() {
        runBlocking {
            val viewModel = criarViewModel(
                """{"code":"perfil_incompativel","message":"perfil_incompativel","details":null}""",
                HttpStatusCode.UnprocessableEntity,
            )
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaFeedVagas(viewModel = viewModel, aoAbrirDetalhe = {}, aoDefinirPontoBase = {})
                }
            }

            compose.waitForIdle()
            compose.onNodeWithText("Esta lista é para quem trabalha como profissional.", useUnmergedTree = true).assertIsDisplayed()
            compose.onNodeWithText("Tentar novamente").assertDoesNotExist()
            compose.onNodeWithText("Definir ponto base").assertDoesNotExist()
        }
    }

    @Test
    fun `quando api retorna erro exibe mensagem de erro e botao tentar novamente`() {
        runBlocking {
            val erroJson = """{"code":"PGRST500","message":"erro"}"""
            val viewModel = criarViewModel(erroJson, HttpStatusCode.InternalServerError)
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaFeedVagas(
                        viewModel = viewModel,
                        aoAbrirDetalhe = {},
                    )
                }
            }

            compose.waitForIdle()
            compose.onNodeWithText("Tentar novamente").assertIsDisplayed().assertHasClickAction()
        }
    }

    @Test
    fun `quando possui vagas abertas exibe lista e ao clicar abre detalhe`() {
        runBlocking {
            val json = "[${vagaJson(id = "vaga-abc", funcao = "Garçom", estabelecimento = "Restaurante Central")}]"
            val viewModel = criarViewModel(json)
            viewModel.carregar().join()

            var vagaIdClicada: String? = null

            compose.setContent {
                FrilaTheme {
                    TelaFeedVagas(
                        viewModel = viewModel,
                        aoAbrirDetalhe = { vagaIdClicada = it },
                    )
                }
            }

            compose.waitForIdle()
            compose.onNodeWithText("Restaurante Central").assertIsDisplayed().performClick()
            assertEquals("vaga-abc", vagaIdClicada)
        }
    }

    @Test
    fun `campo de busca permite digitar texto e limpar busca`() {
        runBlocking {
            val viewModel = criarViewModel("[]")
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaFeedVagas(
                        viewModel = viewModel,
                        aoAbrirDetalhe = {},
                    )
                }
            }

            compose.waitForIdle()
            val campoBusca = compose.onNodeWithContentDescription("Buscar função ou estabelecimento")
            campoBusca.assertIsDisplayed()
            campoBusca.performTextInput("Barista")
            compose.waitForIdle()

            assertEquals("Barista", viewModel.estado.value.textoBusca)

            // Botão limpar aparece quando há texto
            compose.onNodeWithContentDescription("Limpar busca").assertIsDisplayed().performClick()
            compose.waitForIdle()

            assertEquals("", viewModel.estado.value.textoBusca)
        }
    }

    @Test
    fun `durante o carregamento exibe skeleton anunciado uma unica vez (RNF10)`() {
        // Sem chamar carregar(), o estado default do FeedVagasViewModel fica em CARREGANDO —
        // MEDIDO em EstadoFeed.kt:64.
        val viewModel = criarViewModel()

        compose.setContent {
            FrilaTheme {
                TelaFeedVagas(
                    viewModel = viewModel,
                    aoAbrirDetalhe = {},
                )
            }
        }
        compose.waitForIdle()

        compose.onNodeWithContentDescription("Carregando lista de vagas...").assertIsDisplayed()
    }

    @Test
    fun `skeleton do carregamento anuncia como liveRegion Polite (RNF10)`() {
        // MEDIDO (Shisui, PR #594, bloqueante 1): sabotagem removendo liveRegion sobreviveu —
        // sem esta asserção explícita, nada provava que o container usa LiveRegionMode.Polite
        // (e não, por exemplo, Assertive, que interrompe o que o TalkBack já estava lendo).
        val viewModel = criarViewModel()

        compose.setContent {
            FrilaTheme {
                TelaFeedVagas(
                    viewModel = viewModel,
                    aoAbrirDetalhe = {},
                )
            }
        }
        compose.waitForIdle()

        compose.onNodeWithContentDescription("Carregando lista de vagas...")
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.LiveRegion, LiveRegionMode.Polite))
    }

    // RF10/RNF10: ordenação flexível do feed — chips visíveis e acessíveis.

    @Test
    fun `chips de ordenacao sao visiveis com alvo minimo de 48dp`() {
        runBlocking {
            val viewModel = criarViewModel(
                "[${vagaJson(id = "a")}, ${vagaJson(id = "b", distanciaKm = 9.0)}]",
            )
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaFeedVagas(viewModel = viewModel, aoAbrirDetalhe = {})
                }
            }
            compose.waitForIdle()

            compose.onNodeWithText("Menor distância")
                .assertIsDisplayed()
                .assertWidthIsAtLeast(48.dp)
                .assertHeightIsAtLeast(48.dp)
            compose.onNodeWithText("Maior valor")
                .assertIsDisplayed()
                .assertWidthIsAtLeast(48.dp)
                .assertHeightIsAtLeast(48.dp)
        }
    }

    @Test
    fun `selecionar Maior valor reordena a lista e atualiza o estado semantico do chip`() {
        runBlocking {
            val viewModel = criarViewModel(
                "[${vagaJson(id = "a", funcao = "barato", valorCentavos = 10_000L, distanciaKm = 2.0)}, " +
                    "${vagaJson(id = "b", funcao = "caro", valorCentavos = 30_000L, distanciaKm = 8.0)}]",
            )
            viewModel.carregar().join()

            compose.setContent {
                FrilaTheme {
                    TelaFeedVagas(viewModel = viewModel, aoAbrirDetalhe = {})
                }
            }
            compose.waitForIdle()

            // Padrão (menor distância): "barato" (2km) vem primeiro.
            assertEquals("barato", viewModel.estado.value.vagas.first().funcaoNome)

            compose.onNodeWithText("Maior valor").performClick()
            compose.waitForIdle()

            // "caro" (R$ 300) agora vem primeiro.
            assertEquals("caro", viewModel.estado.value.vagas.first().funcaoNome)
            compose.onNodeWithText("Maior valor")
                .assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "selecionado"))
            compose.onNodeWithText("Menor distância")
                .assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "não selecionado"))
        }
    }
}
