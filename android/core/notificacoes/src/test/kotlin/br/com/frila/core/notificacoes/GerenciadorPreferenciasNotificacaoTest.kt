package br.com.frila.core.notificacoes

import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class GerenciadorPreferenciasNotificacaoTest {

    @Test
    fun `canal comeca ativado por padrao`() {
        val gerenciador = GerenciadorPreferenciasNotificacaoEmMemoria()
        assertTrue(gerenciador.estaAtivado(GerenciadorDeCanais.CANAL_URGENCIA))
    }

    @Test
    fun `desativar um canal nao afeta os outros`() {
        val gerenciador = GerenciadorPreferenciasNotificacaoEmMemoria()
        gerenciador.definirAtivado(GerenciadorDeCanais.CANAL_TURNOS, false)

        assertFalse(gerenciador.estaAtivado(GerenciadorDeCanais.CANAL_TURNOS))
        assertTrue(gerenciador.estaAtivado(GerenciadorDeCanais.CANAL_URGENCIA))
        assertTrue(gerenciador.estaAtivado(GerenciadorDeCanais.CANAL_SISTEMA))
    }
}
