package br.com.frila.feature.entrada.senha

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.DemonstracaoContas
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.SessaoDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.Sessao
import java.util.concurrent.atomic.AtomicLong
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private val PADRAO_EMAIL_SENHA = Regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")

/** Estado da tela de login rotineiro por e-mail e senha. A senha existe só em memória enquanto o usuário digita. */
data class EstadoEntradaComSenha(
    val email: String = "",
    val senha: String = "",
    val carregando: Boolean = false,
    val erro: String? = null,
    val autenticado: Boolean = false,
)

/**
 * Login rotineiro por e-mail e senha (`POST /auth/v1/token?grant_type=password`).
 * - Falhas de autenticação devolvem mensagem neutra anti-enumeração.
 * - Contas de demonstração não passam por senha (seguem no fluxo dedicado `/functions/v1/entrar-demonstracao`).
 * - Em caso de erro, a sessão anterior (se houvesse) nunca é restaurada nem reaproveitada.
 * - A senha é limpa da memória assim que o login conclui e nunca é persistida ou logada.
 */
class EntradaComSenhaViewModel(
    private val servicoAutenticacao: ServicoAutenticacao,
    private val armazenamentoDeSessao: ArmazenamentoDeSessao,
    escopo: CoroutineScope? = null,
    private val aoEntrar: suspend () -> Unit = {},
    private val permitirDominioDeTeste: Boolean = false,
    emailInicial: String = "",
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope
    private val _estado = MutableStateFlow(EstadoEntradaComSenha(email = emailInicial))
    val estado: StateFlow<EstadoEntradaComSenha> = _estado.asStateFlow()

    private val sequenciaDeTentativa = AtomicLong(0L)
    private var tentativaAtual: Long = 0L
    private var pedido: Job? = null

    fun aoMudarEmail(novoEmail: String) {
        _estado.update { it.copy(email = novoEmail, erro = null) }
    }

    fun aoMudarSenha(novaSenha: String) {
        _estado.update { it.copy(senha = novaSenha, erro = null) }
    }

    fun aoConsumirAutenticacao() {
        _estado.update { it.copy(autenticado = false) }
    }

    fun cancelarTentativaAtual() {
        tentativaAtual = sequenciaDeTentativa.incrementAndGet()
        pedido?.cancel()
        pedido = null
        _estado.update { it.copy(carregando = false) }
    }

    fun entrar(): Job? {
        pedido?.takeIf { it.isActive }?.let { return it }
        val email = _estado.value.email.trim().lowercase()
        val senha = _estado.value.senha

        if (!PADRAO_EMAIL_SENHA.matches(email)) {
            _estado.update { it.copy(erro = "Informe um e-mail válido.") }
            return null
        }
        if (senha.isEmpty()) {
            _estado.update { it.copy(erro = "Digite sua senha para entrar.") }
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
                val sessaoDto = servicoAutenticacao.entrarComSenha(email, senha)
                if (tentativaAtual != idTentativa) return@launch
                armazenamentoDeSessao.salvarSessao(sessaoDto.paraSessao())
                _estado.update { it.copy(carregando = false, senha = "", erro = null, autenticado = true) }
                try {
                    aoEntrar()
                } catch (cancelado: CancellationException) {
                    throw cancelado
                } catch (_: Exception) {
                }
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
                _estado.update { it.copy(carregando = false, erro = "Não foi possível entrar agora. Tente de novo em instantes.") }
            }
        }.also { pedido = it }
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.SEM_REDE -> "Sem conexão. Verifique sua internet e tente de novo."
        CodigoErroAPI.LIMITE_EXCEDIDO -> "Muitas tentativas em pouco tempo. Aguarde alguns minutos e tente de novo."
        CodigoErroAPI.NAO_AUTENTICADO,
        CodigoErroAPI.NAO_ENCONTRADO,
        -> MENSAGEM_CREDENCIAIS_NEUTRA
        else -> "Não foi possível entrar agora. Tente de novo em instantes."
    }

    companion object {
        const val MENSAGEM_CREDENCIAIS_NEUTRA =
            "E-mail ou senha incorretos. Confira os dados ou defina uma senha para sua conta."
    }
}

private fun SessaoDto.paraSessao(): Sessao = Sessao(
    accessToken = accessToken,
    refreshToken = refreshToken,
    tokenType = tokenType,
    expiresIn = expiresIn,
)
