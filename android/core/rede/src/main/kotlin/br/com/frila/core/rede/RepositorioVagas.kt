package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.regra.instanteDoServidor
import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.time.Instant
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerializationException
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

data class ResultadoVagas(val vagas: List<VagaAbertaDto>, val emCache: Boolean)

/** O snapshot não confirma cancelamentos remotos; só rede pode confirmar disponibilidade. */
fun VagaAbertaDto.aindaDisponivelEm(instante: Instant): Boolean =
    posicoesAbertas > 0 && runCatching { instanteDoServidor(fimEm).isAfter(instante) }.getOrDefault(false)

/**
 * Fallback só para SEM_REDE; invalidação é definitiva e não espera uma chamada de rede. [buscarNaRede] é a primeira página do
 * feed, a única que vai para o cache; as seguintes ([proximaPagina]) vêm só da rede e nunca o tocam.
 */
class RepositorioVagas(
    private val arquivoCache: File?,
    private val agora: () -> Instant = Instant::now,
    /** A página a partir de um deslocamento. Nulo: este repositório não pagina (quem chama vai direto ao serviço). */
    private val buscarPaginaNaRede: (suspend (deslocamento: Int) -> List<VagaAbertaDto>)? = null,
    private val buscarNaRede: suspend () -> List<VagaAbertaDto>,
) {
    private val mutex = Mutex()
    private val bloqueio = Any()
    private var invalidado = false
    private var memoria: List<VagaAbertaDto>? = null
    private var aoInvalidar: (() -> Unit)? = null

    fun observarInvalidacao(acao: () -> Unit) = synchronized(bloqueio) {
        if (invalidado) acao() else aoInvalidar = acao
    }

    /** Serializa publicação no feed com o descarte, inclusive quando a rede termina ao sair. */
    fun usarSeValido(acao: () -> Unit) = synchronized(bloqueio) { if (!invalidado) acao() }

    fun invalidar() = synchronized(bloqueio) {
        invalidado = true
        memoria = null
        aoInvalidar?.invoke()
        aoInvalidar = null
        arquivoCache?.let { if (it.exists() && !it.delete()) throw IOException("Não foi possível apagar o cache de vagas") }
    }

    suspend fun obterCache(): ResultadoVagas? = withContext(Dispatchers.IO) {
        synchronized(bloqueio) {
            if (invalidado) return@synchronized null
            val cache = memoria ?: lerDisco() ?: return@synchronized null
            memoria = cache.filter { it.aindaDisponivelEm(agora()) }
            ResultadoVagas(memoria!!, emCache = true)
        }
    }

    suspend fun listar(): ResultadoVagas = mutex.withLock {
        synchronized(bloqueio) { verificarValidade() }
        val vagas = try {
            buscarNaRede()
        } catch (erro: ErroDaApi) {
            if (erro.codigo != CodigoErroAPI.SEM_REDE) throw erro
            return@withLock obterCache() ?: throw erro
        }
        withContext(Dispatchers.IO) {
            synchronized(bloqueio) {
                verificarValidade()
                memoria = vagas.toList()
                gravarDisco(vagas)
                ResultadoVagas(vagas, emCache = false)
            }
        }
    }

    /**
     * A página seguinte do feed, a partir de [deslocamento], só da rede: sem cache e sem fallback offline (o erro sobe). Depois de
     * [invalidar] (a sessão acabou), não pede nem devolve nada: lança `CancellationException`, como [listar]. `null` se este
     * repositório não pagina.
     */
    suspend fun proximaPagina(deslocamento: Int): List<VagaAbertaDto>? {
        val buscar = buscarPaginaNaRede ?: return null
        synchronized(bloqueio) { verificarValidade() }
        val pagina = buscar(deslocamento)
        synchronized(bloqueio) { verificarValidade() }
        return pagina
    }

    private fun verificarValidade() {
        if (invalidado) throw CancellationException("Cache descartado ao encerrar a sessão")
    }

    private fun lerDisco(): List<VagaAbertaDto>? = try {
        arquivoCache?.let { Json.decodeFromString<List<VagaAbertaDto>>(it.readText()) }
    } catch (_: IOException) { null } catch (_: SerializationException) { null }

    private fun gravarDisco(vagas: List<VagaAbertaDto>) {
        val arquivo = arquivoCache ?: return
        var temporario: File? = null
        try {
            val destino = arquivo.absoluteFile
            destino.parentFile.mkdirs()
            temporario = File.createTempFile("vagas-", ".tmp", destino.parentFile)
            temporario.writeText(Json.encodeToString(vagas))
            Files.move(temporario.toPath(), destino.toPath(), StandardCopyOption.REPLACE_EXISTING)
        } catch (_: IOException) {
            // Falha de persistência não esconde resposta online; memória continua válida.
        } finally { temporario?.delete() }
    }
}
