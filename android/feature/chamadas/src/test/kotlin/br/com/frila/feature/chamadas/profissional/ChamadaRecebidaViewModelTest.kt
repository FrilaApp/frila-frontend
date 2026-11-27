package br.com.frila.feature.chamadas.profissional

import io.ktor.client.engine.mock.respond
import io.ktor.client.network.sockets.ConnectTimeoutException
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.time.Instant

class ChamadaRecebidaViewModelTest {

    /** 16/11/2026 21:00 em Brasília = 17/11 00:00Z; a chamada da fixture expira 17/11 12:00Z. */
    private val antesDoPrazo = Instant.parse("2026-11-17T00:00:00Z")
    private val depoisDoPrazo = Instant.parse("2026-11-17T12:00:00Z")

    private fun viewModelCom(rede: RedeDeTeste, agora: Instant = antesDoPrazo) = ChamadaRecebidaViewModel(
        chamadaId = Fixtures.CHAMADA,
        detalhar = rede.servico::detalheChamada,
        responder = rede.servico::responderChamada,
        agora = { agora },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    private fun rede(detalhe: String = Fixtures.detalheChamadaJson()) = RedeDeTeste().apply {
        ok("/rpc/detalhe_chamada", detalhe)
    }

    @Test
    fun `carregar le detalhe_chamada e abre a chamada para responder`() = runBlocking {
        val rede = rede()
        val vm = viewModelCom(rede)
        assertTrue(vm.estado.value.carregando)

        vm.carregar().join()

        val tela = vm.estado.value
        assertFalse(tela.carregando)
        assertEquals("Bistrô Aurora", tela.detalhe!!.outraParte.nome)
        assertEquals(18000L, tela.detalhe!!.valorCentavos)
        assertTrue(tela.podeResponder)
        assertNull(tela.mensagemDeConcorrencia)
        val pedido = rede.pedidos.single()
        assertEquals("/rest/v1/rpc/detalhe_chamada", pedido.caminho)
        assertEquals(Fixtures.CHAMADA, pedido.corpo!!["chamada_id"]!!.jsonPrimitive.content)
    }

    @Test
    fun `aceitar manda resposta aceitar sem motivo e libera local e responsavel (RN36)`() = runBlocking {
        val rede = rede()
        rede.ok("/rpc/responder_chamada", Fixtures.resultadoJson("aceita"))
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.aceitar().join()

        val corpo = rede.doCaminho("/rpc/responder_chamada").single().corpo!!
        assertEquals(setOf("chamada_id", "resposta"), corpo.keys)
        assertEquals("aceitar", corpo["resposta"]!!.jsonPrimitive.content)
        val tela = vm.estado.value
        assertFalse(tela.respondendo)
        assertEquals("SCS Quadra 2", tela.resultado!!.local)
        assertEquals("Ana", tela.resultado!!.responsavelLocal)
        assertEquals(Fixtures.TURNO, tela.resultado!!.turnoId)
        assertEquals("aceita", tela.detalhe!!.estado)
        assertEquals("SCS Quadra 2", tela.detalhe!!.local)
        assertFalse(tela.podeResponder)
    }

    @Test
    fun `recusar com motivo manda o motivo do contrato e nao pune`() = runBlocking {
        val rede = rede()
        rede.ok("/rpc/responder_chamada", Fixtures.resultadoJson("recusada"))
        val vm = viewModelCom(rede)
        vm.carregar().join()
        vm.abrirRecusa()
        assertTrue(vm.estado.value.mostrarRecusa)
        vm.escolherMotivo("agenda")

        vm.recusar().join()

        val corpo = rede.doCaminho("/rpc/responder_chamada").single().corpo!!
        assertEquals("recusar", corpo["resposta"]!!.jsonPrimitive.content)
        assertEquals("agenda", corpo["motivo_recusa"]!!.jsonPrimitive.content)
        val tela = vm.estado.value
        assertFalse(tela.mostrarRecusa)
        assertEquals("recusada", tela.resultado!!.chamada.estado)
        assertEquals("agenda", tela.detalhe!!.motivoRecusa)
        assertFalse(tela.podeResponder)
    }

    @Test
    fun `recusar sem motivo nao manda motivo_recusa`() = runBlocking {
        val rede = rede()
        rede.ok("/rpc/responder_chamada", Fixtures.resultadoJson("recusada"))
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.recusar().join()

        val corpo = rede.doCaminho("/rpc/responder_chamada").single().corpo!!
        assertEquals(setOf("chamada_id", "resposta"), corpo.keys)
    }

    @Test
    fun `chamada que o relogio ja venceu nao chama o servidor e explica`() = runBlocking {
        val rede = rede()
        val vm = viewModelCom(rede, agora = depoisDoPrazo)

        vm.carregar().join()

        assertEquals(TextosChamadaProfissional.CHAMADA_EXPIRADA, vm.estado.value.mensagemDeConcorrencia)
        assertFalse(vm.estado.value.podeResponder)
        vm.aceitar().join()
        vm.recusar().join()
        assertTrue(rede.doCaminho("/rpc/responder_chamada").isEmpty())
    }

    @Test
    fun `prazo que vence entre abrir a tela e tocar em aceitar tambem nao chama o servidor`() = runBlocking {
        val rede = rede()
        var agora = antesDoPrazo
        val vm = ChamadaRecebidaViewModel(Fixtures.CHAMADA, rede.servico::detalheChamada, rede.servico::responderChamada, { agora }, CoroutineScope(Dispatchers.Unconfined))
        vm.carregar().join()
        assertTrue(vm.estado.value.podeResponder)

        agora = depoisDoPrazo
        vm.aceitar().join()

        assertTrue(rede.doCaminho("/rpc/responder_chamada").isEmpty())
        assertEquals(TextosChamadaProfissional.CHAMADA_EXPIRADA, vm.estado.value.mensagemDeConcorrencia)
    }

    @Test
    fun `chamada que ja nao esta aberta carrega sem botoes e com o aviso certo`() = runBlocking {
        val esperados = mapOf(
            "expirada" to TextosChamadaProfissional.CHAMADA_EXPIRADA,
            "cancelada" to TextosChamadaProfissional.CHAMADA_CANCELADA,
            "encerrada" to TextosChamadaProfissional.CHAMADA_ENCERRADA,
            "recusada" to TextosChamadaProfissional.CHAMADA_RECUSADA,
        )
        for ((estado, mensagem) in esperados) {
            val vm = viewModelCom(rede(Fixtures.detalheChamadaJson(estado = estado)))
            vm.carregar().join()
            assertEquals(mensagem, vm.estado.value.mensagemDeConcorrencia, estado)
            assertFalse(vm.estado.value.podeResponder, estado)
        }
    }

    @Test
    fun `409 chamada_indisponivel vira o aviso do estado que o servidor diz`() = runBlocking {
        val casos = mapOf(
            "expirada" to TextosChamadaProfissional.CHAMADA_EXPIRADA,
            "cancelada" to TextosChamadaProfissional.CHAMADA_CANCELADA,
            "encerrada" to TextosChamadaProfissional.CHAMADA_ENCERRADA,
            "aceita" to TextosChamadaProfissional.CHAMADA_ENCERRADA,
        )
        for ((detalhes, mensagem) in casos) {
            val rede = rede()
            rede.recusa("/rpc/responder_chamada", HttpStatusCode.Conflict, Fixtures.erro("chamada_indisponivel", detalhes))
            val vm = viewModelCom(rede)
            vm.carregar().join()

            vm.aceitar().join()

            assertEquals(mensagem, vm.estado.value.mensagemDeConcorrencia, detalhes)
            assertNull(vm.estado.value.erro)
            assertFalse(vm.estado.value.respondendo)
            assertFalse(vm.estado.value.podeResponder)
        }
    }

    @Test
    fun `422 inelegivel diz porque nao da para aceitar e deixa tentar outra coisa`() = runBlocking {
        val casos = mapOf(
            "turno_sobreposto" to TextosChamadaProfissional.INELEGIVEL_TURNO_SOBREPOSTO,
            "funcao_incompativel" to TextosChamadaProfissional.INELEGIVEL_FUNCAO,
        )
        for ((detalhes, mensagem) in casos) {
            val rede = rede()
            rede.recusa("/rpc/responder_chamada", HttpStatusCode.UnprocessableEntity, Fixtures.erro("inelegivel", detalhes))
            val vm = viewModelCom(rede)
            vm.carregar().join()

            vm.aceitar().join()

            assertEquals(mensagem, vm.estado.value.erro, detalhes)
            assertFalse(vm.estado.value.respondendo)
        }
    }

    @Test
    fun `bloqueio, conta suspensa, recurso desligado e rede viram mensagem propria ao responder`() = runBlocking {
        val casos = listOf(
            Triple(HttpStatusCode.NotFound, Fixtures.erro("nao_encontrado"), TextosChamadaProfissional.INDISPONIVEL),
            Triple(HttpStatusCode.Forbidden, Fixtures.erro("conta_suspensa"), TextosChamadaProfissional.CONTA_SUSPENSA),
            Triple(HttpStatusCode.Forbidden, Fixtures.erro("sem_permissao", "recurso_desligado"), TextosChamadaProfissional.DESLIGADO),
            Triple(HttpStatusCode.BadGateway, "<html>502</html>", TextosChamadaProfissional.ERRO),
        )
        for ((status, corpo, esperado) in casos) {
            val rede = rede()
            rede.recusa("/rpc/responder_chamada", status, corpo)
            val vm = viewModelCom(rede)
            vm.carregar().join()

            vm.recusar().join()

            assertEquals(esperado, vm.estado.value.erro, corpo)
            assertFalse(vm.estado.value.respondendo)
            assertFalse(vm.estado.value.mostrarRecusa)
        }
        val semRede = rede()
        semRede.resposta("/rpc/responder_chamada") { throw ConnectTimeoutException("sem rede") }
        val vm = viewModelCom(semRede)
        vm.carregar().join()
        vm.aceitar().join()
        assertEquals(TextosChamadaProfissional.ERRO, vm.estado.value.erro)
        assertFalse(vm.estado.value.respondendo)
    }

    @Test
    fun `falha ao carregar nao deixa a tela carregando e tentar de novo recupera`() = runBlocking {
        val rede = RedeDeTeste()
        rede.recusa("/rpc/detalhe_chamada", HttpStatusCode.NotFound, Fixtures.erro("nao_encontrado"))
        val vm = viewModelCom(rede)

        vm.carregar().join()
        assertFalse(vm.estado.value.carregando)
        assertEquals(TextosChamadaProfissional.INDISPONIVEL, vm.estado.value.erro)
        assertNull(vm.estado.value.detalhe)

        rede.ok("/rpc/detalhe_chamada", Fixtures.detalheChamadaJson())
        vm.carregar().join()
        assertNull(vm.estado.value.erro)
        assertTrue(vm.estado.value.podeResponder)
    }

    @Test
    fun `recurso desligado ao carregar mostra o aviso de indisponivel`() = runBlocking {
        val rede = RedeDeTeste()
        rede.recusa("/rpc/detalhe_chamada", HttpStatusCode.Forbidden, Fixtures.erro("sem_permissao", "recurso_desligado"))
        val vm = viewModelCom(rede)
        vm.carregar().join()
        assertEquals(TextosChamadaProfissional.DESLIGADO, vm.estado.value.erro)
    }

    @Test
    fun `segundo toque em aceitar com a resposta em voo nao manda outra`() = runBlocking {
        val rede = rede()
        val liberar = CompletableDeferred<Unit>()
        rede.resposta("/rpc/responder_chamada") {
            liberar.await()
            respond(Fixtures.resultadoJson("aceita"), HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val vm = ChamadaRecebidaViewModel(Fixtures.CHAMADA, rede.servico::detalheChamada, rede.servico::responderChamada, { antesDoPrazo }, CoroutineScope(Dispatchers.Default))
        vm.carregar().join()

        val primeiro = vm.aceitar()
        assertTrue(vm.estado.value.respondendo)
        val segundo = vm.aceitar()
        liberar.complete(Unit)
        withTimeout(5_000) { primeiro.join(); segundo.join() }

        assertEquals(1, rede.doCaminho("/rpc/responder_chamada").size)
    }

    @Test
    fun `abrir a folha de recusa so vale com a chamada aberta`() = runBlocking {
        val vm = viewModelCom(rede(Fixtures.detalheChamadaJson(estado = "cancelada")))
        vm.carregar().join()
        vm.abrirRecusa()
        assertFalse(vm.estado.value.mostrarRecusa)
    }

    // ---- Chamada já aceita: reaberta, ou aceita sem a resposta ter chegado (cartão CeCqMUq9) ----

    private fun detalheAceito() = Fixtures.detalheChamadaJson(
        estado = "aceita", turnoId = Fixtures.TURNO, local = "SCS Quadra 2", responsavelLocal = "Ana",
    )

    /** `detalhe_chamada` devolve [primeira] na carga e [depois] nas conferências seguintes. */
    private fun redeComConferencia(primeira: String, depois: String?): RedeDeTeste {
        val rede = RedeDeTeste()
        var chamadas = 0
        rede.resposta("/rpc/detalhe_chamada") {
            if (++chamadas == 1 || depois == null) {
                if (chamadas == 1) respond(primeira, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
                else respond(Fixtures.erro("erro_interno"), HttpStatusCode.InternalServerError, headersOf(HttpHeaders.ContentType, "application/json"))
            } else {
                respond(depois, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            }
        }
        return rede
    }

    @Test
    fun `chamada aceita reaberta carrega como aceita, com o turno do detalhe e sem o aviso de encerrada`() = runBlocking {
        val vm = viewModelCom(rede(detalheAceito()))

        vm.carregar().join()

        val tela = vm.estado.value
        assertTrue(tela.chamadaAceita)
        assertEquals(Fixtures.TURNO, tela.turnoAceito)
        assertNull(tela.mensagemDeConcorrencia)
        assertFalse(tela.podeResponder)
    }

    @Test
    fun `chamada aceita reaberta sem turno no detalhe e aceita, sem turno para abrir`() = runBlocking {
        val vm = viewModelCom(rede(Fixtures.detalheChamadaJson(estado = "aceita")))

        vm.carregar().join()

        assertTrue(vm.estado.value.chamadaAceita)
        assertNull(vm.estado.value.turnoAceito)
        assertNull(vm.estado.value.mensagemDeConcorrencia)
    }

    @Test
    fun `erro de rede ao aceitar com o aceite gravado confere no servidor e mostra a chamada aceita`() = runBlocking {
        val rede = redeComConferencia(Fixtures.detalheChamadaJson(), detalheAceito())
        rede.resposta("/rpc/responder_chamada") { throw ConnectTimeoutException("sem rede") }
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.aceitar().join()

        val tela = vm.estado.value
        assertEquals(2, rede.doCaminho("/rpc/detalhe_chamada").size)
        assertTrue(tela.chamadaAceita)
        assertEquals(Fixtures.TURNO, tela.turnoAceito)
        assertNull(tela.erro)
        assertNull(tela.mensagemDeConcorrencia)
        assertFalse(tela.respondendo)
    }

    @Test
    fun `409 chamada_indisponivel confere no servidor antes do aviso e vale o estado dele`() = runBlocking {
        data class Caso(val detalhesDoErro: String, val doServidor: String, val aviso: String?, val aceita: Boolean)
        val casos = listOf(
            Caso("encerrada", detalheAceito(), null, true),
            Caso("encerrada", Fixtures.detalheChamadaJson(estado = "expirada"), TextosChamadaProfissional.CHAMADA_EXPIRADA, false),
            Caso("expirada", Fixtures.detalheChamadaJson(estado = "cancelada"), TextosChamadaProfissional.CHAMADA_CANCELADA, false),
            Caso("expirada", Fixtures.detalheChamadaJson(estado = "encerrada"), TextosChamadaProfissional.CHAMADA_ENCERRADA, false),
        )
        for (caso in casos) {
            val rede = redeComConferencia(Fixtures.detalheChamadaJson(), caso.doServidor)
            rede.recusa("/rpc/responder_chamada", HttpStatusCode.Conflict, Fixtures.erro("chamada_indisponivel", caso.detalhesDoErro))
            val vm = viewModelCom(rede)
            vm.carregar().join()

            vm.aceitar().join()

            val rotulo = "${caso.detalhesDoErro} -> ${caso.aviso}"
            assertEquals(caso.aviso, vm.estado.value.mensagemDeConcorrencia, rotulo)
            assertEquals(caso.aceita, vm.estado.value.chamadaAceita, rotulo)
            assertNull(vm.estado.value.erro, rotulo)
        }
    }

    @Test
    fun `409 sem conseguir conferir cai no aviso do que o servidor disse`() = runBlocking {
        val rede = redeComConferencia(Fixtures.detalheChamadaJson(), depois = null)
        rede.recusa("/rpc/responder_chamada", HttpStatusCode.Conflict, Fixtures.erro("chamada_indisponivel", "cancelada"))
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.aceitar().join()

        assertEquals(TextosChamadaProfissional.CHAMADA_CANCELADA, vm.estado.value.mensagemDeConcorrencia)
        assertFalse(vm.estado.value.chamadaAceita)
    }

    @Test
    fun `erro de rede que nao chegou ao servidor mostra o erro, deixa a chamada aberta e tentar de novo aceita`() = runBlocking {
        val rede = redeComConferencia(Fixtures.detalheChamadaJson(), Fixtures.detalheChamadaJson())
        var tentativa = 0
        rede.resposta("/rpc/responder_chamada") {
            if (++tentativa == 1) throw ConnectTimeoutException("sem rede")
            respond(Fixtures.resultadoJson("aceita"), HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.aceitar().join()

        assertEquals(TextosChamadaProfissional.ERRO, vm.estado.value.erro)
        assertTrue(vm.estado.value.podeResponder)
        assertFalse(vm.estado.value.chamadaAceita)

        vm.aceitar().join()

        assertTrue(vm.estado.value.chamadaAceita)
        assertNull(vm.estado.value.erro)
    }

    @Test
    fun `depois de um erro sem conseguir conferir o relogio local nao declara a chamada expirada`() = runBlocking {
        var agora = antesDoPrazo
        val rede = redeComConferencia(Fixtures.detalheChamadaJson(), depois = null)
        var tentativa = 0
        rede.resposta("/rpc/responder_chamada") {
            if (++tentativa == 1) throw ConnectTimeoutException("sem rede")
            respond(Fixtures.resultadoJson("aceita"), HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val vm = ChamadaRecebidaViewModel(Fixtures.CHAMADA, rede.servico::detalheChamada, rede.servico::responderChamada, { agora }, CoroutineScope(Dispatchers.Unconfined))
        vm.carregar().join()
        vm.aceitar().join() // a resposta se perdeu e a conferência também falhou: o aceite pode ter gravado
        assertEquals(TextosChamadaProfissional.ERRO, vm.estado.value.erro)

        agora = depoisDoPrazo // o prazo passou enquanto isso: quem decide é o servidor, não o relógio do aparelho
        vm.aceitar().join()

        assertEquals(2, rede.doCaminho("/rpc/responder_chamada").size)
        assertTrue(vm.estado.value.chamadaAceita)
        assertNull(vm.estado.value.mensagemDeConcorrencia)
    }
}
