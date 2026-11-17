package br.com.frila.feature.turnos.contratante

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
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
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Reabrir a vaga quando o profissional não chega (RF13, D06; L2-2; paridade com `AcompanhamentoViewModel.swift`).
 * Reabrir conta como falta, não tem volta e não é idempotente: só com confirmação, um envio por vez e nunca de novo sozinho.
 */
class ReabrirPorAtrasoTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")

    private fun contexto(
        emAtraso: Boolean = true,
        estadoDaPosicao: String? = "confirmada",
        posicaoId: String? = "pos1",
        verificacao: String? = null,
        checkinTipo: String? = null,
    ) = ContextoDoTurnoContratante(
        turnoId = "t1", funcao = "Garçom", local = "SQN 108",
        inicio = Instant.parse("2026-11-12T21:00:00Z"), fim = Instant.parse("2026-11-13T03:00:00Z"),
        profissional = null, aCaminhoEm = null, checkinEm = null, checkinTipo = checkinTipo,
        verificacao = verificacao, emAtraso = emAtraso, posicaoId = posicaoId, estadoDaPosicao = estadoDaPosicao,
    )

    private class Rede(val resposta: suspend MockRequestHandleScope.(HttpRequestData) -> HttpResponseData) {
        val corpos = mutableListOf<String?>()
        val caminhos = mutableListOf<String>()
    }

    private fun viewModelCom(rede: Rede, contexto: ContextoDoTurnoContratante = contexto(), comReabrir: Boolean = true): AcompanhamentoContratanteViewModel {
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
            reabrir = if (comReabrir) servico::reabrirPorAtraso else null,
        )
    }

    private fun MockRequestHandleScope.ok(reaberta: Boolean = true) = respond(
        """{"posicao_id":"pos1","falta":true,"reaberta":$reaberta,"nova_posicao_id":${if (reaberta) "\"pos2\"" else "null"}}""",
        HttpStatusCode.OK, json,
    )

    private fun MockRequestHandleScope.recusa(status: HttpStatusCode, codigo: String, detalhes: String? = null) =
        respond("""{"code":"$codigo","message":"x","details":${detalhes?.let { "\"$it\"" } ?: "null"}}""", status, json)

    // ---- quando o botão existe ----

    @Test
    fun `em atraso, na posicao confirmada e com a reabertura ligada, pode reabrir`() {
        assertTrue(viewModelCom(Rede { ok() }).estado.value.podeReabrir)
    }

    @Test
    fun `sem a reabertura ligada o botao nunca existe, nem em atraso`() {
        assertFalse(viewModelCom(Rede { ok() }, comReabrir = false).estado.value.podeReabrir)
    }

    @Test
    fun `antes dos 15 minutos, com posicao cancelada, sem id da posicao ou com check-in feito nao pode reabrir`() {
        assertFalse(viewModelCom(Rede { ok() }, contexto(emAtraso = false)).estado.value.podeReabrir)
        assertFalse(viewModelCom(Rede { ok() }, contexto(estadoDaPosicao = "cancelada")).estado.value.podeReabrir)
        assertFalse(viewModelCom(Rede { ok() }, contexto(estadoDaPosicao = null)).estado.value.podeReabrir)
        assertFalse(viewModelCom(Rede { ok() }, contexto(posicaoId = null)).estado.value.podeReabrir)
        assertFalse(viewModelCom(Rede { ok() }, contexto(verificacao = "pendente", checkinTipo = "manual")).estado.value.podeReabrir)
    }

    // ---- a confirmação antes de reabrir ----

    @Test
    fun `pedir abre a pergunta, desistir fecha, e nada e enviado`() {
        val rede = Rede { ok() }
        val vm = viewModelCom(rede)

        vm.pedirReabertura()
        assertTrue(vm.estado.value.pedindoReabertura)
        vm.desistirDaReabertura()

        assertFalse(vm.estado.value.pedindoReabertura)
        assertEquals(0, rede.caminhos.size)
    }

    @Test
    fun `sem pedir antes, confirmar nao envia nada`() = runBlocking {
        val rede = Rede { ok() }
        val vm = viewModelCom(rede)

        assertNull(vm.confirmarReabertura())

        assertEquals(0, rede.caminhos.size)
    }

    @Test
    fun `quem nao pode reabrir nem abre a pergunta`() {
        val vm = viewModelCom(Rede { ok() }, contexto(emAtraso = false))

        vm.pedirReabertura()

        assertFalse(vm.estado.value.pedindoReabertura)
    }

    // ---- o envio ----

    @Test
    fun `confirmar manda POST reabrir_por_atraso com a posicao, registra a falta e reabre`() = runBlocking {
        val rede = Rede { ok(reaberta = true) }
        val vm = viewModelCom(rede)
        vm.pedirReabertura()

        vm.confirmarReabertura()!!.join()

        assertEquals(listOf("/rest/v1/rpc/reabrir_por_atraso"), rede.caminhos)
        assertEquals("""{"posicao_id":"pos1"}""", rede.corpos.single()?.replace(" ", ""))
        val estado = vm.estado.value
        assertEquals(ResultadoDaReabertura(reaberta = true), estado.reabertura)
        assertEquals(AvisoDaReabertura.REABERTA, estado.avisoDaReabertura)
        assertEquals("cancelada", estado.contexto.estadoDaPosicao)
        assertFalse(estado.reabrindo)
        assertFalse(estado.pedindoReabertura)
        assertFalse(estado.podeReabrir)
    }

    @Test
    fun `turno que ficou descoberto registra a falta sem reabrir e diz isso`() = runBlocking {
        val vm = viewModelCom(Rede { ok(reaberta = false) })
        vm.pedirReabertura()

        vm.confirmarReabertura()!!.join()

        assertEquals(ResultadoDaReabertura(reaberta = false), vm.estado.value.reabertura)
        assertEquals(AvisoDaReabertura.FALTA_SEM_REABERTURA, vm.estado.value.avisoDaReabertura)
    }

    @Test
    fun `depois de reabrir nao existe mais como reabrir de novo - nunca repete sozinho`() = runBlocking {
        val rede = Rede { ok() }
        val vm = viewModelCom(rede)
        vm.pedirReabertura()
        vm.confirmarReabertura()!!.join()

        vm.pedirReabertura()

        assertFalse(vm.estado.value.pedindoReabertura)
        assertNull(vm.confirmarReabertura())
        assertEquals(1, rede.caminhos.size)
    }

    @Test
    fun `um envio por vez - com a reabertura em voo nao ha como pedir nem confirmar de novo`() = runBlocking {
        val solta = CompletableDeferred<Unit>()
        val rede = Rede { solta.await(); ok() }
        val vm = viewModelCom(rede)
        vm.pedirReabertura()

        val envio = vm.confirmarReabertura()!!
        assertTrue(vm.estado.value.reabrindo)
        vm.pedirReabertura()
        assertFalse(vm.estado.value.pedindoReabertura)
        assertNull(vm.confirmarReabertura())
        solta.complete(Unit)
        envio.join()

        assertEquals(1, rede.caminhos.size)
        assertFalse(vm.estado.value.reabrindo)
    }

    // ---- as recusas do contrato, em texto do Frila ----

    private fun recusaComAviso(
        resposta: suspend MockRequestHandleScope.(HttpRequestData) -> HttpResponseData,
        aviso: AvisoDaReabertura,
        recusada: Boolean,
    ) = runBlocking {
        val rede = Rede(resposta)
        val vm = viewModelCom(rede)
        vm.pedirReabertura()

        vm.confirmarReabertura()!!.join()

        val estado = vm.estado.value
        assertEquals(aviso, estado.avisoDaReabertura)
        assertTrue(aviso.erro)
        assertFalse(estado.reabrindo)
        assertFalse(estado.pedindoReabertura)
        assertNull(estado.reabertura)
        assertEquals(recusada, estado.reaberturaRecusada)
        assertEquals(!recusada, estado.podeReabrir)
        assertEquals(1, rede.caminhos.size)
    }

    @Test
    fun `422 antes da tolerancia diz que ainda nao passaram 15 minutos e some o botao`() =
        recusaComAviso({ recusa(HttpStatusCode.UnprocessableEntity, "reabertura_antes_da_tolerancia") }, AvisoDaReabertura.ANTES_DA_TOLERANCIA, recusada = true)

    @Test
    fun `409 com check-in registrado diz que o profissional ja chegou`() =
        recusaComAviso({ recusa(HttpStatusCode.Conflict, "posicao_nao_cancelavel", "checkin_registrado") }, AvisoDaReabertura.CHECKIN_REGISTRADO, recusada = true)

    @Test
    fun `409 sem details diz que a situacao do turno mudou`() =
        recusaComAviso({ recusa(HttpStatusCode.Conflict, "posicao_nao_cancelavel") }, AvisoDaReabertura.SITUACAO_MUDOU, recusada = true)

    @Test
    fun `403 diz que so a casa reabre`() =
        recusaComAviso({ recusa(HttpStatusCode.Forbidden, "sem_permissao") }, AvisoDaReabertura.SEM_PERMISSAO, recusada = true)

    @Test
    fun `401 diz que a sessao expirou`() =
        recusaComAviso({ recusa(HttpStatusCode.Unauthorized, "nao_autenticado") }, AvisoDaReabertura.SESSAO_EXPIRADA, recusada = false)

    @Test
    fun `sem rede diz que a vaga nao foi reaberta e deixa tentar de novo`() =
        recusaComAviso({ throw ConnectTimeoutException("sem rota", null) }, AvisoDaReabertura.SEM_REDE, recusada = false)

    @Test
    fun `resposta ilegivel de gateway vira o texto generico, sem o corpo cru`() =
        recusaComAviso({ respond("<html>502</html>", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "text/html")) }, AvisoDaReabertura.GENERICO, recusada = false)

    @Test
    fun `depois de uma recusa o botao volta so quando o painel for relido`() = runBlocking {
        val vm = viewModelCom(Rede { recusa(HttpStatusCode.UnprocessableEntity, "reabertura_antes_da_tolerancia") })
        vm.pedirReabertura()
        vm.confirmarReabertura()!!.join()
        assertFalse(vm.estado.value.podeReabrir)

        vm.atualizarContexto(contexto(emAtraso = true))

        assertTrue(vm.estado.value.podeReabrir)
        assertNotNull(vm.estado.value.avisoDaReabertura)
    }
}
