package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.seguranca.Sessao
import java.util.Base64
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.contentOrNull
import java.time.Duration
import java.time.Instant
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.Job

/** Envio desacoplado da UI; falhas de rede, RPC ou persistência nunca viram erro de tela. */
class RegistradorDeTelemetria(
    private val enviar: suspend (RegistroDeEventoDto) -> Boolean,
    private val fila: FilaDeTelemetria,
    private val contaLocal: () -> String?,
    private val consultarConta: suspend () -> String,
    private val escopo: CoroutineScope,
    private val agora: () -> Instant = Instant::now,
) {
    fun disparar(evento: EventoDeTelemetria, vagaId: String? = null, turnoId: String? = null) {
        // Captura o dono antes de agendar: um evento antigo não ganha o dono da próxima sessão.
        val contexto = fila.contexto(runCatching { contaLocal() }.getOrNull()) ?: return
        escopo.launch { registrarNoContexto(contexto, evento, vagaId, turnoId, null) }
    }

    suspend fun registrar(
        evento: EventoDeTelemetria,
        vagaId: String? = null,
        turnoId: String? = null,
        ocorridoEm: Instant? = null,
    ): Boolean {
        val contexto = fila.contexto(runCatching { contaLocal() }.getOrNull()) ?: return false
        return registrarNoContexto(contexto, evento, vagaId, turnoId, ocorridoEm)
    }

    private fun contextoAtual(contexto: ContextoDaTelemetria): Boolean =
        fila.valido(contexto) && contaLocal() == contexto.contaId

    private suspend fun registrarNoContexto(
        contexto: ContextoDaTelemetria, evento: EventoDeTelemetria, vagaId: String?, turnoId: String?, ocorridoEm: Instant?,
    ): Boolean {
        if (!contextoAtual(contexto)) return false
        val instante = agora()
        val momento = ocorridoEm?.coerceAtMost(instante)
        val registro = RegistroDeEventoDto(evento, vagaId, turnoId, momento?.toString())
        return try {
            enviar(registro).also { escopo.launch { reenviar() } }
        } catch (cancelado: CancellationException) {
            throw cancelado
        } catch (erro: Exception) {
            if (deveGuardar(erro) && contextoAtual(contexto)) silenciosamente {
                fila.guardar(contexto, registro.copy(ocorridoEm = (momento ?: instante).toString()), instante, LIMITE_DE_PENDENTES)
            }
            false
        }
    }

    fun acompanharConectividade(monitor: MonitorDeConectividade): Job = escopo.launch {
        monitor.status.collect { if (it == StatusConectividade.CONECTADO) reenviar() }
    }

    /** Reserva na fila compartilhada: até registradores diferentes reenviam um de cada vez. */
    suspend fun reenviar() {
        if (!fila.reenvio.tryLock()) return
        try {
            silenciosamente {
                val contexto = fila.contexto(runCatching { contaLocal() }.getOrNull()) ?: return@silenciosamente
                val pendentes = fila.eventosPendentes()
                if (pendentes.isEmpty()) return@silenciosamente
                val contaAtual = consultarConta()
                if (contaAtual != contexto.contaId || !contextoAtual(contexto)) return@silenciosamente
                val instante = agora()
                for (pendente in pendentes) {
                    if (!contextoAtual(contexto)) return@silenciosamente
                    val ocorrido = Instant.parse(pendente.registro.ocorridoEm ?: pendente.guardadoEm)
                    if (pendente.contaId != contaAtual || Duration.between(ocorrido, instante) > IDADE_MAXIMA) {
                        fila.remover(contexto, pendente.id)
                        continue
                    }
                    try {
                        enviar(pendente.registro.copy(ocorridoEm = ocorrido.coerceAtMost(instante).toString()))
                    } catch (cancelado: CancellationException) {
                        throw cancelado
                    } catch (erro: Exception) {
                        if (deveGuardar(erro)) return@silenciosamente
                    }
                    fila.remover(contexto, pendente.id)
                }
            }
        } finally { fila.reenvio.unlock() }
    }

    private suspend inline fun silenciosamente(bloco: () -> Unit) {
        try { bloco() } catch (cancelado: CancellationException) { throw cancelado } catch (_: Exception) { }
    }

    companion object {
        const val LIMITE_DE_PENDENTES = 200
        val IDADE_MAXIMA: Duration = Duration.ofDays(30)

        internal fun deveGuardar(erro: Exception): Boolean {
            if (erro !is ErroDaApi) return true
            if (erro.codigoOriginal in setOf("400", "http_400")) return false
            return erro.codigo in setOf(
                CodigoErroAPI.SEM_REDE, CodigoErroAPI.DESCONHECIDO, CodigoErroAPI.RESPOSTA_INVALIDA,
                CodigoErroAPI.LIMITE_EXCEDIDO, CodigoErroAPI.NAO_AUTENTICADO,
                CodigoErroAPI.SEM_PERMISSAO, CodigoErroAPI.CONTA_SUSPENSA,
            )
        }
    }
}

/** O sub serve só para isolar a fila; autenticação continua sendo responsabilidade do cliente. */
fun contaDaSessaoParaTelemetria(sessao: Sessao?): String? = try {
    val corpo = sessao?.accessToken?.split('.')?.takeIf { it.size == 3 }?.get(1)
    corpo?.let {
        val sujeito = Json.parseToJsonElement(String(Base64.getUrlDecoder().decode(it)))
            .jsonObject["sub"]?.jsonPrimitive
        sujeito?.takeIf { it.isString }?.contentOrNull?.takeIf { it.isNotBlank() }
    }
} catch (_: IllegalArgumentException) { null }
