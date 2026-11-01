package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
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
 * Primeira fatia do modo offline: leitura com fallback apenas para SEM_REDE.
 * O chamador deve fornecer arquivo privado por sessão/consulta e removê-lo ao sair.
 * Ainda não ligado ao feed: coordenadas e isolamento de sessão serão integrados nessa etapa.
 */
class RepositorioVagas(
    private val arquivoCache: File,
    private val buscarNaRede: suspend () -> List<VagaAbertaDto>,
) {
    private val mutex = Mutex()
    private var memoria: List<VagaAbertaDto>? = null

    suspend fun listar(): ResultadoVagas = mutex.withLock {
        val vagas = try {
            buscarNaRede()
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
        try {
            Json.decodeFromString<List<VagaAbertaDto>>(arquivoCache.readText())
        } catch (_: IOException) {
            null
        } catch (_: SerializationException) {
            null
        }
    }

    private suspend fun gravarDisco(vagas: List<VagaAbertaDto>) = withContext(Dispatchers.IO) {
        var temporario: File? = null
        try {
            val destino = arquivoCache.absoluteFile
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
