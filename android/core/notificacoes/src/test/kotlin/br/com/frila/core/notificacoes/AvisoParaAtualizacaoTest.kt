package br.com.frila.core.notificacoes

import br.com.frila.core.dominio.regra.AtualizacaoAutomatica
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/** O push da conta ativa sinaliza as listas; o de outra conta (neutralizado, RN15) não mexe em lista nenhuma (HaRJJ0L0). */
class AvisoParaAtualizacaoTest {

    private fun notificacao(neutralizada: Boolean) = NotificacaoParaExibir(
        canal = GerenciadorDeCanais.CANAL_SISTEMA, titulo = "Frila", corpo = "x", vagaId = null, neutralizada = neutralizada,
        silenciada = false, chamadaId = null, turnoId = null,
    )

    private fun atualizacaoComSessao() = AtualizacaoAutomatica(sessao = { "vinculo-1" })

    @Test
    fun `push da conta ativa sobe o contador de avisos`() {
        val atualizacao = atualizacaoComSessao()
        AvisoParaAtualizacao.sinalizar(notificacao(neutralizada = false), atualizacao)
        assertEquals(1, atualizacao.avisos.value)
    }

    @Test
    fun `push neutralizado de outra conta nao conta`() {
        val atualizacao = atualizacaoComSessao()
        AvisoParaAtualizacao.sinalizar(notificacao(neutralizada = true), atualizacao)
        assertEquals(0, atualizacao.avisos.value)
    }

    @Test
    fun `sem sessao o aviso nao conta`() {
        val atualizacao = AtualizacaoAutomatica(sessao = { null })
        AvisoParaAtualizacao.sinalizar(notificacao(neutralizada = false), atualizacao)
        assertEquals(0, atualizacao.avisos.value)
    }
}
