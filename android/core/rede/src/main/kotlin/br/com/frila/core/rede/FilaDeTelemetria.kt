package br.com.frila.core.rede

import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.time.Instant
import java.util.UUID
import kotlinx.coroutines.sync.Mutex
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
data class EventoDeTelemetriaPendente(
    val id: String = UUID.randomUUID().toString(),
    val contaId: String,
    val registro: RegistroDeEventoDto,
    val guardadoEm: String,
)

internal data class ContextoDaTelemetria(val contaId: String, val geracao: Long)

/** Arquivo privado fora do backup; só identificadores. O logout invalida também gravações em voo. */
class FilaDeTelemetria(private val arquivo: File?) {
    internal val reenvio = Mutex()
    private var geracao = 0L
    private var memoria: List<EventoDeTelemetriaPendente>? = null

    @Synchronized
    internal fun contexto(contaId: String?): ContextoDaTelemetria? = contaId?.let { ContextoDaTelemetria(it, geracao) }

    @Synchronized
    internal fun valido(contexto: ContextoDaTelemetria): Boolean = contexto.geracao == geracao

    @Synchronized
    fun eventosPendentes(): List<EventoDeTelemetriaPendente> {
        memoria?.let { return it.toList() }
        val salvos = try {
            arquivo?.takeIf { it.exists() }?.readText()?.let { Json.decodeFromString<List<EventoDeTelemetriaPendente>>(it) }
        } catch (_: kotlinx.serialization.SerializationException) { null }
        return (salvos ?: emptyList()).also { memoria = it }.toList()
    }

    @Synchronized
    internal fun guardar(contexto: ContextoDaTelemetria, registro: RegistroDeEventoDto, instante: Instant, limite: Int) {
        if (!valido(contexto)) return
        gravar((eventosPendentes() + EventoDeTelemetriaPendente(
            contaId = contexto.contaId, registro = registro, guardadoEm = instante.toString(),
        )).takeLast(limite))
    }

    @Synchronized
    internal fun remover(contexto: ContextoDaTelemetria, id: String) {
        if (valido(contexto)) gravar(eventosPendentes().filterNot { it.id == id })
    }

    @Synchronized
    fun limpar() {
        geracao++
        memoria = emptyList()
        arquivo?.let { if (it.exists() && !it.delete()) throw IOException("Não foi possível limpar a fila de telemetria") }
    }

    private fun gravar(eventos: List<EventoDeTelemetriaPendente>) {
        memoria = eventos
        val destino = arquivo?.absoluteFile ?: return
        destino.parentFile.mkdirs()
        val temporario = File.createTempFile("telemetria-", ".tmp", destino.parentFile)
        try {
            temporario.writeText(Json.encodeToString(eventos))
            Files.move(temporario.toPath(), destino.toPath(), StandardCopyOption.REPLACE_EXISTING)
        } finally { temporario.delete() }
    }
}
