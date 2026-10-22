package br.com.frila.core.notificacoes

import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.Sessao
import br.com.frila.core.seguranca.ValidadorIsolamentoConta
import io.mockk.every
import io.mockk.mockk
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Prova cabal de RN15: isolamento de conta em aparelho compartilhado por `vinculo_id`
 * (`iOS/Contrato/openapi.yaml`, linhas 438-449, e `ValidadorIsolamentoConta` em
 * `:core:seguranca`). Nenhum destes testes depende de Android/Robolectric — tudo passa por
 * `ArmazenamentoDeSessao`, uma interface pura, mockada com MockK.
 */
class ProcessadorDePushTest {

    private fun sessaoCom(vinculoId: String?) = Sessao(
        accessToken = "token",
        refreshToken = "refresh",
        tokenType = "bearer",
        expiresIn = 3600,
        vinculoId = vinculoId,
    )

    private fun processadorComSessao(sessao: Sessao?): ProcessadorDePush {
        val armazenamento = mockk<ArmazenamentoDeSessao>()
        every { armazenamento.obterSessao() } returns sessao
        return ProcessadorDePush(armazenamento)
    }

    @Test
    fun `vinculo_id do push igual ao da sessao ativa - exibe conteudo original`() {
        val processador = processadorComSessao(sessaoCom(vinculoId = "vinculo-abc"))

        val resultado = processador.processar(
            mapOf("vinculo_id" to "vinculo-abc", "tipo" to "vaga_urgente", "titulo" to "Nova vaga!", "corpo" to "Garçom às 19h"),
        )

        assertFalse(resultado.neutralizada)
        assertEquals("Nova vaga!", resultado.titulo)
        assertEquals("Garçom às 19h", resultado.corpo)
        assertEquals(GerenciadorDeCanais.CANAL_URGENCIA, resultado.canal)
    }

    @Test
    fun `vinculo_id do push divergente da sessao ativa - neutraliza e nao vaza dado privado (RN15)`() {
        // Caso central da RN15: aparelho compartilhado, a conta anterior já saiu, o push dela
        // chega atrasado. O conteúdo original (título, corpo, vaga_id) nunca pode aparecer.
        val processador = processadorComSessao(sessaoCom(vinculoId = "vinculo-da-conta-atual"))

        val resultado = processador.processar(
            mapOf(
                "vinculo_id" to "vinculo-da-conta-anterior",
                "tipo" to "vaga_urgente",
                "vaga_id" to "vaga-secreta-123",
                "titulo" to "Vaga confidencial do contratante X",
                "corpo" to "R$ 500 — endereço sigiloso",
            ),
        )

        assertTrue(resultado.neutralizada)
        assertEquals(ValidadorIsolamentoConta.MENSAGEM_NEUTRALIZADA, resultado.corpo)
        assertFalse(resultado.corpo.contains("sigiloso"))
        assertFalse(resultado.corpo.contains("500"))
        assertNull(resultado.vagaId)
        assertEquals(GerenciadorDeCanais.CANAL_SISTEMA, resultado.canal)
    }

    @Test
    fun `sem sessao ativa no aparelho - neutraliza mesmo com vinculo_id no push`() {
        val processador = processadorComSessao(sessao = null)

        val resultado = processador.processar(
            mapOf("vinculo_id" to "vinculo-qualquer", "titulo" to "Não deveria aparecer", "corpo" to "Dado sensível"),
        )

        assertTrue(resultado.neutralizada)
        assertEquals(ValidadorIsolamentoConta.MENSAGEM_NEUTRALIZADA, resultado.corpo)
    }

    @Test
    fun `push sem vinculo_id (servidor anterior a 0_2_30) - regra antiga, exibe original`() {
        val processador = processadorComSessao(sessaoCom(vinculoId = "vinculo-abc"))

        val resultado = processador.processar(
            mapOf("tipo" to "turno", "titulo" to "Lembrete de turno", "corpo" to "Seu turno começa em 1h"),
        )

        assertFalse(resultado.neutralizada)
        assertEquals("Lembrete de turno", resultado.titulo)
        assertEquals(GerenciadorDeCanais.CANAL_TURNOS, resultado.canal)
    }

    @Test
    fun `payload sem titulo ou corpo nao quebra - usa valores padrao`() {
        val processador = processadorComSessao(sessaoCom(vinculoId = "vinculo-abc"))

        val resultado = processador.processar(mapOf("vinculo_id" to "vinculo-abc"))

        assertFalse(resultado.neutralizada)
        assertEquals("Frila", resultado.titulo)
        assertEquals("", resultado.corpo)
        assertEquals(GerenciadorDeCanais.CANAL_SISTEMA, resultado.canal)
    }

    @Test
    fun `tipo confirmacao tambem usa o canal de urgencia`() {
        val processador = processadorComSessao(sessaoCom(vinculoId = "vinculo-abc"))

        val resultado = processador.processar(mapOf("vinculo_id" to "vinculo-abc", "tipo" to "confirmacao"))

        assertEquals(GerenciadorDeCanais.CANAL_URGENCIA, resultado.canal)
    }

    @Test
    fun `tipo checkin usa o canal de turnos`() {
        val processador = processadorComSessao(sessaoCom(vinculoId = "vinculo-abc"))

        val resultado = processador.processar(mapOf("vinculo_id" to "vinculo-abc", "tipo" to "checkin"))

        assertEquals(GerenciadorDeCanais.CANAL_TURNOS, resultado.canal)
    }

    @Test
    fun `vaga_id so aparece quando o conteudo original e permitido`() {
        val processador = processadorComSessao(sessaoCom(vinculoId = "vinculo-abc"))

        val resultado = processador.processar(mapOf("vinculo_id" to "vinculo-abc", "vaga_id" to "vaga-123"))

        assertEquals("vaga-123", resultado.vagaId)
    }
}
