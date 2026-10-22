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
}
