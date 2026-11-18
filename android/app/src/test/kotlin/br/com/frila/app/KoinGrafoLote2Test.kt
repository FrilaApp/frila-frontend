package br.com.frila.app

import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoConfianca
import br.com.frila.core.rede.ServicoConta
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.feature.conta.ContaSuspensaViewModel
import br.com.frila.feature.conta.ContestarDespachoViewModel
import br.com.frila.feature.equipe.IncluirNaEquipeViewModel
import br.com.frila.feature.suporte.BloqueiosViewModel
import br.com.frila.feature.turnos.contratante.AcompanhamentoContratanteViewModel
import br.com.frila.feature.turnos.contratante.ContextoDoTurnoContratante
import br.com.frila.feature.vagas.candidaturas.MinhasCandidaturasViewModel
import br.com.frila.feature.vagas.candidaturas.RetirarCandidaturaViewModel
import br.com.frila.feature.vagas.detalhe.AberturaDeVagaViewModel
import br.com.frila.feature.vagas.detalhe.DetalheVagaViewModel
import br.com.frila.feature.vagas.painel.CancelarVagaViewModel
import br.com.frila.feature.vagas.painel.MotivoDeCancelamentoDaVaga
import br.com.frila.feature.vagas.painel.RepublicarPosicoesRestantesViewModel
import br.com.frila.feature.vagas.painel.RepublicarVagaViewModel
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import io.mockk.mockk
import java.time.Duration
import java.time.Instant
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
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

private val moduloLocalizacaoDoGrafoDoLote2 = module {
    single<ProvedorDeLocalizacao> { mockk(relaxed = true) }
}

/**
 * L2-8: o grafo monta os ViewModels do Lote 2 e cada um fala com a chamada certa do servidor. O servidor aqui é um
 * `MockEngine` que só guarda o caminho pedido (a resposta é uma recusa qualquer: o que se prova é a ligação).
 */
@OptIn(ExperimentalCoroutinesApi::class)
class KoinGrafoLote2Test : KoinTest {

    private class Pedido(val caminho: String, val corpo: String?)

    private val pedidos = mutableListOf<Pedido>()

    private fun cliente() = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-teste",
        engine = MockEngine { request ->
            pedidos += Pedido(request.url.encodedPath, (request.body as? TextContent)?.text)
            respond("{}", HttpStatusCode.InternalServerError, headersOf(HttpHeaders.ContentType, "application/json"))
        },
    )

    @BeforeEach
    fun antes() {
        Dispatchers.setMain(UnconfinedTestDispatcher())
        val cliente = cliente()
        startKoin {
            modules(
                listOf(moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacaoDoGrafoDoLote2, moduloFeatures) +
                    module {
                        single { ServicoVagas(cliente) }
                        single { ServicoTurnos(cliente) }
                        single { ServicoConta(cliente) }
                        single { ServicoConfianca(cliente) }
                    },
            )
        }
    }

    @AfterEach
    fun depois() {
        stopKoin()
        Dispatchers.resetMain()
    }

    private fun caminhos() = pedidos.map { it.caminho }

    @Test
    fun `cancelar vaga chama cancelar_vaga com a vaga e o motivo`() = runBlocking {
        val viewModel = get<CancelarVagaViewModel> { parametersOf("v1", Instant.now().plusSeconds(36_000)) }
        viewModel.escolherMotivo(MotivoDeCancelamentoDaVaga.MOVIMENTO_MENOR)

        viewModel.confirmar()?.join()

        assertEquals(listOf("/rest/v1/rpc/cancelar_vaga"), caminhos())
        assertTrue(pedidos.single().corpo.orEmpty().contains("\"vaga_id\":\"v1\""), pedidos.single().corpo)
    }

    @Test
    fun `republicar vaga chama republicar_vaga`() = runBlocking {
        val viewModel = get<RepublicarVagaViewModel> { parametersOf("v1", false, Duration.ofHours(6)) }

        viewModel.republicar()?.join()

        assertEquals(listOf("/rest/v1/rpc/republicar_vaga"), caminhos())
    }

    @Test
    fun `republicar posicoes restantes chama republicar_posicoes_restantes`() = runBlocking {
        val viewModel = get<RepublicarPosicoesRestantesViewModel> { parametersOf("v1", 2, { _: String -> }, { }) }

        viewModel.executar()?.join()

        assertEquals(listOf("/rest/v1/rpc/republicar_posicoes_restantes"), caminhos())
    }

    @Test
    fun `abrir a vaga pelo id le detalhe_vaga`() = runBlocking {
        val viewModel = get<AberturaDeVagaViewModel> { parametersOf("v1") }

        viewModel.carregar().join()

        assertEquals(listOf("/rest/v1/rpc/detalhe_vaga"), caminhos())
    }

    @Test
    fun `o detalhe da vaga continua montando so com a vaga da lista`() {
        assertNotNull(get<DetalheVagaViewModel> { parametersOf(vagaDaLista()) })
    }

    @Test
    fun `minhas candidaturas le minhas_candidaturas e retirar chama retirar_candidatura`() = runBlocking {
        get<MinhasCandidaturasViewModel>().carregar().join()
        get<RetirarCandidaturaViewModel> { parametersOf("c1", { }) }.retirar()?.join()

        assertTrue(caminhos().containsAll(listOf("/rest/v1/rpc/minhas_candidaturas", "/rest/v1/rpc/retirar_candidatura")), caminhos().toString())
    }

    @Test
    fun `reabrir por atraso chama reabrir_por_atraso depois da pergunta`() = runBlocking {
        val contexto = ContextoDoTurnoContratante(
            turnoId = "t1", funcao = "Garçom", local = "SQN 108", inicio = Instant.now().minusSeconds(3_600), fim = Instant.now().plusSeconds(3_600),
            profissional = null, aCaminhoEm = null, checkinEm = null, checkinTipo = null, verificacao = null, emAtraso = true,
            posicaoId = "p1", estadoDaPosicao = "confirmada",
        )
        val viewModel = get<AcompanhamentoContratanteViewModel> { parametersOf(contexto) }

        viewModel.pedirReabertura()
        viewModel.confirmarReabertura()?.join()

        assertEquals(listOf("/rest/v1/rpc/reabrir_por_atraso"), caminhos())
    }

    @Test
    fun `conta suspensa le situacao_da_conta e contestar despacho chama pedir_revisao_despacho`() = runBlocking {
        get<ContaSuspensaViewModel> { parametersOf({ }) }.carregar().join()
        val contestar = get<ContestarDespachoViewModel>()
        contestar.mudarRelato("Recebi uma vaga que não faz sentido para mim.")
        contestar.contestar()?.join()

        assertEquals(
            listOf("/rest/v1/rpc/situacao_da_conta", "/rest/v1/rpc/pedir_revisao_despacho"),
            caminhos(),
        )
    }

    @Test
    fun `bloqueios le listar_bloqueios`() = runBlocking {
        get<BloqueiosViewModel>().carregar().join()

        assertEquals(listOf("/rest/v1/rpc/listar_bloqueios"), caminhos())
    }

    @Test
    fun `incluir na equipe le a equipe e chama incluir_na_equipe`() = runBlocking {
        val viewModel = get<IncluirNaEquipeViewModel> { parametersOf("est-1", "pro-1") }

        viewModel.carregar().join()
        viewModel.incluir().join()

        assertTrue(caminhos().contains("/rest/v1/rpc/incluir_na_equipe"), caminhos().toString())
    }
}
