package br.com.frila.app

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.RepositorioVagas
import br.com.frila.core.rede.ResultadoVagas
import br.com.frila.core.seguranca.Sessao
import java.io.File
import java.util.Base64
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

class ArquivoCacheVagasTest {
    @TempDir lateinit var raiz: File
    private fun sessao(pessoa: String, renovacao: String = "renovacao-teste", vinculo: String? = null): Sessao {
        val corpo = Base64.getUrlEncoder().withoutPadding().encodeToString("{\"sub\":\"$pessoa\"}".toByteArray())
        return Sessao("cabecalho.$corpo.assinatura-sintetica", renovacao, "bearer", 60, vinculo)
    }

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
}
