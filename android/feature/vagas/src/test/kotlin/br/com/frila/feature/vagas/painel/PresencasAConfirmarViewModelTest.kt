package br.com.frila.feature.vagas.painel

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.PainelDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.PosicaoNoPainelDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.VagaNoPainelDto
import br.com.frila.core.rede.VagaResumoDto
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.network.sockets.ConnectTimeoutException
import io.ktor.client.request.HttpRequestData
import io.ktor.client.request.HttpResponseData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import java.time.Instant
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Cartão Uk5UJWjQ, fatia 2: "Confirmar presença" no cartão de "Presenças a confirmar" (`confirmar_checkin_manual`), como o
 * `confirmarPresenca` do `AcompanhamentoViewModel` do iOS. A confirmação passa pelo cliente real (`ServicoTurnos`): o 409 chega
 * como o servidor o manda.
 */
class PresencasAConfirmarViewModelTest {

    private val agora = Instant.parse("2026-11-12T22:00:00Z")
    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val ana = PerfilPublicoDto("pro-1", "profissional", "Ana Souza", null, ReputacaoDto(1, 1, null, 1, 1))

    private fun painel(pendentes: List<String>) = PainelDto(
        estabelecimentoId = "est-1",
        checkinsPendentes = pendentes,
        vagas = listOf(
            VagaNoPainelDto(
                vaga = VagaResumoDto("v1", "Garçom", "SQN 108", "Asa Norte", "2026-11-12T21:00:00Z", "2026-11-13T03:00:00Z", 16_000),
                modo = "urgencia", estado = "preenchida", oculta = false, alertaVagaVazia = false, candidatosPendentes = 0,
                posicoes = listOf(PosicaoNoPainelDto(id = "p4", estado = "confirmada", turnoId = "t1", profissional = ana, emAtraso = false)),
            ),
        ),
    )

    private val registroJson = """{"turno_id":"t1","tipo":"manual","verificacao":"verificado","registrado_em":"2026-11-12T21:05:00Z"}"""

    private class Rede(val responder: suspend MockRequestHandleScope.(HttpRequestData) -> HttpResponseData) {
        val corpos = mutableListOf<String>()
        val servico = ServicoTurnos(
            ClienteSupabase(
                baseUrl = "https://frila.supabase.co",
                apiKey = "chave-teste",
                engine = MockEngine { request ->
                    if (request.url.encodedPath.endsWith("/rpc/confirmar_checkin_manual")) corpos += (request.body as TextContent).text
                    responder(request)
                },
            ),
        )
    }

    private fun viewModel(rede: Rede, paineis: suspend (leitura: Int) -> Result<PainelDto>): Pair<MinhasVagasViewModel, () -> Int> {
        var leituras = 0
        val vm = MinhasVagasViewModel(
            estabelecimentoId = "est-1",
            buscarPainel = { _, _, _ -> leituras++; paineis(leituras) },
            confirmarCheckin = rede.servico::confirmarCheckinManual,
            relogio = { agora },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        return vm to { leituras }
    }

    @Test
    fun `confirmar envia o turno, tira o cartao, avisa e rele o painel`() = runBlocking {
        val rede = Rede { respond(registroJson, HttpStatusCode.OK, json) }
        val (vm, leituras) = viewModel(rede) { n -> Result.success(painel(if (n == 1) listOf("t1") else emptyList())) }
        vm.carregar().join()
        assertTrue(vm.estado.value.podeConfirmar("t1"))

        vm.confirmarPresenca("t1").join()

        assertEquals(listOf("""{"turno_id":"t1"}"""), rede.corpos)
        assertTrue(vm.estado.value.presencasAConfirmar.isEmpty())
        assertEquals(AvisoDaPresenca.CONFIRMADA, vm.estado.value.avisoDaPresenca)
        assertEquals(2, leituras())
        assertTrue(vm.estado.value.confirmando.isEmpty())
    }

    @Test
    fun `confirmada, o cartao sai na hora mesmo se a releitura do painel falhar`() = runBlocking {
        val rede = Rede { respond(registroJson, HttpStatusCode.OK, json) }
        val (vm, leituras) = viewModel(rede) { n ->
            if (n == 1) Result.success(painel(listOf("t1"))) else Result.failure(IllegalStateException("sem painel"))
        }
        vm.carregar().join()

        vm.confirmarPresenca("t1").join()

        assertEquals(2, leituras())
        assertTrue(vm.estado.value.presencasAConfirmar.isEmpty())
        assertFalse(vm.estado.value.podeConfirmar("t1"))
        assertEquals(AvisoDaPresenca.CONFIRMADA, vm.estado.value.avisoDaPresenca)
    }

    @Test
    fun `segundo toque com a confirmacao em voo nao envia de novo`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        val rede = Rede { liberar.await(); respond(registroJson, HttpStatusCode.OK, json) }
        val (vm, _) = viewModel(rede) { n -> Result.success(painel(if (n == 1) listOf("t1") else emptyList())) }
        vm.carregar().join()

        val primeiro = vm.confirmarPresenca("t1")
        assertEquals(setOf("t1"), vm.estado.value.confirmando)
        vm.confirmarPresenca("t1").join()
        liberar.complete(Unit)
        primeiro.join()

        assertEquals(1, rede.corpos.size)
        assertTrue(vm.estado.value.confirmando.isEmpty())
    }

