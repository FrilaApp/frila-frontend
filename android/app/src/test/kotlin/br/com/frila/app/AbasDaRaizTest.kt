package br.com.frila.app

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

/** As abas das telas raiz espelham o iOS: quatro para o profissional, duas para a casa. */
class AbasDaRaizTest {

    private val casa = PapelDaRaiz.Contratante(rotaDeMinhasVagas = "minhas_vagas/casa-1?nomeEstabelecimento=Bar")

    @Test
    fun `profissional tem Vagas, Meus turnos, Candidaturas e Conta, nesta ordem`() {
        val abas = abasDaRaiz(PapelDaRaiz.Profissional)

        assertEquals(listOf("Vagas", "Meus turnos", "Candidaturas", "Conta"), abas.map { it.rotulo })
        assertEquals(listOf(Rotas.FEED, Rotas.MEUS_TURNOS, Rotas.MINHAS_CANDIDATURAS, Rotas.PERFIL), abas.map { it.rota })
    }

    @Test
    fun `casa tem Minhas vagas e Conta, e a primeira leva a casa em uso`() {
        val abas = abasDaRaiz(casa)

        assertEquals(listOf("Minhas vagas", "Conta"), abas.map { it.rotulo })
        assertEquals("minhas_vagas/casa-1?nomeEstabelecimento=Bar", abas.first().rota)
        assertEquals(Rotas.MINHAS_VAGAS, abas.first().padrao)
    }

    @Test
    fun `a aba ativa sai do padrao da rota, e fora das raizes nao ha barra`() {
        val doProfissional = abasDaRaiz(PapelDaRaiz.Profissional)

        assertEquals(0, abaDaRota(doProfissional, Rotas.FEED))
        assertEquals(3, abaDaRota(doProfissional, Rotas.PERFIL))
        assertEquals(0, abaDaRota(abasDaRaiz(casa), Rotas.MINHAS_VAGAS))
        assertNull(abaDaRota(doProfissional, Rotas.DETALHE))
        assertNull(abaDaRota(doProfissional, Rotas.ENTRADA))
        assertNull(abaDaRota(abasDaRaiz(casa), Rotas.FEED))
        assertNull(abaDaRota(doProfissional, null))
    }

    @Test
    fun `sem a abertura, so as raizes do profissional dizem o papel - o Perfil serve aos dois e nao diz`() {
        assertEquals(PapelDaRaiz.Profissional, papelPelaRota(Rotas.MEUS_TURNOS))
        assertEquals(PapelDaRaiz.Profissional, papelPelaRota(Rotas.MINHAS_CANDIDATURAS))
        assertNull(papelPelaRota(Rotas.PERFIL))
        assertNull(papelPelaRota(Rotas.MINHAS_VAGAS))
        assertNull(papelPelaRota(null))
    }
}
