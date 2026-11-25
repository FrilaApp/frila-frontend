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

    fun candidatar(): Job {
        _estado.update {
            it.copy(
                statusCandidatura = StatusCandidatura.ENVIANDO,
                mensagem = null,
                ehConflitoHorario = false,
                ehVagaPreenchida = false,
                ehVagaEncerrada = false,
                ehContaSuspensa = false,
            )
        }

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
     * `ehConflitoHorario`, `ehVagaPreenchida`, `ehVagaEncerrada` e `ehContaSuspensa` são eventos de uma vez só: a tela navega uma
     * única vez por candidatura recusada. Cada `consumirNavegacaoPara...` devolve `true` para quem consumiu o evento primeiro e
     * `false` para os demais. A tela precisa disto porque o efeito dela pode rodar de novo (recomposição, troca do ramo do feed
     * para o detalhe aberto pelo id, volta da tela de destino) com o `estado` que a composição já tinha lido, ainda verdadeiro,
     * depois de o evento ter sido consumido: ler o `estado` capturado não basta, e navegar duas vezes empilha a tela duas vezes.
     */
    fun consumirNavegacaoParaConflito(): Boolean = consumirEvento({ it.ehConflitoHorario }) { it.copy(ehConflitoHorario = false) }

    fun consumirNavegacaoParaVagaPreenchida(): Boolean = consumirEvento({ it.ehVagaPreenchida }) { it.copy(ehVagaPreenchida = false) }

    fun consumirNavegacaoParaVagaEncerrada(): Boolean = consumirEvento({ it.ehVagaEncerrada }) { it.copy(ehVagaEncerrada = false) }

    fun consumirNavegacaoParaContaSuspensa(): Boolean = consumirEvento({ it.ehContaSuspensa }) { it.copy(ehContaSuspensa = false) }

    private fun consumirEvento(ligado: (EstadoDetalheVaga) -> Boolean, desligar: (EstadoDetalheVaga) -> EstadoDetalheVaga): Boolean {
        var consumiu = false
        _estado.update { atual ->
            consumiu = ligado(atual)
            if (consumiu) desligar(atual) else atual
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
