package br.com.frila.core.dominio.modelo

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.time.Instant

class ComprovanteCheckinTest {

    private val turnoId = "test-turno-1234"
    private val instante = Instant.parse("2026-10-27T15:30:00Z")

    @Test
    fun `gera comprovante geolocalizado com hash e coordenadas aproximadas a 3 casas decimais`() {
        val coordenada = Coordenada(latitude = -15.794212, longitude = -47.882199)
        val comprovante = GeradorComprovanteCheckin.gerar(
            turnoId = turnoId,
            registradoEm = instante,
            tipoVerificacao = TipoVerificacaoCheckin.GEOLOCALIZADO,
            coordenada = coordenada,
        )

        assertEquals(turnoId, comprovante.turnoId)
        assertEquals(instante, comprovante.registradoEm)
        assertEquals(TipoVerificacaoCheckin.GEOLOCALIZADO, comprovante.tipoVerificacao)
        assertEquals("-15.794, -47.882", comprovante.coordenadasAproximadas)
        assertTrue(comprovante.codigoAutenticacao.startsWith("CHK-"))
        assertEquals(12, comprovante.codigoAutenticacao.length) // CHK- (4) + 8 hex chars = 12
    }

    @Test
    fun `gera comprovante manual pendente sem coordenadas quando coordenada e nula`() {
        val comprovante = GeradorComprovanteCheckin.gerar(
            turnoId = turnoId,
            registradoEm = instante,
            tipoVerificacao = TipoVerificacaoCheckin.MANUAL_PENDENTE,
            coordenada = null,
        )

        assertEquals(TipoVerificacaoCheckin.MANUAL_PENDENTE, comprovante.tipoVerificacao)
        assertNull(comprovante.coordenadasAproximadas)
        assertTrue(comprovante.codigoAutenticacao.startsWith("CHK-"))
    }

    @Test
    fun `calculo de codigo de autenticacao e deterministico para mesmo turno e instante`() {
        val codigo1 = GeradorComprovanteCheckin.calcularCodigoAutenticacao(turnoId, instante)
        val codigo2 = GeradorComprovanteCheckin.calcularCodigoAutenticacao(turnoId, instante)
        val codigoOutroTurno = GeradorComprovanteCheckin.calcularCodigoAutenticacao("outro-turno", instante)

        assertEquals(codigo1, codigo2)
        assertTrue(codigo1 != codigoOutroTurno)
    }

    @Test
    fun `texto de compartilhamento contem codigo, horario, status e identificador do turno`() {
        val coordenada = Coordenada(latitude = -15.7942, longitude = -47.8822)
        val comprovante = GeradorComprovanteCheckin.gerar(
            turnoId = turnoId,
            registradoEm = instante,
            tipoVerificacao = TipoVerificacaoCheckin.GEOLOCALIZADO,
            coordenada = coordenada,
        )

        val texto = comprovante.textoCompartilhamento()

        assertTrue(texto.contains("Comprovante de Check-in · Frila"))
        assertTrue(texto.contains(comprovante.codigoAutenticacao))
        assertTrue(texto.contains("Geolocalizado na vaga"))
        assertTrue(texto.contains("-15.794, -47.882"))
        assertTrue(texto.contains(turnoId))
    }
}
