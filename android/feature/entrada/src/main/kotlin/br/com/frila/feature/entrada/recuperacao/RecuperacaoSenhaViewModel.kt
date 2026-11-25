package br.com.frila.feature.entrada.recuperacao

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

private val PADRAO_EMAIL_RECUPERACAO = Regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")

/** Estado da tela de recuperação de senha / migração única de conta legada OTP-only. */
data class EstadoRecuperacaoSenha(
    val email: String = "",
    val carregando: Boolean = false,
    val erro: String? = null,
    val avancarParaCodigo: Boolean = false,
)

/**
 * Fluxo recovery-only (`create_user: false`) para:
 * 1) redefinir senha esquecida;
 * 2) migrar conta legada OTP-only para senha preservando o mesmo `auth.uid`.
 *
 * Regras de segurança:
 * - Nunca cria usuário novo (`solicitarOtpRecuperacao` envia `create_user: false`).
 * - Anti-enumeração: e-mail com conta (200) e e-mail sem conta ou social-only (`otp_disabled` /
 *   `user_not_found`) produzem o MESMO resultado visível: avançam para a tela do código, que traz o texto
 *   neutro "Se houver uma conta com este e-mail, enviamos um código". Nunca cria conta nem avança para cadastro.
 * - Nunca mascara 429 (`LIMITE_EXCEDIDO`) nem falta de rede (`SEM_REDE`): esses erros não dizem nada sobre a conta.
 * - Sem fallback de demonstração.
 * - Protegido contra retorno tardio/cancelamento via [tentativaAtual].
 */
class RecuperacaoSenhaViewModel(
    private val servicoAutenticacao: ServicoAutenticacao,
    escopo: CoroutineScope? = null,
    private val permitirDominioDeTeste: Boolean = false,
    emailInicial: String = "",
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope
    private val _estado = MutableStateFlow(EstadoRecuperacaoSenha(email = emailInicial))
    val estado: StateFlow<EstadoRecuperacaoSenha> = _estado.asStateFlow()

    private val sequenciaDeTentativa = AtomicLong(0L)
    private var tentativaAtual: Long = 0L
    private var pedido: Job? = null

    fun aoMudarEmail(novoEmail: String) {
        _estado.update { it.copy(email = novoEmail, erro = null) }
    }

    fun aoNavegarParaCodigo() {
        _estado.update { it.copy(avancarParaCodigo = false) }
    }

    fun cancelarTentativaAtual() {
        tentativaAtual = sequenciaDeTentativa.incrementAndGet()
        pedido?.cancel()
        pedido = null
        _estado.update { it.copy(carregando = false) }
    }

    fun solicitarRecuperacao(): Job? {
        pedido?.takeIf { it.isActive }?.let { return it }
        val email = _estado.value.email.trim().lowercase()

        if (!PADRAO_EMAIL_RECUPERACAO.matches(email)) {
            _estado.update { it.copy(erro = "Informe um e-mail válido.") }
            return null
        }
        // Sem fallback de demonstração na recuperação.
        if (DemonstracaoContas.ehContaDeDemonstracao(email, permitirDominioDeTeste)) {
            _estado.update { it.copy(erro = "Esta conta usa apenas o modo demonstração.") }
            return null
        }

        val idTentativa = sequenciaDeTentativa.incrementAndGet()
        tentativaAtual = idTentativa
        _estado.update { it.copy(email = email, carregando = true, erro = null) }

        return escopoDeTrabalho.launch {
            try {
                servicoAutenticacao.solicitarOtpRecuperacao(email)
                if (tentativaAtual != idTentativa) return@launch
                _estado.update { it.copy(carregando = false, avancarParaCodigo = true) }
            } catch (cancelado: CancellationException) {
                if (tentativaAtual == idTentativa) {
                    _estado.update { it.copy(carregando = false) }
                }
                throw cancelado
            } catch (erro: ErroDaApi) {
                if (tentativaAtual != idTentativa) return@launch
                if (indicaIdentidadeInexistenteOuSocialOnly(erro)) {
                    // Mesmo resultado do envio com sucesso: quem não tem conta não se distingue de quem tem.
                    _estado.update { it.copy(carregando = false, erro = null, avancarParaCodigo = true) }
                } else {
                    _estado.update { it.copy(carregando = false, erro = mensagemDeErro(erro)) }
                }
            } catch (_: Exception) {
                if (tentativaAtual != idTentativa) return@launch
                _estado.update {
                    it.copy(
                        carregando = false,
                        erro = "Não foi possível enviar o código. Tente de novo em instantes.",
                    )
                }
            }
        }.also { pedido = it }
    }

    private fun indicaIdentidadeInexistenteOuSocialOnly(erro: ErroDaApi): Boolean {
        if (erro.codigo == CodigoErroAPI.LIMITE_EXCEDIDO || erro.codigo == CodigoErroAPI.SEM_REDE) {
            return false
        }
        return erro.codigo == CodigoErroAPI.NAO_ENCONTRADO ||
            erro.codigoOriginal == "otp_disabled" ||
            erro.codigoOriginal == "user_not_found"
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.SEM_REDE -> "Sem conexão. Verifique sua internet e tente de novo."
        CodigoErroAPI.LIMITE_EXCEDIDO -> MENSAGEM_LIMITE_DE_CODIGOS
        else -> "Não foi possível enviar o código. Tente de novo em instantes."
    }
}
