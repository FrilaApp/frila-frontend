package br.com.frila.feature.vagas.detalhe

import br.com.frila.core.rede.InclusosDto
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/** "O que está incluso" do detalhe da vaga (DLjTVc2e, item 153): a lista e a ordem do `itensInclusos` do iOS. */
class ItensInclusosTest {

    private fun inclusos(refeicao: Boolean = true, transporte: Boolean = false, material: Boolean = false) =
        InclusosDto(incluiRefeicao = refeicao, incluiTransporte = transporte, exigeMaterialProprio = material)

    private fun pares(vararg itens: Pair<String, String>) = itens.map { ItemIncluso(it.first, it.second) }

    @Test
    fun `sem o detalhe so os tres itens do feed, nessa ordem`() {
        assertEquals(
            pares("Refeição" to "Sim", "Transporte" to "Não", "Material" to "Não precisa levar"),
            itensInclusos(inclusos(), detalhe = null),
        )
    }

    @Test
    fun `com o detalhe, quem recebe, o rateio e as observacoes depois, na ordem do iOS`() {
        val detalhe = vagaDoServidor(participaRateio = true, observacoes = "Chegar 15 minutos antes")
        assertEquals(
            pares(
                "Refeição" to "Sim", "Transporte" to "Não", "Material" to "Não precisa levar",
                "Quem recebe" to "Procure a gerente no balcão", "Rateio dos 10%" to "Sim", "Observações" to "Chegar 15 minutos antes",
            ),
            itensInclusos(inclusos(), detalhe),
        )
    }

    @Test
    fun `material exigido diz Precisa levar, e transporte incluso diz Sim`() {
        val itens = itensInclusos(inclusos(refeicao = false, transporte = true, material = true), detalhe = null)
        assertEquals(pares("Refeição" to "Não", "Transporte" to "Sim", "Material" to "Precisa levar"), itens)
    }

    @Test
    fun `o rateio nao dito pela casa e observacoes em branco ficam de fora`() {
        val detalhe = vagaDoServidor(participaRateio = null, observacoes = "   ")
        assertEquals(
            pares("Refeição" to "Sim", "Transporte" to "Não", "Material" to "Não precisa levar", "Quem recebe" to "Procure a gerente no balcão"),
            itensInclusos(inclusos(), detalhe),
        )
    }

    @Test
    fun `o rateio Nao aparece como Nao`() {
        val detalhe = vagaDoServidor(participaRateio = false, observacoes = null)
        assertEquals("Não", itensInclusos(inclusos(), detalhe).single { it.rotulo == "Rateio dos 10%" }.valor)
    }
}
