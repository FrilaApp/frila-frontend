package br.com.frila.app

import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.localizacao.GerenciadorGeofencingTurnos
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoConfianca
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.Sessao
import br.com.frila.feature.conta.ExclusaoDeContaViewModel
import br.com.frila.feature.equipe.EquipeDeConfiancaViewModel
import br.com.frila.feature.equipe.EstadoEquipe
import br.com.frila.feature.suporte.DenunciaViewModel
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
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.koin.core.context.startKoin
import org.koin.core.context.stopKoin
import org.koin.core.parameter.parametersOf
import org.koin.dsl.module
import org.koin.test.KoinTest
import org.koin.test.get

private val moduloLocalizacaoDeTeste = module {
    single<ProvedorDeLocalizacao> { mockk(relaxed = true) }
    single<GerenciadorGeofencingTurnos> { mockk(relaxed = true) }
}

/**
 * Cartão i25gMr5D: o grafo monta os serviços e ViewModels de Conta, Suporte e Equipe, e o que
 * está atrás de cada fiação é de fato chamado (rota, corpo e efeito na sessão), não só resolvido.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class KoinGrafoContaSuporteEquipeTest : KoinTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val casa = "11111111-1111-1111-1111-111111111111"

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

    /** Grafo real de produção, com a rede dos três serviços trocada por um motor falso. */
    private fun iniciar(rede: Rede) {
        startKoin {
            modules(
                listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacaoDeTeste, moduloFeatures) +
                    module {
                        single { ServicoPerfil(clienteCom(rede)) }
                        single { ServicoConfianca(clienteCom(rede)) }
                        single { ServicoMembros(clienteCom(rede)) }
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
    fun `grafo resolve servicos e ViewModels de conta, suporte e equipe`() {
        startKoin {
            modules(listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacaoDeTeste, moduloFeatures))
        }

        assertNotNull(get<ServicoConfianca>())
        assertNotNull(get<ServicoMembros>())
        assertNotNull(get<ExclusaoDeContaViewModel>())
        assertNotNull(get<DenunciaViewModel> { parametersOf(TipoDeAlvo.PROFISSIONAL, "p1", null, null) })
        assertNotNull(get<DenunciaViewModel> { parametersOf(TipoDeAlvo.ESTABELECIMENTO, "e1", "turno-1", "chamada-1") })
        assertNotNull(get<EquipeDeConfiancaViewModel> { parametersOf(casa) })
    }

    @Test
    fun `exclusao de conta com sucesso limpa a sessao do grafo, e recusa 409 deixa a sessao de pe`() = runBlocking {
        val ok = Rede {
            respond(
                """{"perfil_removido_em":"2026-11-10T12:00:00Z","dados_apagados_ate":"2026-11-25","turnos_cancelados":1}""",
                HttpStatusCode.Accepted,
                json,
            )
        }
        iniciar(ok)
        val sessao = get<ArmazenamentoDeSessao>()
        sessao.salvarSessao(Sessao("a", "r", "bearer", 3600))
        val viewModel = get<ExclusaoDeContaViewModel>()
        viewModel.alterarConfirmacao(true)

        viewModel.confirmarExclusao().join()

        assertEquals("/functions/v1/excluir-conta", ok.pedidos.single().caminho)
        assertEquals(1, viewModel.estado.value.resultado?.turnosCancelados)
        assertFalse(sessao.estaAutenticado())

        stopKoin()
        val recusa = Rede { respond("""{"code":"administrador_unico","message":"transfira"}""", HttpStatusCode.Conflict, json) }
        iniciar(recusa)
        val sessaoViva = get<ArmazenamentoDeSessao>()
        sessaoViva.salvarSessao(Sessao("a", "r", "bearer", 3600))
        val viewModelRecusado = get<ExclusaoDeContaViewModel>()
        viewModelRecusado.alterarConfirmacao(true)

        viewModelRecusado.confirmarExclusao().join()

        assertTrue(sessaoViva.estaAutenticado())
        assertNotNull(viewModelRecusado.estado.value.mensagemErro)
    }

    @Test
    fun `DenunciaViewModel do grafo usa os parametros da rota e chama denunciar e bloquear`() = runBlocking {
        val rede = Rede { request ->
            if (request.url.encodedPath.endsWith("/denunciar")) {
                respond(
                    """{"ocorrencia_id":"6f1c2a4e-1111-2222-3333-444455556666","tipo":"denuncia","criada_em":"2026-11-10T12:00:00Z","prazo_resposta_ate":"2026-11-17"}""",
                    HttpStatusCode.OK,
                    json,
                )
            } else {
                respond("""{"alvo_tipo":"estabelecimento","alvo_id":"e1","criado_em":"2026-11-10T12:00:00Z"}""", HttpStatusCode.OK, json)
            }
        }
        iniciar(rede)
        val viewModel = get<DenunciaViewModel> { parametersOf(TipoDeAlvo.ESTABELECIMENTO, "e1", "turno-1", "chamada-1") }
        viewModel.editarRelato("Relato com mais de dez caracteres.")

        viewModel.enviarDenuncia().join()
        viewModel.abrirDialogoBloqueio()
        viewModel.confirmarBloqueio().join()

        assertEquals("/rest/v1/rpc/denunciar", rede.pedidos[0].caminho)
        val corpo = rede.pedidos[0].corpo.orEmpty()
        assertTrue(corpo.contains("\"alvo_tipo\":\"estabelecimento\""), corpo)
        assertTrue(corpo.contains("\"alvo_id\":\"e1\""), corpo)
        assertTrue(corpo.contains("\"turno_id\":\"turno-1\""), corpo)
        assertTrue(corpo.contains("\"chamada_id\":\"chamada-1\""), corpo)
        assertEquals("/rest/v1/rpc/bloquear", rede.pedidos[1].caminho)
        assertTrue(viewModel.estado.value.bloqueado)
    }

    @Test
    fun `EquipeDeConfiancaViewModel do grafo lista, remove e sai com o estabelecimento da rota`() = runBlocking {
        val rede = Rede { request ->
            when {
                request.url.encodedPath.endsWith("/equipe_de_confianca") -> respond(
                    """[{"id":"a1","tipo":"profissional","nome":"Ana","funcoes":["garçom"],
                        "reputacao":{"positivas":1,"total":1,"turnos_considerados":1,"turnos_realizados":1}}]""",
                    HttpStatusCode.OK,
                    json,
                )
                request.url.encodedPath.endsWith("/remover_da_equipe") ->
                    respond("""{"estabelecimento_id":"$casa","profissional_id":"a1"}""", HttpStatusCode.OK, json)
                else -> respond("{}", HttpStatusCode.OK, json)
            }
        }
        iniciar(rede)
        val viewModel = get<EquipeDeConfiancaViewModel> { parametersOf(casa) }

        viewModel.carregar().join()
        val ana = (viewModel.estado.value.estado as EstadoEquipe.Conteudo).membros.single()
        viewModel.remover(ana).join()
        viewModel.sairDaEquipe(casa).join()

        assertEquals(
            listOf("/rest/v1/rpc/equipe_de_confianca", "/rest/v1/rpc/remover_da_equipe", "/rest/v1/rpc/sair_da_equipe"),
            rede.pedidos.map { it.caminho },
        )
        rede.pedidos.forEach { assertTrue(it.corpo.orEmpty().contains(casa), it.corpo) }
        assertEquals(EstadoEquipe.Vazio, viewModel.estado.value.estado)
        assertTrue(viewModel.estado.value.saiu)
    }
}
