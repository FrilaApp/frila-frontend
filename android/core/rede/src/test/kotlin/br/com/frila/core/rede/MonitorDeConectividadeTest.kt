package br.com.frila.core.rede

import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** RNF01 (cartão 9Q0sJIzW): porta de domínio + dublê controlável. */
class MonitorDeConectividadeTest {

    @Test
    fun `estaConectado e verdadeiro quando o status e CONECTADO`() {
        val monitor = MonitorDeConectividadeFalso(statusInicial = StatusConectividade.CONECTADO)
        assertTrue(monitor.estaConectado)
    }

    @Test
    fun `estaConectado e falso quando o status e SEM_CONEXAO`() {
        val monitor = MonitorDeConectividadeFalso(statusInicial = StatusConectividade.SEM_CONEXAO)
        assertFalse(monitor.estaConectado)
    }

    @Test
    fun `definirStatus muda o valor observado em status e em estaConectado`() {
        val monitor = MonitorDeConectividadeFalso(statusInicial = StatusConectividade.CONECTADO)

        monitor.definirStatus(StatusConectividade.SEM_CONEXAO)

        assertFalse(monitor.estaConectado)
        assertTrue(monitor.status.value == StatusConectividade.SEM_CONEXAO)
    }

    @Test
    fun `default do construtor e CONECTADO`() {
        val monitor = MonitorDeConectividadeFalso()
        assertTrue(monitor.estaConectado)
    }
}
