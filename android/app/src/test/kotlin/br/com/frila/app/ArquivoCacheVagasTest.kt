package br.com.frila.app

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.RepositorioVagas
import br.com.frila.core.rede.ResultadoVagas
import br.com.frila.core.rede.*
import br.com.frila.core.seguranca.Sessao
import java.io.File
import java.util.Base64
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.async
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

class ArquivoCacheVagasTest {
    @TempDir lateinit var raiz: File
    private fun sessao(pessoa: String, renovacao: String = "renovacao-teste", vinculo: String? = null): Sessao {
        val corpo = Base64.getUrlEncoder().withoutPadding().encodeToString("{\"sub\":\"$pessoa\"}".toByteArray())
        return Sessao("cabecalho.$corpo.assinatura-sintetica", renovacao, "bearer", 60, vinculo)
    }

    private val vaga = VagaAbertaDto(
        "vaga-sintetica", FuncaoDto("funcao", "Atendimento", "Salão"),
        PerfilPublicoDto("local", "estabelecimento", "Local sintético",
            reputacao = ReputacaoDto(0, 0, turnosConsiderados = 0, turnosRealizados = 0)),
        java.time.Instant.now().plusSeconds(3600).toString(), java.time.Instant.now().plusSeconds(7200).toString(),
        "Local de teste", "Região de teste", 1.0, 12000, 1, InclusosDto(false, false, false), "selecao",
    )

    @Test fun `identidade do cache nao depende da renovacao nem do vinculo`() = runTest {
        val antes = sessao("pessoa-sintetica")
        RepositorioVagas(arquivoCacheVagas(raiz, antes)) { emptyList() }.listar()
        val depois = sessao("pessoa-sintetica", "renovacao-nova", "vinculo-novo")
        val reaberto = RepositorioVagas(arquivoCacheVagas(raiz, depois)) {
            throw ErroDaApi(CodigoErroAPI.SEM_REDE, "sem_rede", null, "Teste")
        }
        assertEquals(ResultadoVagas(emptyList(), true), reaberto.listar())
    }

    @Test fun `sem identidade valida nao persiste e contas distintas nao compartilham arquivo`() {
        assertNull(arquivoCacheVagas(raiz, null))
        assertNull(arquivoCacheVagas(raiz, Sessao("invalido", "teste", "bearer", 60)))
        val arquivo = arquivoCacheVagas(raiz, sessao("pessoa-a"))!!
        assertNotEquals(arquivo, arquivoCacheVagas(raiz, sessao("pessoa-b")))
        assertFalse(arquivo.name.contains("pessoa-a"))
    }
    @Test fun linceLogoutApagaArquivoDaConta() = runTest {
        val cache = CacheVagasDaSessao(raiz)
        val armazenamento = SessaoComCacheVagas(br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria(), cache)
        armazenamento.salvarSessao(sessao("pessoa-a"))
        val arquivo = arquivoCacheVagas(raiz, armazenamento.obterSessao())!!
        val repositorio = cache.criar(armazenamento) { listOf(vaga) }
        repositorio.listar()
        assertEquals(listOf(vaga), repositorio.obterCache()!!.vagas)
        val perfil = br.com.frila.feature.perfil.PerfilViewModel(
            io.mockk.mockk(relaxed = true), io.mockk.mockk(relaxed = true), armazenamento, escopo = this,
        )
        perfil.aoDeslogar()
        assertNull(armazenamento.obterSessao())
        assertFalse(arquivo.exists(), "Logout manteve arquivo persistido de vagas da conta")
        assertNull(repositorio.obterCache(), "Logout manteve cache na memória")
    }

    @Test fun linceReentradaDaMesmaContaNaoRecuperaCacheAposLogout() = runTest {
        val cache = CacheVagasDaSessao(raiz)
        val armazenamento = SessaoComCacheVagas(br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria(), cache)
        armazenamento.salvarSessao(sessao("pessoa-a"))
        cache.criar(armazenamento) { listOf(vaga) }.listar()
        br.com.frila.feature.perfil.PerfilViewModel(
            io.mockk.mockk(relaxed = true), io.mockk.mockk(relaxed = true), armazenamento, escopo = this,
        ).aoDeslogar()
        armazenamento.salvarSessao(sessao("pessoa-a", "renovacao-nova"))
        val reaberto = cache.criar(armazenamento) {
            throw ErroDaApi(CodigoErroAPI.SEM_REDE, "sem_rede", null, "Teste")
        }
        assertNull(reaberto.obterCache(), "Reentrada offline recuperou cache que sobreviveu ao logout")
    }

    @Test fun trocaDeContaDescartaDiscoMemoriaEFeedAnterior() = runTest {
        val cache = CacheVagasDaSessao(raiz)
        val armazenamento = SessaoComCacheVagas(br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria(), cache)
        armazenamento.salvarSessao(sessao("pessoa-a"))
        val arquivoA = arquivoCacheVagas(raiz, armazenamento.obterSessao())!!
        val repoA = cache.criar(armazenamento) { listOf(vaga) }
        repoA.listar()
        var invalidouFeed = false
        repoA.observarInvalidacao { invalidouFeed = true }
        armazenamento.salvarSessao(sessao("pessoa-b"))
        assertTrue(invalidouFeed)
        assertFalse(arquivoA.exists())
        assertNull(repoA.obterCache())
        assertNull(cache.criar(armazenamento) { listOf(vaga) }.obterCache())
        armazenamento.salvarSessao(sessao("pessoa-a"))
        assertNull(cache.criar(armazenamento) { listOf(vaga) }.obterCache())
    }

    @Test fun logoutImpedeRedePendenteDeRecriarArquivo() = runTest {
        val cache = CacheVagasDaSessao(raiz)
        val armazenamento = SessaoComCacheVagas(br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria(), cache)
        armazenamento.salvarSessao(sessao("pessoa-a"))
        val arquivo = arquivoCacheVagas(raiz, armazenamento.obterSessao())!!
        val iniciou = kotlinx.coroutines.CompletableDeferred<Unit>()
        val liberar = kotlinx.coroutines.CompletableDeferred<Unit>()
        val repo = cache.criar(armazenamento) { iniciou.complete(Unit); liberar.await(); listOf(vaga) }
        val pedido = async {
            try { repo.listar(); false } catch (_: kotlinx.coroutines.CancellationException) { true }
        }
        iniciou.await()
        armazenamento.limparSessao()
        liberar.complete(Unit)
        assertTrue(pedido.await(), "Rede pendente republicou dados após logout")
        assertFalse(arquivo.exists())
        assertNull(repo.obterCache())
    }

    @Test fun renovacaoDaMesmaContaPreservaCache() = runTest {
        val cache = CacheVagasDaSessao(raiz)
        val armazenamento = SessaoComCacheVagas(br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria(), cache)
        armazenamento.salvarSessao(sessao("pessoa-a"))
        val repo = cache.criar(armazenamento) { listOf(vaga) }
        repo.listar()
        armazenamento.salvarSessao(sessao("pessoa-a", "renovacao-nova"))
        assertNotNull(repo.obterCache())
        assertNotNull(cache.criar(armazenamento) { listOf(vaga) }.obterCache())
    }

}
