package br.com.frila.feature.turnos

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.MotivoCancelamento
import br.com.frila.core.dominio.modelo.RegraCancelamentoTurno
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoTurnos
import java.time.Clock
import kotlinx.coroutines.CancellationException
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
    private val relogio: Clock = Clock.systemUTC(),
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

    fun abrirCancelamento(turno: ItemTurno) {
        _estado.update {
            it.copy(
                cancelamento = EstadoCancelamentoTurno(
                    turno = turno,
                    contaComoFalta = RegraCancelamentoTurno.contaComoFalta(turno.inicio, relogio.instant()),
                ),
            )
        }
    }

    fun selecionarMotivo(motivo: MotivoCancelamento) {
        _estado.update { atual ->
            val cancelamento = atual.cancelamento ?: return@update atual
            atual.copy(
                cancelamento = cancelamento.copy(
                    motivoSelecionado = motivo,
                    detalhes = if (motivo.exigeDetalhes) cancelamento.detalhes else "",
                    mensagemErro = null,
                ),
            )
        }
    }

    fun atualizarDetalhes(texto: String) {
        _estado.update { atual ->
            val cancelamento = atual.cancelamento ?: return@update atual
            atual.copy(cancelamento = cancelamento.copy(detalhes = texto, mensagemErro = null))
        }
    }

    fun fecharCancelamento() {
        _estado.update { atual ->
            if (atual.cancelamento?.enviando == true) atual else atual.copy(cancelamento = null)
        }
    }

    fun confirmarCancelamento(): Job? {
        val cancelamento = _estado.value.cancelamento ?: return null
        if (!cancelamento.podeConfirmar) return null
        val motivo = cancelamento.motivoCompleto ?: return null
        _estado.update { it.copy(cancelamento = cancelamento.copy(enviando = true, mensagemErro = null)) }

        return escopoDeTrabalho.launch {
            try {
                val resultado = servicoTurnos.cancelarPosicao(cancelamento.turno.posicaoId, motivo)
                val cancelado = cancelamento.turno.copy(estado = "cancelada")
                _estado.update { atual ->
                    atual.copy(
                        agendados = atual.agendados.filterNot { it.turnoId == cancelado.turnoId },
                        historico = listOf(cancelado) + atual.historico.filterNot { it.turnoId == cancelado.turnoId },
                        cancelamento = null,
                        mensagemFeedback = if (resultado.falta) {
                            "Turno cancelado e registrado como falta."
                        } else {
                            "Turno cancelado sem penalidade de reputação."
                        },
                    )
                }
            } catch (erro: ErroDaApi) {
                _estado.update { atual ->
                    atual.copy(
                        cancelamento = atual.cancelamento?.copy(
                            enviando = false,
                            mensagemErro = mensagemDeErroCancelamento(erro),
                        ),
                    )
                }
            } catch (erro: CancellationException) {
                throw erro
            } catch (_: Exception) {
                _estado.update { atual ->
                    atual.copy(
                        cancelamento = atual.cancelamento?.copy(
                            enviando = false,
                            mensagemErro = "Não foi possível cancelar o turno. Tente novamente.",
                        ),
                    )
                }
            }
        }
    }

    fun consumirFeedback() {
        _estado.update { it.copy(mensagemFeedback = null) }
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo.name) {
        "SEM_REDE" -> "Sem conexão. Verifique sua internet e tente de novo."
        else -> "Não foi possível carregar seus turnos. Tente de novo em instantes."
    }

    private fun mensagemDeErroCancelamento(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.POSICAO_NAO_CANCELAVEL ->
            "Este turno não pode mais ser cancelado. Atualize a tela para ver como ele está."
        CodigoErroAPI.CAMPO_INVALIDO, CodigoErroAPI.CAMPO_OBRIGATORIO ->
            "O motivo não foi aceito. Revise o texto e tente novamente."
        CodigoErroAPI.SEM_REDE -> "Sem conexão. O cancelamento não foi enviado."
        else -> "Não foi possível cancelar o turno. Tente novamente."
    }
}
