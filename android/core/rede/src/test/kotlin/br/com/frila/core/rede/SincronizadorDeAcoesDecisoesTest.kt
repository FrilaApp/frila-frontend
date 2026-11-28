package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import java.io.File
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

/**
 * Cartão mKKpMgVv (item 223): duas decisões da fila offline que o teste existente só cobria pela metade (iOS `SincronizadorAcoes.swift`).
 * (1) O check-out recusado por `checkin_pendente` ESPERA enquanto há um check-in pendente do MESMO turno; sem ele, é recusa
 * definitiva (senão ficaria na fila para sempre). (2) Publicação e republicação com 429 ou erro desconhecido continuam na fila.
 */
class SincronizadorDeAcoesDecisoesTest {
    @TempDir lateinit var diretorio: File
    private val fila by lazy { FilaDeAcoes(File(diretorio, "fila.json")) }
    private val enviadas = mutableListOf<AcaoPendente>()
    private var falha: ((AcaoPendente) -> Throwable?) = { null }

    private fun erro(codigo: CodigoErroAPI) = ErroDaApi(codigo, codigo.name, null, "Erro sintético")
    private fun acao(tipo: TipoAcaoPendente, turno: String = "turno-1") =
        AcaoPendente(tipo, "conta-a", "2026-11-23T12:00:00Z", turnoId = turno, alvoId = "alvo", motivo = "motivo")
    private val envio: EnvioDeAcao = { a -> enviadas += a; falha(a)?.let { throw it } }
    private fun sincronizador() = SincronizadorDeAcoes(fila, { "conta-a" }, TipoAcaoPendente.entries.associateWith { envio })

    // ---- check-out recusado por checkin_pendente ----

    @Test fun `checkout recusado por checkin pendente sem checkin na fila vira recusa e sai da fila`() = runTest {
        val checkout = acao(TipoAcaoPendente.CHECKOUT)
        fila.enfileirar(checkout)
        falha = { erro(CodigoErroAPI.CHECKIN_PENDENTE) }

        sincronizador().sincronizar()

        assertTrue(fila.pendentes().isEmpty(), "sem check-in na fila, o check-out não pode ficar esperando para sempre")
        assertEquals(listOf(TipoAcaoPendente.CHECKOUT to CodigoErroAPI.CHECKIN_PENDENTE), fila.recusadas().map { it.tipo to it.codigo })
        sincronizador().sincronizar()
        assertEquals(listOf(checkout), enviadas, "a recusa não volta aos reenvios")
    }

    @Test fun `checkin pendente de OUTRO turno nao segura o checkout deste, que vira recusa`() = runTest {
        val checkinDeOutro = acao(TipoAcaoPendente.CHECKIN, turno = "turno-2")
        val checkout = acao(TipoAcaoPendente.CHECKOUT, turno = "turno-1")
        fila.enfileirar(checkinDeOutro); fila.enfileirar(checkout)
        falha = { if (it.tipo == TipoAcaoPendente.CHECKIN) erro(CodigoErroAPI.DESCONHECIDO) else erro(CodigoErroAPI.CHECKIN_PENDENTE) }

        sincronizador().sincronizar()

        assertEquals(listOf(checkinDeOutro), fila.pendentes(), "o check-in do outro turno segue na fila; o check-out deste saiu")
        assertEquals(listOf("turno-1" to CodigoErroAPI.CHECKIN_PENDENTE), fila.recusadas().map { it.turnoId to it.codigo })
    }

    @Test fun `com dois turnos, so o checkout do turno que ainda tem checkin na fila espera`() = runTest {
        val checkinA = acao(TipoAcaoPendente.CHECKIN, turno = "turno-a")
        val checkoutA = acao(TipoAcaoPendente.CHECKOUT, turno = "turno-a")
        val checkoutB = acao(TipoAcaoPendente.CHECKOUT, turno = "turno-b")
        fila.enfileirar(checkinA); fila.enfileirar(checkoutA); fila.enfileirar(checkoutB)
        falha = { if (it.tipo == TipoAcaoPendente.CHECKIN) erro(CodigoErroAPI.DESCONHECIDO) else erro(CodigoErroAPI.CHECKIN_PENDENTE) }

        sincronizador().sincronizar()

        assertEquals(listOf(checkinA, checkoutA), fila.pendentes(), "o do turno-a espera pelo check-in do turno-a")
        assertEquals(listOf("turno-b"), fila.recusadas().map { it.turnoId }, "o do turno-b não tem check-in na fila: recusa")
    }

    @Test fun `o checkin que e enviado com sucesso na mesma passada libera a recusa do checkout`() = runTest {
        // O check-in do mesmo turno sai da fila ao ser aceito; o check-out, na sequência, recebe checkin_pendente e não tem mais com quem esperar.
        val checkin = acao(TipoAcaoPendente.CHECKIN)
        val checkout = acao(TipoAcaoPendente.CHECKOUT)
        fila.enfileirar(checkin); fila.enfileirar(checkout)
        falha = { if (it.tipo == TipoAcaoPendente.CHECKOUT) erro(CodigoErroAPI.CHECKIN_PENDENTE) else null }

        sincronizador().sincronizar()

        assertTrue(fila.pendentes().isEmpty())
        assertEquals(listOf(TipoAcaoPendente.CHECKOUT to CodigoErroAPI.CHECKIN_PENDENTE), fila.recusadas().map { it.tipo to it.codigo })
    }

    // ---- publicação e republicação: 429 e erro desconhecido continuam na fila ----

    @Test fun `publicacao e republicacao com 429, erro desconhecido ou resposta invalida continuam na fila, sem recusa, e a passada segue`() = runTest {
        val transitorios = listOf(CodigoErroAPI.LIMITE_EXCEDIDO, CodigoErroAPI.DESCONHECIDO, CodigoErroAPI.RESPOSTA_INVALIDA)
        for (tipo in listOf(TipoAcaoPendente.PUBLICACAO_VAGA, TipoAcaoPendente.REPUBLICACAO_VAGA)) {
            for (codigo in transitorios) {
                val a = acao(tipo); val seguinte = acao(TipoAcaoPendente.CANCELAMENTO_VAGA)
                fila.limpar(); enviadas.clear()
                fila.enfileirar(a); fila.enfileirar(seguinte)
                falha = { if (it.id == a.id) erro(codigo) else null }

                sincronizador().sincronizar()

                assertEquals(listOf(a), fila.pendentes(), "$tipo com $codigo fica na fila (a seguinte foi aceita)")
                assertTrue(fila.recusadas(true).isEmpty(), "$tipo com $codigo não é recusa")
                assertEquals(listOf(a, seguinte), enviadas, "$tipo com $codigo: a passada segue para a próxima")
            }
        }
    }

    @Test fun `publicacao com recusa definitiva sai da fila, para contrastar com os transitorios`() = runTest {
        val a = acao(TipoAcaoPendente.PUBLICACAO_VAGA)
        fila.enfileirar(a)
        falha = { erro(CodigoErroAPI.HORARIO_INVALIDO) }

        sincronizador().sincronizar()

        assertTrue(fila.pendentes().isEmpty())
        assertEquals(listOf(CodigoErroAPI.HORARIO_INVALIDO), fila.recusadas().map { it.codigo })
    }
}
