package br.com.frila.feature.vagas.detalhe

import br.com.frila.core.rede.EventoDeTelemetria
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.core.rede.VagaDto
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Detalhe de uma vaga e candidatura (RF08/RF09/RN10/RN19/RN21). `vaga` chega inteira da tela de
 * feed, que já tem o DTO carregado — não refaz a chamada de rede só para mostrar o detalhe. Aberta
 * pelo id, quem a leu foi o `AberturaDeVagaViewModel`, e o `detalhe` traz o que a lista não tem.
 *
 * `escopo`: ver nota em `br.com.frila.feature.entrada.entrada.EntradaViewModel`.
 */
class DetalheVagaViewModel(
    vaga: VagaAbertaDto,
    private val servicoVagas: ServicoVagas,
    /** O detalhe lido por `detalhe_vaga`, quando a vaga foi aberta pelo id (link ou aviso). */
    detalhe: VagaDto? = null,
    escopo: CoroutineScope? = null,
    private val registrarEvento: (EventoDeTelemetria, String?, String?) -> Unit = { _, _, _ -> },
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoDetalheVaga(vaga = vaga, detalhe = detalhe))
    val estado: StateFlow<EstadoDetalheVaga> = _estado.asStateFlow()

    init { registrarEvento(EventoDeTelemetria.VAGA_DETALHE_ABERTO, vaga.id, null) }

    /**
     * Uma candidatura por vez: a trava é do estado e atômica (como `ValidacaoDoCodigoViewModel.validar`), não só do botão, que só se
     * desliga depois de a tela redesenhar. O segundo toque com a primeira em voo não manda outra requisição, não repete o evento
     * `CANDIDATURA_ENVIADA` e não deixa o 409 `posicao_ja_preenchida` de um segundo pedido trocar a confirmada por erro. Depois de uma
     * falha o toque seguinte candidata de novo.
     */
    fun candidatar(): Job {
        var iniciou = false
        _estado.update {
            iniciou = it.statusCandidatura != StatusCandidatura.ENVIANDO
            if (!iniciou) {
                it
            } else {
                it.copy(
                    statusCandidatura = StatusCandidatura.ENVIANDO,
                    mensagem = null,
                    navegarParaConfirmada = false,
                    ehConflitoHorario = false,
                    ehVagaPreenchida = false,
                    ehVagaEncerrada = false,
                    ehContaSuspensa = false,
                )
            }
        }
        if (!iniciou) return escopoDeTrabalho.launch { }

        return escopoDeTrabalho.launch {
            try {
                val resultado = servicoVagas.candidatar(_estado.value.vaga.id)
                registrarEvento(EventoDeTelemetria.CANDIDATURA_ENVIADA, _estado.value.vaga.id, resultado.turnoId)
                val confirmada = resultado.estado == "confirmada"
                _estado.update {
                    it.copy(
                        statusCandidatura = if (confirmada) StatusCandidatura.CONFIRMADA else StatusCandidatura.PENDENTE,
                        contato = resultado.contato,
                        mensagem = if (confirmada) {
                            "Candidatura confirmada! Confira o contato abaixo."
                        } else {
                            "Candidatura enviada. Aguarde a escolha do contratante."
                        },
                        navegarParaConfirmada = confirmada,
                    )
                }
            } catch (erro: ErroDaApi) {
                val ehConflito = erro.codigo == CodigoErroAPI.INELEGIVEL && erro.detalhes == "turno_sobreposto"
                val ehPreenchida = erro.codigo == CodigoErroAPI.POSICAO_JA_PREENCHIDA
                val ehEncerrada = erro.codigo == CodigoErroAPI.VAGA_ENCERRADA
                val ehSuspensa = erro.codigo == CodigoErroAPI.CONTA_SUSPENSA ||
                    (erro.codigo == CodigoErroAPI.SEM_PERMISSAO && erro.detalhes == "conta_suspensa") ||
                    (erro.codigo == CodigoErroAPI.INELEGIVEL && erro.detalhes == "perfil_suspenso")
                _estado.update {
                    it.copy(
                        statusCandidatura = StatusCandidatura.ERRO,
                        mensagem = mensagemDeErro(erro),
                        ehConflitoHorario = ehConflito,
                        ehVagaPreenchida = ehPreenchida,
                        ehVagaEncerrada = ehEncerrada,
                        ehContaSuspensa = ehSuspensa,
                    )
                }
            } catch (erro: CancellationException) {
                throw erro
            } catch (_: Exception) {
                // Resposta que não decodifica não é ErroDaApi: sem isto a tela ficava em "enviando".
                _estado.update {
                    it.copy(statusCandidatura = StatusCandidatura.ERRO, mensagem = "Não foi possível enviar sua candidatura. Tente de novo em instantes.")
                }
            }
        }
    }

    /**
     * Os 5 eventos de navegação do detalhe disparam uma única vez por resultado de candidatura.
     * Cada consumo lê e limpa o evento de forma atômica no `_estado`, preservando status, contato e mensagem
     * (em especial `statusCandidatura == StatusCandidatura.CONFIRMADA`, que mantém o cartão e o botão desabilitado).
     * Sem isto, o `LaunchedEffect` da tela reentra na recomposição, na volta do destino (`popBackStack`) ou
     * na rotação com o `estado` ainda verdadeiro e empilha o destino de novo.
     */
    fun consumirNavegacaoParaConfirmada(): Boolean =
        consumirEvento({ it.navegarParaConfirmada }) { it.copy(navegarParaConfirmada = false) }

    fun consumirNavegacaoParaConflitoHorario(): Boolean =
        consumirEvento({ it.ehConflitoHorario }) { it.copy(ehConflitoHorario = false) }

    fun consumirNavegacaoParaVagaPreenchida(): Boolean =
        consumirEvento({ it.ehVagaPreenchida }) { it.copy(ehVagaPreenchida = false) }

    fun consumirNavegacaoParaVagaEncerrada(): Boolean =
        consumirEvento({ it.ehVagaEncerrada }) { it.copy(ehVagaEncerrada = false) }

    fun consumirNavegacaoParaContaSuspensa(): Boolean =
        consumirEvento({ it.ehContaSuspensa }) { it.copy(ehContaSuspensa = false) }

    private inline fun consumirEvento(
        presente: (EstadoDetalheVaga) -> Boolean,
        limpar: (EstadoDetalheVaga) -> EstadoDetalheVaga,
    ): Boolean {
        var consumiu = false
        _estado.update { atual ->
            consumiu = presente(atual)
            if (consumiu) limpar(atual) else atual
        }
        return consumiu
    }

    /**
     * Mensagens de erro de candidatura medidas em `iOS/Contrato/openapi.yaml:2199`
     * (`/rpc/candidatar`): `409 posicao_ja_preenchida`, `422 inelegivel`, `409 vaga_encerrada`.
     */
    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.POSICAO_JA_PREENCHIDA -> "Que pena, a vaga acabou de ser preenchida."
        CodigoErroAPI.VAGA_ENCERRADA -> "Esta vaga foi encerrada."
        CodigoErroAPI.CONTA_SUSPENSA -> MENSAGEM_SUSPENSAO
        CodigoErroAPI.INELEGIVEL -> when (erro.detalhes) {
            "turno_sobreposto" ->
                "Você já tem um turno confirmado que coincide com o horário desta vaga. " +
                    "Não é possível assumir dois turnos ao mesmo tempo."
            "perfil_suspenso" -> MENSAGEM_SUSPENSAO
            "funcao_incompativel" -> "Esta vaga exige uma função que não está cadastrada no seu perfil profissional."
            else -> "Você não está elegível para este turno."
        }
        CodigoErroAPI.NAO_ENCONTRADO -> "Esta vaga não está mais disponível. Volte para a lista e escolha outra."
        CodigoErroAPI.SEM_REDE -> "Não foi possível confirmar o envio. Tente de novo quando a conexão voltar."
        else -> "Não foi possível enviar sua candidatura. Tente de novo em instantes."
    }

    private companion object {
        const val MENSAGEM_SUSPENSAO =
            "Enquanto a suspensão durar, você não pode se candidatar a vagas. " +
                "O motivo e o caminho para contestar ficam na área da sua conta."
    }
}