    @Test
    fun `409 checkin_ja_confirmado ou checkin_pendente tira o botao, avisa que a situacao mudou e rele o painel`() = runBlocking {
        for (codigo in listOf("checkin_ja_confirmado", "checkin_pendente")) {
            val rede = Rede { respond("""{"code":"$codigo","message":"x","details":null}""", HttpStatusCode.Conflict, json) }
            // A releitura falha: o turno segue na lista, mas sem botão até o painel ser relido.
            val (vm, leituras) = viewModel(rede) { n ->
                if (n == 1) Result.success(painel(listOf("t1"))) else Result.failure(IllegalStateException("sem painel"))
            }
            vm.carregar().join()

            vm.confirmarPresenca("t1").join()

            assertEquals(AvisoDaPresenca.SITUACAO_MUDOU, vm.estado.value.avisoDaPresenca, codigo)
            assertFalse(vm.estado.value.podeConfirmar("t1"), codigo)
            assertEquals(2, leituras(), codigo)
            vm.confirmarPresenca("t1").join()
            assertEquals(1, rede.corpos.size, codigo)
        }
    }

    @Test
    fun `sem rede avisa e deixa o botao para tentar de novo, sem reler o painel`() = runBlocking {
        val rede = Rede { throw ConnectTimeoutException("sem rede") }
        val (vm, leituras) = viewModel(rede) { Result.success(painel(listOf("t1"))) }
        vm.carregar().join()

        vm.confirmarPresenca("t1").join()

        assertEquals(AvisoDaPresenca.SEM_REDE, vm.estado.value.avisoDaPresenca)
        assertTrue(vm.estado.value.podeConfirmar("t1"))
        assertEquals(1, leituras())
        assertEquals(1, vm.estado.value.presencasAConfirmar.size)
    }

    /**
     * Item 186: 404, 403 e 401 ao confirmar no cartão, pelo cliente real. Cada um mostra a mensagem dele (a mesma da tela do turno da
     * casa) e não é "a situação mudou": o botão fica, o cartão fica e o painel não é relido.
     */
    @Test
    fun `404, 403 e 401 ao confirmar mostram a mensagem de cada um e deixam o botao`() = runBlocking {
        val casos = listOf(
            Triple(HttpStatusCode.NotFound, "nao_encontrado", "Não encontramos este turno."),
            Triple(HttpStatusCode.Forbidden, "sem_permissao", "Você não tem permissão para confirmar a presença neste turno."),
            Triple(HttpStatusCode.Unauthorized, "nao_autenticado", "Sua sessão expirou. Entre de novo."),
        )
        for ((status, codigo, mensagem) in casos) {
            val rede = Rede { respond("""{"code":"$codigo","message":"x","details":null}""", status, json) }
            val (vm, leituras) = viewModel(rede) { Result.success(painel(listOf("t1"))) }
            vm.carregar().join()

            vm.confirmarPresenca("t1").join()

            val estado = vm.estado.value
            assertEquals(mensagem, estado.avisoDaPresenca?.mensagem, codigo)
            assertTrue(estado.avisoDaPresenca!!.erro, codigo)
            assertTrue(estado.podeConfirmar("t1"), codigo)
            assertEquals(listOf("t1"), estado.presencasAConfirmar.map { it.turnoId }, codigo)
            assertTrue(estado.confirmando.isEmpty(), codigo)
            assertEquals(1, leituras(), codigo)
            assertEquals(1, rede.corpos.size, codigo)
        }
    }

    @Test
    fun `leitura que ja estava em voo antes da confirmacao nao traz o cartao de volta`() = runBlocking {
        val leituraVelha = CompletableDeferred<Unit>()
        val rede = Rede { respond(registroJson, HttpStatusCode.OK, json) }
        val (vm, leituras) = viewModel(rede) { n ->
            when (n) {
                1 -> Result.success(painel(listOf("t1")))
                // Começou antes da confirmação: o painel dela ainda tem o t1 pendente.
                2 -> { leituraVelha.await(); Result.success(painel(listOf("t1"))) }
                else -> Result.success(painel(emptyList()))
            }
        }
        vm.carregar().join()
        vm.atualizarEmSilencio()

        vm.confirmarPresenca("t1").join()
        leituraVelha.complete(Unit)

        assertEquals(3, leituras())
        assertTrue(vm.estado.value.presencasAConfirmar.isEmpty())
    }

    @Test
    fun `sem o caminho de confirmar nao ha botao nem envio`() = runBlocking {
        val vm = MinhasVagasViewModel(
            estabelecimentoId = "est-1",
            buscarPainel = { _, _, _ -> Result.success(painel(listOf("t1"))) },
            relogio = { agora },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        vm.carregar().join()

        assertFalse(vm.confirmaPeloCartao)
        vm.confirmarPresenca("t1").join()
        assertNull(vm.estado.value.avisoDaPresenca)
    }
}
