package br.com.frila.app.falhas

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** L1-6: com a coleta desligada, o que o SDK deixou guardado no aparelho sai na abertura (igual ao iOS). */
class RelatorioDeFalhasTest {

    private class FirebaseFalso(override val configurado: Boolean) : FalhasDoFirebase {
        var apagamentos = 0
        var ultimaColetaDefinida: Boolean? = null
        override fun apagarRelatoriosPendentes() { apagamentos++ }
        override fun definirColetaAtiva(ativa: Boolean) { ultimaColetaDefinida = ativa }
    }

    @Test
    fun `coleta desligada e Firebase configurado apaga os relatorios pendentes uma vez`() {
        val firebase = FirebaseFalso(configurado = true)
        assertTrue(RelatorioDeFalhas.iniciarSeConfigurado(coletaLigada = false, firebase = firebase))
        assertEquals(1, firebase.apagamentos)
        assertEquals(false, firebase.ultimaColetaDefinida)
    }

    @Test
    fun `coleta ligada nao apaga nada e sincroniza o SDK`() {
        val firebase = FirebaseFalso(configurado = true)
        assertFalse(RelatorioDeFalhas.iniciarSeConfigurado(coletaLigada = true, firebase = firebase))
        assertEquals(0, firebase.apagamentos)
        assertEquals(true, firebase.ultimaColetaDefinida)
    }

    @Test
    fun `sem Firebase configurado nao toca no SDK`() {
        val firebase = FirebaseFalso(configurado = false)
        assertFalse(RelatorioDeFalhas.iniciarSeConfigurado(coletaLigada = false, firebase = firebase))
        assertEquals(0, firebase.apagamentos)
    }
}
