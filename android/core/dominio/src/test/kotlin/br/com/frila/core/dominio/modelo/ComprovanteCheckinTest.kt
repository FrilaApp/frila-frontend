package br.com.frila.core.dominio.modelo

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.time.Instant

class ComprovanteCheckinTest {

    private val turnoId = "test-turno-1234"
    private val instante = Instant.parse("2026-10-27T15:30:00Z")

    @Test
    fun `gera comprovante geolocalizado com hash e horario`() {
        val comprovante = GeradorComprovanteCheckin.gerar(
            turnoId = turnoId,
            registradoEm = instante,
            tipoVerificacao = TipoVerificacaoCheckin.GEOLOCALIZADO,
        )

        assertEquals(turnoId, comprovante.turnoId)
        assertEquals(instante, comprovante.registradoEm)
        assertEquals(TipoVerificacaoCheckin.GEOLOCALIZADO, comprovante.tipoVerificacao)
        assertEquals("CHK-9945BC73", comprovante.codigoAutenticacao)
        assertEquals("27/10/2026 12:30:00", comprovante.horarioFormatado())
        assertTrue(comprovante.codigoAutenticacao.startsWith("CHK-"))
        assertEquals(12, comprovante.codigoAutenticacao.length) // CHK- (4) + 8 hex chars = 12
    }

    @Test
    fun `gera comprovante manual pendente`() {
        val comprovante = GeradorComprovanteCheckin.gerar(
            turnoId = turnoId,
            registradoEm = instante,
            tipoVerificacao = TipoVerificacaoCheckin.MANUAL_PENDENTE,
        )

        assertEquals(TipoVerificacaoCheckin.MANUAL_PENDENTE, comprovante.tipoVerificacao)
        assertTrue(comprovante.codigoAutenticacao.startsWith("CHK-"))
    }

    @Test
    fun `gera comprovante manual confirmado pelo contratante`() {
        val comprovante = GeradorComprovanteCheckin.gerar(
            turnoId = turnoId,
            registradoEm = instante,
            tipoVerificacao = TipoVerificacaoCheckin.MANUAL_CONFIRMADO,
        )

        assertEquals(TipoVerificacaoCheckin.MANUAL_CONFIRMADO, comprovante.tipoVerificacao)
        assertEquals("Check-in manual confirmado pelo contratante", comprovante.tipoVerificacao.descricao)
        val texto = comprovante.textoCompartilhamento()
        assertTrue(texto.contains("Status: Check-in manual confirmado pelo contratante"))
    }

    @Test
    fun `gera comprovante sem verificacao e texto de compartilhamento nao afirma presenca verificada`() {
        val comprovante = GeradorComprovanteCheckin.gerar(
            turnoId = turnoId,
            registradoEm = instante,
            tipoVerificacao = TipoVerificacaoCheckin.NAO_VERIFICADO,
        )

        assertEquals(TipoVerificacaoCheckin.NAO_VERIFICADO, comprovante.tipoVerificacao)
        assertEquals("Sem verificação", comprovante.tipoVerificacao.descricao)
        val texto = comprovante.textoCompartilhamento()
        assertTrue(texto.contains("Status: Sem verificação"))
        assertTrue(!texto.contains("Geolocalizado"))
        assertTrue(!texto.contains("confirmado"))
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
    fun `texto de compartilhamento contem codigo, horario, status e identificador do turno, e nunca a posicao`() {
        val comprovante = GeradorComprovanteCheckin.gerar(
            turnoId = turnoId,
            registradoEm = instante,
            tipoVerificacao = TipoVerificacaoCheckin.GEOLOCALIZADO,
        )

        val texto = comprovante.textoCompartilhamento()

        assertTrue(texto.contains("Comprovante de Check-in · Frila"))
        assertTrue(texto.contains(comprovante.codigoAutenticacao))
        assertTrue(texto.contains("Geolocalizado na vaga"))
        assertTrue(texto.contains(turnoId))
        assertEquals(
            listOf("Comprovante de Check-in · Frila", "Código: ${comprovante.codigoAutenticacao}", "Horário: 27/10/2026 12:30:00",
                "Status: Geolocalizado na vaga", "Turno: $turnoId"),
            texto.lines(),
        )
    }

    @Test
    fun `hora desconhecida: o comprovante existe, sem hora inventada, com codigo proprio`() {
        val semHora = GeradorComprovanteCheckin.gerar(turnoId, null, TipoVerificacaoCheckin.GEOLOCALIZADO)
        val comHora = GeradorComprovanteCheckin.gerar(turnoId, instante, TipoVerificacaoCheckin.GEOLOCALIZADO)

        assertEquals(null, semHora.registradoEm)
        assertEquals(ComprovanteCheckin.HORARIO_INDISPONIVEL, semHora.horarioFormatado())
        assertTrue(semHora.textoCompartilhamento().contains("Horário: indisponível"))
        assertTrue(semHora.codigoAutenticacao.startsWith("CHK-"))
        assertEquals(semHora.codigoAutenticacao, GeradorComprovanteCheckin.gerar(turnoId, null, TipoVerificacaoCheckin.GEOLOCALIZADO).codigoAutenticacao)
        assertTrue(semHora.codigoAutenticacao != comHora.codigoAutenticacao)
    }
}
