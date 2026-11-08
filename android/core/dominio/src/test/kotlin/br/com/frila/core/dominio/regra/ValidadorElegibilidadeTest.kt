package br.com.frila.core.dominio.regra

import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.dominio.modelo.EstadoTurno
import br.com.frila.core.dominio.modelo.Turno
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.time.LocalDateTime

class ValidadorElegibilidadeTest {

    private val profissional = Coordenada(-15.7801, -47.9292) // Brasília (Plano Piloto)
    private val vagaPerto = Coordenada(-15.8267, -47.9218) // ~5km (Águas Claras, aprox.)
    private val vagaLonge = Coordenada(-16.6869, -49.2648) // ~170km (Goiânia)

    @Test
    fun `distanciaDentroDoLimite aceita vaga dentro de 15km`() {
        assertTrue(ValidadorElegibilidade.distanciaDentroDoLimite(profissional, vagaPerto))
    }

    @Test
    fun `distanciaDentroDoLimite recusa vaga acima de 15km`() {
        assertFalse(ValidadorElegibilidade.distanciaDentroDoLimite(profissional, vagaLonge))
    }

    @Test
    fun `distanciaDentroDoLimite aceita exatamente no limite de 15km`() {
        // Ponto a exatamente 15.000km ao norte, pela inversão da própria fórmula de Haversine
        // (delta_lat_rad = distanciaKm / raioMedioTerraKm): distância medida = 14.999999999999936km.
        val deltaGraus = Math.toDegrees(15.0 / 6371.0)
        val noLimite = Coordenada(profissional.latitude + deltaGraus, profissional.longitude)

        assertEquals(15.0, profissional.distanciaKmAte(noLimite), 1e-9)
        assertTrue(ValidadorElegibilidade.distanciaDentroDoLimite(profissional, noLimite))
    }

    @Test
    fun `semSobreposicaoDeHorario true quando nao ha turno confirmado`() {
        val novo = turno(inicio = "2026-11-01T08:00", fim = "2026-11-01T14:00")

        assertTrue(ValidadorElegibilidade.semSobreposicaoDeHorario(emptyList(), novo))
    }

    @Test
    fun `semSobreposicaoDeHorario false quando ha turno confirmado no mesmo intervalo`() {
        val existente = turno(inicio = "2026-11-01T08:00", fim = "2026-11-01T14:00")
        val novo = turno(inicio = "2026-11-01T10:00", fim = "2026-11-01T18:00")

        assertFalse(ValidadorElegibilidade.semSobreposicaoDeHorario(listOf(existente), novo))
    }

    @Test
    fun `semSobreposicaoDeHorario true quando turnos sao adjacentes sem cruzar`() {
        val existente = turno(inicio = "2026-11-01T08:00", fim = "2026-11-01T14:00")
        val novo = turno(inicio = "2026-11-01T14:00", fim = "2026-11-01T20:00")

        assertTrue(ValidadorElegibilidade.semSobreposicaoDeHorario(listOf(existente), novo))
    }

    @Test
    fun `elegivel exige distancia e ausencia de sobreposicao ao mesmo tempo`() {
        val existente = turno(inicio = "2026-11-01T08:00", fim = "2026-11-01T14:00")
        val novoSemConflito = turno(inicio = "2026-11-01T15:00", fim = "2026-11-01T20:00")
        val novoComConflito = turno(inicio = "2026-11-01T10:00", fim = "2026-11-01T20:00")

        assertTrue(
            ValidadorElegibilidade.elegivel(profissional, vagaPerto, listOf(existente), novoSemConflito),
        )
        assertFalse(
            ValidadorElegibilidade.elegivel(profissional, vagaLonge, listOf(existente), novoSemConflito),
        )
        assertFalse(
            ValidadorElegibilidade.elegivel(profissional, vagaPerto, listOf(existente), novoComConflito),
        )
    }

    private fun turno(inicio: String, fim: String) = Turno(
        id = "turno-teste",
        vagaId = "vaga-teste",
        profissionalId = "profissional-teste",
        inicio = LocalDateTime.parse(inicio),
        fim = LocalDateTime.parse(fim),
        estado = EstadoTurno.AGENDADO,
    )
}
