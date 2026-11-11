package br.com.frila.app

import br.com.frila.core.localizacao.GerenciadorGeofencingTurnos
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.feature.turnos.contratante.AcompanhamentoContratanteViewModel
import br.com.frila.feature.turnos.contratante.AvisoDaConfirmacao
import br.com.frila.feature.turnos.contratante.ContextoDoTurnoContratante
import br.com.frila.feature.turnos.contratante.PresencaDoTurno
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
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

private val moduloLocalizacaoDoGrafoDeTurno = module {
    single<ProvedorDeLocalizacao> { mockk(relaxed = true) }
    single<GerenciadorGeofencingTurnos> { mockk(relaxed = true) }
}

/**
 * Cartão zqub2hps: o grafo monta o `AcompanhamentoContratanteViewModel` com o contexto da rota e o liga a
 * `ServicoTurnos.confirmarCheckinManual`; o que está atrás da fiação é de fato chamado.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class KoinGrafoTurnoDoContratanteTest : KoinTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")

    private fun contexto(turnoId: String = "t1") = ContextoDoTurnoContratante(
        turnoId = turnoId, funcao = "Garçom", local = "SQN 108",
        inicio = Instant.parse("2026-11-12T21:00:00Z"), fim = Instant.parse("2026-11-13T03:00:00Z"),
        profissional = null, aCaminhoEm = null, checkinEm = Instant.parse("2026-11-12T21:02:00Z"),
        checkinTipo = "manual", verificacao = "pendente", emAtraso = false,
    )

    private val modulosBase get() = listOf(
        moduloSeguranca, moduloRede, moduloNotificacoes, moduloLocalizacaoDoGrafoDeTurno, moduloFeatures,
    )

    private fun iniciarComRede(corpos: MutableList<Pair<String, String?>>) {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { request ->
                corpos += request.url.encodedPath to (request.body as? TextContent)?.text
                respond(
                    """{"turno_id":"t9","tipo":"manual","verificacao":"verificado","registrado_em":"2026-11-12T21:05:00Z"}""",
                    HttpStatusCode.OK,
                    json,
                )
            },
        )
        startKoin { modules(modulosBase + module { single { ServicoTurnos(cliente) } }) }
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
    fun `grafo resolve ServicoTurnos e AcompanhamentoContratanteViewModel com o contexto da rota`() {
        startKoin { modules(modulosBase) }

        assertNotNull(get<ServicoTurnos>())
        assertNotNull(get<AcompanhamentoContratanteViewModel> { parametersOf(contexto()) })
    }

    @Test
    fun `o contexto da rota chega ao estado e os ViewModels do grafo sao independentes`() {
        iniciarComRede(mutableListOf())

        val primeiro = get<AcompanhamentoContratanteViewModel> { parametersOf(contexto("t1")) }
        val segundo = get<AcompanhamentoContratanteViewModel> { parametersOf(contexto("t2")) }

        assertNotSame(primeiro, segundo)
        assertEquals("t1", primeiro.estado.value.contexto.turnoId)
        assertEquals("t2", segundo.estado.value.contexto.turnoId)
        assertEquals(PresencaDoTurno.CHECKIN_MANUAL_PENDENTE, primeiro.estado.value.presenca)
    }

    @Test
    fun `ViewModel do grafo confirma a presenca pela RPC com o turno do contexto`() = runBlocking {
        val chamadas = mutableListOf<Pair<String, String?>>()
        iniciarComRede(chamadas)
        val viewModel = get<AcompanhamentoContratanteViewModel> { parametersOf(contexto("t1")) }

        viewModel.confirmarPresenca().join()

        val (caminho, corpo) = chamadas.single()
        assertEquals("/rest/v1/rpc/confirmar_checkin_manual", caminho)
        assertTrue(corpo.orEmpty().contains("\"turno_id\":\"t1\""), corpo)
        assertEquals(PresencaDoTurno.VERIFICADA, viewModel.estado.value.presenca)
        assertEquals(AvisoDaConfirmacao.CONFIRMADA_AGORA, viewModel.estado.value.aviso)
    }
}
