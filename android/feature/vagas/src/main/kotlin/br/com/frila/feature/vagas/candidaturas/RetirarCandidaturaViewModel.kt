package br.com.frila.feature.vagas.candidaturas

import br.com.frila.core.rede.EventoDeTelemetria
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.CandidaturaDto
import br.com.frila.core.rede.ErroDaApi
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

enum class SituacaoDaRetirada {
    /** Dá para retirar (também depois de uma falha passageira). */
    PENDENTE,
    RETIRANDO,
    RETIRADA,

    /** A casa já respondeu, ou a candidatura não é desta conta: não há mais o que retirar. */
    INDISPONIVEL,
}

data class EstadoRetirarCandidatura(
    val situacao: SituacaoDaRetirada = SituacaoDaRetirada.PENDENTE,
    val falha: String? = null,
)

/**
 * Retirar a candidatura antes de ser escolhido (`retirar_candidatura`, RN24; paridade com o
 * `RetirarCandidaturaViewModel` do iOS). Sem penalidade. A retirada nunca é guardada para depois: sem rede é
 * mensagem, porque enviada mais tarde a casa já pode ter escolhido a pessoa. Quando o servidor diz que a candidatura
 * já teve resposta, a lista da conta diz qual (escolhida, recusada ou expirada).
 *
 * [retirar] é `ServicoVagas.retirarCandidatura`; [minhasCandidaturas], `ServicoVagas.minhasCandidaturas()`.
 * [aoRetirar] avisa quem abriu que a lista mudou. `escopo`: mesma razão do `MinhasVagasViewModel`.
 */
class RetirarCandidaturaViewModel(
    val candidaturaId: String,
    private val retirar: suspend (candidaturaId: String) -> CandidaturaDto,
    private val minhasCandidaturas: suspend () -> List<CandidaturaDto>,
    private val aoRetirar: () -> Unit = {},
    escopo: CoroutineScope? = null,
    private val registrarEvento: (EventoDeTelemetria, String?, String?) -> Unit = { _, _, _ -> },
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoRetirarCandidatura())
    val estado: StateFlow<EstadoRetirarCandidatura> = _estado.asStateFlow()

    /** O toque em "Retirar" na confirmação. `null` se já há um envio em voo ou se não há mais o que retirar. */
    fun retirar(): Job? {
        if (_estado.value.situacao != SituacaoDaRetirada.PENDENTE) return null
        _estado.value = EstadoRetirarCandidatura(SituacaoDaRetirada.RETIRANDO)
        return escopoDeTrabalho.launch {
            try {
                val candidatura = retirar(candidaturaId)
                if (candidatura.estado == ESTADO_RETIRADA) {
                    registrarEvento(EventoDeTelemetria.CANDIDATURA_RETIRADA, candidatura.vaga.id, candidatura.turnoId)
                    _estado.value = EstadoRetirarCandidatura(SituacaoDaRetirada.RETIRADA)
                    aoRetirar()
                } else {
                    // O contrato só devolve a retirada; qualquer outro estado é a resposta que a casa já deu.
                    _estado.value = EstadoRetirarCandidatura(SituacaoDaRetirada.INDISPONIVEL, jaRespondida(candidatura.estado))
                }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
                _estado.value = falhaDe(erro)
            }
        }
    }

    private suspend fun falhaDe(erro: Exception): EstadoRetirarCandidatura = when ((erro as? ErroDaApi)?.codigo) {
        CodigoErroAPI.SEM_REDE -> EstadoRetirarCandidatura(SituacaoDaRetirada.PENDENTE, TextosCandidaturas.RETIRADA_SEM_CONEXAO)
        CodigoErroAPI.CANDIDATURA_INDISPONIVEL -> EstadoRetirarCandidatura(SituacaoDaRetirada.INDISPONIVEL, jaRespondida(estadoAtual()))
        CodigoErroAPI.NAO_ENCONTRADO -> EstadoRetirarCandidatura(SituacaoDaRetirada.INDISPONIVEL, TextosCandidaturas.RETIRADA_NAO_ENCONTRADA)
        CodigoErroAPI.NAO_AUTENTICADO -> EstadoRetirarCandidatura(SituacaoDaRetirada.PENDENTE, TextosCandidaturas.SESSAO_EXPIRADA)
        else -> EstadoRetirarCandidatura(SituacaoDaRetirada.PENDENTE, TextosCandidaturas.RETIRADA_FALHA)
    }

    /** Escolhida, recusada ou expirada: a lista da conta diz qual das três. Se a lista falhar, fica o texto genérico. */
    private suspend fun estadoAtual(): String? = try {
        minhasCandidaturas().firstOrNull { it.id == candidaturaId }?.estado
    } catch (erro: CancellationException) {
        throw erro
    } catch (_: Exception) {
        null
    }

    private fun jaRespondida(estado: String?): String = when (estado) {
        ESTADO_ACEITA -> TextosCandidaturas.JA_ESCOLHIDA
        ESTADO_RECUSADA -> TextosCandidaturas.JA_RECUSADA
        ESTADO_EXPIRADA -> TextosCandidaturas.JA_EXPIRADA
        else -> TextosCandidaturas.JA_RESPONDIDA
    }
}
