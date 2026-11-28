package br.com.frila.core.seguranca

import java.util.concurrent.CyclicBarrier
import java.util.concurrent.atomic.AtomicBoolean
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/**
 * P3 do time do Cauê no #1091 (En8IkArK): o apagar e o gravar condicionais contra a troca de conta, em duas threads de verdade.
 * Em qualquer ordem, a conta que entrou fica: ou o condicional age sobre a anterior antes da troca, ou vê a nova e não faz nada.
 */
class ArmazenamentoDeSessaoConcorrenteTest {

    private val contaA = Sessao("access-a", "refresh-a", "bearer", 3_600L)
    private val contaA2 = Sessao("access-a2", "refresh-a2", "bearer", 3_600L)
    private val contaB = Sessao("access-b", "refresh-b", "bearer", 3_600L)

    private fun emDuasThreads(primeira: () -> Unit, segunda: () -> Unit) {
        val largada = CyclicBarrier(2)
        val threads = listOf(primeira, segunda).map { passo -> Thread { largada.await(); passo() } }
        threads.forEach(Thread::start)
        threads.forEach(Thread::join)
    }

    @Test
    fun `apagar condicional da conta anterior nunca apaga a conta que entrou`() {
        repeat(REPETICOES) { volta ->
            val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(contaA) }
            val apagou = AtomicBoolean()

            emDuasThreads({ apagou.set(armazenamento.limparSeRefreshTokenIgual("refresh-a")) }, { armazenamento.salvarSessao(contaB) })

            assertEquals(contaB, armazenamento.obterSessao(), "volta $volta (apagou=${apagou.get()})")
        }
    }

    @Test
    fun `gravar condicional da renovacao nunca sobrescreve a conta que entrou`() {
        repeat(REPETICOES) { volta ->
            val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(contaA) }

            emDuasThreads({ armazenamento.salvarSeRefreshTokenIgual("refresh-a", contaA2) }, { armazenamento.salvarSessao(contaB) })

            assertEquals(contaB, armazenamento.obterSessao(), "volta $volta")
        }
    }

    private companion object {
        const val REPETICOES = 2_000
    }
}
