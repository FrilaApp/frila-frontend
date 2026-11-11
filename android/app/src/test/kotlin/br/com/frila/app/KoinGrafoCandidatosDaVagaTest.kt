package br.com.frila.app

import br.com.frila.core.localizacao.GerenciadorGeofencingTurnos
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.feature.vagas.candidatos.CandidatosDaVagaViewModel
import br.com.frila.feature.vagas.candidatos.EstadoDosCandidatos
import br.com.frila.feature.vagas.candidatos.ResultadoDaEscolha
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.client.request.HttpResponseData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import io.mockk.mockk
import java.time.Instant
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNotSame
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.core.parameter.parametersOf
import org.koin.dsl.module
import org.koin.test.KoinTest
import org.koin.test.get

private val moduloLocalizacaoDoGrafoDeCandidatos = module {
    single<ProvedorDeLocalizacao> { mockk(relaxed = true) }
    single<GerenciadorGeofencingTurnos> { mockk(relaxed = true) }
}

/**
 * Cartão 6LkwUVYr: o grafo monta o `CandidatosDaVagaViewModel` com os parâmetros da rota, e o que está
 * atrás da fiação é de fato chamado (rotas, corpos, parâmetros que chegam ao estado).
 */
@OptIn(ExperimentalCoroutinesApi::class)
class KoinGrafoCandidatosDaVagaTest : KoinTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val inicio = Instant.parse("2026-11-12T18:00:00Z")

    private class Pedido(val caminho: String, val corpo: String?)

    private class Rede(val resposta: MockRequestHandleScope.(HttpRequestData) -> HttpResponseData) {
        val pedidos = mutableListOf<Pedido>()
    }

    private val candidatosJson = """
        [{"candidatura_id":"c1","criada_em":"2026-11-10T12:00:00Z","da_equipe":true,
          "profissional":{"id":"p1","tipo":"profissional","nome":"Ana",
            "reputacao":{"positivas":1,"total":1,"turnos_considerados":1,"turnos_realizados":1}}},
         {"candidatura_id":"c2","criada_em":"2026-11-10T13:00:00Z",
          "profissional":{"id":"p2","tipo":"profissional","nome":"Beto",
            "reputacao":{"positivas":0,"total":0,"turnos_considerados":0,"turnos_realizados":0}}}]
    """.trimIndent()

    private fun redePadrao() = Rede { request ->
        if (request.url.encodedPath.endsWith("/escolher_candidato")) {
            respond("""{"estado":"confirmada","posicao_id":"pos-1","turno_id":"t1"}""", HttpStatusCode.OK, json)
        } else {
            respond(candidatosJson, HttpStatusCode.OK, json)
        }
    }

    private fun clienteCom(rede: Rede) = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-teste",
        engine = MockEngine { request ->
            rede.pedidos += Pedido(request.url.encodedPath, (request.body as? TextContent)?.text)
            rede.resposta(this, request)
        },
    )

    /** Grafo real de produção, com a rede de [ServicoVagas] trocada por um motor falso. */
    private fun iniciar(rede: Rede) {
        startKoin {
            modules(
                listOf(
                    moduloSeguranca,
                    moduloRede,
                    moduloNotificacoes,
                    moduloLocalizacaoDoGrafoDeCandidatos,
                    moduloFeatures,
                ) + module { single { ServicoVagas(clienteCom(rede)) } },
            )
        }
    }

    @BeforeEach
    fun antes() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
    }

    @AfterEach
    fun depois() {
        stopKoin()
        Dispatchers.resetMain()
    }

    @Test
    fun `grafo resolve CandidatosDaVagaViewModel com os parametros da rota, informados ou nao`() {
        startKoin {
            modules(
                listOf(
                    moduloSeguranca,
                    moduloRede,
                    moduloNotificacoes,
                    moduloLocalizacaoDoGrafoDeCandidatos,
                    moduloFeatures,
                ),
            )
        }

        assertNotNull(get<ServicoVagas>())
        assertNotNull(get<CandidatosDaVagaViewModel> { parametersOf("vaga-1", 2, inicio) })
        assertNotNull(get<CandidatosDaVagaViewModel> { parametersOf("vaga-1", null, null) })
    }

    @Test
    fun `os parametros da rota chegam ao estado do ViewModel`() {
        iniciar(redePadrao())

        val completo = get<CandidatosDaVagaViewModel> { parametersOf("vaga-1", 2, inicio) }
        val vazio = get<CandidatosDaVagaViewModel> { parametersOf("vaga-1", null, null) }

        assertEquals(2, completo.estado.value.posicoesAbertas)
        assertEquals(Instant.parse("2026-11-11T18:00:00Z"), completo.estado.value.prazoDeEscolha)
        assertNull(vazio.estado.value.posicoesAbertas)
        assertNull(vazio.estado.value.prazoDeEscolha)
    }

    @Test
    fun `ViewModels do grafo sao independentes`() {
        iniciar(redePadrao())

        val primeiro = get<CandidatosDaVagaViewModel> { parametersOf("vaga-1", 1, null) }
        val segundo = get<CandidatosDaVagaViewModel> { parametersOf("vaga-2", 3, null) }

        assertNotSame(primeiro, segundo)
        assertEquals(1, primeiro.estado.value.posicoesAbertas)
        assertEquals(3, segundo.estado.value.posicoesAbertas)
    }

    @Test
    fun `ViewModel do grafo le os candidatos da vaga da rota e escolhe pela RPC`() = runBlocking {
        val rede = redePadrao()
        iniciar(rede)
        val viewModel = get<CandidatosDaVagaViewModel> { parametersOf("vaga-7", 2, inicio) }

        viewModel.carregar().join()
        viewModel.pedirEscolha(viewModel.estado.value.candidatos.first { it.candidaturaId == "c2" })
        viewModel.confirmarEscolha().join()

        assertEquals("/rest/v1/rpc/candidatos_da_vaga", rede.pedidos[0].caminho)
        assertTrue(rede.pedidos[0].corpo.orEmpty().contains("\"vaga_id\":\"vaga-7\""), rede.pedidos[0].corpo)
        assertEquals("/rest/v1/rpc/escolher_candidato", rede.pedidos[1].caminho)
        assertTrue(rede.pedidos[1].corpo.orEmpty().contains("\"candidatura_id\":\"c2\""), rede.pedidos[1].corpo)
        assertEquals(ResultadoDaEscolha("Beto", vagaPreenchida = false), viewModel.estado.value.resultado)
        assertEquals(1, viewModel.estado.value.posicoesAbertas)
    }

    @Test
    fun `com uma posicao aberta a escolha do grafo enche a vaga`() = runBlocking {
        iniciar(redePadrao())
        val viewModel = get<CandidatosDaVagaViewModel> { parametersOf("vaga-7", 1, null) }
        viewModel.carregar().join()
        assertTrue(viewModel.estado.value.ultimaPosicao)

        viewModel.pedirEscolha(viewModel.estado.value.candidatos.first())
        viewModel.confirmarEscolha().join()

        assertEquals(ResultadoDaEscolha("Ana", vagaPreenchida = true), viewModel.estado.value.resultado)
        assertEquals(EstadoDosCandidatos.Vazio, viewModel.estado.value.lista)
        assertFalse(viewModel.estado.value.ultimaPosicao)
    }
}
