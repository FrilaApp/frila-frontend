package br.com.frila.feature.vagas.feed

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
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
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão ANdaZu4f: o vazio do feed separa "não há vaga" de "os filtros esconderam tudo", como o iOS, e "Limpar filtros" limpa
 * também os filtros que só o Android tem (remuneração, período e a faixa por hora).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h891dp")
class FeedVazioTest {

    @get:Rule
    val compose = createComposeRule()

    private val json = headersOf(HttpHeaders.ContentType, "application/json")

    /** Uma vaga a 20 km, de garçom, R$ 160 por 6 h (cerca de R$ 26,67/h), às 18h de Brasília. */
    private val vagaJson = """
        [{"id":"v1","funcao":{"id":"f1","nome":"garçom","categoria":"Salão"},
         "estabelecimento":{"id":"e1","tipo":"estabelecimento","nome":"Bar do Zé",
           "reputacao":{"positivas":7,"total":7,"taxa_comparecimento":1.0,"turnos_considerados":7,"turnos_realizados":7}},
         "inicio_em":"2026-11-01T21:00:00Z","fim_em":"2026-11-02T03:00:00Z","local":"SQN 108","regiao_administrativa":"Asa Norte",
         "distancia_km":20.0,"valor_centavos":16000,"posicoes_abertas":2,
         "inclusos":{"inclui_refeicao":true,"inclui_transporte":false,"exige_material_proprio":false},"modo":"selecao"}]
    """.trimIndent()

    private fun viewModel(resposta: String) = FeedVagasViewModel(
        servicoVagas = ServicoVagas(
            ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = MockEngine { respond(resposta, HttpStatusCode.OK, json) }),
        ),
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    private fun montar(vm: FeedVagasViewModel) {
        compose.setContent { FrilaTheme { TelaFeedVagas(vm, aoAbrirDetalhe = {}) } }
        compose.waitForIdle()
    }

    private fun contar(texto: String) = compose.onAllNodesWithText(texto).fetchSemanticsNodes().size

    @Test
    fun `sem vaga e sem filtro diz que nao ha vaga aberta, sem Limpar filtros`() = runBlocking {
        val vm = viewModel("[]")
        vm.carregar().join()
        montar(vm)

        compose.onNodeWithText(TextosVazioDoFeed.SEM_FILTROS_TITULO).assertExists()
        compose.onNodeWithText(TextosVazioDoFeed.SEM_FILTROS_MENSAGEM).assertExists()
        assertEquals(0, contar(TextosVazioDoFeed.COM_FILTROS_TITULO))
        assertEquals(0, contar(TextosVazioDoFeed.LIMPAR_FILTROS))
    }

    @Test
    fun `filtro que esconde tudo diz isso, e Limpar filtros traz a vaga de volta`() = runBlocking {
        val vm = viewModel(vagaJson)
        vm.carregar().join()
        vm.aoSelecionarFiltroDistancia(FiltroDistancia.entries.first { it.limiteKm == 5.0 })
        montar(vm)

        compose.onNodeWithText(TextosVazioDoFeed.COM_FILTROS_TITULO).assertExists()
        compose.onNodeWithText(TextosVazioDoFeed.LIMPAR_FILTROS).performClick()
        compose.waitForIdle()

        assertEquals(StatusFeed.SUCESSO, vm.estado.value.status)
        assertEquals(listOf("v1"), vm.estado.value.vagas.map { it.id })
        assertFalse(vm.estado.value.temFiltroAtivo)
    }

    /** Cada filtro, sozinho, esconde a vaga: o vazio oferece "Limpar filtros", e limpar devolve tudo ao padrão. */
    private fun verificarFiltro(nome: String, aplicar: FeedVagasViewModel.() -> Unit) = runBlocking {
        val vm = viewModel(vagaJson)
        vm.carregar().join()
        vm.aplicar()
        assertTrue(nome, vm.estado.value.temFiltroAtivo)
        assertEquals(nome, StatusFeed.VAZIO, vm.estado.value.status)

        vm.aoLimparFiltros().join()

        val estado = vm.estado.value
        assertFalse(nome, estado.temFiltroAtivo)
        assertEquals(nome, FiltroDistancia.QUALQUER, estado.filtroDistancia)
        assertEquals(nome, null, estado.filtroFuncao)
        assertEquals(nome, FiltroRemuneracao.QUALQUER, estado.filtroRemuneracao)
        assertEquals(nome, FiltroPeriodo.QUALQUER, estado.filtroPeriodo)
        assertFalse(nome, estado.faixaRemuneracaoHora.ativa)
        assertEquals(nome, StatusFeed.SUCESSO, estado.status)
    }

    @Test
    fun `limpar cobre a distancia`() = verificarFiltro("distância") {
        aoSelecionarFiltroDistancia(FiltroDistancia.entries.first { it.limiteKm == 5.0 })
    }

    @Test
    fun `limpar cobre a funcao`() = verificarFiltro("função") { aoSelecionarFiltroFuncao("barman") }

    @Test
    fun `limpar cobre a remuneracao, que so o Android tem`() = verificarFiltro("remuneração") {
        aoSelecionarFiltroRemuneracao(FiltroRemuneracao.entries.last())
    }

    @Test
    fun `limpar cobre o periodo, que so o Android tem`() = verificarFiltro("período") {
        // A vaga é às 18h de Brasília: a manhã a esconde.
        aoSelecionarFiltroPeriodo(FiltroPeriodo.MANHA)
    }

    @Test
    fun `limpar cobre a faixa por hora, que so o Android tem`() = verificarFiltro("faixa") {
        runBlocking { aoAlterarFaixaRemuneracaoHora(90f..100f, ativa = true).join() }
    }

    @Test
    fun `a ordenacao nao conta como filtro`() = runBlocking {
        val vm = viewModel("[]")
        vm.carregar().join()
        vm.aoSelecionarOrdenacao(OpcaoOrdenacaoVagas.entries.last())

        assertFalse(vm.estado.value.temFiltroAtivo)
    }
}
