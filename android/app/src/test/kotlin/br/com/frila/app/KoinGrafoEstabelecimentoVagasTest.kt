package br.com.frila.app

import br.com.frila.core.localizacao.GerenciadorGeofencingTurnos
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.feature.estabelecimento.CadastroEstabelecimentoViewModel
import br.com.frila.feature.estabelecimento.TipoEstabelecimento
import br.com.frila.feature.vagas.publicacao.EstabelecimentoDaVaga
import br.com.frila.feature.vagas.publicacao.PublicarVagaViewModel
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
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.core.parameter.parametersOf
import org.koin.dsl.module
import org.koin.test.KoinTest
import org.koin.test.get

private val moduloLocalizacaoDoGrafoDeEstabelecimento = module {
    single<ProvedorDeLocalizacao> { mockk(relaxed = true) }
    single<GerenciadorGeofencingTurnos> { mockk(relaxed = true) }
}

/**
 * Cartão uB6pxGpW: o grafo monta os serviços e os ViewModels de Estabelecimento e de Publicação de
 * vaga, e o que está atrás de cada fiação é de fato chamado (rota, corpo, parâmetros da rota).
 */
@OptIn(ExperimentalCoroutinesApi::class)
class KoinGrafoEstabelecimentoVagasTest : KoinTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val casa = EstabelecimentoDaVaga(
        id = "casa-1",
        endereco = "CLS 408, Bloco B, Loja 12",
        regiaoAdministrativa = "Asa Norte",
        ponto = CoordenadaDto(-15.7942, -47.8822),
    )

    private class Pedido(val caminho: String, val corpo: String?)

    private class Rede(val resposta: MockRequestHandleScope.(HttpRequestData) -> HttpResponseData) {
        val pedidos = mutableListOf<Pedido>()
    }

    private fun clienteCom(rede: Rede) = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-teste",
        engine = MockEngine { request ->
            rede.pedidos += Pedido(request.url.encodedPath, (request.body as? TextContent)?.text)
            rede.resposta(this, request)
        },
    )

    /** Grafo real de produção, com a rede dos serviços trocada por um motor falso. */
    private fun iniciar(rede: Rede) {
        startKoin {
            modules(
                listOf(
                    moduloSeguranca,
                    moduloRede,
                    moduloNotificacoes,
                    moduloLocalizacaoDoGrafoDeEstabelecimento,
                    moduloFeatures,
                ) + module {
                    single { ServicoPerfil(clienteCom(rede)) }
                    single { ServicoMembros(clienteCom(rede)) }
                    single { ServicoVagas(clienteCom(rede)) }
                },
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
    fun `grafo resolve os servicos e os ViewModels de estabelecimento e de publicacao`() {
        startKoin {
            modules(
                listOf(
                    moduloSeguranca,
                    moduloRede,
                    moduloNotificacoes,
                    moduloLocalizacaoDoGrafoDeEstabelecimento,
                    moduloFeatures,
                ),
            )
        }

        assertNotNull(get<ServicoVagas>())
        assertNotNull(get<ServicoMembros>())
        assertNotNull(get<CadastroEstabelecimentoViewModel>())
        assertNotNull(get<PublicarVagaViewModel> { parametersOf(casa) })
    }

    @Test
    fun `ViewModels de publicacao do grafo sao independentes e cada um guarda a casa da sua rota`() {
        startKoin {
            modules(
                listOf(
                    moduloSeguranca,
                    moduloRede,
                    moduloNotificacoes,
                    moduloLocalizacaoDoGrafoDeEstabelecimento,
                    moduloFeatures,
                ),
            )
        }
        val outra = casa.copy(id = "casa-2", endereco = "SQN 108")

        val primeiro = get<PublicarVagaViewModel> { parametersOf(casa) }
        val segundo = get<PublicarVagaViewModel> { parametersOf(outra) }

        assertNotSame(primeiro, segundo)
        assertEquals("CLS 408, Bloco B, Loja 12", primeiro.estado.value.local)
        assertEquals("SQN 108", segundo.estado.value.local)
    }

    @Test
    fun `CadastroEstabelecimentoViewModel do grafo manda o cadastro para a RPC e guarda o estabelecimento criado`() = runBlocking {
        val rede = Rede {
            respond(
                """
                {"id":"nova-1","nome":"Bar da Lia","documento":"12345678000199","tipo":"evento",
                 "endereco":"CLS 408, Bloco B, Loja 12","regiao_administrativa":"Plano Piloto",
                 "ponto":{"latitude":-15.7942,"longitude":-47.8822},"papel":"administrador"}
                """.trimIndent(),
                HttpStatusCode.OK,
                json,
            )
        }
        iniciar(rede)
        val viewModel = get<CadastroEstabelecimentoViewModel>()
        viewModel.editarNome("Bar da Lia")
        viewModel.editarDocumento("12345678000199")
        viewModel.escolherTipo(TipoEstabelecimento.EVENTO)
        viewModel.editarEndereco("CLS 408, Bloco B, Loja 12")
        viewModel.escolherRegiao("Plano Piloto")
        viewModel.editarLatitude("-15,7942")
        viewModel.editarLongitude("-47.8822")

        viewModel.cadastrar().join()

        val pedido = rede.pedidos.single()
        assertEquals("/rest/v1/rpc/cadastrar_estabelecimento", pedido.caminho)
        val corpo = pedido.corpo.orEmpty()
        assertTrue(corpo.contains("\"tipo\":\"evento\""), corpo)
        assertTrue(corpo.contains("\"regiao_administrativa\":\"Plano Piloto\""), corpo)
        assertTrue(corpo.contains("\"ponto\":{\"latitude\":-15.7942,\"longitude\":-47.8822}"), corpo)
        assertEquals("nova-1", viewModel.estado.value.estabelecimentoCriado?.id)
    }

    @Test
    fun `PublicarVagaViewModel do grafo le funcoes e publica com a casa e o ponto dos parametros da rota`() = runBlocking {
        val rede = Rede { request ->
            if (request.url.encodedPath.endsWith("/funcao")) {
                respond("""[{"id":"f1","nome":"Garçom","categoria":"Salão"}]""", HttpStatusCode.OK, json)
            } else {
                respond("""{"vaga_id":"v1","posicoes":["p1"]}""", HttpStatusCode.OK, json)
            }
        }
        iniciar(rede)
        val viewModel = get<PublicarVagaViewModel> { parametersOf(casa) }

        viewModel.carregarFuncoes().join()
        viewModel.escolherFuncao("f1")
        viewModel.editarValor("140")
        viewModel.editarResponsavel("Lia")
        viewModel.publicar().join()

        assertEquals(
            listOf("/rest/v1/funcao", "/rest/v1/rpc/publicar_vaga"),
            rede.pedidos.map { it.caminho },
        )
        val corpo = rede.pedidos[1].corpo.orEmpty()
        assertTrue(corpo.contains("\"estabelecimento_id\":\"casa-1\""), corpo)
        assertTrue(corpo.contains("\"regiao_administrativa\":\"Asa Norte\""), corpo)
        assertTrue(corpo.contains("\"local\":\"CLS 408, Bloco B, Loja 12\""), corpo)
        assertTrue(corpo.contains("\"ponto\":{\"latitude\":-15.7942,\"longitude\":-47.8822}"), corpo)
        assertTrue(corpo.contains("\"valor_centavos\":14000"), corpo)
        assertEquals("v1", viewModel.estado.value.publicada?.vagaId)
    }
}
