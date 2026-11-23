package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import java.io.File
import java.io.IOException
import java.time.Instant
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class RegistradorDeTelemetriaTest {
    @TempDir lateinit var pasta: File
    private val instante = Instant.parse("2026-11-23T12:00:00Z")
    private val evento = EventoDeTelemetria.APP_ABERTO
    private fun erro(codigo: CodigoErroAPI) = ErroDaApi(codigo, codigo.name.lowercase(), null, "sintetico")

    @Test
    fun `offline persiste e reabre com a hora original em ordem`() = runTest {
        val arquivo = File(pasta, "eventos.json")
        val fila = FilaDeTelemetria(arquivo)
        val offline = RegistradorDeTelemetria({ throw IOException() }, fila, { "conta-a" }, { "conta-a" }, backgroundScope) { instante }
        assertFalse(offline.registrar(evento))
        assertFalse(offline.registrar(EventoDeTelemetria.VAGA_VISTA, vagaId = "vaga-sintetica"))
        val enviados = mutableListOf<RegistroDeEventoDto>()
        val reaberta = FilaDeTelemetria(arquivo)
        val online = RegistradorDeTelemetria({ enviados += it; true }, reaberta, { "conta-a" }, { "conta-a" }, backgroundScope) { instante.plusSeconds(600) }
        online.reenviar()
        assertEquals(listOf(evento, EventoDeTelemetria.VAGA_VISTA), enviados.map { it.evento })
        assertTrue(enviados.all { it.ocorridoEm == instante.toString() })
        assertTrue(FilaDeTelemetria(arquivo).eventosPendentes().isEmpty())
    }

    @Test
    fun `limite de 200 descarta os mais antigos`() = runTest {
        val fila = FilaDeTelemetria(File(pasta, "eventos.json"))
        val registrador = RegistradorDeTelemetria({ throw IOException() }, fila, { "a" }, { "a" }, backgroundScope) { instante }
        repeat(205) { registrador.registrar(evento, vagaId = "$it") }
        assertEquals(200, fila.eventosPendentes().size)
        assertEquals("5", fila.eventosPendentes().first().registro.vagaId)
        assertEquals("204", fila.eventosPendentes().last().registro.vagaId)
    }

    @Test
    fun `idade maior que 30 dias descarta e a fronteira de 30 dias ainda envia`() = runTest {
        val fila = FilaDeTelemetria(null)
        val offline = RegistradorDeTelemetria({ throw IOException() }, fila, { "a" }, { "a" }, backgroundScope) { instante }
        offline.registrar(evento, ocorridoEm = instante.minusSeconds(30 * 86400L + 1))
        offline.registrar(EventoDeTelemetria.VAGA_VISTA, ocorridoEm = instante.minusSeconds(30 * 86400L))
        val enviados = mutableListOf<RegistroDeEventoDto>()
        RegistradorDeTelemetria({ enviados += it; true }, fila, { "a" }, { "a" }, backgroundScope) { instante }.reenviar()
        assertEquals(listOf(EventoDeTelemetria.VAGA_VISTA), enviados.map { it.evento })
        assertTrue(fila.eventosPendentes().isEmpty())
    }

    @Test
    fun `outra conta nunca envia o evento da anterior`() = runTest {
        val fila = FilaDeTelemetria(null)
        var conta: String? = "a"
        RegistradorDeTelemetria({ throw IOException() }, fila, { conta }, { "a" }, backgroundScope) { instante }.registrar(evento)
        conta = "b"
        var envios = 0
        RegistradorDeTelemetria({ envios++; true }, fila, { conta }, { "b" }, backgroundScope) { instante }.reenviar()
        assertEquals(0, envios)
        assertTrue(fila.eventosPendentes().isEmpty())
    }

    @Test
    fun `sem conta local nao envia nem guarda e sem confirmacao remota espera`() = runTest {
        val fila = FilaDeTelemetria(null)
        var envios = 0
        RegistradorDeTelemetria({ envios++; true }, fila, { null }, { "a" }, backgroundScope).registrar(evento)
        assertEquals(0, envios)
        RegistradorDeTelemetria({ throw IOException() }, fila, { "a" }, { "a" }, backgroundScope) { instante }.registrar(evento)
        RegistradorDeTelemetria({ envios++; true }, fila, { "a" }, { throw IOException() }, backgroundScope) { instante }.reenviar()
        assertEquals(0, envios)
        assertEquals(1, fila.eventosPendentes().size)
    }

    @Test
    fun `422 sai da fila e erro de rede mantem este e os seguintes`() = runTest {
        val fila = FilaDeTelemetria(null)
        val offline = RegistradorDeTelemetria({ throw IOException() }, fila, { "a" }, { "a" }, backgroundScope) { instante }
        repeat(3) { offline.registrar(evento, vagaId = "$it") }
        val reenviador = RegistradorDeTelemetria({
            if (it.vagaId == "0") throw erro(CodigoErroAPI.CAMPO_INVALIDO)
            throw IOException()
        }, fila, { "a" }, { "a" }, backgroundScope) { instante }
        reenviador.reenviar()
        assertEquals(listOf("1", "2"), fila.eventosPendentes().map { it.registro.vagaId })
    }

    @Test
    fun `recusa definitiva nao guarda e falhas temporarias guardam`() = runTest {
        for (codigo in listOf(CodigoErroAPI.CAMPO_INVALIDO, CodigoErroAPI.NAO_AUTENTICADO, CodigoErroAPI.SEM_PERMISSAO,
            CodigoErroAPI.CONTA_SUSPENSA, CodigoErroAPI.LIMITE_EXCEDIDO, CodigoErroAPI.DESCONHECIDO)) {
            val fila = FilaDeTelemetria(null)
            assertFalse(RegistradorDeTelemetria({ throw erro(codigo) }, fila, { "a" }, { "a" }, backgroundScope) { instante }.registrar(evento))
            assertEquals(if (codigo == CodigoErroAPI.CAMPO_INVALIDO) 0 else 1, fila.eventosPendentes().size)
        }
        assertFalse(RegistradorDeTelemetria.deveGuardar(ErroDaApi(CodigoErroAPI.DESCONHECIDO, "http_400", null, "")))
    }

    @Test
    fun `relogio adiantado limita data no primeiro envio e no reenvio`() = runTest {
        val fila = FilaDeTelemetria(null)
        val enviados = mutableListOf<RegistroDeEventoDto>()
        RegistradorDeTelemetria({ enviados += it; throw IOException() }, fila, { "a" }, { "a" }, backgroundScope) { instante }
            .registrar(evento, ocorridoEm = instante.plusSeconds(600))
        assertEquals(instante.toString(), enviados.single().ocorridoEm)
        val voltou = instante.minusSeconds(600)
        RegistradorDeTelemetria({ enviados += it; true }, fila, { "a" }, { "a" }, backgroundScope) { voltou }.reenviar()
        assertEquals(voltou.toString(), enviados.last().ocorridoEm)
    }

    @Test
    fun `dois reenviadores compartilham reserva e liberam ao terminar`() = runTest {
        val fila = FilaDeTelemetria(null)
        RegistradorDeTelemetria({ throw IOException() }, fila, { "a" }, { "a" }, backgroundScope) { instante }.registrar(evento)
        val liberar = CompletableDeferred<Unit>()
        var envios = 0
        val primeiro = RegistradorDeTelemetria({ envios++; liberar.await(); true }, fila, { "a" }, { "a" }, backgroundScope) { instante }
        val segundo = RegistradorDeTelemetria({ envios++; true }, fila, { "a" }, { "a" }, backgroundScope) { instante }
        val tarefa = launch { primeiro.reenviar() }
        runCurrent()
        segundo.reenviar()
        assertEquals(1, envios)
        liberar.complete(Unit)
        tarefa.join()
        assertFalse(fila.reenvio.isLocked)
    }

    @Test
    fun `logout limpa disco e recusa gravacao de envio antigo em voo`() = runTest {
        val arquivo = File(pasta, "eventos.json")
        val fila = FilaDeTelemetria(arquivo)
        val liberar = CompletableDeferred<Unit>()
        val registrador = RegistradorDeTelemetria({ liberar.await(); throw IOException() }, fila, { "a" }, { "a" }, backgroundScope) { instante }
        val envio = launch { registrador.registrar(evento) }
        runCurrent()
        fila.limpar()
        liberar.complete(Unit)
        envio.join()
        assertTrue(fila.eventosPendentes().isEmpty())
        assertFalse(arquivo.exists())
    }

    @Test
    fun `falha de disco nunca propaga para o fluxo`() = runTest {
        val arquivo = File(pasta, "nao-e-pasta").apply { writeText("sintetico") }
        val fila = FilaDeTelemetria(File(arquivo, "eventos.json"))
        assertFalse(RegistradorDeTelemetria({ throw IOException() }, fila, { "a" }, { "a" }, backgroundScope) { instante }.registrar(evento))
    }
}
