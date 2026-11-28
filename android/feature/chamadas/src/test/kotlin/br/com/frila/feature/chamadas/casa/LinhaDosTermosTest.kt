package br.com.frila.feature.chamadas.casa

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/**
 * Cartão 1uDgSseN (item 264): o texto que a casa lê antes de confirmar a chamada com os termos da vaga já aberta (0.2.95). Tem quatro combinações de
 * refeição e transporte, mais o material próprio; o único teste que existia cobria uma (refeição sem transporte, com material). Os textos esperados são os
 * do iOS (`TelaTermosDaVagaAbertaProvisoria.swift`), escritos aqui por extenso: se a constante do Android mudar de redação, o teste acusa.
 */
class LinhaDosTermosTest {

    private fun termos(refeicao: Boolean, transporte: Boolean, material: Boolean, valorCentavos: Long = 15_000) =
        TermosDaVagaAberta("vaga-1", valorCentavos, incluiRefeicao = refeicao, incluiTransporte = transporte, exigeMaterialProprio = material)

    @Test
    fun `refeicao e transporte inclusos`() {
        assertEquals("R$ 150,00, Refeição e transporte inclusos", linhaDosTermos(termos(refeicao = true, transporte = true, material = false)))
    }

    @Test
    fun `refeicao inclusa, sem transporte`() {
        assertEquals("R$ 150,00, Refeição inclusa, sem transporte", linhaDosTermos(termos(refeicao = true, transporte = false, material = false)))
    }

    @Test
    fun `sem refeicao, transporte incluso`() {
        assertEquals("R$ 150,00, Sem refeição, transporte incluso", linhaDosTermos(termos(refeicao = false, transporte = true, material = false)))
    }

    @Test
    fun `sem refeicao nem transporte`() {
        assertEquals("R$ 150,00, Sem refeição nem transporte", linhaDosTermos(termos(refeicao = false, transporte = false, material = false)))
    }

    @Test
    fun `refeicao e transporte inclusos, com material proprio`() {
        assertEquals(
            "R$ 150,00, Refeição e transporte inclusos, Exige material próprio",
            linhaDosTermos(termos(refeicao = true, transporte = true, material = true)),
        )
    }

    @Test
    fun `refeicao inclusa, sem transporte, com material proprio`() {
        assertEquals(
            "R$ 150,00, Refeição inclusa, sem transporte, Exige material próprio",
            linhaDosTermos(termos(refeicao = true, transporte = false, material = true)),
        )
    }

    @Test
    fun `sem refeicao, transporte incluso, com material proprio`() {
        assertEquals(
            "R$ 150,00, Sem refeição, transporte incluso, Exige material próprio",
            linhaDosTermos(termos(refeicao = false, transporte = true, material = true)),
        )
    }

    @Test
    fun `sem refeicao nem transporte, com material proprio`() {
        assertEquals(
            "R$ 150,00, Sem refeição nem transporte, Exige material próprio",
            linhaDosTermos(termos(refeicao = false, transporte = false, material = true)),
        )
    }

    @Test
    fun `o valor e o da vaga, com milhar e centavos`() {
        assertEquals(
            "R$ 1.234,56, Sem refeição nem transporte",
            linhaDosTermos(termos(refeicao = false, transporte = false, material = false, valorCentavos = 123_456)),
        )
    }

    @Test
    fun `as quatro combinacoes dao quatro textos diferentes`() {
        val textos = listOf(true to true, true to false, false to true, false to false)
            .map { (refeicao, transporte) -> linhaDosTermos(termos(refeicao, transporte, material = false)) }

        assertEquals(4, textos.toSet().size)
    }

    @Test
    fun `o material proprio so aparece quando a vaga exige`() {
        assertEquals(false, linhaDosTermos(termos(refeicao = true, transporte = true, material = false)).contains("material"))
        assertEquals(true, linhaDosTermos(termos(refeicao = true, transporte = true, material = true)).endsWith(", Exige material próprio"))
    }
}
