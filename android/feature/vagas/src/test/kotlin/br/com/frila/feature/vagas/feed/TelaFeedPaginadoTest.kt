package br.com.frila.feature.vagas.feed

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.hasScrollToIndexAction
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToIndex
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoVagas
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.util.Collections
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão qmheBhAK, fatia 2: a tela do feed pagina. O último cartão pede a página seguinte, a contagem diz quando há mais
 * ("N vagas carregadas", como o iOS), e o fim da lista oferece "Carregar mais vagas" para tentar de novo depois de uma falha.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h891dp")
class TelaFeedPaginadoTest {

    @get:Rule
    val compose = createComposeRule()

    private val json = headersOf(HttpHeaders.ContentType, "application/json")

    private fun vagaJson(id: String) = """
        {"id":"$id","funcao":{"id":"f1","nome":"garçom","categoria":"Salão"},
         "estabelecimento":{"id":"e1","tipo":"estabelecimento","nome":"Casa $id",
           "reputacao":{"positivas":7,"total":7,"taxa_comparecimento":1.0,"turnos_considerados":7,"turnos_realizados":7}},
         "inicio_em":"2026-11-01T21:00:00Z","fim_em":"2026-11-02T03:00:00Z","local":"SQN 108","regiao_administrativa":"Asa Norte",
         "distancia_km":4.2,"valor_centavos":16000,"posicoes_abertas":2,
         "inclusos":{"inclui_refeicao":true,"inclui_transporte":false,"exige_material_proprio":false},"modo":"selecao"}
    """.trimIndent()

    private fun pagina(ids: List<String>) = ids.joinToString(",", "[", "]") { vagaJson(it) }

    private val deslocamentos: MutableList<Int> = Collections.synchronizedList(mutableListOf())

    /** [segunda] responde o deslocamento 30: `null` é uma recusa (422, que o cliente não repete sozinho, ao contrário de um 503). */
    private fun viewModel(primeira: Int, segunda: () -> List<String>?): FeedVagasViewModel {
        val engine = MockEngine { request ->
            val d = request.url.parameters["deslocamento"]!!.toInt()
            deslocamentos += d
            if (d == 0) {
                respond(pagina((0 until primeira).map { "v$it" }), HttpStatusCode.OK, json)
            } else {
                segunda()?.let { respond(pagina(it), HttpStatusCode.OK, json) }
                    ?: respond("""{"code":"campo_invalido","message":"x"}""", HttpStatusCode.UnprocessableEntity, json)
            }
        }
        return FeedVagasViewModel(
            servicoVagas = ServicoVagas(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine)),
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    private fun lista() = compose.onNode(hasScrollToIndexAction() and SemanticsMatcher.keyIsDefined(SemanticsProperties.VerticalScrollAxisRange))

    /** Busca, filtros e cabeçalho vêm antes dos cartões: com 30 vagas, o último cartão é o índice 32 e o rodapé, o 33. */
    private fun rolarAteOFim() = lista().performScrollToIndex(33)

    @Test
    fun `rolar ate o ultimo cartao pede a pagina seguinte e a contagem diz quando ha mais`() = runBlocking {
        val vm = viewModel(primeira = 30) { (30 until 35).map { "v$it" } }
        vm.carregar().join()
        compose.setContent { FrilaTheme { TelaFeedVagas(vm, aoAbrirDetalhe = {}) } }
        compose.waitForIdle()
        compose.onNodeWithText("30 vagas carregadas").assertExists()
        assertEquals(listOf(0), deslocamentos.toList())

        rolarAteOFim()
        compose.waitUntil(5_000) { vm.estado.value.vagas.size == 35 }
        compose.waitForIdle()

        assertEquals(listOf(0, 30), deslocamentos.toList())
        // A última página veio menor: no fim da lista não há mais rodapé (35 cartões vão do índice 3 ao 37).
        lista().performScrollToIndex(37)
        compose.waitForIdle()
        assertEquals(0, compose.onAllNodesWithTag(TAG_CARREGAR_MAIS).fetchSemanticsNodes().size)
        // E a contagem, no topo, já não diz "carregadas".
        lista().performScrollToIndex(0)
        compose.waitForIdle()
        compose.onNodeWithText("35 vagas").assertExists()
        assertEquals(0, compose.onAllNodesWithText("35 vagas carregadas").fetchSemanticsNodes().size)
    }

    @Test
    fun `a pagina seguinte que falha deixa Carregar mais vagas, e o toque tenta de novo`() = runBlocking {
        var falhar = true
        val vm = viewModel(primeira = 30) { if (falhar) null else listOf("v30") }
        vm.carregar().join()
        compose.setContent { FrilaTheme { TelaFeedVagas(vm, aoAbrirDetalhe = {}) } }

        rolarAteOFim()
        compose.waitUntil(5_000) { deslocamentos.size == 2 && !vm.estado.value.carregandoMais }
        compose.waitForIdle()
        assertEquals(30, vm.estado.value.vagas.size)

        falhar = false
        rolarAteOFim()
        compose.onNodeWithTag(TAG_CARREGAR_MAIS).performClick()
        compose.waitUntil(5_000) { vm.estado.value.vagas.size == 31 }

        assertEquals(listOf(0, 30, 30), deslocamentos.toList())
    }

    @Test
    fun `lista menor que uma pagina nao pede mais nem mostra o rodape`() = runBlocking {
        val vm = viewModel(primeira = 2) { error("não pede a segunda") }
        vm.carregar().join()
        compose.setContent { FrilaTheme { TelaFeedVagas(vm, aoAbrirDetalhe = {}) } }
        compose.waitForIdle()

        compose.onNodeWithText("2 vagas").assertExists()
        assertEquals(0, compose.onAllNodesWithTag(TAG_CARREGAR_MAIS).fetchSemanticsNodes().size)
        assertEquals(listOf(0), deslocamentos.toList())
    }
}
