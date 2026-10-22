package br.com.frila.app

import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import io.mockk.every
import io.mockk.mockk
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class AppNavegacaoTest {

    @Test
    fun `com sessao ativa a rota inicial e FEED`() {
        val armazenamento = mockk<ArmazenamentoDeSessao>()
        every { armazenamento.estaAutenticado() } returns true

        assertEquals(Rotas.FEED, rotaInicial(armazenamento))
    }

    @Test
    fun `sem sessao ativa a rota inicial e ENTRADA`() {
        val armazenamento = mockk<ArmazenamentoDeSessao>()
        every { armazenamento.estaAutenticado() } returns false

        assertEquals(Rotas.ENTRADA, rotaInicial(armazenamento))
    }

    @Test
    fun `rota de codigo embute o email`() {
        assertEquals("codigo/profissional@exemplo.com", Rotas.codigo("profissional@exemplo.com"))
    }

    @Test
    fun `rota de detalhe embute o id da vaga`() {
        assertEquals("detalhe/vaga-123", Rotas.detalhe("vaga-123"))
    }
}
