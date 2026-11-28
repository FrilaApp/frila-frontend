package br.com.frila.feature.turnos

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Test

/**
 * Cartão ZFMABBMH (item 296): os dois textos da avaliação na fila, do iOS por extenso (`TextosDaPresenca.swift:112` e
 * `TextosDoProfissional.swift:357`). Os outros testes usam as constantes, então só este fixa o literal. A recusa não pode dizer que o envio
 * "não será repetido": a tela volta a mostrar os botões e a pessoa pode avaliar de novo.
 *
 * JUnit: nenhum método devolve valor (um `@Test` que devolve valor é ignorado).
 */
class TextosDaFilaDeAvaliacaoTest {

    @Test
    fun `a avaliacao na fila diz o que o iOS diz`() {
        assertEquals("Avaliação salva. Será enviada quando a internet voltar.", TextosDaFilaDeAvaliacao.NA_FILA)
    }

    @Test
    fun `a avaliacao recusada diz o que o iOS diz, e que da para tentar de novo`() {
        assertEquals(
            "A avaliação guardada neste aparelho não foi registrada. Você pode tentar novamente quando a avaliação estiver disponível.",
            TextosDaFilaDeAvaliacao.RECUSADA,
        )
    }

    @Test
    fun `a recusa nao promete que o envio nao sera repetido, porque a tela volta a mostrar os botoes`() {
        assertFalse(TextosDaFilaDeAvaliacao.RECUSADA.contains("não será repetido"))
    }
}
