package br.com.frila.app

import br.com.frila.core.rede.AcaoPendente
import br.com.frila.core.rede.TipoAcaoPendente
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import java.io.File
import java.util.Base64
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

/** A6.1: a fila de ações sem rede sai com a sessão: logout, troca de conta e expiração. O refresh da mesma conta a preserva. */
class FilaDeAcoesDaSessaoTest {
    @TempDir lateinit var raiz: File
    private val acao = AcaoPendente(TipoAcaoPendente.CHECKIN, "conta-sintetica", "2026-11-23T12:00:00Z", turnoId = "turno")
    private fun sessao(pessoa: String, renovacao: String = "renovacao-teste"): Sessao {
        val corpo = Base64.getUrlEncoder().withoutPadding().encodeToString("{\"sub\":\"$pessoa\"}".toByteArray())
        return Sessao("cabecalho.$corpo.assinatura-sintetica", renovacao, "bearer", 60, null)
    }
    private fun montar(): Pair<CacheVagasDaSessao, SessaoComCacheVagas> {
        val cache = CacheVagasDaSessao(raiz)
        val armazenamento = SessaoComCacheVagas(ArmazenamentoDeSessaoEmMemoria(), cache)
        armazenamento.salvarSessao(sessao("pessoa-a"))
        cache.filaDeAcoes.enfileirar(acao)
        return cache to armazenamento
    }
    private val arquivo get() = File(raiz, "acoes/fila.json")

    @Test fun `a fila fica em arquivo privado do app e sobrevive a uma nova instancia`() {
        val (cache, _) = montar()
        assertTrue(arquivo.isFile)
        assertEquals(listOf(acao), CacheVagasDaSessao(raiz).filaDeAcoes.pendentes())
        assertEquals(listOf(acao), cache.filaDeAcoes.pendentes())
    }

    @Test fun `logout limpa a fila e apaga o arquivo`() {
        val (cache, armazenamento) = montar()
        armazenamento.limparSessao()
        assertTrue(cache.filaDeAcoes.pendentes().isEmpty())
        assertFalse(File(raiz, "acoes").exists())
    }

    @Test fun `outra conta entrando limpa a fila e o refresh da mesma conta a preserva`() {
        val (cache, armazenamento) = montar()
        armazenamento.salvarSessao(sessao("pessoa-a", "renovacao-nova"))
        assertEquals(listOf(acao), cache.filaDeAcoes.pendentes())
        armazenamento.salvarSessao(sessao("pessoa-b"))
        assertTrue(cache.filaDeAcoes.pendentes().isEmpty())
        assertFalse(File(raiz, "acoes").exists())
    }

    @Test fun `limpar o cache direto, como na expiracao, tambem apaga a fila`() {
        val (cache, _) = montar()
        cache.limpar()
        assertTrue(cache.filaDeAcoes.pendentes().isEmpty())
        assertFalse(arquivo.exists())
    }
}
