package br.com.frila.core.seguranca

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class ArmazenamentoDeSessaoTest {

    private lateinit var armazenamento: ArmazenamentoDeSessaoEmMemoria

    private val sessaoDeTeste = Sessao(
        accessToken = "access-123",
        refreshToken = "refresh-456",
        tokenType = "bearer",
        expiresIn = 3600,
        vinculoId = "vinculo-abc",
    )

    @BeforeEach
    fun antesDeCada() {
        armazenamento = ArmazenamentoDeSessaoEmMemoria()
    }

    @Test
    fun `sem sessao salva nao esta autenticado e obterSessao e nulo`() {
        assertFalse(armazenamento.estaAutenticado())
        assertNull(armazenamento.obterSessao())
    }

    @Test
    fun `ciclo completo - salvar, obter, estar autenticado, limpar`() {
        armazenamento.salvarSessao(sessaoDeTeste)

        assertTrue(armazenamento.estaAutenticado())
        assertEquals(sessaoDeTeste, armazenamento.obterSessao())

        armazenamento.limparSessao()

        assertFalse(armazenamento.estaAutenticado())
        assertNull(armazenamento.obterSessao())
    }

    @Test
    fun `salvar sessao nova sobrescreve a anterior`() {
        armazenamento.salvarSessao(sessaoDeTeste)
        val novaSessao = sessaoDeTeste.copy(accessToken = "access-789", vinculoId = "vinculo-xyz")

        armazenamento.salvarSessao(novaSessao)

        assertEquals(novaSessao, armazenamento.obterSessao())
    }

    @Test
    fun `sessaoObservavel reflete o estado atual`() {
        assertNull(armazenamento.sessaoObservavel.value)

        armazenamento.salvarSessao(sessaoDeTeste)
        assertEquals(sessaoDeTeste, armazenamento.sessaoObservavel.value)

        armazenamento.limparSessao()
        assertNull(armazenamento.sessaoObservavel.value)
    }

    @Test
    fun `acesso concorrente nao perde nem corrompe o valor salvo por ultimo`() {
        val executor = Executors.newFixedThreadPool(8)
        val pronto = CountDownLatch(50)

        repeat(50) { indice ->
            executor.submit {
                armazenamento.salvarSessao(sessaoDeTeste.copy(accessToken = "access-$indice"))
                pronto.countDown()
            }
        }

        assertTrue(pronto.await(10, TimeUnit.SECONDS))
        executor.shutdown()

        // Não dá para prever qual das 50 escritas venceu, mas tem que ser uma delas, nunca um
        // estado intermediário/corrompido — e tem que estar autenticado ao final.
        val sessaoFinal = armazenamento.obterSessao()
        assertTrue(armazenamento.estaAutenticado())
        assertTrue(sessaoFinal != null && sessaoFinal.accessToken.startsWith("access-"))
    }

    @Test
    fun `biometria comeca desativada e pode ser ativada`() {
        assertFalse(armazenamento.isBiometriaAtivada())

        armazenamento.definirBiometriaAtivada(true)

        assertTrue(armazenamento.isBiometriaAtivada())
    }

    @Test
    fun `limparSessao desativa a biometria RN15`() {
        armazenamento.salvarSessao(sessaoDeTeste)
        armazenamento.definirBiometriaAtivada(true)
        assertTrue(armazenamento.isBiometriaAtivada())

        armazenamento.limparSessao()

        assertFalse(armazenamento.isBiometriaAtivada())
    }

    @Test
    fun `salvarSeRefreshTokenIgual grava quando o refresh token e o esperado`() {
        armazenamento.salvarSessao(sessaoDeTeste)
        val renovada = sessaoDeTeste.copy(accessToken = "access-novo", refreshToken = "refresh-novo")

        assertTrue(armazenamento.salvarSeRefreshTokenIgual(sessaoDeTeste.refreshToken, renovada))

        assertEquals(renovada, armazenamento.obterSessao())
        assertEquals(renovada, armazenamento.sessaoObservavel.value)
    }

    @Test
    fun `salvarSeRefreshTokenIgual nao grava quando outra conta esta guardada ou nao ha sessao`() {
        val renovada = sessaoDeTeste.copy(refreshToken = "refresh-novo")
        assertFalse(armazenamento.salvarSeRefreshTokenIgual(sessaoDeTeste.refreshToken, renovada))
        assertNull(armazenamento.obterSessao())

        val outraConta = sessaoDeTeste.copy(accessToken = "access-b", refreshToken = "refresh-b")
        armazenamento.salvarSessao(outraConta)

        assertFalse(armazenamento.salvarSeRefreshTokenIgual(sessaoDeTeste.refreshToken, renovada))
        assertEquals(outraConta, armazenamento.obterSessao())
    }

    @Test
    fun `limparSeRefreshTokenIgual apaga so quando o refresh token e o esperado`() {
        val outraConta = sessaoDeTeste.copy(accessToken = "access-b", refreshToken = "refresh-b")
        armazenamento.salvarSessao(outraConta)
        armazenamento.definirBiometriaAtivada(true)

        assertFalse(armazenamento.limparSeRefreshTokenIgual(sessaoDeTeste.refreshToken))
        assertEquals(outraConta, armazenamento.obterSessao())
        assertTrue(armazenamento.isBiometriaAtivada())

        assertTrue(armazenamento.limparSeRefreshTokenIgual(outraConta.refreshToken))
        assertNull(armazenamento.obterSessao())
        assertNull(armazenamento.sessaoObservavel.value)
        assertFalse(armazenamento.isBiometriaAtivada())
        assertFalse(armazenamento.limparSeRefreshTokenIgual(outraConta.refreshToken))
    }

    @Test
    fun `renovacao de A concorrente com a troca para B nunca termina com a sessao de A`() {
        val sessaoA = sessaoDeTeste
        val sessaoB = sessaoDeTeste.copy(accessToken = "access-b", refreshToken = "refresh-b")
        val renovadaA = sessaoDeTeste.copy(accessToken = "access-a2", refreshToken = "refresh-a2")
        val pool = Executors.newFixedThreadPool(2)
        var sobrescritas = 0
        try {
            repeat(ITERACOES_CONCORRENTES) {
                val loja = ArmazenamentoDeSessaoEmMemoria()
                loja.salvarSessao(sessaoA)
                val largada = CountDownLatch(1)
                val renovacao = pool.submit {
                    largada.await()
                    loja.salvarSeRefreshTokenIgual(sessaoA.refreshToken, renovadaA)
                }
                val troca = pool.submit {
                    largada.await()
                    loja.limparSessao()
                    loja.salvarSessao(sessaoB)
                }
                largada.countDown()
                renovacao.get(5, TimeUnit.SECONDS)
                troca.get(5, TimeUnit.SECONDS)
                if (loja.obterSessao() != sessaoB) sobrescritas++
            }
        } finally {
            pool.shutdownNow()
        }

        assertEquals(0, sobrescritas, "sessões de B sobrescritas em $ITERACOES_CONCORRENTES iterações")
    }

    private companion object {
        const val ITERACOES_CONCORRENTES = 6_000
    }
}
