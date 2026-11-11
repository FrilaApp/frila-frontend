package br.com.frila.app

import br.com.frila.core.localizacao.GerenciadorGeofencingTurnos
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.feature.vagas.painel.ListaMinhasVagas
import br.com.frila.feature.vagas.painel.MinhasVagasViewModel
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
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

private val moduloLocalizacaoDoGrafoDeMinhasVagas = module {
    single<ProvedorDeLocalizacao> { mockk(relaxed = true) }
    single<GerenciadorGeofencingTurnos> { mockk(relaxed = true) }
}

/**
 * Cartão 6JfSzOR7: o grafo monta o `MinhasVagasViewModel` com os parâmetros da rota e o liga ao
 * `ServicoVagas.painelEstabelecimento`; o que está atrás da fiação é de fato chamado.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class KoinGrafoMinhasVagasTest : KoinTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")

    private class Pedido(val caminho: String, val corpo: String?)

    private val painelJson = """
        {"estabelecimento_id":"est-1","checkins_pendentes":[],"vagas":[
          {"vaga":{"id":"v1","funcao":"garçom","local":"SQN 108","regiao_administrativa":"Asa Norte",
                   "inicio_em":"2026-11-12T21:00:00Z","fim_em":"2026-11-13T03:00:00Z","valor_centavos":16000},
           "modo":"selecao","estado":"publicada","oculta":false,"alerta_vaga_vazia":false,"candidatos_pendentes":1,"posicoes":[]},
          {"vaga":{"id":"v2","funcao":"barman","local":"SQN 108","regiao_administrativa":"Asa Norte",
                   "inicio_em":"2026-11-14T21:00:00Z","fim_em":"2026-11-15T03:00:00Z","valor_centavos":18000},
           "modo":"urgencia","estado":"publicada","oculta":false,"alerta_vaga_vazia":false,"candidatos_pendentes":0,"posicoes":[]}
        ]}
    """.trimIndent()

    private fun clienteCom(pedidos: MutableList<Pedido>) = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-teste",
        engine = MockEngine { request ->
            pedidos += Pedido(request.url.encodedPath, (request.body as? TextContent)?.text)
            respond(painelJson, HttpStatusCode.OK, json)
        },
    )

    private fun iniciar(pedidos: MutableList<Pedido>) {
        startKoin {
            modules(
                listOf(
                    moduloSeguranca,
                    moduloRede,
                    moduloNotificacoes,
                    moduloLocalizacaoDoGrafoDeMinhasVagas,
                    moduloFeatures,
                ) + module { single { ServicoVagas(clienteCom(pedidos)) } },
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
    fun `grafo resolve MinhasVagasViewModel com os parametros da rota, informados ou nao`() {
        startKoin {
            modules(
                listOf(
                    moduloSeguranca,
                    moduloRede,
                    moduloNotificacoes,
                    moduloLocalizacaoDoGrafoDeMinhasVagas,
                    moduloFeatures,
                ),
            )
        }

        assertNotNull(get<ServicoVagas>())
        assertNotNull(get<MinhasVagasViewModel> { parametersOf("est-1", "Bar da Lia", "v1") })
        assertNotNull(get<MinhasVagasViewModel> { parametersOf("est-1", null, null) })
    }

    @Test
    fun `os parametros da rota chegam ao ViewModel`() {
        iniciar(mutableListOf())

        val completo = get<MinhasVagasViewModel> { parametersOf("est-1", "Bar da Lia", "v1") }
        val vazio = get<MinhasVagasViewModel> { parametersOf("est-2", null, null) }

        assertEquals("est-1", completo.estabelecimentoId)
        assertEquals("Bar da Lia", completo.nomeEstabelecimento)
        assertEquals("est-2", vazio.estabelecimentoId)
        assertNull(vazio.nomeEstabelecimento)
    }

    @Test
    fun `ViewModels do grafo sao independentes`() {
        iniciar(mutableListOf())

        val primeiro = get<MinhasVagasViewModel> { parametersOf("est-1", null, null) }
        val segundo = get<MinhasVagasViewModel> { parametersOf("est-2", null, null) }

        assertNotSame(primeiro, segundo)
        assertEquals("est-1", primeiro.estabelecimentoId)
        assertEquals("est-2", segundo.estabelecimentoId)
    }

    @Test
    fun `ViewModel do grafo le o painel do estabelecimento da rota pela RPC e destaca a vaga recem publicada`() = runBlocking {
        val pedidos = mutableListOf<Pedido>()
        iniciar(pedidos)
        val viewModel = get<MinhasVagasViewModel> { parametersOf("est-1", "Bar da Lia", "v2") }

        viewModel.carregar().join()

        val pedido = pedidos.single()
        assertEquals("/rest/v1/rpc/painel_estabelecimento", pedido.caminho)
        assertTrue(pedido.corpo.orEmpty().contains("\"estabelecimento_id\":\"est-1\""), pedido.corpo)
        assertTrue(pedido.corpo.orEmpty().contains("\"de\":"), pedido.corpo)
        assertTrue(pedido.corpo.orEmpty().contains("\"ate\":"), pedido.corpo)
        val itens = (viewModel.estado.value.lista as ListaMinhasVagas.Sucesso).itens
        assertEquals(setOf("v1", "v2"), itens.map { it.id }.toSet())
        assertEquals(listOf("v2"), itens.filter { it.recemPublicada }.map { it.id })
        assertTrue(itens.single { it.id == "v1" }.podeVerCandidatos)
    }
}
