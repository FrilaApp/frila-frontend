package br.com.frila.feature.turnos

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoTurnos
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
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoAvaliacao())
    val estado: StateFlow<EstadoAvaliacao> = _estado.asStateFlow()

    fun avaliar(turnoId: String, resposta: Boolean): Job {
        _estado.update { it.copy(status = StatusAvaliacao.ENVIANDO, mensagemErro = null) }
        return escopoDeTrabalho.launch {
            try {
                val avaliacao = servicoTurnos.avaliarTurno(turnoId = turnoId, resposta = resposta)
                _estado.update {
                    it.copy(status = StatusAvaliacao.SUCESSO, respostaRegistrada = avaliacao.resposta)
                }
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(status = StatusAvaliacao.ERRO, mensagemErro = mensagemDeErro(erro)) }
            }
        }
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.AVALIACAO_INDISPONIVEL -> "Este turno ainda não pode ser avaliado."
        CodigoErroAPI.AVALIACAO_JA_REGISTRADA -> "Você já avaliou este turno com uma resposta diferente."
        CodigoErroAPI.SEM_PERMISSAO -> "Você não tem permissão para avaliar este turno."
        CodigoErroAPI.SEM_REDE -> "Sem conexão. Verifique sua internet e tente de novo."
        else -> "Não foi possível registrar sua avaliação. Tente de novo."
    }
}
