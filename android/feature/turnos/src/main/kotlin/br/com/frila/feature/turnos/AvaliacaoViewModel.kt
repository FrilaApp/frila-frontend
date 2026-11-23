package br.com.frila.feature.turnos

import br.com.frila.core.rede.EventoDeTelemetria
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.AcaoPendente
import br.com.frila.core.rede.FilaDeAcoes
import br.com.frila.core.rede.TipoAcaoPendente
import java.io.IOException
import java.time.Instant
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoTurnos
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Avaliação binária de turno cumprido (RF15/RN07/RN08/RN11/RN22, UC06): "Você trabalharia nesse
 * local de novo?", sim ou não, nunca nota de 1 a 5. Um voto por lado do turno — reenviar a
 * mesma resposta devolve a avaliação já gravada; resposta diferente é conflito
 * (`avaliacao_ja_registrada`).
 *
 * `escopo`: ver nota em `br.com.frila.feature.entrada.entrada.EntradaViewModel` sobre por que
 * testes injetam um escopo próprio em vez de depender de `viewModelScope`/`Dispatchers.Main`.
 */
class AvaliacaoViewModel(
    private val servicoTurnos: ServicoTurnos,
    escopo: CoroutineScope? = null,
    private val registrarEvento: (EventoDeTelemetria, String?, String?) -> Unit = { _, _, _ -> },
    private val filaDeAcoes: FilaDeAcoes? = null,
    private val contaAtual: () -> String? = { null },
    private val instanteAtual: () -> Instant = Instant::now,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoAvaliacao())
    val estado: StateFlow<EstadoAvaliacao> = _estado.asStateFlow()

    /** A avaliação em voo: um segundo toque ("sim" e "não" em sequência) não envia de novo. */
    private var envio: Job? = null

    private var observacao: Job? = null
    private var turnoObservado: String? = null
    private var contaObservada: String? = null

    /** Relê ao abrir e a cada mudança da fila; só considera o turno e a conta desta tela. */
    fun observar(turnoId: String) {
        if (turnoObservado == turnoId) return
        observacao?.cancel()
        turnoObservado = turnoId
        contaObservada = contaAtual()
        _estado.value = EstadoAvaliacao()
        reconciliarComAFila(turnoId)
        val fila = filaDeAcoes ?: return
        observacao = escopoDeTrabalho.launch { fila.versao.collect { reconciliarComAFila(turnoId) } }
    }

    private fun reconciliarComAFila(turnoId: String) {
        val fila = filaDeAcoes ?: return
        val conta = contaAtual()
        if (conta != contaObservada) {
            contaObservada = conta
            _estado.value = EstadoAvaliacao()
        }
        if (conta == null) return
        synchronized(fila) {
            val pendente = fila.pendentes().firstOrNull {
                it.tipo == TipoAcaoPendente.AVALIACAO && it.turnoId == turnoId && it.contaId == conta
            }
            val recusada = fila.recusadas().any {
                it.tipo == TipoAcaoPendente.AVALIACAO && it.turnoId == turnoId && it.contaId == conta
            }
            var enviada = false
            _estado.update { e ->
                enviada = false
                when {
                    pendente != null -> e.copy(status = StatusAvaliacao.NA_FILA, respostaRegistrada = pendente.resposta, mensagemErro = null)
                    recusada && e.status != StatusAvaliacao.ENVIANDO ->
                        EstadoAvaliacao(status = StatusAvaliacao.ERRO, mensagemErro = TextosDaFilaDeAvaliacao.RECUSADA)
                    e.status == StatusAvaliacao.NA_FILA -> {
                        enviada = true
                        e.copy(status = StatusAvaliacao.SUCESSO)
                    }
                    else -> e
                }
            }
            if (enviada) registrarEvento(EventoDeTelemetria.AVALIACAO_ENVIADA, null, turnoId)
        }
    }

    private fun guardarNaFila(turnoId: String, resposta: Boolean, toque: Instant, conta: String?): Boolean {
        val fila = filaDeAcoes ?: return false
        if (conta == null || contaAtual() != conta) return false
        return try {
            synchronized(fila) {
                val existente = fila.pendentes().firstOrNull {
                    it.tipo == TipoAcaoPendente.AVALIACAO && it.turnoId == turnoId && it.contaId == conta
                }
                val acao = existente ?: AcaoPendente(TipoAcaoPendente.AVALIACAO, conta, toque.toString(),
                    turnoId = turnoId, resposta = resposta).also { fila.enfileirar(it) }
                _estado.update { it.copy(status = StatusAvaliacao.NA_FILA, respostaRegistrada = acao.resposta, mensagemErro = null) }
                if (existente == null) registrarEvento(EventoDeTelemetria.ACAO_ENFILEIRADA_OFFLINE, null, turnoId)
            }
            true
        } catch (_: IOException) { false }
    }

    fun avaliar(turnoId: String, resposta: Boolean): Job {
        observar(turnoId)
        reconciliarComAFila(turnoId)
        if (_estado.value.status in setOf(StatusAvaliacao.NA_FILA, StatusAvaliacao.SUCESSO)) return escopoDeTrabalho.launch { }
        envio?.takeIf { it.isActive }?.let { return it }
        val toque = instanteAtual()
        val conta = contaAtual()
        filaDeAcoes?.let { fila ->
            runCatching { fila.recusadas().filter {
                it.tipo == TipoAcaoPendente.AVALIACAO && it.turnoId == turnoId && it.contaId == conta
            }.forEach { fila.reconhecerRecusa(it.id) } }
        }
        _estado.update { it.copy(status = StatusAvaliacao.ENVIANDO, mensagemErro = null) }
        return escopoDeTrabalho.launch {
            try {
                val avaliacao = servicoTurnos.avaliarTurno(turnoId = turnoId, resposta = resposta)
                registrarEvento(EventoDeTelemetria.AVALIACAO_ENVIADA, null, turnoId)
                _estado.update {
                    it.copy(status = StatusAvaliacao.SUCESSO, respostaRegistrada = avaliacao.resposta)
                }
            } catch (erro: ErroDaApi) {
                if (erro.codigo == CodigoErroAPI.SEM_REDE && guardarNaFila(turnoId, resposta, toque, conta)) return@launch
                _estado.update { it.copy(status = StatusAvaliacao.ERRO, mensagemErro = mensagemDeErro(erro)) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (_: Exception) {
                // Resposta que não decodifica não é ErroDaApi: sem isto a tela ficava em "enviando".
                _estado.update {
                    it.copy(
                        status = StatusAvaliacao.ERRO,
                        mensagemErro = "Não foi possível registrar sua avaliação. Tente de novo.",
                    )
                }
            }
        }.also { envio = it }
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.AVALIACAO_INDISPONIVEL -> "Este turno ainda não pode ser avaliado."
        CodigoErroAPI.AVALIACAO_JA_REGISTRADA -> "Você já avaliou este turno com uma resposta diferente."
        CodigoErroAPI.SEM_PERMISSAO -> "Você não tem permissão para avaliar este turno."
        CodigoErroAPI.SEM_REDE -> "Sem conexão. Verifique sua internet e tente de novo."
        else -> "Não foi possível registrar sua avaliação. Tente de novo."
    }
}
