package br.com.frila.app

import br.com.frila.core.rede.FilaDeAcoes
import br.com.frila.core.rede.RepositorioVagas
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.Sessao
import br.com.frila.feature.perfil.CompressorDeFotoPerfil
import java.io.File
import java.io.IOException
import java.util.Collections
import java.util.WeakHashMap
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/** Inclui instâncias ainda em uso e arquivos de execuções anteriores. Sem Context, só memória. */
internal class CacheVagasDaSessao(
    private val raiz: File?,
    private val limparTelemetria: () -> Unit = {},
    /** `filesDir`, onde ficam os arquivos `avatar_perfil_*`: a foto é da conta que saiu e não pode sobrar para a próxima (#793). */
    private val diretorioDosAvatares: File? = null,
) {
    private val repositorios = Collections.newSetFromMap(WeakHashMap<RepositorioVagas, Boolean>())

    /** A fila de ações sem rede (A6) é da conta que saiu: sai junto com o cache, em logout, troca e expiração. */
    val filaDeAcoes = FilaDeAcoes(raiz?.resolve("acoes/fila.json"))

    @Synchronized fun criar(armazenamento: ArmazenamentoDeSessao, rede: suspend () -> List<VagaAbertaDto>): RepositorioVagas =
        RepositorioVagas(raiz?.let { arquivoCacheVagas(it, armazenamento.obterSessao()) }, buscarNaRede = rede)
            .also { repositorios.add(it) }

    @Synchronized fun limpar() {
        var falha: IOException? = null
        // A limpeza de telemetria também é silenciosa; nunca impede encerrar a sessão.
        try { limparTelemetria() } catch (_: IOException) { }
        repositorios.forEach { repositorio ->
            try { repositorio.invalidar() } catch (erro: IOException) { falha = erro }
        }
        repositorios.clear()
        raiz?.resolve("vagas")?.let {
            if (it.exists() && !it.deleteRecursively()) falha = IOException("Não foi possível apagar o cache de vagas")
        }
        try { filaDeAcoes.limpar() } catch (erro: IOException) { falha = erro }
        raiz?.resolve("acoes")?.let {
            if (it.exists() && !it.deleteRecursively()) falha = IOException("Não foi possível apagar a fila de ações")
        }
        // O destino guardado (tela inicial por papel) é da conta que saiu; a próxima avalia de novo.
        raiz?.resolve(DestinoGuardadoEmArquivo.PASTA)?.let {
            if (it.exists() && !it.deleteRecursively()) falha = IOException("Não foi possível apagar o destino guardado")
        }
        diretorioDosAvatares?.listFiles { arquivo ->
            arquivo.name.startsWith(CompressorDeFotoPerfil.PREFIXO_ARQUIVO_AVATAR) || arquivo.name == CompressorDeFotoPerfil.NOME_ARQUIVO_TEMPORARIO
        }?.forEach { if (!it.delete()) falha = IOException("Não foi possível apagar o avatar") }
        falha?.let { throw it }
    }
}

/** Um único ponto cobre logout, outra conta, exclusão e sessão que se tornou inválida. */
internal class SessaoComCacheVagas(
    internal val origem: ArmazenamentoDeSessao,
    private val cache: CacheVagasDaSessao,
) : ArmazenamentoDeSessao by origem {
    private val _encerramentos = MutableStateFlow(0)

    /**
     * Já limpou desde que a sessão sumiu: ler de novo sem sessão não limpa outra vez. Sem isto, quem relê a conta a cada
     * mudança da fila (a tela de check-in) limpava, mudava a fila e relia, em ciclo, depois do logout.
     */
    private var limpoSemSessao = false

    /** C0-8: soma um a cada sessão apagada (token recusado, Sair, exclusão), para a navegação voltar à entrada. */
    val encerramentos: StateFlow<Int> = _encerramentos.asStateFlow()

    override fun limparSessao() = synchronized(cache) {
        try { cache.limpar(); limpoSemSessao = true } finally {
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
        limpoSemSessao = false
    }
    /** Mesma troca de conta do [salvarSessao], mas só se a sessão guardada ainda é a [esperado]; senão não limpa nada. */
    override fun salvarSeRefreshTokenIgual(esperado: String, nova: Sessao): Boolean = synchronized(cache) {
        val anterior = origem.obterSessao()
        if (anterior?.refreshToken != esperado) return@synchronized false
        if (arquivoCacheVagas(File("."), anterior) != arquivoCacheVagas(File("."), nova)) cache.limpar()
        val gravou = origem.salvarSeRefreshTokenIgual(esperado, nova)
        if (gravou) limpoSemSessao = false
        gravou
    }

    override fun limparSeRefreshTokenIgual(esperado: String): Boolean = synchronized(cache) {
        if (origem.obterSessao()?.refreshToken != esperado) return@synchronized false
        limparSessao()
        true
    }

    override fun obterSessao(): Sessao? = synchronized(cache) {
        origem.obterSessao().also {
            when {
                it != null -> limpoSemSessao = false
                !limpoSemSessao -> { cache.limpar(); limpoSemSessao = true }
            }
        }
    }
    override fun estaAutenticado(): Boolean = obterSessao() != null
}
