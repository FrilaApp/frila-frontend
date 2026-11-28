package br.com.frila.feature.chamadas.casa

import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.MeuEstabelecimentoDto
import java.time.Instant
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class FolhaDeChamadaDaBuscaTest {

    private val agora = Instant.parse("2026-11-16T15:00:00Z")
    private val casa = MeuEstabelecimentoDto(
        id = "c1", nome = "Bistrô Ipê", tipo = "restaurante", endereco = "SCS Quadra 2",
        regiaoAdministrativa = "Plano Piloto", ponto = CoordenadaDto(-15.79, -47.88), papel = "administrador",
    )

    private fun validar(
        valor: String = "180",
        total: Boolean = true,
        inicio: String = "17/11/2026 12:00",
        fim: String = "17/11/2026 16:00",
        responsavel: String = "Bistrô Ipê",
        recado: String = "",
        funcao: String? = "f1",
        casa: MeuEstabelecimentoDto? = this.casa,
    ) = validarFolhaDaBusca(funcao, casa, valor, total, lerDataEHora(inicio)!!, lerDataEHora(fim)!!, responsavel, recado, agora)

    private fun falta(r: ResultadoDaFolha) = (r as ResultadoDaFolha.Falta).motivo

    @Test
    fun `campos completos montam o trabalho com a casa, o horario de Brasilia e o recado limpo`() {
        val pronto = validar(valor = "1.500,50", recado = "  Traga avental ") as ResultadoDaFolha.Pronto

        val t = pronto.trabalho
        assertEquals("f1", t.funcaoId)
        assertEquals(150050L, t.valorCentavos)
        assertEquals("SCS Quadra 2", t.local)
        assertEquals("Plano Piloto", t.regiaoAdministrativa)
        assertEquals(Instant.parse("2026-11-17T15:00:00Z"), t.inicio)
        assertEquals(Instant.parse("2026-11-17T19:00:00Z"), t.fim)
        assertEquals("Traga avental", pronto.recado)
        assertNull((validar() as ResultadoDaFolha.Pronto).recado)
    }

    @Test
    fun `cada regra devolve o seu motivo, na ordem do iOS`() {
        assertEquals(TextosChamadaCasa.FALTA_VALOR, falta(validar(valor = "")))
        assertEquals(TextosChamadaCasa.FALTA_VALOR, falta(validar(valor = "0")))
        assertEquals(TextosChamadaCasa.FALTA_CONFIRMAR_TOTAL, falta(validar(total = false)))
        assertEquals(TextosChamadaCasa.FALTA_RESPONSAVEL, falta(validar(responsavel = "  ")))
        // Item 261: início e término vêm dos seletores (instantes); a data digitada inválida só existe no filtro da busca (`lerDataEHora`).
        assertEquals(TextosChamadaCasa.FALTA_ANTECEDENCIA, falta(validar(inicio = "16/11/2026 13:00", fim = "16/11/2026 17:00")))
        assertEquals(TextosChamadaCasa.FALTA_DURACAO, falta(validar(fim = "17/11/2026 13:00")))
        assertEquals(TextosChamadaCasa.FALTA_DURACAO, falta(validar(fim = "18/11/2026 12:00")))
        assertEquals(TextosChamadaCasa.RECADO_LONGO, falta(validar(recado = "x".repeat(301))))
        assertEquals(TextosChamadaCasa.BUSCA_SEM_CASA, falta(validar(casa = null)))
        assertEquals(TextosChamadaCasa.BUSCA_SEM_CASA, falta(validar(funcao = null)))
    }

    @Test
    fun `os limites de 2 h de antecedencia e de 2 a 16 h de turno valem`() {
        assertTrue(validar(inicio = "16/11/2026 15:00", fim = "16/11/2026 17:00") is ResultadoDaFolha.Pronto)
        assertTrue(validar(inicio = "17/11/2026 12:00", fim = "18/11/2026 04:00") is ResultadoDaFolha.Pronto)
    }

    @Test
    fun `lerDataEHora aceita so o formato do fuso do DF`() {
        assertEquals(Instant.parse("2026-11-17T15:00:00Z"), lerDataEHora(" 17/11/2026 12:00 "))
        assertNull(lerDataEHora("2026-11-17 12:00"))
        assertNull(lerDataEHora("17/11/2026"))
        assertNull(lerDataEHora("32/11/2026 12:00"))
    }

    @Test
    fun `valores fora da faixa de referencia sao aceitos na validacao da folha`() {
        val baixo = validar(valor = "49,99") as ResultadoDaFolha.Pronto
        val alto = validar(valor = "2000,01") as ResultadoDaFolha.Pronto
        assertEquals(4999L, baixo.trabalho.valorCentavos)
        assertEquals(200001L, alto.trabalho.valorCentavos)
    }
}
