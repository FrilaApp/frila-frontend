package br.com.frila.feature.turnos

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.MotivoCancelamento
import br.com.frila.core.dominio.modelo.RegraCancelamentoTurno
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoTurnos
import java.time.Clock
import java.time.Instant
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
                val historicoCompleto = turnos.filter { it.estado in ESTADOS_HISTORICO }.map { it.paraItem() }

                _estado.update {
                    it.copy(
                        status = if (turnos.isEmpty()) StatusMeusTurnos.VAZIO else StatusMeusTurnos.SUCESSO,
                        agendados = agendados,
                        historicoCompleto = historicoCompleto,
                        paginaHistorico = 1,
                    )
                }
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(status = StatusMeusTurnos.ERRO, mensagemErro = mensagemDeErro(erro)) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (_: Exception) {
                // Resposta que não decodifica (campo que o servidor omitiu, HTML de portal) não é ErroDaApi:
                // sem isto a tela ficava em "carregando" e a exceção subia crua.
                _estado.update {
                    it.copy(
                        status = StatusMeusTurnos.ERRO,
                        mensagemErro = "Não foi possível carregar seus turnos. Tente de novo em instantes.",
                    )
                }
            }
        }
    }

    fun tentarNovamente(): Job = carregar()

    /**
     * RF16: libera a próxima fatia de [TAMANHO_PAGINA_HISTORICO] itens do histórico já carregado
     * em memória (o backend não tem `limit`/`offset`, MEDIDO em `20260924220000_meus_turnos.sql`
     * — a paginação aqui é só sobre o que já chegou). Guard clause evita trabalho duplicado
     * quando a lista já terminou ou uma página já está a caminho — o gatilho de scroll pode
     * disparar várias vezes antes da UI recompor.
     */
    fun carregarMaisHistorico(): Job? {
        val atual = _estado.value
        if (!atual.temMaisHistorico || atual.carregandoMaisHistorico) return null

        _estado.update { it.copy(carregandoMaisHistorico = true) }
        return escopoDeTrabalho.launch {
            _estado.update { it.copy(paginaHistorico = it.paginaHistorico + 1, carregandoMaisHistorico = false) }
        }
    }

    /**
     * Pull-to-refresh (RF16): busca a lista de novo na rede e reseta a paginação do histórico
     * para a primeira página — o mesmo comportamento de abrir a tela do zero.
     */
    fun atualizar(): Job {
        _estado.update { it.copy(atualizando = true, mensagemErro = null) }
        return escopoDeTrabalho.launch {
            try {
                val turnos = servicoTurnos.listarMeusTurnos()
                val agendados = turnos.filter { it.estado in ESTADOS_AGENDADOS }.map { it.paraItem() }
                val historicoCompleto = turnos.filter { it.estado in ESTADOS_HISTORICO }.map { it.paraItem() }

                _estado.update {
                    it.copy(
                        status = if (turnos.isEmpty()) StatusMeusTurnos.VAZIO else StatusMeusTurnos.SUCESSO,
                        agendados = agendados,
                        historicoCompleto = historicoCompleto,
                        paginaHistorico = 1,
                        mensagemErro = null,
                    )
                }
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(mensagemErro = mensagemDeErro(erro)) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (_: Exception) {
                _estado.update { it.copy(mensagemErro = "Não foi possível atualizar seus turnos. Tente de novo em instantes.") }
            } finally {
                _estado.update { it.copy(atualizando = false) }
            }
        }
    }

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
        val motivo = cancelamento.motivoCompleto ?: "Cancelamento pelo profissional"
        _estado.update { it.copy(cancelamento = cancelamento.copy(enviando = true, mensagemErro = null)) }

        return escopoDeTrabalho.launch {
            try {
                val resultado = servicoTurnos.cancelarPosicao(cancelamento.turno.posicaoId, motivo)
                val cancelado = cancelamento.turno.copy(estado = "cancelada")
                _estado.update { atual ->
                    atual.copy(
                        agendados = atual.agendados.filterNot { it.turnoId == cancelado.turnoId },
                        historicoCompleto = listOf(cancelado) + atual.historicoCompleto.filterNot { it.turnoId == cancelado.turnoId },
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

    /**
     * L2-1 (US14, RF12): "Estou a caminho" — `avisar_a_caminho`, idempotente no servidor. Só dentro da janela e sem aviso
     * nem check-in ([podeAvisarACaminho]); um envio por vez. Devolve `null` quando não envia. A recusa vira texto do Frila
     * em [EstadoMeusTurnos.erroACaminho], e nenhuma falha deixa o botão em "avisando".
     */
    fun avisarACaminho(turno: ItemTurno): Job? {
        val atual = _estado.value
        if (atual.avisandoACaminho != null || !podeAvisarACaminho(turno, relogio.instant())) return null
        _estado.update { it.copy(avisandoACaminho = turno.turnoId, erroACaminho = null) }

        return escopoDeTrabalho.launch {
            try {
                val resultado = servicoTurnos.avisarACaminho(turno.turnoId)
                val quando = Instant.parse(resultado.aCaminhoEm)
                _estado.update { tela ->
                    tela.copy(
                        avisandoACaminho = null,
                        agendados = tela.agendados.map { if (it.turnoId == turno.turnoId) it.copy(aCaminhoEm = quando) else it },
                    )
                }
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(avisandoACaminho = null, erroACaminho = ErroDoACaminho(turno.turnoId, mensagemDeErroACaminho(erro))) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (_: Exception) {
                // Resposta que não decodifica (HTML de portal, campo omitido) não é ErroDaApi: nunca o corpo cru (RN15).
                _estado.update { it.copy(avisandoACaminho = null, erroACaminho = ErroDoACaminho(turno.turnoId, TextosACaminho.ERRO_GENERICO)) }
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

    /** `avisar_a_caminho`: `422 a_caminho_fora_da_janela`, `403` (conta suspensa vem em `details`) e sem rede têm texto próprio. */
    private fun mensagemDeErroACaminho(erro: ErroDaApi): String = when {
        erro.codigo == CodigoErroAPI.A_CAMINHO_FORA_DA_JANELA -> TextosACaminho.ERRO_FORA_DA_JANELA
        erro.codigo == CodigoErroAPI.SEM_REDE -> TextosACaminho.ERRO_SEM_REDE
        erro.codigo == CodigoErroAPI.CONTA_SUSPENSA ||
            (erro.codigo == CodigoErroAPI.SEM_PERMISSAO && erro.detalhes == "conta_suspensa") -> TextosACaminho.ERRO_CONTA_SUSPENSA
        else -> TextosACaminho.ERRO_GENERICO
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
