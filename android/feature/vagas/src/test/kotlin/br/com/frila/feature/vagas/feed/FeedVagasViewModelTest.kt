package br.com.frila.feature.vagas.feed

import br.com.frila.core.dominio.modelo.Coordenada
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
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
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

    private fun provedorSemCoordenada(): ProvedorDeLocalizacao {
        val provedor = mockk<ProvedorDeLocalizacao>()
        coEvery { provedor.obterCoordenadaAtual() } returns null
        return provedor
    }

    private fun viewModelComEngine(
        engine: MockEngine,
        preferencias: ArmazenamentoPreferenciasFiltro = ArmazenamentoPreferenciasFiltroEmMemoria(),
        provedorDeLocalizacao: ProvedorDeLocalizacao = provedorSemCoordenada(),
    ): FeedVagasViewModel {
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        return FeedVagasViewModel(
            servicoVagas = ServicoVagas(cliente),
            provedorDeLocalizacao = provedorDeLocalizacao,
            armazenamentoPreferencias = preferencias,
            escopo = CoroutineScope(Dispatchers.Default),
        )
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

        assertEquals(listOf("c", "b"), viewModel.estado.value.vagas.map { it.id })
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

    @Test
    fun `busca por funcao mostra somente vagas correspondentes`() = runBlocking {
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

        viewModel.aoAlterarTextoBusca("cozinheiro")

        assertEquals(listOf("b"), viewModel.estado.value.vagas.map { it.id })
    }

    @Test
    fun `busca por estabelecimento mostra somente vagas correspondentes`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${vagaJson(id = "a", estabelecimento = "Bar do Zé")}, ${vagaJson(id = "b", estabelecimento = "Bistrô Central")}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()

        viewModel.aoAlterarTextoBusca("Bistrô Central")

        assertEquals(listOf("b"), viewModel.estado.value.vagas.map { it.id })
    }

    @Test
    fun `busca ignora maiusculas minusculas e espacos externos`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${vagaJson(id = "a", funcao = "Garçom")}, ${vagaJson(id = "b", funcao = "cozinheiro")}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()

        viewModel.aoAlterarTextoBusca("  GARÇOM  ")

        assertEquals(listOf("a"), viewModel.estado.value.vagas.map { it.id })
    }

    @Test
    fun `busca combina com remuneracao periodo funcao e distancia`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[" + listOf(
                        vagaJson(id = "alvo", funcao = "cozinheiro", estabelecimento = "Cozinha Central", distanciaKm = 4.0, inicioEm = "2026-11-01T15:00:00Z", valorCentavos = 15_000),
                        vagaJson(id = "busca", funcao = "cozinheiro", estabelecimento = "Outro Local", distanciaKm = 4.0, inicioEm = "2026-11-01T15:00:00Z", valorCentavos = 15_000),
                        vagaJson(id = "salario", funcao = "cozinheiro", estabelecimento = "Cozinha Central", distanciaKm = 4.0, inicioEm = "2026-11-01T15:00:00Z", valorCentavos = 14_999),
                        vagaJson(id = "periodo", funcao = "cozinheiro", estabelecimento = "Cozinha Central", distanciaKm = 4.0, inicioEm = "2026-11-01T09:00:00Z", valorCentavos = 20_000),
                        vagaJson(id = "funcao", funcao = "garçom", estabelecimento = "Cozinha Central", distanciaKm = 4.0, inicioEm = "2026-11-01T15:00:00Z", valorCentavos = 20_000),
                        vagaJson(id = "distancia", funcao = "cozinheiro", estabelecimento = "Cozinha Central", distanciaKm = 6.0, inicioEm = "2026-11-01T15:00:00Z", valorCentavos = 20_000),
                    ).joinToString(",") + "]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()

        viewModel.aoAlterarTextoBusca("central")
        viewModel.aoSelecionarFiltroRemuneracao(FiltroRemuneracao.CENTO_E_CINQUENTA)
        viewModel.aoSelecionarFiltroPeriodo(FiltroPeriodo.TARDE)
        viewModel.aoSelecionarFiltroFuncao("cozinheiro")
        viewModel.aoSelecionarFiltroDistancia(FiltroDistancia.CINCO_KM)

        assertEquals(listOf("alvo"), viewModel.estado.value.vagas.map { it.id })
    }

    @Test
    fun `limpar busca restaura vagas sem alterar outros filtros`() = runBlocking {
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
        viewModel.aoAlterarTextoBusca("cozinheiro")
        assertEquals(1, viewModel.estado.value.vagas.size)

        viewModel.aoLimparBusca()

        assertEquals("", viewModel.estado.value.textoBusca)
        assertEquals(listOf("a", "b"), viewModel.estado.value.vagas.map { it.id })
    }

    @Test
    fun `atualizar preserva filtros ativos e atualiza lista com novas vagas`() = runBlocking {
        var chamada = 0
        val viewModel = viewModelComEngine(
            MockEngine {
                chamada++
                val json = if (chamada == 1) {
                    "[${vagaJson(id = "1", funcao = "garçom")}]"
                } else {
                    "[${vagaJson(id = "1", funcao = "garçom")}, ${vagaJson(id = "2", funcao = "garçom")}]"
                }
                respond(
                    content = json,
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.carregar().join()
        assertEquals(1, viewModel.estado.value.vagas.size)

        viewModel.aoSelecionarFiltroFuncao("garçom")
        viewModel.atualizar().join()

        assertEquals(2, viewModel.estado.value.vagas.size)
        assertEquals("garçom", viewModel.estado.value.filtroFuncao)
        assertEquals(false, viewModel.estado.value.atualizando)
        assertEquals(StatusFeed.SUCESSO, viewModel.estado.value.status)
    }

    @Test
    fun `atualizar com falha mantem dados anteriores e expoe mensagem de erro`() = runBlocking {
        var chamada = 0
        val viewModel = viewModelComEngine(
            MockEngine {
                chamada++
                if (chamada == 1) {
                    respond(
                        content = "[${vagaJson(id = "1", funcao = "garçom")}]",
                        status = HttpStatusCode.OK,
                        headers = headersOf(HttpHeaders.ContentType, "application/json"),
                    )
                } else {
                    respond(
                        content = """{"code": "500", "message": "erro interno do servidor"}""",
                        status = HttpStatusCode.InternalServerError,
                        headers = headersOf(HttpHeaders.ContentType, "application/json"),
                    )
                }
            },
        )

        viewModel.carregar().join()
        assertEquals(1, viewModel.estado.value.vagas.size)

        viewModel.atualizar().join()

        assertEquals(1, viewModel.estado.value.vagas.size)
        assertEquals(false, viewModel.estado.value.atualizando)
        assertTrue(viewModel.estado.value.mensagemErro != null)
    }

    @Test
    fun `filtro de remuneracao por hora exclui vagas abaixo do minimo selecionado (RF05, RN01)`() = runBlocking {
        // Todas as vagas duram 4 horas (18:00 às 22:00)
        // Vaga A: R$ 80,00 total = R$ 20,00/h
        // Vaga B: R$ 120,00 total = R$ 30,00/h
        // Vaga C: R$ 200,00 total = R$ 50,00/h
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[" + listOf(
                        vagaJson(id = "a", inicioEm = "2026-11-01T18:00:00Z", fimEm = "2026-11-01T22:00:00Z", valorCentavos = 8_000L),
                        vagaJson(id = "b", inicioEm = "2026-11-01T18:00:00Z", fimEm = "2026-11-01T22:00:00Z", valorCentavos = 12_000L),
                        vagaJson(id = "c", inicioEm = "2026-11-01T18:00:00Z", fimEm = "2026-11-01T22:00:00Z", valorCentavos = 20_000L),
                    ).joinToString(",") + "]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()
        assertEquals(3, viewModel.estado.value.vagas.size)

        // Seleciona faixa mínima de R$ 25/h até R$ 60/h
        viewModel.aoAlterarFaixaRemuneracaoHora(25f..60f, ativa = true)

        // Vaga A (R$ 20/h) deve ser excluída por estar abaixo do mínimo (R$ 25/h)
        val vagasFiltradas = viewModel.estado.value.vagas.map { it.id }
        assertEquals(listOf("c", "b"), vagasFiltradas)
    }

    @Test
    fun `filtro de remuneracao por hora exclui vagas acima do maximo selecionado quando ativo`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[" + listOf(
                        vagaJson(id = "b", inicioEm = "2026-11-01T18:00:00Z", fimEm = "2026-11-01T22:00:00Z", valorCentavos = 12_000L),
                        vagaJson(id = "c", inicioEm = "2026-11-01T18:00:00Z", fimEm = "2026-11-01T22:00:00Z", valorCentavos = 20_000L),
                    ).joinToString(",") + "]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()

        // Seleciona faixa de R$ 25/h a R$ 35/h (exclui Vaga C a R$ 50/h)
        viewModel.aoAlterarFaixaRemuneracaoHora(25f..35f, ativa = true)

        assertEquals(listOf("b"), viewModel.estado.value.vagas.map { it.id })
    }

    @Test
    fun `aoAlterarFaixaRemuneracaoHora persiste faixa e status no armazenamento local`() {
        val preferencias = ArmazenamentoPreferenciasFiltroEmMemoria()
        val viewModel = viewModelComEngine(
            MockEngine { respond(content = "[]", status = HttpStatusCode.OK) },
            preferencias = preferencias,
        )

        viewModel.aoAlterarFaixaRemuneracaoHora(30f..80f, ativa = true)

        val salva = preferencias.obterFaixaRemuneracaoHora()
        assertNotNull(salva)
        assertEquals(30f, salva?.minima)
        assertEquals(80f, salva?.maxima)
        assertEquals(true, salva?.ativa)
    }

    @Test
    fun `inicializacao restaura preferencia de faixa de remuneracao salva`() {
        val preferencias = ArmazenamentoPreferenciasFiltroEmMemoria()
        preferencias.salvarFaixaRemuneracaoHora(minimo = 35f, maximo = 95f, ativa = true)

        val viewModel = viewModelComEngine(
            MockEngine { respond(content = "[]", status = HttpStatusCode.OK) },
            preferencias = preferencias,
        )

        assertEquals(35f, viewModel.estado.value.faixaRemuneracaoHora.minima)
        assertEquals(95f, viewModel.estado.value.faixaRemuneracaoHora.maxima)
        assertEquals(true, viewModel.estado.value.faixaRemuneracaoHora.ativa)
    }

    @Test
    fun `aoLimparFiltrosAvancados redefine faixa padrao e limpa persistencia`() {
        val preferencias = ArmazenamentoPreferenciasFiltroEmMemoria()
        preferencias.salvarFaixaRemuneracaoHora(minimo = 35f, maximo = 95f, ativa = true)

        val viewModel = viewModelComEngine(
            MockEngine { respond(content = "[]", status = HttpStatusCode.OK) },
            preferencias = preferencias,
        )

        viewModel.aoLimparFiltrosAvancados()

        assertEquals(FaixaRemuneracaoHora.PADRAO, viewModel.estado.value.faixaRemuneracaoHora)
        assertEquals(null, preferencias.obterFaixaRemuneracaoHora())
    }

    @Test
    fun `filtro de distancia 25km exclui vaga acima do raio`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${vagaJson(id = "a", distanciaKm = 20.0)}, ${vagaJson(id = "b", distanciaKm = 30.0)}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()

        viewModel.aoSelecionarFiltroDistancia(FiltroDistancia.VINTE_E_CINCO_KM)

        assertEquals(listOf("a"), viewModel.estado.value.vagas.map { it.id })
    }

    @Test
    fun `filtro de distancia 50km exclui vaga acima do raio`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${vagaJson(id = "a", distanciaKm = 40.0)}, ${vagaJson(id = "b", distanciaKm = 60.0)}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()

        viewModel.aoSelecionarFiltroDistancia(FiltroDistancia.CINQUENTA_KM)

        assertEquals(listOf("a"), viewModel.estado.value.vagas.map { it.id })
    }

    @Test
    fun `carregar repassa coordenada atual ao ServicoVagas`() = runBlocking {
        var latitudeRecebida: String? = null
        var longitudeRecebida: String? = null
        val provedor = mockk<ProvedorDeLocalizacao>()
        coEvery { provedor.obterCoordenadaAtual() } returns Coordenada(latitude = -15.79, longitude = -47.88)
        val viewModel = viewModelComEngine(
            MockEngine { request ->
                latitudeRecebida = request.url.parameters["latitude"]
                longitudeRecebida = request.url.parameters["longitude"]
                respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
            },
            provedorDeLocalizacao = provedor,
        )

        viewModel.carregar().join()

        assertEquals("-15.79", latitudeRecebida)
        assertEquals("-47.88", longitudeRecebida)
    }

    @Test
    fun `carregar sem coordenada disponivel chama ServicoVagas sem latitude e longitude (fallback gracioso)`() = runBlocking {
        var tinhaLatitude = true
        val viewModel = viewModelComEngine(
            MockEngine { request ->
                tinhaLatitude = request.url.parameters.contains("latitude")
                respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
            },
            provedorDeLocalizacao = provedorSemCoordenada(),
        )

        viewModel.carregar().join()

        assertTrue(!tinhaLatitude)
        assertEquals(StatusFeed.VAZIO, viewModel.estado.value.status)
    }

    @Test
    fun `carregar nao restringe a chamada por distancia_max_km mesmo com filtro de distancia ativo`() = runBlocking {
        // Achado bloqueante (Shisui): restringir no servidor por distancia_max_km impede ampliar o
        // raio no cliente sem forcar um recarregamento. carregar() precisa buscar tudo e deixar o
        // filtro reativo em aplicarFiltros() cuidar do raio.
        var distanciaMaxRecebida: String? = null
        val viewModel = viewModelComEngine(
            MockEngine { request ->
                distanciaMaxRecebida = request.url.parameters["distancia_max_km"]
                respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        viewModel.aoSelecionarFiltroDistancia(FiltroDistancia.VINTE_E_CINCO_KM)

        viewModel.carregar().join()

        assertEquals(null, distanciaMaxRecebida)
    }

    @Test
    fun `ampliar o filtro de distancia revela vagas mais distantes sem recarregar (Shisui)`() = runBlocking {
        // Repro exato do Shisui: mock do servidor respeita distancia_max_km de verdade. Se carregar()
        // enviasse distancia_max_km=5, a vaga B (40km) nunca chegaria ao cliente e ampliar o chip
        // para 50km continuaria preso em [A], igual ao bug reportado.
        val viewModel = viewModelComEngine(
            MockEngine { request ->
                val distanciaMax = request.url.parameters["distancia_max_km"]?.toDouble()
                val todas = listOf(
                    vagaJson(id = "a", distanciaKm = 3.0) to 3.0,
                    vagaJson(id = "b", distanciaKm = 40.0) to 40.0,
                )
                val visiveis = todas.filter { (_, distancia) -> distanciaMax == null || distancia <= distanciaMax }
                respond(
                    content = "[" + visiveis.joinToString(",") { it.first } + "]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.aoSelecionarFiltroDistancia(FiltroDistancia.CINCO_KM)
        viewModel.carregar().join()
        assertEquals(listOf("a"), viewModel.estado.value.vagas.map { it.id })

        viewModel.aoSelecionarFiltroDistancia(FiltroDistancia.CINQUENTA_KM)

        assertEquals(listOf("a", "b"), viewModel.estado.value.vagas.map { it.id })
    }

    @Test
    fun `ampliar para Qualquer apos filtro estreito revela todas as vagas sem recarregar`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${vagaJson(id = "a", distanciaKm = 3.0)}, ${vagaJson(id = "b", distanciaKm = 40.0)}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.aoSelecionarFiltroDistancia(FiltroDistancia.CINCO_KM)
        viewModel.carregar().join()
        assertEquals(1, viewModel.estado.value.vagas.size)

        viewModel.aoSelecionarFiltroDistancia(FiltroDistancia.QUALQUER)

        assertEquals(listOf("a", "b"), viewModel.estado.value.vagas.map { it.id })
    }

    @Test
    fun `atualizar repassa coordenada atual ao ServicoVagas`() = runBlocking {
        var latitudeRecebida: String? = null
        var longitudeRecebida: String? = null
        val provedor = mockk<ProvedorDeLocalizacao>()
        coEvery { provedor.obterCoordenadaAtual() } returns Coordenada(latitude = -15.79, longitude = -47.88)
        val viewModel = viewModelComEngine(
            MockEngine { request ->
                latitudeRecebida = request.url.parameters["latitude"]
                longitudeRecebida = request.url.parameters["longitude"]
                respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
            },
            provedorDeLocalizacao = provedor,
        )

        viewModel.atualizar().join()

        assertEquals("-15.79", latitudeRecebida)
        assertEquals("-47.88", longitudeRecebida)
    }

    @Test
    fun `atualizar sem coordenada disponivel chama ServicoVagas sem latitude e longitude (fallback gracioso)`() = runBlocking {
        var tinhaLatitude = true
        val viewModel = viewModelComEngine(
            MockEngine { request ->
                tinhaLatitude = request.url.parameters.contains("latitude")
                respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
            },
            provedorDeLocalizacao = provedorSemCoordenada(),
        )

        viewModel.atualizar().join()

        assertTrue(!tinhaLatitude)
    }

    // RF10/RNF04: ordenação flexível do feed por maior valor e menor distância.

    @Test
    fun `vagas inicializam ordenadas por menor distancia (padrao RF10)`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${vagaJson(id = "longe", distanciaKm = 8.0)}, ${vagaJson(id = "perto", distanciaKm = 2.0)}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.carregar().join()

        assertEquals(OpcaoOrdenacaoVagas.MENOR_DISTANCIA, viewModel.estado.value.opcaoOrdenacao)
        assertEquals("perto", viewModel.estado.value.vagas[0].id)
        assertEquals("longe", viewModel.estado.value.vagas[1].id)
    }

    @Test
    fun `ao selecionar maior valor ordena do maior para o menor valorCentavos`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${vagaJson(id = "barato", valorCentavos = 10_000L)}, ${vagaJson(id = "caro", valorCentavos = 30_000L)}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()

        viewModel.aoSelecionarOrdenacao(OpcaoOrdenacaoVagas.MAIOR_VALOR)

        assertEquals(OpcaoOrdenacaoVagas.MAIOR_VALOR, viewModel.estado.value.opcaoOrdenacao)
        assertEquals("caro", viewModel.estado.value.vagas[0].id)
        assertEquals("barato", viewModel.estado.value.vagas[1].id)
    }

    @Test
    fun `ordenar por maior valor desempata por menor distancia`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${vagaJson(id = "longe", valorCentavos = 20_000L, distanciaKm = 9.0)}, " +
                        "${vagaJson(id = "perto", valorCentavos = 20_000L, distanciaKm = 1.0)}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()

        viewModel.aoSelecionarOrdenacao(OpcaoOrdenacaoVagas.MAIOR_VALOR)

        assertEquals("perto", viewModel.estado.value.vagas[0].id)
        assertEquals("longe", viewModel.estado.value.vagas[1].id)
    }

    @Test
    fun `ordenar por menor distancia desempata por maior valor`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${vagaJson(id = "barato", distanciaKm = 3.0, valorCentavos = 10_000L)}, " +
                        "${vagaJson(id = "caro", distanciaKm = 3.0, valorCentavos = 25_000L)}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        viewModel.carregar().join()

        assertEquals("caro", viewModel.estado.value.vagas[0].id)
        assertEquals("barato", viewModel.estado.value.vagas[1].id)
    }

    @Test
    fun `alternar ordenacao nao dispara nova chamada HTTP (RNF04)`() = runBlocking {
        val chamadas = java.util.concurrent.atomic.AtomicInteger(0)
        val viewModel = viewModelComEngine(
            MockEngine {
                chamadas.incrementAndGet()
                respond(
                    content = "[${vagaJson(id = "a")}, ${vagaJson(id = "b", distanciaKm = 9.0)}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()
        assertEquals(1, chamadas.get())

        viewModel.aoSelecionarOrdenacao(OpcaoOrdenacaoVagas.MAIOR_VALOR)
        viewModel.aoSelecionarOrdenacao(OpcaoOrdenacaoVagas.MENOR_DISTANCIA)

        assertEquals(1, chamadas.get()) { "trocar a ordenação não deveria chamar a rede de novo" }
    }

    @Test
    fun `busca textual e filtros mantem a ordenacao selecionada`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${vagaJson(id = "a", funcao = "garçom")}, ${vagaJson(id = "b", funcao = "garçom", distanciaKm = 9.0)}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()
        viewModel.aoSelecionarOrdenacao(OpcaoOrdenacaoVagas.MAIOR_VALOR)

        viewModel.aoAlterarTextoBusca("gar")

        assertEquals(OpcaoOrdenacaoVagas.MAIOR_VALOR, viewModel.estado.value.opcaoOrdenacao)
    }

    @Test
    fun `pull-to-refresh mantem a preferencia de ordenacao`() = runBlocking {
        val viewModel = viewModelComEngine(
            MockEngine {
                respond(
                    content = "[${vagaJson(id = "a")}, ${vagaJson(id = "b", distanciaKm = 9.0)}]",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        viewModel.carregar().join()
        viewModel.aoSelecionarOrdenacao(OpcaoOrdenacaoVagas.MAIOR_VALOR)

        viewModel.atualizar().join()

        assertEquals(OpcaoOrdenacaoVagas.MAIOR_VALOR, viewModel.estado.value.opcaoOrdenacao)
    }
}
