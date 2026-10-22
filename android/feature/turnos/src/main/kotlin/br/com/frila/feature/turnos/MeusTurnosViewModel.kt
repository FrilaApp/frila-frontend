package br.com.frila.feature.turnos

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoTurnos
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private val ESTADOS_AGENDADOS = setOf("confirmada")
private val ESTADOS_HISTORICO = setOf("cumprida", "cancelada")

/**
 * Meus turnos (RF13/RF14/RF15/RNF06): separa Agendados de Histórico pelo campo `estado` do
 * turno. RN12: o turno cancelado continua na lista (vem de `:core:rede` sem filtro) — aqui ele
 * só é roteado para a aba Histórico, nunca descartado.
 *
 * `escopo`: ver nota em `br.com.frila.feature.entrada.entrada.EntradaViewModel` sobre por que
 * testes injetam um escopo próprio em vez de depender de `viewModelScope`/`Dispatchers.Main`.
 */
class MeusTurnosViewModel(
    private val servicoTurnos: ServicoTurnos,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoMeusTurnos())
    val estado: StateFlow<EstadoMeusTurnos> = _estado.asStateFlow()

    fun carregar(): Job {
        _estado.update { it.copy(status = StatusMeusTurnos.CARREGANDO, mensagemErro = null) }
        return escopoDeTrabalho.launch {
            try {
                val turnos = servicoTurnos.listarMeusTurnos()
                val agendados = turnos.filter { it.estado in ESTADOS_AGENDADOS }.map { it.paraItem() }
                val historico = turnos.filter { it.estado in ESTADOS_HISTORICO }.map { it.paraItem() }

                _estado.update {
                    it.copy(
                        status = if (turnos.isEmpty()) StatusMeusTurnos.VAZIO else StatusMeusTurnos.SUCESSO,
                        agendados = agendados,
                        historico = historico,
                    )
                }
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(status = StatusMeusTurnos.ERRO, mensagemErro = mensagemDeErro(erro)) }
            }
        }
    }

    fun tentarNovamente(): Job = carregar()

    fun aoSelecionarAba(aba: AbaDeTurnos) {
        _estado.update { it.copy(abaSelecionada = aba) }
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo.name) {
        "SEM_REDE" -> "Sem conexão. Verifique sua internet e tente de novo."
        else -> "Não foi possível carregar seus turnos. Tente de novo em instantes."
    }
}
