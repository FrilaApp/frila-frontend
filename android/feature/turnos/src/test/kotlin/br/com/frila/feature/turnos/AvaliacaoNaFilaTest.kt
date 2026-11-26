package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.*
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.headersOf
import java.io.File
import java.io.IOException
import java.time.Instant
import java.util.concurrent.CopyOnWriteArrayList
import kotlinx.coroutines.*
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

class AvaliacaoNaFilaTest {
    @TempDir lateinit var diretorio: File
    private val turno = "turno-sintetico"
    private var conta: String? = "conta-sintetica"
    private val toque = Instant.ofEpochSecond(1795132800)
    private val fila by lazy { FilaDeAcoes(File(diretorio, "fila.json")) }
    private val escopo = CoroutineScope(Dispatchers.Unconfined + SupervisorJob())
    private val eventos = CopyOnWriteArrayList<EventoDeTelemetria>()
    private var offline = true
    private var recusaDireta = false
    private var pedidos = 0
    private val cliente = ClienteSupabase("https://sintetico.supabase.invalid", "chave-sintetica", engine = MockEngine {
        pedidos++
        if (offline) throw IOException("sem rede sintética")
        if (recusaDireta) return@MockEngine respond(
            """{"code":"avaliacao_indisponivel","message":"sintético"}""", io.ktor.http.HttpStatusCode.UnprocessableEntity,
            headersOf(HttpHeaders.ContentType, "application/json"),
        )
        respond("""{"turno_id":"$turno","resposta":true,"criada_em":"2026-11-20T00:00:00Z"}""",
            headers = headersOf(HttpHeaders.ContentType, "application/json"))
    })
    private val servico = ServicoTurnos(cliente)
    private fun vm(comFila: Boolean = true) = AvaliacaoViewModel(servico, escopo,
        registrarEvento = { evento, _, _ -> eventos += evento },
        filaDeAcoes = if (comFila) fila else null, contaAtual = { conta }, instanteAtual = { toque },
    ).also { it.observar(turno) }
    private fun sincronizador(envio: suspend (AcaoPendente) -> Unit = {
        servico.avaliarTurno(it.turnoId!!, it.resposta!!)
    }) = SincronizadorDeAcoes(fila, { conta ?: "outra-conta" }, mapOf(TipoAcaoPendente.AVALIACAO to envio))
    @AfterEach fun fechar() { escopo.cancel(); cliente.close() }

    /**
     * O coletor de `fila.versao` do `AvaliacaoViewModel` pode terminar numa thread do `Dispatchers.Default`
     * (depois do HTTP simulado): espera a reconciliação refletir no estado antes de conferir.
     */
    private suspend fun aguardar(condicao: () -> Boolean) {
        repeat(100) {
            if (condicao()) return
            delay(50)
        }
        assertTrue(condicao(), "a condição não chegou a tempo")
    }

    @Test fun `sem rede guarda resposta e instante do toque sem duplicar nem ao reabrir`() = runBlocking {
        val vm = vm()
        vm.avaliar(turno, false).join()
        val acao = fila.pendentes().single()
        val antes = pedidos
        vm.avaliar(turno, true).join()
        val reaberta = vm()
        reaberta.avaliar(turno, true).join()
        assertEquals(StatusAvaliacao.NA_FILA, reaberta.estado.value.status)
        assertEquals(false, reaberta.estado.value.respostaRegistrada)
        assertEquals(TipoAcaoPendente.AVALIACAO, acao.tipo)
        assertEquals(conta, acao.contaId)
        assertEquals(turno, acao.turnoId)
        assertEquals(false, acao.resposta)
        assertEquals(toque.toString(), acao.instanteDoToque)
        assertEquals(listOf(acao), FilaDeAcoes(File(diretorio, "fila.json")).pendentes())
        assertEquals(antes, pedidos)
        assertEquals(listOf(EventoDeTelemetria.ACAO_ENFILEIRADA_OFFLINE), eventos)
    }

    @Test fun `rede volta envia uma vez e tela aberta passa a enviada`() = runBlocking {
        val vm = vm()
        vm.avaliar(turno, true).join()
        offline = false
        val antes = pedidos
        val sinc = sincronizador()
        sinc.sincronizar(); sinc.sincronizar()
        assertEquals(antes + 1, pedidos)
        assertTrue(fila.pendentes().isEmpty())
        aguardar { vm.estado.value.status == StatusAvaliacao.SUCESSO && eventos.count { it == EventoDeTelemetria.AVALIACAO_ENVIADA } == 1 }
        assertEquals(StatusAvaliacao.SUCESSO, vm.estado.value.status)
        assertEquals(true, vm.estado.value.respostaRegistrada)
        assertEquals(1, eventos.count { it == EventoDeTelemetria.AVALIACAO_ENVIADA })
    }

