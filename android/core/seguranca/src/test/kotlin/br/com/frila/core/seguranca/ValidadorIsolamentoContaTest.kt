package br.com.frila.core.seguranca

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ValidadorIsolamentoContaTest {

    @Test
    fun `vinculo_id do push igual ao da sessao ativa - exibe conteudo original`() {
        val permite = ValidadorIsolamentoConta.devePermitirConteudoOriginal(
            vinculoIdDoPush = "vinculo-abc",
            vinculoIdDaSessaoAtiva = "vinculo-abc",
        )

        assertTrue(permite)
    }

    @Test
    fun `vinculo_id do push divergente da sessao ativa - neutraliza (RN15)`() {
        // Caso central da RN15: aparelho compartilhado, conta anterior já saiu, push atrasado chega.
        val permite = ValidadorIsolamentoConta.devePermitirConteudoOriginal(
            vinculoIdDoPush = "vinculo-da-conta-anterior",
            vinculoIdDaSessaoAtiva = "vinculo-da-conta-atual",
        )

        assertFalse(permite)
    }

    @Test
    fun `sem sessao ativa no aparelho - neutraliza mesmo com vinculo_id no push`() {
        val permite = ValidadorIsolamentoConta.devePermitirConteudoOriginal(
            vinculoIdDoPush = "vinculo-qualquer",
            vinculoIdDaSessaoAtiva = null,
        )

        assertFalse(permite)
    }

    @Test
    fun `push sem vinculo_id (servidor anterior a 0_2_30) - regra antiga, exibe`() {
        val permite = ValidadorIsolamentoConta.devePermitirConteudoOriginal(
            vinculoIdDoPush = null,
            vinculoIdDaSessaoAtiva = "vinculo-abc",
        )

        assertTrue(permite)
    }

    @Test
    fun `sem vinculo_id em nenhum dos dois lados - regra antiga, exibe`() {
        val permite = ValidadorIsolamentoConta.devePermitirConteudoOriginal(
            vinculoIdDoPush = null,
            vinculoIdDaSessaoAtiva = null,
        )

        assertTrue(permite)
    }

    @Test
    fun `mensagem neutralizada nunca varia por payload - e sempre o texto generico fixo`() {
        assertTrue(ValidadorIsolamentoConta.MENSAGEM_NEUTRALIZADA.isNotBlank())
        assertFalse(ValidadorIsolamentoConta.MENSAGEM_NEUTRALIZADA.contains("vaga", ignoreCase = true))
    }

    /**
     * Dkl0qvR7 (item 289): o texto exato do contrato (`openapi.yaml:773`: "Nova notificação do Frila", "Abra o aplicativo para
     * conferir.") e do iOS (`FiltroDoPushPorVinculo.tituloNeutro`/`corpoNeutro`). Comparar com a constante não pegaria um texto
     * trocado; aqui vai o literal.
     */
    @Test
    fun `o texto neutro e o do contrato, palavra por palavra`() {
        assertEquals("Abra o aplicativo para conferir.", ValidadorIsolamentoConta.MENSAGEM_NEUTRALIZADA)
        assertEquals("Nova notificação do Frila", ValidadorIsolamentoConta.TITULO_NEUTRO)
    }
}
