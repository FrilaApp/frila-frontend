package br.com.frila.app

import br.com.frila.core.rede.AcaoPendente
import br.com.frila.core.rede.TipoAcaoPendente
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import java.io.File
import java.util.Base64
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

/**
 * Cartão amdmG1fd (item 266): uma guarda que falha ao esvaziar (`limparGuardas`) não aborta o `limpar()`. Sem o `try/catch` de
 * `CacheVagasDaSessao.kt:48`, a exceção saía antes de apagar `vagas/`, a fila e o destino guardado: a sessão sumia, mas o cache da conta
 * que saiu ficava no aparelho. A guarda lança uma exceção que não é `IOException`, como um estado inesperado de uma tela.
 */
class LimpezaComGuardaFalhandoTest {

    @TempDir lateinit var raiz: File

    private fun sessaoDe(pessoa: String): ArmazenamentoDeSessaoEmMemoria {
        val corpo = Base64.getUrlEncoder().withoutPadding().encodeToString("{\"sub\":\"$pessoa\"}".toByteArray())
        return ArmazenamentoDeSessaoEmMemoria().also { it.salvarSessao(Sessao("cabecalho.$corpo.assinatura-sintetica", "renovacao", "bearer", 60)) }
    }

    @Test
    fun `uma guarda que lanca nao impede apagar as vagas, a fila e o destino da conta que saiu`() {
        var guardasChamadas = 0
        val cache = CacheVagasDaSessao(raiz, limparGuardas = {
            guardasChamadas++
            throw IllegalStateException("guarda sintética falhou")
        })
        val sessao = sessaoDe("pessoa-a")
        val arquivoDasVagas = checkNotNull(arquivoCacheVagas(raiz, sessao.obterSessao())) { "a sessão tem identidade: há arquivo de vagas" }
        arquivoDasVagas.parentFile.mkdirs()
        arquivoDasVagas.writeText("[]")
        cache.filaDeAcoes.enfileirar(AcaoPendente(TipoAcaoPendente.CHECKIN, "pessoa-a", "2026-11-23T12:00:00Z", turnoId = "turno"))
        DestinoGuardadoEmArquivo(raiz, sessao).salvar(DestinoDaConta.Profissional)
        // O cenário existe antes de limpar: sem isto, as asserções de baixo passariam com nada a apagar.
        assertTrue(arquivoDasVagas.exists())
        assertTrue(File(raiz, "acoes/fila.json").exists())
        assertNotNull(DestinoGuardadoEmArquivo(raiz, sessao).obter())

        cache.limpar()

        assertEquals(1, guardasChamadas, "a guarda foi chamada (e lançou)")
        assertFalse(File(raiz, "vagas").exists(), "o cache de vagas da conta que saiu fica no aparelho")
        assertTrue(cache.filaDeAcoes.pendentes().isEmpty())
        assertFalse(File(raiz, "acoes").exists(), "a fila da conta que saiu fica no aparelho")
        assertNull(DestinoGuardadoEmArquivo(raiz, sessao).obter(), "o destino da conta que saiu fica no aparelho")
    }
}
