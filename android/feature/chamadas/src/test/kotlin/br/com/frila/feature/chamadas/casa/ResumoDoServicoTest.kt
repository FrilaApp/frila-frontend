package br.com.frila.feature.chamadas.casa

import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.ServicoNoPerfilDto
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Test

/**
 * Cartão a4VXONgE (item 257): `resumoDoServico` (`Formatacao.kt`) e `unidadeDoServico` (`TextosChamadaCasa.kt`) em paridade com
 * `TextosDosServicos.swift:12-36`. Só o ramo da diária tinha teste (nas telas); apagar o ramo `a_combinar`, tirar
 * `horasIncluidas != null` (a tela mostraria "diária de null h"), trocar "Por pessoa" e trocar o separador " • " passavam.
 * O valor sai de `Dinheiro.formatado()`, com espaço sem quebra depois do "R$" (`U+00A0`).
 *
 * JUnit: nenhum método devolve valor (um `@Test` que devolve valor é ignorado).
 */
class ResumoDoServicoTest {

    private val garcom = FuncaoDto("f1", "Garçom", "Salão")

    private fun servico(unidade: String, valor: Long? = null, horas: Int? = null) =
        ServicoNoPerfilDto(funcao = garcom, unidade = unidade, valorCentavos = valor, horasIncluidas = horas)

    private val nbsp = " "

    // ---- diária ----

    @Test
    fun `diaria com valor e horas diz o valor por diaria de N h`() {
        assertEquals("R\$${nbsp}150,00 por diária de 8 h", resumoDoServico(servico("diaria", 15_000, 8)))
        assertEquals("R\$${nbsp}1.500,00 por diária de 12 h", resumoDoServico(servico("diaria", 150_000, 12)))
        assertEquals("R\$${nbsp}0,01 por diária de 1 h", resumoDoServico(servico("diaria", 1, 1)))
    }

    @Test
    fun `diaria sem horas incluidas nunca mostra null, cai no valor com a unidade`() {
        val resumo = resumoDoServico(servico("diaria", 15_000, horas = null))

        assertEquals("R\$${nbsp}150,00 • Diária", resumo)
        assertFalse(resumo!!.contains("null"))
        assertFalse(resumo.contains("por diária de"))
    }

    @Test
    fun `diaria sem valor mostra so a unidade, com ou sem horas`() {
        assertEquals("Diária", resumoDoServico(servico("diaria", valor = null, horas = null)))
        assertEquals("Diária", resumoDoServico(servico("diaria", valor = null, horas = 8)))
    }

    // ---- a combinar ----

    @Test
    fun `a combinar diz so A combinar, mesmo com valor guardado`() {
        assertEquals("A combinar", resumoDoServico(servico("a_combinar")))
        assertEquals("A combinar", resumoDoServico(servico("a_combinar", valor = 1_000)))
        assertEquals("A combinar", resumoDoServico(servico("a_combinar", valor = 1_000, horas = 8)))
    }

    // ---- as outras unidades: valor, separador e unidade ----

    @Test
    fun `com valor, o resumo e o valor, um ponto no meio com espacos e a unidade`() {
        assertEquals("R\$${nbsp}40,00 • Hora", resumoDoServico(servico("hora", 4_000)))
        assertEquals("R\$${nbsp}500,00 • Evento", resumoDoServico(servico("evento", 50_000)))
        assertEquals("R\$${nbsp}900,00 • Pacote", resumoDoServico(servico("pacote", 90_000)))
        assertEquals("R\$${nbsp}60,00 • Por pessoa", resumoDoServico(servico("por_pessoa", 6_000)))
    }

    @Test
    fun `o separador e exatamente espaco, bolinha U+2022, espaco`() {
        val resumo = resumoDoServico(servico("hora", 4_000))!!

        assertEquals(" • ", resumo.substring(resumo.indexOf('•') - 1, resumo.indexOf('•') + 2))
        assertEquals(2, resumo.split(" • ").size, "um único separador")
        assertFalse(resumo.contains(" - "))
        assertFalse(resumo.contains(" · "))
    }

    @Test
    fun `sem valor, o resumo e so a unidade`() {
        assertEquals("Hora", resumoDoServico(servico("hora")))
        assertEquals("Evento", resumoDoServico(servico("evento")))
        assertEquals("Pacote", resumoDoServico(servico("pacote")))
        assertEquals("Por pessoa", resumoDoServico(servico("por_pessoa")))
    }

    @Test
    fun `unidade que o app nao conhece aparece como veio, com ou sem valor`() {
        assertEquals("R\$${nbsp}1,00 • quinzena", resumoDoServico(servico("quinzena", 100)))
        assertEquals("quinzena", resumoDoServico(servico("quinzena")))
    }

    // ---- unidadeDoServico ----

    @Test
    fun `os rotulos das unidades sao os do iOS`() {
        assertEquals("Hora", TextosChamadaCasa.unidadeDoServico("hora"))
        assertEquals("Diária", TextosChamadaCasa.unidadeDoServico("diaria"))
        assertEquals("Evento", TextosChamadaCasa.unidadeDoServico("evento"))
        assertEquals("Pacote", TextosChamadaCasa.unidadeDoServico("pacote"))
        assertEquals("Por pessoa", TextosChamadaCasa.unidadeDoServico("por_pessoa"))
        assertEquals("A combinar", TextosChamadaCasa.unidadeDoServico("a_combinar"))
    }

    @Test
    fun `unidade desconhecida volta como veio, sem maiuscula nem traducao`() {
        assertEquals("quinzena", TextosChamadaCasa.unidadeDoServico("quinzena"))
        assertEquals("", TextosChamadaCasa.unidadeDoServico(""))
        assertEquals("HORA", TextosChamadaCasa.unidadeDoServico("HORA"))
    }
}
