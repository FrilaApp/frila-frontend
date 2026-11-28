package br.com.frila.core.dominio.modelo

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/**
 * Cartão mnZrCJeY (item 299): uma frase só para o cancelamento que ficou na fila por falta de rede, igual à do iOS
 * (`TextosDoCancelamento.swift:48`). Os outros testes leem a constante ou o texto do módulo; este fixa o literal.
 *
 * JUnit: nenhum método devolve valor (um `@Test` que devolve valor é ignorado).
 */
class TextosDoCancelamentoTest {

    @Test
    fun `o cancelamento na fila diz o que o iOS diz`() {
        assertEquals("Sem conexão. O cancelamento será enviado quando a internet voltar.", TextosDoCancelamento.NA_FILA_SEM_CONEXAO)
    }
}
