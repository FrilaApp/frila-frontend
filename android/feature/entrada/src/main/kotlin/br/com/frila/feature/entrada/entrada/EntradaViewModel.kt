package br.com.frila.feature.entrada.entrada

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.rede.DemonstracaoContas
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoAutenticacao
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private val PADRAO_EMAIL = Regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")

/**
 * Tela de entrada: valida formato de e-mail, solicita OTP (exceto para contas de
 * demonstração da Play Store, que pulam direto para a tela de código).
 *
 * `escopo` é nulo em produção (usa `viewModelScope`, que depende de `Dispatchers.Main`); testes
 * injetam um escopo dedicado. [solicitarCodigo] devolve o [Job] lançado (ou `null` quando o
 * caminho é síncrono) para que o teste possa esperar com `job.join()` — o cliente Ktor de
 * `:core:rede` processa a resposta num dispatcher real por baixo dos panos mesmo com
 * `MockEngine`, então nem `advanceUntilIdle()` nem "unconfined eager" sozinhos bastam para
 * garantir que a corrotina terminou antes da asserção.
 */
class EntradaViewModel(
    private val servicoAutenticacao: ServicoAutenticacao,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoEntrada())
    val estado: StateFlow<EstadoEntrada> = _estado.asStateFlow()

    fun aoMudarEmail(novoEmail: String) {
        _estado.update {
            it.copy(
                email = novoEmail,
                erro = null,
                ehContaDeDemonstracao = DemonstracaoContas.ehContaDeDemonstracao(novoEmail.trim()),
            )
        }
    }

    fun ehEmailValido(email: String): Boolean = PADRAO_EMAIL.matches(email.trim())

    fun solicitarCodigo(): Job? {
        val email = _estado.value.email.trim()

        if (!ehEmailValido(email)) {
            _estado.update { it.copy(erro = "Informe um e-mail válido.") }
            return null
        }


        if (DemonstracaoContas.ehContaDeDemonstracao(email)) {
            // Modo demo: não há OTP a solicitar, a tela de código chama entrarDemonstracao direto.
            _estado.update { it.copy(erro = null, otpSolicitado = true) }
            return null
        }

        return escopoDeTrabalho.launch {
            _estado.update { it.copy(carregando = true, erro = null) }
            try {
                servicoAutenticacao.solicitarOtp(email)
                _estado.update { it.copy(carregando = false, otpSolicitado = true) }
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(carregando = false, erro = mensagemDeErro(erro)) }
            }
        }
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo.name) {
        "SEM_REDE" -> "Sem conexão. Verifique sua internet e tente de novo."
        else -> "Não foi possível enviar o código. Tente de novo em instantes."
    }
}
