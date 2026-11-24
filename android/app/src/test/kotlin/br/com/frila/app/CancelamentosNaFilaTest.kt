package br.com.frila.app

import br.com.frila.core.dominio.modelo.MotivoCancelamento
import br.com.frila.core.rede.*
import br.com.frila.feature.turnos.*
import br.com.frila.feature.turnos.contratante.*
import br.com.frila.feature.vagas.painel.*
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.headersOf
import java.io.File
import java.io.IOException
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import kotlinx.coroutines.*
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

/** Os dois pontos de entrada usam a fila e o sincronizador reais, com HTTP sintético. */
class CancelamentosNaFilaTest {
    @TempDir lateinit var raiz: File
    private val toque = Instant.ofEpochSecond(1795435200)
    private val turno = ItemTurno("turno", "posicao", toque, funcaoNome = "Função sintética",
        estabelecimentoNome = "Casa sintética", dataHorarioFormatado = "", valorFormatado = "", estado = "confirmada")
    private class Tela(val confirmar: () -> Job?, val motivo: (String) -> Unit,
        val naFila: () -> Boolean, val erro: () -> String?, val concluida: () -> Boolean)
    private inner class Caso(val casa: Boolean) : AutoCloseable {
        val tipo = if (casa) TipoAcaoPendente.CANCELAMENTO_VAGA else TipoAcaoPendente.CANCELAMENTO_POSICAO
        var conta: String? = "conta-sintetica"
        var offline = true
        var recusar = false
        var pedidos = 0
        val eventos = mutableListOf<Triple<EventoDeTelemetria, String?, String?>>()
        val fila = FilaDeAcoes(File(raiz, "$tipo.json"))
        val escopo = CoroutineScope(Dispatchers.Unconfined + SupervisorJob())
        val cliente = ClienteSupabase("https://sintetico.supabase.invalid", "chave-sintetica", engine = MockEngine {
            pedidos++
            if (offline) throw IOException("sem rede sintética")
            if (recusar) return@MockEngine respond("""{"code":"sem_permissao","message":"detalhe privado sintético"}""",
                io.ktor.http.HttpStatusCode.Forbidden, headersOf(HttpHeaders.ContentType, "application/json"))
            respond(if (casa) """{"vaga_id":"vaga","estado":"cancelada","posicoes_canceladas":1}"""
                else """{"posicao_id":"posicao","falta":false,"reaberta":true}""",
                headers = headersOf(HttpHeaders.ContentType, "application/json"))
        })
        val turnos = ServicoTurnos(cliente)
        val vagas = ServicoVagas(cliente)
        fun tela(comFila: Boolean = true): Tela {
            val registrar: (EventoDeTelemetria, String?, String?) -> Unit = { e, v, t -> eventos += Triple(e, v, t) }
            if (casa) {
                val vm = CancelarVagaViewModel("vaga", toque, vagas::cancelarVaga, relogio = { toque }, escopo = escopo,
                    filaDeAcoes = if (comFila) fila else null, contaAtual = { conta }, registrarEvento = registrar)
                return Tela(vm::confirmar, { vm.escolherMotivo(MotivoDeCancelamentoDaVaga.OUTRO); vm.mudarDetalhes(it) },
                    { vm.estado.value.naFila }, { vm.estado.value.erro }, { vm.estado.value.concluida })
            }
            val vm = MeusTurnosViewModel(turnos, Clock.fixed(toque, ZoneOffset.UTC), escopo,
                filaDeAcoes = if (comFila) fila else null, contaAtual = { conta }, registrarEvento = registrar)
            vm.abrirCancelamento(turno)
            return Tela(vm::confirmarCancelamento, { vm.selecionarMotivo(MotivoCancelamento.OUTRO); vm.atualizarDetalhes(it) },
                { vm.estado.value.cancelamento?.naFila == true }, { vm.estado.value.cancelamento?.mensagemErro },
                { vm.estado.value.mensagemFeedback == "Cancelamento enviado." })
        }
        suspend fun sincronizar() = SincronizadorDeAcoes(fila, { conta ?: "outra-conta" }, mapOf(tipo to { a ->
            if (casa) vagas.cancelarVaga(a.alvoId!!, a.motivo!!) else turnos.cancelarPosicao(a.alvoId!!, a.motivo!!)
            Unit
        })).sincronizar()
        override fun close() { escopo.cancel(); cliente.close() }
    }

    @Test fun `casa cancela posicao com fila persistente deduplicacao telemetria recusa e reenvio`() = runBlocking {
        for (recusar in listOf(false, true)) Caso(false).use { c ->
            var leituras = 0
            fun tela() = AcompanhamentoContratanteViewModel(
                ContextoDoTurnoContratante("turno", "Função", "Casa", toque, toque.plusSeconds(3600),
                    null, null, null, null, null, false, "posicao", "confirmada"),
                { error("não confirma") }, c.escopo, cancelar = c.turnos::cancelarPosicao, relogio = { toque },
                filaDeAcoes = c.fila, contaAtual = { c.conta },
                registrarEvento = { e, v, t -> c.eventos += Triple(e, v, t) }, reler = { leituras++; null })
            val vm = tela(); vm.pedirCancelamento(); vm.confirmarCancelamento("  Imprevisto sintético  ")!!.join()
            val acao = c.fila.pendentes().single()
            assertEquals("posicao", acao.alvoId); assertEquals("Imprevisto sintético", acao.motivo)
            assertEquals(toque.toString(), acao.instanteDoToque); assertEquals(c.conta, acao.contaId)
            assertEquals(listOf(acao), FilaDeAcoes(File(raiz, "${c.tipo}.json")).pendentes())
            val antes = c.pedidos
            vm.pedirCancelamento(); assertNull(vm.confirmarCancelamento("Outro motivo"))
            val reaberta = tela(); assertTrue(reaberta.estado.value.cancelamentoNaFila)
            reaberta.pedirCancelamento(); assertNull(reaberta.confirmarCancelamento("Imprevisto"))
            assertEquals(antes, c.pedidos)
            assertEquals(listOf(Triple(EventoDeTelemetria.ACAO_ENFILEIRADA_OFFLINE, null, "turno")), c.eventos)
            c.offline = false; c.recusar = recusar; c.sincronizar(); c.sincronizar()
            assertEquals(antes + 1, c.pedidos); assertTrue(c.fila.pendentes().isEmpty())
            assertFalse(vm.estado.value.cancelamentoNaFila)
            if (recusar) {
                assertTrue(vm.estado.value.cancelamentoRecusado); assertTrue(tela().estado.value.cancelamentoRecusado)
                assertTrue(vm.estado.value.avisoDoCancelamento!!.contains("não foi aceito")); assertEquals(0, leituras)
            } else {
                assertEquals("cancelada", vm.estado.value.contexto.estadoDaPosicao); assertEquals(2, leituras)
            }
            assertFalse(vm.estado.value.podeCancelar)
        }
    }

