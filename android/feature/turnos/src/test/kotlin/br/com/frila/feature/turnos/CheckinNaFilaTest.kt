package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.LeituraDeLocalizacao
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.AcaoPendente
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.EventoDeTelemetria
import br.com.frila.core.rede.FilaDeAcoes
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.SincronizadorDeAcoes
import br.com.frila.core.rede.TipoAcaoPendente
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import java.io.File
import java.io.IOException
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

/** A6.2: check-in e checkout sem rede entram na fila do aparelho, saem quando a rede volta e a recusa vira aviso. */
class CheckinNaFilaTest {
    @TempDir lateinit var diretorio: File
    private val turnoId = "11111111-1111-1111-1111-111111111111"
    private val conta = "conta-sintetica"
    private val agora = Instant.parse("2026-11-02T03:10:00Z")
    private val vaga = Coordenada(latitude = -15.7942, longitude = -47.8822)
    private val aUns111Metros = Coordenada(latitude = -15.7932, longitude = -47.8822)
    private val registroJson =
        """{"turno_id":"$turnoId","tipo":"geolocalizado","verificacao":"verificado","registrado_em":"2026-11-02T03:10:00Z","distancia_m":111}"""
    private val fila by lazy { FilaDeAcoes(File(diretorio, "fila.json")) }
    private val eventos = mutableListOf<Pair<EventoDeTelemetria, String?>>()
    private var offline = true
    private val pedidos = mutableListOf<String>()

