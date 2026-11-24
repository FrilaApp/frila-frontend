package br.com.frila.feature.entrada.criar

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.DemonstracaoContas
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.feature.entrada.entrada.MENSAGEM_LIMITE_DE_CODIGOS
import java.util.concurrent.atomic.AtomicLong
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private val PADRAO_EMAIL_CRIAR = Regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")

/** Estado da tela de criação de conta (envio único de OTP para confirmar e-mail antes de definir senha). */
data class EstadoCriarConta(
    val email: String = "",
    val carregando: Boolean = false,
    val erro: String? = null,
    val otpSolicitado: Boolean = false,
)

/**
 * Criação de conta nova: envia OTP com `create_user: true` uma única vez para confirmar o e-mail.
 * Depois da confirmação do código, o fluxo segue para definir senha e entrar no `DestinoDaConta`.
 * Contas de demonstração não passam por criação de conta.
 */
class CriarContaViewModel(
    private val servicoAutenticacao: ServicoAutenticacao,
    escopo: CoroutineScope? = null,
    private val permitirDominioDeTeste: Boolean = false,
    emailInicial: String = "",
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope
    private val _estado = MutableStateFlow(EstadoCriarConta(email = emailInicial))
    val estado: StateFlow<EstadoCriarConta> = _estado.asStateFlow()

    private val sequenciaDeTentativa = AtomicLong(0L)
    private var tentativaAtual: Long = 0L
    private var pedido: Job? = null

    fun aoMudarEmail(novoEmail: String) {
        _estado.update { it.copy(email = novoEmail, erro = null) }
    }

    fun aoNavegarParaCodigo() {
        _estado.update { it.copy(otpSolicitado = false) }
    }

    fun cancelarTentativaAtual() {
        tentativaAtual = sequenciaDeTentativa.incrementAndGet()
        pedido?.cancel()
        pedido = null
        _estado.update { it.copy(carregando = false) }
    }

    fun solicitarCodigoDeCriacao(): Job? {
        pedido?.takeIf { it.isActive }?.let { return it }
        val email = _estado.value.email.trim().lowercase()

        if (!PADRAO_EMAIL_CRIAR.matches(email)) {
            _estado.update { it.copy(erro = "Informe um e-mail válido.") }
            return null
        }
        if (DemonstracaoContas.ehContaDeDemonstracao(email, permitirDominioDeTeste)) {
            _estado.update { it.copy(erro = "Esta conta usa apenas o modo demonstração.") }
            return null
        }

        val idTentativa = sequenciaDeTentativa.incrementAndGet()
        tentativaAtual = idTentativa
        _estado.update { it.copy(email = email, carregando = true, erro = null) }

        return escopoDeTrabalho.launch {
            try {
                servicoAutenticacao.solicitarOtp(email)
                if (tentativaAtual != idTentativa) return@launch
                _estado.update { it.copy(carregando = false, otpSolicitado = true) }
            } catch (cancelado: CancellationException) {
                if (tentativaAtual == idTentativa) {
                    _estado.update { it.copy(carregando = false) }
                }
                throw cancelado
            } catch (erro: ErroDaApi) {
                if (tentativaAtual != idTentativa) return@launch
                _estado.update { it.copy(carregando = false, erro = mensagemDeErro(erro)) }
            } catch (_: Exception) {
                if (tentativaAtual != idTentativa) return@launch
                _estado.update { it.copy(carregando = false, erro = "Não foi possível enviar o código. Tente de novo em instantes.") }
            }
        }.also { pedido = it }
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.SEM_REDE -> "Sem conexão. Verifique sua internet e tente de novo."
        CodigoErroAPI.LIMITE_EXCEDIDO -> MENSAGEM_LIMITE_DE_CODIGOS
        else -> "Não foi possível enviar o código. Tente de novo em instantes."
    }
}
