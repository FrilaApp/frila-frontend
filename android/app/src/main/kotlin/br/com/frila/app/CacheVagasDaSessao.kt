package br.com.frila.app

import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.rede.RepositorioVagas
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.Sessao
import java.io.File
import java.io.IOException
import java.util.Collections
import java.util.WeakHashMap
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/** Inclui instâncias ainda em uso e arquivos de execuções anteriores. Sem Context, só memória. */
internal class CacheVagasDaSessao(private val raiz: File?) {
    private val repositorios = Collections.newSetFromMap(WeakHashMap<RepositorioVagas, Boolean>())
    @Synchronized fun criar(armazenamento: ArmazenamentoDeSessao, rede: suspend (Coordenada?) -> List<VagaAbertaDto>): RepositorioVagas =
        RepositorioVagas(raiz?.let { arquivoCacheVagas(it, armazenamento.obterSessao()) }, buscarNaRede = rede)
            .also { repositorios.add(it) }

    @Synchronized fun limpar() {
        var falha: IOException? = null
        repositorios.forEach { repositorio ->
            try { repositorio.invalidar() } catch (erro: IOException) { falha = erro }
        }
        repositorios.clear()
        raiz?.resolve("vagas")?.let {
            if (it.exists() && !it.deleteRecursively()) falha = IOException("Não foi possível apagar o cache de vagas")
        }
        // O destino guardado (tela inicial por papel) é da conta que saiu; a próxima avalia de novo.
        raiz?.resolve(DestinoGuardadoEmArquivo.PASTA)?.let {
            if (it.exists() && !it.deleteRecursively()) falha = IOException("Não foi possível apagar o destino guardado")
        }
        falha?.let { throw it }
    }
}

/** Um único ponto cobre logout, outra conta, exclusão e sessão que se tornou inválida. */
internal class SessaoComCacheVagas(
    internal val origem: ArmazenamentoDeSessao,
    private val cache: CacheVagasDaSessao,
) : ArmazenamentoDeSessao by origem {
    private val _encerramentos = MutableStateFlow(0)

    /** C0-8: soma um a cada sessão apagada (token recusado, Sair, exclusão), para a navegação voltar à entrada. */
    val encerramentos: StateFlow<Int> = _encerramentos.asStateFlow()

    override fun limparSessao() = synchronized(cache) {
        try { cache.limpar() } finally {
            origem.limparSessao()
            _encerramentos.update { it + 1 }
        }
    }
    override fun salvarSessao(sessao: Sessao) = synchronized(cache) {
        // Hash do sub é estável durante refresh; identidade desconhecida é tratada como troca.
        val anterior = arquivoCacheVagas(File("."), origem.obterSessao())
        val proxima = arquivoCacheVagas(File("."), sessao)
        if (anterior == null || anterior != proxima) cache.limpar()
        origem.salvarSessao(sessao)
    }
    override fun obterSessao(): Sessao? = synchronized(cache) {
        origem.obterSessao().also { if (it == null) cache.limpar() }
    }
    override fun estaAutenticado(): Boolean = obterSessao() != null
}
