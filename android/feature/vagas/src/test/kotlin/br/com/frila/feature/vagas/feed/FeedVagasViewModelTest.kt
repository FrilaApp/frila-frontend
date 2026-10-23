package br.com.frila.feature.vagas.feed

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
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * `MockEngine` processa a resposta num dispatcher real por baixo dos panos mesmo em teste —
 * por isso o ViewModel devolve o `Job` de [FeedVagasViewModel.carregar] e o teste espera com
 * `.join()` de verdade, em vez de confiar num `TestDispatcher`/`advanceUntilIdle()` (ver a nota
 * detalhada em `br.com.frila.feature.entrada.entrada.EntradaViewModel`).
 */
class FeedVagasViewModelTest {

    private fun vagaJson(
        id: String = "11111111-1111-1111-1111-111111111111",
        funcao: String = "garçom",
        distanciaKm: Double = 4.2,
        inicioEm: String = "2026-11-01T21:00:00Z",
        valorCentavos: Long = 16_000L,
    ) = """
        {
          "id": "$id",
          "funcao": {"id": "22222222-2222-2222-2222-222222222222", "nome": "$funcao", "categoria": "Salão"},
          "estabelecimento": {
            "id": "33333333-3333-3333-3333-333333333333",
            "tipo": "estabelecimento",
            "nome": "Bar do Zé",
            "reputacao": {"positivas": 7, "total": 7, "taxa_comparecimento": 1.0, "turnos_considerados": 7, "turnos_realizados": 7}
          },
          "inicio_em": "$inicioEm",
          "fim_em": "2026-11-02T03:00:00Z",
          "local": "SQN 108",
          "regiao_administrativa": "Asa Norte",
          "distancia_km": $distanciaKm,
          "valor_centavos": $valorCentavos,
          "posicoes_abertas": 2,
          "inclusos": {"inclui_refeicao": true, "inclui_transporte": false, "exige_material_proprio": false},
          "modo": "selecao"
        }
    """.trimIndent()

    private fun viewModelComEngine(engine: MockEngine): FeedVagasViewModel {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        return FeedVagasViewModel(ServicoVagas(cliente), escopo = CoroutineScope(Dispatchers.Default))
    }

    @Test
    fun `carregar com sucesso preenche vagas e status SUCESSO`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${vagaJson()}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.carregar().join()

