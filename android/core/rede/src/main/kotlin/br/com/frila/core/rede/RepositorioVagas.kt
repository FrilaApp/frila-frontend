package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.Coordenada
import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerializationException
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

data class ResultadoVagas(val vagas: List<VagaAbertaDto>, val emCache: Boolean)

/**
 * Leitura com fallback apenas para SEM_REDE. Arquivo nulo mantém somente memória.
 * O app fornece arquivo privado separado por sessão; distâncias em cache são da última consulta.
 */
class RepositorioVagas(
    private val arquivoCache: File?,
    private val buscarNaRede: suspend (Coordenada?) -> List<VagaAbertaDto>,
) {
    private val mutex = Mutex()
    private var memoria: List<VagaAbertaDto>? = null

    suspend fun obterCache(): ResultadoVagas? = mutex.withLock {
        val cache = memoria ?: lerDisco() ?: return@withLock null
        memoria = cache
        ResultadoVagas(cache, emCache = true)
    }

    suspend fun listar(coordenada: Coordenada? = null): ResultadoVagas = mutex.withLock {
        val vagas = try {
            buscarNaRede(coordenada)
        } catch (erro: ErroDaApi) {
            if (erro.codigo != CodigoErroAPI.SEM_REDE) throw erro
            val cache = memoria ?: lerDisco() ?: throw erro
            memoria = cache
            return@withLock ResultadoVagas(cache, emCache = true)
        }
        memoria = vagas.toList()
        gravarDisco(vagas)
        ResultadoVagas(vagas, emCache = false)
    }

    private suspend fun lerDisco(): List<VagaAbertaDto>? = withContext(Dispatchers.IO) {
        val arquivo = arquivoCache ?: return@withContext null
        try {
            Json.decodeFromString<List<VagaAbertaDto>>(arquivo.readText())
        } catch (_: IOException) {
            null
        } catch (_: SerializationException) {
            null
        }
    }

    private suspend fun gravarDisco(vagas: List<VagaAbertaDto>) = withContext(Dispatchers.IO) {
        val arquivo = arquivoCache ?: return@withContext
        var temporario: File? = null
        try {
            val destino = arquivo.absoluteFile
            destino.parentFile.mkdirs()
            temporario = File.createTempFile("vagas-", ".tmp", destino.parentFile)
            temporario.writeText(Json.encodeToString(vagas))
            Files.move(temporario.toPath(), destino.toPath(), StandardCopyOption.REPLACE_EXISTING)
        } catch (_: IOException) {
            // Falha de persistência não esconde resposta online; o cache em memória continua válido.
        } finally {
            temporario?.delete()
        }
    }
}