    @Test fun `sem rede persiste motivo e toque sem duplicar por toque ou reabertura`() = runBlocking {
        for (casa in listOf(false, true)) Caso(casa).use { c ->
            val tela = c.tela()
            tela.motivo(" ab "); assertNull(tela.confirmar()); assertEquals(0, c.pedidos)
            tela.motivo("  Imprevisto sintético  "); tela.confirmar()!!.join()
            val acao = c.fila.pendentes().single()
            assertEquals("Imprevisto sintético", acao.motivo)
            assertEquals(if (casa) "vaga" else "posicao", acao.alvoId)
            assertEquals(c.conta, acao.contaId); assertEquals(c.tipo, acao.tipo)
            assertEquals(toque.toString(), acao.instanteDoToque)
            assertEquals(listOf(acao), FilaDeAcoes(File(raiz, "${c.tipo}.json")).pendentes())
            val antes = c.pedidos
            tela.motivo("Outro detalhe")
            assertTrue(tela.erro()!!.contains("quando a conexão voltar"))
            assertNull(tela.confirmar())
            val reaberta = c.tela()
            assertTrue(reaberta.naFila()); assertTrue(reaberta.erro()!!.contains("quando a conexão voltar"))
            assertNull(reaberta.confirmar()); assertEquals(antes, c.pedidos)
            assertEquals(listOf(Triple(EventoDeTelemetria.ACAO_ENFILEIRADA_OFFLINE,
                if (casa) "vaga" else null, if (casa) null else "turno")), c.eventos)
        }
    }

    @Test fun `rede volta envia uma vez e recusa definitiva vira aviso minimo ao reabrir`() = runBlocking {
        for (casa in listOf(false, true)) Caso(casa).use { c ->
            val tela = c.tela(); tela.motivo("Imprevisto"); tela.confirmar()!!.join()
            val antes = c.pedidos
            c.offline = false; c.recusar = true; c.sincronizar()
            assertTrue(c.fila.pendentes().isEmpty()); assertEquals(1, c.fila.recusadas().size)
            assertEquals("O cancelamento não foi aceito. Atualize a tela e tente de novo.", tela.erro())
            assertEquals(tela.erro(), c.tela().erro())
            assertFalse(tela.naFila()); assertFalse(tela.concluida())
            tela.motivo("Novo imprevisto"); c.offline = true; tela.confirmar()!!.join()
            assertTrue(c.fila.recusadas().isEmpty())
            c.offline = false; c.recusar = false
            val antesDoReenvio = c.pedidos
            c.sincronizar(); c.sincronizar()
            assertEquals(antesDoReenvio + 1, c.pedidos); assertTrue(c.pedidos > antes)
            assertTrue(c.fila.pendentes().isEmpty()); assertTrue(tela.concluida())
        }
    }

    @Test fun `outra conta descarta sem enviar e logout nao mostra sucesso`() = runBlocking {
        for (casa in listOf(false, true)) Caso(casa).use { c ->
            val tela = c.tela(); tela.motivo("Imprevisto"); tela.confirmar()!!.join()
            c.conta = "outra-conta"; val antes = c.pedidos; c.sincronizar()
            assertEquals(antes, c.pedidos); assertTrue(c.fila.pendentes().isEmpty())
            assertFalse(tela.naFila()); assertFalse(tela.concluida())
            val nova = c.tela(); nova.motivo("Imprevisto"); nova.confirmar()!!.join()
            c.conta = null; c.fila.limpar()
            assertTrue(c.fila.pendentes().isEmpty()); assertFalse(nova.naFila()); assertFalse(nova.concluida())
        }
    }

    @Test fun `sem conta ou fila e recusa direta nao enfileiram`() = runBlocking {
        for (casa in listOf(false, true)) Caso(casa).use { c ->
            for ((comFila, conta) in listOf(false to "conta-sintetica", true to null)) {
                c.conta = conta
                val tela = c.tela(comFila); tela.motivo("Imprevisto"); tela.confirmar()!!.join()
                assertNotNull(tela.erro()); assertFalse(tela.naFila())
            }
            c.conta = "conta-sintetica"; c.offline = false; c.recusar = true
            val tela = c.tela(); tela.motivo("Imprevisto"); tela.confirmar()!!.join()
            assertNotNull(tela.erro()); assertTrue(c.fila.pendentes().isEmpty()); assertTrue(c.eventos.isEmpty())
        }
    }
}