    @Test fun `recusa definitiva vira aviso minimo inclusive ao reabrir e novo toque o reconhece`() = runBlocking {
        val vm = vm()
        vm.avaliar(turno, true).join()
        sincronizador { throw ErroDaApi(CodigoErroAPI.AVALIACAO_INDISPONIVEL, "avaliacao_indisponivel", null, "sintético privado") }.sincronizar()
        assertTrue(fila.pendentes().isEmpty())
        aguardar { vm.estado.value.status == StatusAvaliacao.ERRO && vm.estado.value.mensagemErro == TextosDaFilaDeAvaliacao.RECUSADA }
        assertEquals(StatusAvaliacao.ERRO, vm.estado.value.status)
        assertEquals(TextosDaFilaDeAvaliacao.RECUSADA, vm.estado.value.mensagemErro)
        assertEquals(TextosDaFilaDeAvaliacao.RECUSADA, vm().estado.value.mensagemErro)
        vm.avaliar(turno, false).join()
        assertTrue(fila.recusadas().isEmpty())
        assertEquals(StatusAvaliacao.NA_FILA, vm.estado.value.status)
    }

    @Test fun `avaliacao ja registrada sai da fila sem aviso`() = runBlocking {
        val vm = vm()
        vm.avaliar(turno, true).join()
        sincronizador { throw ErroDaApi(CodigoErroAPI.AVALIACAO_JA_REGISTRADA, "avaliacao_ja_registrada", null, "sintético") }.sincronizar()
        assertTrue(fila.pendentes().isEmpty())
        assertTrue(fila.recusadas().isEmpty())
        aguardar { vm.estado.value.status == StatusAvaliacao.SUCESSO }
        assertEquals(StatusAvaliacao.SUCESSO, vm.estado.value.status)
        assertNull(vm.estado.value.mensagemErro)
    }

    @Test fun `outra conta descarta sem enviar e logout limpa sem mostrar sucesso`() = runBlocking {
        val vm = vm()
        vm.avaliar(turno, true).join()
        conta = "outra-conta"
        var envios = 0
        sincronizador { envios++ }.sincronizar()
        assertEquals(0, envios)
        assertTrue(fila.pendentes().isEmpty())
        aguardar { vm.estado.value.status == StatusAvaliacao.OCIOSO }
        assertEquals(StatusAvaliacao.OCIOSO, vm.estado.value.status)
        vm.avaliar(turno, false).join()
        conta = null
        fila.limpar()
        assertTrue(fila.pendentes().isEmpty())
        aguardar { vm.estado.value.status == StatusAvaliacao.OCIOSO }
        assertEquals(StatusAvaliacao.OCIOSO, vm.estado.value.status)
    }

    @Test fun `sem conta ou fila continua com erro de rede e nao guarda`() = runBlocking {
        conta = null
        val semConta = vm()
        semConta.avaliar(turno, true).join()
        val semFila = vm(comFila = false)
        semFila.avaliar(turno, false).join()
        assertEquals(StatusAvaliacao.ERRO, semConta.estado.value.status)
        assertEquals(StatusAvaliacao.ERRO, semFila.estado.value.status)
        assertTrue(fila.pendentes().isEmpty())
    }

    @Test fun `pendencia e recusa de outro turno ou conta nao aparecem`() {
        val outra = AcaoPendente(TipoAcaoPendente.AVALIACAO, "outra-conta", toque.toString(), turnoId = turno, resposta = true)
        fila.enfileirar(outra)
        fila.recusar(outra, CodigoErroAPI.SEM_PERMISSAO)
        fila.enfileirar(outra.copy(id = "outra", contaId = conta!!, turnoId = "outro-turno"))
        assertEquals(StatusAvaliacao.OCIOSO, vm().estado.value.status)
    }
    @Test fun `erro definitivo no envio direto nao entra na fila`() = runBlocking {
        offline = false
        recusaDireta = true
        val vm = vm()
        vm.avaliar(turno, false).join()
        assertEquals(StatusAvaliacao.ERRO, vm.estado.value.status)
        assertTrue(fila.pendentes().isEmpty())
        assertTrue(eventos.isEmpty())
    }

}
