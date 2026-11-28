package br.com.frila.feature.vagas.painel

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.PainelDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.PosicaoNoPainelDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ResultadoRegistroDto
import br.com.frila.core.rede.VagaNoPainelDto
import br.com.frila.core.rede.VagaResumoDto
import java.time.Instant
import java.util.concurrent.CountDownLatch
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Cartão lWLGe0LX (item 161), achados baixos do #1198: a guarda do toque em "Confirmar presença" é atômica; a leitura que
 * estava em voo não aplica o painel depois da confirmação, mesmo que o `buscarPainel` não obedeça ao cancelamento; e o
 * `409 vaga_encerrada` diz que a vaga não está mais disponível.
 */
class PresencasAConfirmarGuardaTest {

    private val agora = Instant.parse("2026-11-12T22:00:00Z")
    private val ana = PerfilPublicoDto("pro-1", "profissional", "Ana Souza", null, ReputacaoDto(1, 1, null, 1, 1))
    private val registro = ResultadoRegistroDto("t1", "manual", "verificado", "2026-11-12T21:05:00Z")

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

    private fun erro(codigo: CodigoErroAPI, original: String) = ErroDaApi(codigo, original, null, "x")

    /** Vários toques simultâneos no mesmo turno, em threads de verdade: só um pode chegar ao servidor. */
    @Test
    fun `toques simultaneos no mesmo turno enviam uma unica confirmacao`() = runBlocking {
        val tentativas = 300
        val toques = 8
        repeat(tentativas) {
            val envios = AtomicInteger()
            val liberar = CompletableDeferred<Unit>()
            val vm = MinhasVagasViewModel(
                estabelecimentoId = "est-1",
                buscarPainel = { _, _, _ -> Result.success(painel(listOf("t1"))) },
                confirmarCheckin = { envios.incrementAndGet(); liberar.await(); Result.success(registro) },
                relogio = { agora },
                escopo = CoroutineScope(Dispatchers.Default),
            )
            vm.carregar().join()
            val largada = CountDownLatch(1)
            val threads = List(toques) { Thread { largada.await(); vm.confirmarPresenca("t1") } }
            threads.forEach(Thread::start)
            largada.countDown()
            threads.forEach(Thread::join)
            // Dá tempo de qualquer envio indevido chegar ao servidor antes de contar.
            Thread.sleep(2)
            liberar.complete(Unit)
            assertEquals(1, envios.get(), "tentativa $it")
        }
    }

    @Test
    fun `leitura em voo que nao obedece ao cancelamento nao devolve o cartao depois da confirmacao`() = runBlocking {
        val leituras = AtomicInteger()
        val leituraVelha = CompletableDeferred<Unit>()
        val vm = MinhasVagasViewModel(
            estabelecimentoId = "est-1",
            buscarPainel = { _, _, _ ->
                // A segunda leitura saiu antes da confirmação e ignora o cancelamento (rede bloqueante): chega com o t1 pendente.
                val n = leituras.incrementAndGet()
                if (n == 2) withContext(NonCancellable) { leituraVelha.await() }
                Result.success(painel(if (n == 3) emptyList() else listOf("t1")))
            },
            confirmarCheckin = { Result.success(registro) },
            relogio = { agora },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        vm.carregar().join()
        val velha = vm.atualizarEmSilencio()

        vm.confirmarPresenca("t1").join()
        leituraVelha.complete(Unit)
        velha.join()

        assertTrue(vm.estado.value.presencasAConfirmar.isEmpty(), "o cartão confirmado não pode voltar")
    }

    @Test
    fun `409 vaga_encerrada diz que a vaga nao esta mais disponivel e deixa o botao`() = runBlocking {
        val vm = MinhasVagasViewModel(
            estabelecimentoId = "est-1",
            buscarPainel = { _, _, _ -> Result.success(painel(listOf("t1"))) },
            confirmarCheckin = { Result.failure(erro(CodigoErroAPI.VAGA_ENCERRADA, "vaga_encerrada")) },
            relogio = { agora },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        vm.carregar().join()

        vm.confirmarPresenca("t1").join()

        assertEquals("Esta vaga não está mais disponível.", vm.estado.value.avisoDaPresenca?.mensagem)
        assertTrue(vm.estado.value.avisoDaPresenca!!.erro)
        assertTrue(vm.estado.value.podeConfirmar("t1"))
    }
}
