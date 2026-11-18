package br.com.frila.feature.vagas.capturas

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.Density
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.TelaFeedVagas
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Prints do lote R2 (profissional, vagas): feed, detalhe, abertura, indisponível e candidaturas, no claro, num
 * Pixel de 411 x 914 dp. Sem `FRILA_CAPTURAS_DIR` (na CI), cada teste só confere que a tela desenha sem quebrar.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasR2Test {

    @get:Rule
    val compose = createComposeRule()

    private fun comFonte(escala: Float, conteudo: @Composable () -> Unit): @Composable () -> Unit = {
        CompositionLocalProvider(LocalDensity provides Density(LocalDensity.current.density, fontScale = escala)) { conteudo() }
    }

    // ---- Feed ----

    private fun vagaJson(
        id: String,
        funcao: String,
        casa: String,
        distanciaKm: Double,
        valorCentavos: Long,
        modo: String,
    ) = """
        {
          "id": "$id",
          "funcao": {"id": "22222222-2222-2222-2222-222222222222", "nome": "$funcao", "categoria": "Salão"},
          "estabelecimento": {
            "id": "33333333-3333-3333-3333-333333333333",
            "tipo": "estabelecimento",
            "nome": "$casa",
            "reputacao": {"positivas": 7, "total": 7, "taxa_comparecimento": 1.0, "turnos_considerados": 7, "turnos_realizados": 7}
          },
          "inicio_em": "2026-11-21T21:00:00Z",
          "fim_em": "2026-11-22T03:00:00Z",
          "local": "SQN 108",
          "regiao_administrativa": "Asa Norte",
          "distancia_km": $distanciaKm,
          "valor_centavos": $valorCentavos,
          "posicoes_abertas": 2,
          "inclusos": {"inclui_refeicao": true, "inclui_transporte": true, "exige_material_proprio": false},
          "modo": "$modo"
        }
    """.trimIndent()

    private val tresVagas = "[" + listOf(
        vagaJson("v1", "Bartender", "Bar do Porto", 1.8, 22_000, "urgencia"),
        vagaJson("v2", "Garçom", "Adega Central", 3.4, 16_000, "selecao"),
        vagaJson("v3", "Auxiliar de cozinha", "Bistrô do Cais", 6.0, 14_000, "selecao"),
    ).joinToString(",") + "]"

    private fun viewModelDoFeed(resposta: String, status: HttpStatusCode = HttpStatusCode.OK): FeedVagasViewModel {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(resposta, status, headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        return FeedVagasViewModel(servicoVagas = ServicoVagas(cliente), escopo = CoroutineScope(Dispatchers.Default))
    }

    private fun feed(viewModel: FeedVagasViewModel, escala: Float = 1f, aoDefinirPontoBase: (() -> Unit)? = null) {
        compose.setContent(
            comFonte(escala) {
                FrilaTheme(temaEscuro = false) {
                    TelaFeedVagas(
                        viewModel = viewModel,
                        aoAbrirDetalhe = {},
                        aoAbrirMeusTurnos = {},
                        aoDefinirPontoBase = aoDefinirPontoBase,
                    )
                }
            },
        )
    }

    @Test
    fun `feed - carregando`() {
        feed(viewModelDoFeed("[]"))
        compose.capturar("r2-01-feed-carregando")
    }

    @Test
    fun `feed - com vagas`() {
        val viewModel = viewModelDoFeed(tresVagas)
        runBlocking { viewModel.carregar().join() }
        feed(viewModel)
        compose.capturar("r2-02-feed-com-vagas")
    }

    @Test
    fun `feed - com vagas, fonte 2x`() {
        val viewModel = viewModelDoFeed(tresVagas)
        runBlocking { viewModel.carregar().join() }
        feed(viewModel, escala = 2f)
        compose.capturar("r2-03-feed-com-vagas-fonte-2x")
    }

    @Test
    fun `feed - vazio`() {
        val viewModel = viewModelDoFeed("[]")
        runBlocking { viewModel.carregar().join() }
        feed(viewModel)
        compose.capturar("r2-04-feed-vazio")
    }

    @Test
    fun `feed - erro`() {
        val viewModel = viewModelDoFeed("""{"code":"PGRST500","message":"erro"}""", HttpStatusCode.InternalServerError)
        runBlocking { viewModel.carregar().join() }
        feed(viewModel)
        compose.capturar("r2-05-feed-erro")
    }

    @Test
    fun `feed - sem ponto base`() {
        val semPontoBase = """{"code":"campo_obrigatorio","message":"sem ponto de referência","details":"latitude"}"""
        val viewModel = viewModelDoFeed(semPontoBase, HttpStatusCode.UnprocessableEntity)
        runBlocking { viewModel.carregar().join() }
        feed(viewModel, aoDefinirPontoBase = {})
        compose.capturar("r2-06-feed-sem-ponto-base")
    }
}
