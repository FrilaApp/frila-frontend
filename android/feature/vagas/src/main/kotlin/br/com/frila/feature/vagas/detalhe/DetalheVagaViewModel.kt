package br.com.frila.feature.vagas.detalhe

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.VagaAbertaDto
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Detalhe de uma vaga e candidatura (RF08/RF09/RN10/RN19/RN21). `vaga` chega inteira da tela de
 * feed, que já tem o DTO carregado — não refaz a chamada de rede só para mostrar o detalhe.
 *
 * `escopo`: ver nota em `br.com.frila.feature.entrada.entrada.EntradaViewModel`.
 */
class DetalheVagaViewModel(
    vaga: VagaAbertaDto,
    private val servicoVagas: ServicoVagas,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoDetalheVaga(vaga = vaga))
    val estado: StateFlow<EstadoDetalheVaga> = _estado.asStateFlow()

    fun candidatar(): Job {
        _estado.update { it.copy(statusCandidatura = StatusCandidatura.ENVIANDO, mensagem = null) }

        return escopoDeTrabalho.launch {
            try {
                val resultado = servicoVagas.candidatar(_estado.value.vaga.id)
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
                _estado.update { it.copy(statusCandidatura = StatusCandidatura.ERRO, mensagem = mensagemDeErro(erro)) }
            }
        }
    }

    /**
     * Mensagens de erro de candidatura medidas em `iOS/Contrato/openapi.yaml:2199`
     * (`/rpc/candidatar`): `409 posicao_ja_preenchida`, `422 inelegivel`, `409 vaga_encerrada`.
     */
    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.POSICAO_JA_PREENCHIDA -> "Que pena, a vaga acabou de ser preenchida."
        CodigoErroAPI.INELEGIVEL -> "Você não está elegível para este turno."
        CodigoErroAPI.VAGA_ENCERRADA -> "Esta vaga foi encerrada."
        else -> "Não foi possível enviar sua candidatura. Tente de novo em instantes."
    }
}
