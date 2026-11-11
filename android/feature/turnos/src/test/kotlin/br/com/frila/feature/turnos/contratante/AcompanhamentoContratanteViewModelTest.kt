package br.com.frila.feature.turnos.contratante

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.PosicaoNoPainelDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ServicoTurnos
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
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.CsvSource

class AcompanhamentoContratanteViewModelTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val html = headersOf(HttpHeaders.ContentType, "text/html")
    private val verificadoJson = """{"turno_id":"t1","tipo":"manual","verificacao":"verificado","registrado_em":"2026-11-12T21:05:00Z"}"""

    private fun contexto(
        verificacao: String? = "pendente",
        checkinTipo: String? = "manual",
        emAtraso: Boolean = false,
        aCaminhoEm: Instant? = null,
        checkinEm: Instant? = Instant.parse("2026-11-12T21:02:00Z"),
    ) = ContextoDoTurnoContratante(
        turnoId = "t1", funcao = "Garçom", local = "SQN 108",
        inicio = Instant.parse("2026-11-12T21:00:00Z"), fim = Instant.parse("2026-11-13T03:00:00Z"),
        profissional = null, aCaminhoEm = aCaminhoEm, checkinEm = checkinEm, checkinTipo = checkinTipo,
        verificacao = verificacao, emAtraso = emAtraso,
    )

    private class Rede(val resposta: MockRequestHandleScope.(HttpRequestData) -> HttpResponseData) {
        val corpos = mutableListOf<String?>()
        val caminhos = mutableListOf<String>()
    }

    private fun viewModelCom(rede: Rede, contexto: ContextoDoTurnoContratante = contexto()): AcompanhamentoContratanteViewModel {
        val engine = MockEngine { request ->
            rede.caminhos += request.url.encodedPath
            rede.corpos += (request.body as? TextContent)?.text
            rede.resposta(this, request)
        }
        val servico = ServicoTurnos(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
        return AcompanhamentoContratanteViewModel(
            contexto = contexto,
            confirmar = servico::confirmarCheckinManual,
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
    }

    private fun MockRequestHandleScope.recusa(status: HttpStatusCode, codigo: String) =
        respond("""{"code":"$codigo","message":"x"}""", status, json)

    // ---- Presença ----

    @ParameterizedTest
    @CsvSource(
        "verificado, geolocalizado, false, false, VERIFICADA",
        "verificado, manual, true, true, VERIFICADA",
        "pendente, manual, false, false, CHECKIN_MANUAL_PENDENTE",
        "pendente, codigo, true, true, CHECKIN_MANUAL_PENDENTE",
        "pendente, tipo_novo, false, false, CHECKIN_MANUAL_PENDENTE",
        "nao_verificado, manual, false, false, NAO_VERIFICADA",
        "NULO, NULO, true, false, EM_ATRASO",
        "NULO, NULO, true, true, EM_ATRASO",
        "NULO, NULO, false, true, A_CAMINHO",
        "NULO, NULO, false, false, AGUARDANDO",
        "pendente, NULO, false, false, AGUARDANDO",
    )
    fun `presencaDe segue a prioridade verificada, pendente, nao verificada, atraso, a caminho, aguardando`(
        verificacao: String,
        tipo: String,
        emAtraso: Boolean,
        aCaminho: Boolean,
        esperada: PresencaDoTurno,
    ) {
        val c = contexto(
            verificacao = verificacao.takeIf { it != "NULO" },
            checkinTipo = tipo.takeIf { it != "NULO" },
            emAtraso = emAtraso,
            aCaminhoEm = if (aCaminho) Instant.parse("2026-11-12T20:00:00Z") else null,
        )

        assertEquals(esperada, presencaDe(c))
    }

    @Test
    fun `dePainel monta o contexto da linha do painel e devolve nulo sem turno`() {
        val vaga = VagaResumoDto("v1", "Garçom", "SQN 108", "Asa Norte", "2026-11-12T21:00:00Z", "2026-11-13T03:00:00Z", 16_000)
        val profissional = PerfilPublicoDto("p1", "profissional", "Ana", reputacao = ReputacaoDto(1, 1, null, 1, 1))
        val posicao = PosicaoNoPainelDto(
            id = "pos-1", estado = "confirmada", profissional = profissional, turnoId = "t1", verificacao = "pendente",
            emAtraso = false, aCaminhoEm = "2026-11-12T19:00:00Z", checkinEm = "2026-11-12T21:02:00Z", checkinTipo = "manual",
        )

        val contexto = ContextoDoTurnoContratante.dePainel(vaga, posicao)!!

        assertEquals("t1", contexto.turnoId)
        assertEquals("Garçom", contexto.funcao)
        assertEquals("Ana", contexto.profissional?.nome)
        assertEquals(Instant.parse("2026-11-12T19:00:00Z"), contexto.aCaminhoEm)
        assertEquals(Instant.parse("2026-11-12T21:02:00Z"), contexto.checkinEm)
        assertEquals("manual", contexto.checkinTipo)
        assertEquals(PresencaDoTurno.CHECKIN_MANUAL_PENDENTE, presencaDe(contexto))
        assertNull(ContextoDoTurnoContratante.dePainel(vaga, posicao.copy(turnoId = null)))
    }

    // ---- Confirmar ----

    @Test
    fun `confirmar manda POST com o turno e a presenca passa a verificada`() = runBlocking {
        val rede = Rede { respond(verificadoJson, HttpStatusCode.OK, json) }
        val vm = viewModelCom(rede)

        vm.confirmarPresenca().join()

        assertEquals(listOf("/rest/v1/rpc/confirmar_checkin_manual"), rede.caminhos)
        assertEquals("t1", ClienteSupabase.jsonFrila.parseToJsonElement(rede.corpos.single()!!).jsonObject["turno_id"]!!.jsonPrimitive.content)
        assertEquals(PresencaDoTurno.VERIFICADA, vm.estado.value.presenca)
        assertEquals(AvisoDaConfirmacao.CONFIRMADA_AGORA, vm.estado.value.aviso)
        assertFalse(vm.estado.value.enviando)
        assertFalse(vm.estado.value.podeConfirmar)
    }

    @Test
    fun `sem check-in manual pendente confirmar nao chama a rede`() = runBlocking {
        val rede = Rede { respond(verificadoJson, HttpStatusCode.OK, json) }
        val aguardando = viewModelCom(rede, contexto(verificacao = null, checkinTipo = null, checkinEm = null))
        val verificada = viewModelCom(rede, contexto(verificacao = "verificado"))

        aguardando.confirmarPresenca().join()
        verificada.confirmarPresenca().join()

        assertTrue(rede.caminhos.isEmpty())
    }

    @Test
    fun `segundo toque com a confirmacao em voo nao manda outra`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        val rede = Rede { runBlocking { liberar.await() }; respond(verificadoJson, HttpStatusCode.OK, json) }
        val vm = viewModelCom(rede)

        val primeira = vm.confirmarPresenca()
        assertTrue(vm.estado.value.enviando)
        vm.confirmarPresenca()
        liberar.complete(Unit)
        withTimeout(5_000) { primeira.join() }

        assertEquals(1, rede.caminhos.size)
    }

    @Test
    fun `409 checkin_ja_confirmado nao e falha e a presenca passa a verificada`() = runBlocking {
        val vm = viewModelCom(Rede { recusa(HttpStatusCode.Conflict, "checkin_ja_confirmado") })

        vm.confirmarPresenca().join()

        assertEquals(PresencaDoTurno.VERIFICADA, vm.estado.value.presenca)
        assertEquals(AvisoDaConfirmacao.JA_CONFIRMADA, vm.estado.value.aviso)
        assertFalse(vm.estado.value.aviso!!.erro)
    }

    @Test
    fun `409 checkin_pendente diz que o painel esta velho e tira o botao`() = runBlocking {
        val vm = viewModelCom(Rede { recusa(HttpStatusCode.Conflict, "checkin_pendente") })

        vm.confirmarPresenca().join()

        assertEquals(AvisoDaConfirmacao.CHECKIN_PENDENTE, vm.estado.value.aviso)
        assertEquals(PresencaDoTurno.AGUARDANDO, vm.estado.value.presenca)
        assertFalse(vm.estado.value.podeConfirmar)
        assertNull(vm.estado.value.contexto.checkinEm)
    }

    private fun falhaDe(rede: Rede): EstadoTurnoDoContratante {
        val vm = viewModelCom(rede)
        runBlocking { vm.confirmarPresenca().join() }
        return vm.estado.value
    }

    @Test
    fun `404, 403 e 401 tem mensagem propria e deixam o botao disponivel`() {
        val casos = listOf(
            Triple(HttpStatusCode.NotFound, "nao_encontrado", AvisoDaConfirmacao.NAO_ENCONTRADO),
            Triple(HttpStatusCode.Forbidden, "sem_permissao", AvisoDaConfirmacao.SEM_PERMISSAO),
            Triple(HttpStatusCode.Unauthorized, "nao_autenticado", AvisoDaConfirmacao.SESSAO_EXPIRADA),
        )
        for ((status, codigo, esperado) in casos) {
            val estado = falhaDe(Rede { recusa(status, codigo) })

            assertEquals(esperado, estado.aviso, codigo)
            assertTrue(estado.aviso!!.erro, codigo)
            assertTrue(estado.podeConfirmar, codigo)
        }
    }

    @Test
    fun `sem rede avisa e deixa tentar de novo`() {
        val estado = falhaDe(Rede { throw ConnectTimeoutException("sem rede") })

        assertEquals(AvisoDaConfirmacao.SEM_REDE, estado.aviso)
        assertTrue(estado.podeConfirmar)
    }

    @Test
    fun `erro 500 em JSON e codigo desconhecido viram generico`() {
        assertEquals(AvisoDaConfirmacao.GENERICO, falhaDe(Rede { recusa(HttpStatusCode.InternalServerError, "erro_interno") }).aviso)
        assertEquals(AvisoDaConfirmacao.GENERICO, falhaDe(Rede { recusa(HttpStatusCode.UnprocessableEntity, "codigo_novo") }).aviso)
    }

    @Test
    fun `200 com HTML, 502 com HTML e 200 sem campo obrigatorio viram generico e liberam o botao`() {
        val casos = listOf<Rede>(
            Rede { respond("<html>ok</html>", HttpStatusCode.OK, html) },
            Rede { respond("<html>502</html>", HttpStatusCode.BadGateway, html) },
            Rede { respond("""{"turno_id":"t1"}""", HttpStatusCode.OK, json) },
        )
        for (rede in casos) {
            val estado = falhaDe(rede)

            assertEquals(AvisoDaConfirmacao.GENERICO, estado.aviso)
            assertFalse(estado.enviando)
            assertTrue(estado.podeConfirmar)
        }
    }

    @Test
    fun `lancamento escapando do servico tambem vira generico e libera o botao`() = runBlocking {
        val vm = AcompanhamentoContratanteViewModel(
            contexto = contexto(),
            confirmar = { error("explodiu") },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )

        vm.confirmarPresenca().join()

        assertEquals(AvisoDaConfirmacao.GENERICO, vm.estado.value.aviso)
        assertFalse(vm.estado.value.enviando)
    }

    @Test
    fun `nova tentativa depois da falha limpa o aviso e confirma`() = runBlocking {
        var tentativa = 0
        val vm = viewModelCom(Rede { if (++tentativa == 1) throw ConnectTimeoutException("sem rede") else respond(verificadoJson, HttpStatusCode.OK, json) })

        vm.confirmarPresenca().join()
        assertEquals(AvisoDaConfirmacao.SEM_REDE, vm.estado.value.aviso)
        vm.confirmarPresenca().join()

        assertEquals(AvisoDaConfirmacao.CONFIRMADA_AGORA, vm.estado.value.aviso)
        assertEquals(PresencaDoTurno.VERIFICADA, vm.estado.value.presenca)
    }
}
