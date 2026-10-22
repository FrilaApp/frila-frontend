package br.com.frila.feature.entrada.codigo

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.rede.DemonstracaoContas
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.SessaoDto
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.Sessao
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private const val TAMANHO_CODIGO = 6

/**
 * Tela de código: verifica o OTP de 6 dígitos (ou entra em modo demo para as contas de
 * revisão) e salva a sessão resultante em [ArmazenamentoDeSessao].
 *
 * Ver nota sobre `escopo` em [br.com.frila.feature.entrada.entrada.EntradaViewModel].
 */
class CodigoViewModel(
    email: String,
    private val servicoAutenticacao: ServicoAutenticacao,
    private val armazenamentoDeSessao: ArmazenamentoDeSessao,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoCodigo(email = email))
    val estado: StateFlow<EstadoCodigo> = _estado.asStateFlow()

    fun aoMudarCodigo(novoCodigo: String) {
        val somenteDigitos = novoCodigo.filter { it.isDigit() }.take(TAMANHO_CODIGO)
        _estado.update { it.copy(codigo = somenteDigitos, erro = null) }
    }

    fun confirmarCodigo(): Job? {
        val estadoAtual = _estado.value

        if (estadoAtual.codigo.length != TAMANHO_CODIGO) {
            _estado.update { it.copy(erro = "Informe os 6 dígitos do código.") }
            return null
        }

        return escopoDeTrabalho.launch {
            _estado.update { it.copy(carregando = true, erro = null) }
            try {
                val sessaoDto = if (DemonstracaoContas.ehContaDeDemonstracao(estadoAtual.email)) {
                    servicoAutenticacao.entrarDemonstracao(estadoAtual.email, estadoAtual.codigo)
                } else {
                    servicoAutenticacao.verificarOtp(estadoAtual.email, estadoAtual.codigo)
                }
                armazenamentoDeSessao.salvarSessao(sessaoDto.paraSessao())
                _estado.update { it.copy(carregando = false, autenticado = true) }
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(carregando = false, erro = mensagemDeErro(erro)) }
            }
        }
    }

    fun reenviarCodigo(): Job? {
        val email = _estado.value.email

        if (DemonstracaoContas.ehContaDeDemonstracao(email)) {
            _estado.update { it.copy(reenviado = true, erro = null) }
            return null
        }

        return escopoDeTrabalho.launch {
            _estado.update { it.copy(carregando = true, erro = null, reenviado = false) }
            try {
                servicoAutenticacao.solicitarOtp(email)
                _estado.update { it.copy(carregando = false, reenviado = true, codigo = "") }
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(carregando = false, erro = mensagemDeErro(erro)) }
            }
        }
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo.name) {
        "CAMPO_INVALIDO" -> "Código incorreto. Confira os 6 dígitos e tente de novo."
        "SEM_REDE" -> "Sem conexão. Verifique sua internet e tente de novo."
        else -> "Não foi possível confirmar o código. Tente de novo em instantes."
    }
}

private fun SessaoDto.paraSessao(): Sessao = Sessao(
    accessToken = accessToken,
    refreshToken = refreshToken,
    tokenType = tokenType,
    expiresIn = expiresIn,
)
