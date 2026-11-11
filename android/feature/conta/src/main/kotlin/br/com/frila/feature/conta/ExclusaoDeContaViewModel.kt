package br.com.frila.feature.conta

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ExclusaoDeContaDto
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Estado da tela de exclusão de conta. `resultado` só existe depois de o servidor aceitar o pedido. */
data class EstadoExclusaoDeConta(
    val confirmouConsequencias: Boolean = false,
    val excluindo: Boolean = false,
    val mensagemErro: String? = null,
    val resultado: ExclusaoDeContaDto? = null,
) {
    val podeExcluir: Boolean get() = confirmouConsequencias && !excluindo && resultado == null
}

/**
 * Exclusão definitiva de conta (RF25/RN15/RNF08, UC16, LGPD art. 18, VI). O contrato de
 * `/functions/v1/excluir-conta` só aceita `confirmar: true`; não há campo de motivo, então a tela
 * não coleta um.
 *
 * [excluir] é a chamada de rede (`ServicoPerfil.excluirConta`). [aoConcluir] roda uma vez, só
 * depois do sucesso, e é onde o chamador limpa a sessão local e navega para fora: nunca antes,
 * porque uma recusa (ex.: `409 administrador_unico`) deixa a conta de pé e a sessão precisa
 * continuar valendo.
 *
 * `escopo`: mesma razão do `PerfilViewModel` (teste injeta um escopo próprio).
 */
class ExclusaoDeContaViewModel(
    private val excluir: suspend () -> ExclusaoDeContaDto,
    private val aoConcluir: () -> Unit = {},
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoExclusaoDeConta())
    val estado: StateFlow<EstadoExclusaoDeConta> = _estado.asStateFlow()

    fun alterarConfirmacao(confirmou: Boolean) {
        _estado.update { if (it.excluindo || it.resultado != null) it else it.copy(confirmouConsequencias = confirmou) }
    }

    /**
     * Sem a confirmação, com pedido em curso ou já concluído, não faz nada: o segundo toque num
     * botão lento não pode disparar um segundo pedido.
     */
    fun confirmarExclusao(): Job {
        if (!_estado.value.podeExcluir) return escopoDeTrabalho.launch { }
        _estado.update { it.copy(excluindo = true, mensagemErro = null) }
        return escopoDeTrabalho.launch {
            try {
                val resultado = excluir()
                _estado.update { it.copy(excluindo = false, resultado = resultado) }
                aoConcluir()
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(excluindo = false, mensagemErro = mensagemDeErro(erro)) }
            } catch (_: Exception) {
                // Corpo não-JSON de gateway ou campo ausente escapam do ErroDaApi; sem isto a tela
                // ficaria em "Excluindo…" para sempre. A mensagem nunca carrega o corpo cru (RN15).
                _estado.update { it.copy(excluindo = false, mensagemErro = TextosExclusaoDeConta.ERRO_GENERICO) }
            }
        }
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.ADMINISTRADOR_UNICO -> TextosExclusaoDeConta.ERRO_ADMIN_UNICO
        CodigoErroAPI.SEM_REDE -> TextosExclusaoDeConta.ERRO_SEM_REDE
        CodigoErroAPI.NAO_AUTENTICADO -> TextosExclusaoDeConta.ERRO_SESSAO
        else -> TextosExclusaoDeConta.ERRO_GENERICO
    }
}