    private val servico: ServicoTurnos by lazy {
        val engine = MockEngine { request ->
            pedidos += request.url.encodedPath
            if (offline) throw IOException("sem rede sintética")
            if (request.url.encodedPath.endsWith("meus_turnos")) {
                respond("""{"mensagem":"indisponível"}""", HttpStatusCode.InternalServerError, headersOf(HttpHeaders.ContentType, "application/json"))
            } else {
                respond(registroJson, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            }
        }
        ServicoTurnos(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
    }

    private fun provedor(): ProvedorDeLocalizacao = mockk<ProvedorDeLocalizacao>().also {
        every { it.temPermissaoDeLocalizacao() } returns true
        every { it.isGpsAtivado() } returns true
        coEvery { it.lerParaCheckin() } returns LeituraDeLocalizacao(aUns111Metros, precisaoMetros = 10f, simulada = false)
    }

    /** Escopo sem despachante: o que a fila avisa chega ao ViewModel na hora, sem corrida nos testes. */
    private fun viewModel(dono: String? = conta, comFila: Boolean = true) = CheckinViewModel(
        turnoId = turnoId, coordenadaDaVaga = vaga, servicoTurnos = servico, provedorDeLocalizacao = provedor(),
        instanteAtual = { agora }, escopo = CoroutineScope(Dispatchers.Unconfined),
        registrarEvento = { evento, _, turno -> eventos += evento to turno },
        filaDeAcoes = if (comFila) fila else null, contaAtual = { dono },
    )

    private fun sincronizador(envioDoCheckin: suspend (br.com.frila.core.rede.AcaoPendente) -> Unit = {
        servico.fazerCheckin(it.turnoId!!, it.distanciaMetros, it.instanteDoToque)
    }) = SincronizadorDeAcoes(fila, { conta }, mapOf(
        TipoAcaoPendente.CHECKIN to envioDoCheckin,
        TipoAcaoPendente.CHECKOUT to { a -> servico.fazerCheckout(a.turnoId!!, a.distanciaMetros, a.instanteDoToque) },
    ))

    private fun aguardar(condicao: () -> Boolean) = runBlocking {
        repeat(100) { if (!condicao()) delay(50) }
        assertTrue(condicao(), "a condição não chegou a tempo")
    }

    @Test fun `check-in sem rede guarda o toque com o instante e a distancia e mostra o estado na fila`() = runBlocking {
        val vm = viewModel()
        vm.fazerCheckin().join()

        assertEquals(StatusCheckin.NA_FILA, vm.estado.value.status)
        assertEquals(RegistroNaFila(agora, manual = false), vm.estado.value.checkinNaFila)
        val acao = fila.pendentes().single()
        assertEquals(TipoAcaoPendente.CHECKIN, acao.tipo)
        assertEquals(turnoId, acao.turnoId)
        assertEquals(conta, acao.contaId)
        assertEquals(agora.toString(), acao.instanteDoToque)
        assertEquals(111, acao.distanciaMetros)
        assertEquals(listOf(EventoDeTelemetria.ACAO_ENFILEIRADA_OFFLINE to turnoId), eventos.filter { it.first == EventoDeTelemetria.ACAO_ENFILEIRADA_OFFLINE })
        assertEquals("Sem conexão. O check-in das 00:10 está guardado neste aparelho e será enviado quando a internet voltar, com esse horário.",
            TextosDaFilaDePresenca.checkinNaFila(vm.estado.value.checkinNaFila!!))
    }

    @Test fun `tela reaberta preserva o instante da fila com deslocamento UTC`() {
        fila.enfileirar(AcaoPendente(
            TipoAcaoPendente.CHECKIN, conta, "2026-11-02T02:40:00+00:00", turnoId = turnoId, distanciaMetros = 111,
        ))

        val vm = viewModel()

        assertEquals(StatusCheckin.NA_FILA, vm.estado.value.status)
        assertEquals(RegistroNaFila(agora.minusSeconds(1800), manual = false), vm.estado.value.checkinNaFila)
        assertTrue(pedidos.isEmpty(), "reabrir a tela lê o instante guardado sem chamar a rede")
    }

    @Test fun `o mesmo toque nao enfileira duas vezes, nem em outra abertura da tela`() = runBlocking {
        val vm = viewModel()
        vm.fazerCheckin().join()
        val pedidosAntes = pedidos.size
        vm.fazerCheckin().join()
        vm.prosseguirCheckinManual().join()
        val reaberta = viewModel()
        assertEquals(StatusCheckin.NA_FILA, reaberta.estado.value.status)
        reaberta.fazerCheckin().join()

        assertEquals(1, fila.pendentes().size)
        assertEquals(pedidosAntes, pedidos.size, "o toque repetido não chama a rede")
        assertEquals(1, eventos.count { it.first == EventoDeTelemetria.ACAO_ENFILEIRADA_OFFLINE })
    }

    @Test fun `checkout sem rede entra na fila uma vez e a tela reaberta o mostra`() = runBlocking {
        val vm = viewModel()
        vm.fazerCheckout().join()
        vm.fazerCheckout().join()

        assertEquals(StatusCheckout.NA_FILA, vm.estado.value.checkout)
        val acao = fila.pendentes().single()
        assertEquals(TipoAcaoPendente.CHECKOUT, acao.tipo)
        assertEquals(111, acao.distanciaMetros)
        assertEquals(StatusCheckout.NA_FILA, viewModel().estado.value.checkout)
    }

    @Test fun `volta da rede envia uma unica vez e a tela sai do estado na fila`() = runBlocking {
        val vm = viewModel()
        vm.fazerCheckin().join()
        vm.fazerCheckout().join()
        offline = false
        pedidos.clear()

        val sinc = sincronizador()
        sinc.sincronizar(); sinc.sincronizar()

        assertEquals(listOf("/rest/v1/rpc/fazer_checkin", "/rest/v1/rpc/fazer_checkout"), pedidos.filter { !it.endsWith("meus_turnos") })
        assertTrue(fila.pendentes().isEmpty())
        assertEquals(StatusCheckout.FEITO, vm.estado.value.checkout)
        // Sem ler o que o servidor gravou (aqui indisponível), o check-in aparece como à espera da casa: o mais prudente.
        aguardar { vm.estado.value.status == StatusCheckin.MANUAL_PENDENTE }
        assertNull(vm.estado.value.checkinNaFila)
        assertEquals(1, eventos.count { it.first == EventoDeTelemetria.CHECKOUT_CONCLUIDO })
    }

    @Test fun `recusa de vez volta como aviso e o novo toque fecha o aviso`() = runBlocking {
        val vm = viewModel()
        vm.fazerCheckin().join()

        sincronizador { throw ErroDaApi(CodigoErroAPI.FORA_DA_JANELA, "fora_da_janela", null, "sintético") }.sincronizar()

        assertTrue(fila.pendentes().isEmpty())
        assertEquals(StatusCheckin.OCIOSO, vm.estado.value.status)
        assertEquals(TextosDaFilaDePresenca.CHECKIN_RECUSADO, vm.estado.value.avisoCheckin)
        assertEquals(TextosDaFilaDePresenca.CHECKIN_RECUSADO, viewModel().estado.value.avisoCheckin)

        vm.fazerCheckin().join()
        assertNull(vm.estado.value.avisoCheckin)
        assertTrue(fila.recusadas().isEmpty(), "o aviso fechado não volta")
    }

    @Test fun `check-in na fila libera o checkout, que tambem enfileira, e a volta da rede envia um de cada em ordem`() = runBlocking {
        val vm = viewModel()
        val turno = ItemTurno(turnoId, "posicao", agora, agora.plusSeconds(3600), "Função", "Casa", "02/11 00:10", "R$ 100,00", "confirmada")
        assertTrue(!checkinFeitoOuNaFila(turno, vm.estado.value), "sem check-in não há check-out")

        vm.fazerCheckin().join()
        assertEquals(StatusCheckin.NA_FILA, vm.estado.value.status)
        assertTrue(checkinFeitoOuNaFila(turno, vm.estado.value), "check-in na fila libera o check-out")
        vm.fazerCheckout().join()

        assertEquals(StatusCheckout.NA_FILA, vm.estado.value.checkout)
        assertEquals(listOf(TipoAcaoPendente.CHECKIN, TipoAcaoPendente.CHECKOUT), fila.pendentes().map { it.tipo })

        offline = false
        pedidos.clear()
        val sinc = sincronizador()
        sinc.sincronizar(); sinc.sincronizar()

        assertEquals(listOf("/rest/v1/rpc/fazer_checkin", "/rest/v1/rpc/fazer_checkout"), pedidos.filter { !it.endsWith("meus_turnos") })
        assertTrue(fila.pendentes().isEmpty())
        assertEquals(StatusCheckout.FEITO, vm.estado.value.checkout)
    }

    @Test fun `sem conta ou sem fila nada e guardado e vale o erro de sem conexao de antes`() = runBlocking {
        val semConta = viewModel(dono = null)
        semConta.fazerCheckin().join()
        val semFila = viewModel(comFila = false)
        semFila.fazerCheckin().join()

        assertEquals(StatusCheckin.ERRO, semConta.estado.value.status)
        assertEquals(StatusCheckin.ERRO, semFila.estado.value.status)
        assertTrue(fila.pendentes().isEmpty())
    }

    @Test fun `o que e de outra conta ou de outro turno nao aparece na tela`() = runBlocking {
        viewModel(dono = "outra-conta").fazerCheckin().join()
        assertEquals(StatusCheckin.OCIOSO, viewModel().estado.value.status)
    }
}