        assertEquals(StatusFeed.SUCESSO, viewModel.estado.value.status)
        assertEquals(1, viewModel.estado.value.vagas.size)
        assertEquals("garçom", viewModel.estado.value.vagas.first().funcaoNome)
    }

    @Test
    fun `carregar sem vagas resulta em status VAZIO`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine { respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json")) },
        )

        viewModel.carregar().join()

        assertEquals(StatusFeed.VAZIO, viewModel.estado.value.status)
        assertTrue(viewModel.estado.value.vagas.isEmpty())
    }

    @Test
    fun `carregar com falha de rede resulta em status ERRO com mensagem`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = """{"code":"perfil_incompativel","message":"conta de contratante"}""",
                    status = HttpStatusCode.UnprocessableEntity,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.carregar().join()

        assertEquals(StatusFeed.ERRO, viewModel.estado.value.status)
        assertTrue(viewModel.estado.value.mensagemErro != null)
    }

    @Test
    fun `filtro de distancia 5km exclui vaga mais distante`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${vagaJson(id = "a", distanciaKm = 3.0)}, ${vagaJson(id = "b", distanciaKm = 12.0)}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()
        assertEquals(2, viewModel.estado.value.vagas.size)

        viewModel.aoSelecionarFiltroDistancia(FiltroDistancia.CINCO_KM)

        assertEquals(1, viewModel.estado.value.vagas.size)
        assertEquals(3.0, viewModel.estado.value.vagas.first().distanciaKm)
    }

    @Test
    fun `filtro Qualquer nao exclui nenhuma vaga`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${vagaJson(id = "a", distanciaKm = 3.0)}, ${vagaJson(id = "b", distanciaKm = 14.9)}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()

        viewModel.aoSelecionarFiltroDistancia(FiltroDistancia.QUALQUER)

        assertEquals(2, viewModel.estado.value.vagas.size)
    }

    @Test
    fun `filtro de funcao mostra so a funcao selecionada`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${vagaJson(id = "a", funcao = "garçom")}, ${vagaJson(id = "b", funcao = "cozinheiro")}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()
        assertEquals(listOf("cozinheiro", "garçom"), viewModel.estado.value.funcoesDisponiveis)

        viewModel.aoSelecionarFiltroFuncao("cozinheiro")

        assertEquals(1, viewModel.estado.value.vagas.size)
        assertEquals("cozinheiro", viewModel.estado.value.vagas.first().funcaoNome)
    }

    @Test
    fun `selecionar funcao nula volta a mostrar todas`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${vagaJson(id = "a", funcao = "garçom")}, ${vagaJson(id = "b", funcao = "cozinheiro")}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()
        viewModel.aoSelecionarFiltroFuncao("cozinheiro")
        assertEquals(1, viewModel.estado.value.vagas.size)

        viewModel.aoSelecionarFiltroFuncao(null)

        assertEquals(2, viewModel.estado.value.vagas.size)
    }

    @Test
    fun `vagas ficam ordenadas da mais proxima para a mais distante`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${vagaJson(id = "longe", distanciaKm = 10.0)}, ${vagaJson(id = "perto", distanciaKm = 1.0)}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.carregar().join()

        assertEquals(1.0, viewModel.estado.value.vagas.first().distanciaKm)
        assertEquals(10.0, viewModel.estado.value.vagas.last().distanciaKm)
    }

    @Test
    fun `tentarNovamente refaz a chamada de carregar`() = runBlocking {
        var chamadas = 0
        val viewModel = viewModelComEngine(
            MockEngine {
                chamadas++
                respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )

        viewModel.carregar().join()
        viewModel.tentarNovamente().join()

        assertEquals(2, chamadas)
    }

    @Test
    fun `status comeca CARREGANDO antes da resposta chegar`() {
        val viewModel = viewModelComEngine(MockEngine { respond(content = "[]", status = HttpStatusCode.OK) })

        assertEquals(StatusFeed.CARREGANDO, viewModel.estado.value.status)
    }

    @Test
    fun `filtro de remuneracao minima exclui valores abaixo do piso`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${vagaJson(id = "a", valorCentavos = 9_999)}, ${vagaJson(id = "b", valorCentavos = 10_000)}, ${vagaJson(id = "c", valorCentavos = 20_000)}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()

        viewModel.aoSelecionarFiltroRemuneracao(FiltroRemuneracao.CEM)

        assertEquals(listOf("b", "c"), viewModel.estado.value.vagas.map { it.id })
    }

    @Test
    fun `filtro de periodo usa horario de Brasilia para manha tarde e noite`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[" + listOf(
                        vagaJson(id = "manha", inicioEm = "2026-11-01T09:00:00Z"),
                        vagaJson(id = "tarde", inicioEm = "2026-11-01T15:00:00Z"),
                        vagaJson(id = "noite", inicioEm = "2026-11-01T21:00:00Z"),
                        vagaJson(id = "madrugada", inicioEm = "2026-11-01T08:59:00Z"),
                    ).joinToString(",") + "]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()

        viewModel.aoSelecionarFiltroPeriodo(FiltroPeriodo.MANHA)
        assertEquals(listOf("manha"), viewModel.estado.value.vagas.map { it.id })

        viewModel.aoSelecionarFiltroPeriodo(FiltroPeriodo.TARDE)
        assertEquals(listOf("tarde"), viewModel.estado.value.vagas.map { it.id })

        viewModel.aoSelecionarFiltroPeriodo(FiltroPeriodo.NOITE)
        assertEquals(listOf("noite", "madrugada"), viewModel.estado.value.vagas.map { it.id })
    }

    @Test
    fun `remuneracao periodo funcao e distancia combinam por intersecao`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[" + listOf(
                        vagaJson(id = "alvo", funcao = "cozinheiro", distanciaKm = 4.0, inicioEm = "2026-11-01T15:00:00Z", valorCentavos = 15_000),
                        vagaJson(id = "salario", funcao = "cozinheiro", distanciaKm = 4.0, inicioEm = "2026-11-01T15:00:00Z", valorCentavos = 14_999),
                        vagaJson(id = "periodo", funcao = "cozinheiro", distanciaKm = 4.0, inicioEm = "2026-11-01T09:00:00Z", valorCentavos = 20_000),
                        vagaJson(id = "funcao", funcao = "garçom", distanciaKm = 4.0, inicioEm = "2026-11-01T15:00:00Z", valorCentavos = 20_000),
                        vagaJson(id = "distancia", funcao = "cozinheiro", distanciaKm = 6.0, inicioEm = "2026-11-01T15:00:00Z", valorCentavos = 20_000),
                    ).joinToString(",") + "]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()

        viewModel.aoSelecionarFiltroRemuneracao(FiltroRemuneracao.CENTO_E_CINQUENTA)
        viewModel.aoSelecionarFiltroPeriodo(FiltroPeriodo.TARDE)
        viewModel.aoSelecionarFiltroFuncao("cozinheiro")
        viewModel.aoSelecionarFiltroDistancia(FiltroDistancia.CINCO_KM)

        assertEquals(listOf("alvo"), viewModel.estado.value.vagas.map { it.id })
    }

    @Test
    fun `limpar filtros avancados restaura todas as vagas`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${vagaJson(id = "a", valorCentavos = 9_000)}, ${vagaJson(id = "b", inicioEm = "2026-11-01T09:00:00Z", valorCentavos = 20_000)}, ${vagaJson(id = "c", valorCentavos = 20_000)}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()
        viewModel.aoSelecionarFiltroRemuneracao(FiltroRemuneracao.DUZENTOS)
        viewModel.aoSelecionarFiltroPeriodo(FiltroPeriodo.NOITE)
        assertEquals(1, viewModel.estado.value.vagas.size)

        viewModel.aoLimparFiltrosAvancados()

        assertEquals(3, viewModel.estado.value.vagas.size)
        assertEquals(FiltroRemuneracao.QUALQUER, viewModel.estado.value.filtroRemuneracao)
        assertEquals(FiltroPeriodo.QUALQUER, viewModel.estado.value.filtroPeriodo)
    }
}
