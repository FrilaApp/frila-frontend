package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.MotivoOcorrencia
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CorpoDoEmailDeSuporteTest {

    @Test
    fun `o corpo leva turno, protocolo, motivo e o relato sem espacos nas pontas`() {
        val corpo = corpoDoEmailDeSuporte(
            turnoId = "turno-1",
            pedido = PedidoDeEmailDeSuporte("ABCD1234", MotivoOcorrencia.PROBLEMA_NO_LOCAL, "  Endereço errado.\n"),
        )

        assertEquals(
            """
            Identificação do turno:
            - ID: turno-1
            - Protocolo: #ABCD1234

            Motivo do chamado:
            Problema no local

            Relato:
            Endereço errado.
            """.trimIndent(),
            corpo,
        )
    }

    @Test
    fun `sem relato o corpo diz que nao houve, em vez de ficar em branco`() {
        val corpo = corpoDoEmailDeSuporte("t", PedidoDeEmailDeSuporte("P", MotivoOcorrencia.OUTRO, "   "))

        assertTrue(corpo.endsWith(TextosOcorrencia.RELATO_VAZIO))
    }

    @Test
    fun `o assunto leva o protocolo`() {
        assertEquals("Ocorrência no turno · protocolo #ABCD1234", TextosOcorrencia.assuntoDoEmail("ABCD1234"))
    }
}
