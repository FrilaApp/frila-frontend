package br.com.frila.app

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * RN15 (MEDIDO, Shisui PR #591): deep link para rota autenticada (`frila://vagas/{vagaId}`,
 * `frila://meus_turnos`, `frila://suporte`) chegava via `NavController.handleDeepLink` e pulava
 * `rotaInicial()`/[Rotas.DESBLOQUEIO] — a biometria ativada nunca era exigida. [GuardaBiometrico]
 * intercepta TODA mudança de destino (deep link, `navigate()`, volta), não só a inicial.
 */
class GuardaBiometricoTest {

    @Test
    fun `sem biometria ativada nunca redireciona`() {
        val guarda = GuardaBiometrico(sessaoDesbloqueadaInicial = true)

        assertNull(guarda.aoMudarDestino(Rotas.FEED))
        assertNull(guarda.aoMudarDestino(Rotas.DETALHE, mapOf("vagaId" to "vaga-123")))
    }

    @Test
    fun `com biometria ativada e sessao travada, rota protegida redireciona para DESBLOQUEIO`() {
        val guarda = GuardaBiometrico(sessaoDesbloqueadaInicial = false)

        assertEquals(Rotas.DESBLOQUEIO, guarda.aoMudarDestino(Rotas.FEED))
    }

    @Test
    fun `rotas pre-autenticacao nunca sao bloqueadas, mesmo travada`() {
        val guarda = GuardaBiometrico(sessaoDesbloqueadaInicial = false)

        assertNull(guarda.aoMudarDestino(Rotas.ENTRADA))
        assertNull(guarda.aoMudarDestino(Rotas.CODIGO))
        assertNull(guarda.aoMudarDestino(Rotas.CADASTRO))
        assertNull(guarda.aoMudarDestino(Rotas.DESBLOQUEIO))
    }

    @Test
    fun `deep link para rota com argumentos guarda o destino pendente com valores preenchidos`() {
        val guarda = GuardaBiometrico(sessaoDesbloqueadaInicial = false)

        val redirecionamento = guarda.aoMudarDestino(Rotas.DETALHE, mapOf("vagaId" to "vaga-123"))

        assertEquals(Rotas.DESBLOQUEIO, redirecionamento)
        assertEquals(Rotas.detalhe("vaga-123"), guarda.aoDesbloquearComSucesso())
    }

    @Test
    fun `sem destino pendente, desbloquear com sucesso cai no FEED`() {
        val guarda = GuardaBiometrico(sessaoDesbloqueadaInicial = false)

        assertEquals(Rotas.FEED, guarda.aoDesbloquearComSucesso())
    }

    @Test
    fun `apos desbloquear com sucesso, a sessao fica liberada e nao redireciona mais`() {
        val guarda = GuardaBiometrico(sessaoDesbloqueadaInicial = false)
        guarda.aoMudarDestino(Rotas.FEED)

        guarda.aoDesbloquearComSucesso()

        assertTrue(guarda.desbloqueada)
        assertNull(guarda.aoMudarDestino(Rotas.FEED))
        assertNull(guarda.aoMudarDestino(Rotas.DETALHE, mapOf("vagaId" to "outra-vaga")))
    }

    @Test
    fun `destino pendente e consumido uma unica vez`() {
        val guarda = GuardaBiometrico(sessaoDesbloqueadaInicial = false)
        guarda.aoMudarDestino(Rotas.MEUS_TURNOS)

        assertEquals(Rotas.MEUS_TURNOS, guarda.aoDesbloquearComSucesso())
        assertEquals(Rotas.FEED, guarda.aoDesbloquearComSucesso())
    }

    @Test
    fun `rota nula nunca redireciona`() {
        val guarda = GuardaBiometrico(sessaoDesbloqueadaInicial = false)

        assertNull(guarda.aoMudarDestino(null))
    }
}
