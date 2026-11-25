package br.com.frila.feature.entrada.senha

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
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

/** Estado da tela de definição/atualização de senha na sessão autenticada atual. */
data class EstadoDefinirSenha(
    val senha: String = "",
    val confirmacao: String = "",
    val carregando: Boolean = false,
    val erro: String? = null,
    val concluido: Boolean = false,
)

/**
 * Define ou atualiza a senha da conta autenticada atual (`PUT /auth/v1/user`), preservando
 * rigorosamente o mesmo `auth.uid`. Nunca persiste a senha em disco nem a envia para logs.
 */
class DefinirSenhaViewModel(
    private val servicoAutenticacao: ServicoAutenticacao,
    private val armazenamentoDeSessao: ArmazenamentoDeSessao,
    escopo: CoroutineScope? = null,
    private val manterDispositivoAtual: Boolean = false,
    private val emailAtual: String? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope
    private val _estado = MutableStateFlow(EstadoDefinirSenha())
    val estado: StateFlow<EstadoDefinirSenha> = _estado.asStateFlow()

    private val sequenciaDeTentativa = AtomicLong(0L)
    private var tentativaAtual: Long = 0L
    private var pedido: Job? = null

    fun aoMudarSenha(novaSenha: String) {
        _estado.update { it.copy(senha = novaSenha, erro = null) }
    }

    fun aoMudarConfirmacao(novaConfirmacao: String) {
        _estado.update { it.copy(confirmacao = novaConfirmacao, erro = null) }
    }

    fun cancelarTentativaAtual() {
        tentativaAtual = sequenciaDeTentativa.incrementAndGet()
        pedido?.cancel()
        pedido = null
        _estado.update { it.copy(carregando = false) }
    }

    fun salvar(): Job? {
        pedido?.takeIf { it.isActive }?.let { return it }
        val estadoAtual = _estado.value

        if (estadoAtual.senha.length < TAMANHO_MINIMO_SENHA) {
            _estado.update { it.copy(erro = "Use pelo menos $TAMANHO_MINIMO_SENHA caracteres na senha.") }
            return null
        }
        if (estadoAtual.senha != estadoAtual.confirmacao) {
            _estado.update { it.copy(erro = "As senhas não conferem. Digite a mesma senha nos dois campos.") }
            return null
        }
        if (!armazenamentoDeSessao.estaAutenticado()) {
            _estado.update { it.copy(erro = "Sua sessão expirou. Entre novamente para definir sua senha.") }
            return null
        }

        val idTentativa = sequenciaDeTentativa.incrementAndGet()
        tentativaAtual = idTentativa
        val novaSenha = estadoAtual.senha
        _estado.update { it.copy(carregando = true, erro = null) }

        return escopoDeTrabalho.launch {
            try {
                val sessaoAtual = armazenamentoDeSessao.obterSessao()
                val resposta = servicoAutenticacao.definirSenha(
                    novaSenha = novaSenha,
                    manterDispositivoAtual = manterDispositivoAtual,
                    emailAtual = emailAtual,
                    refreshToken = sessaoAtual?.refreshToken,
                )
                if (tentativaAtual != idTentativa) return@launch
                resposta.sessao?.let { novaSessao ->
                    armazenamentoDeSessao.salvarSessao(novaSessao.paraSessaoDefinir(vinculoId = sessaoAtual?.vinculoId))
                }
                _estado.update {
                    it.copy(
                        senha = "",
                        confirmacao = "",
                        carregando = false,
                        erro = null,
                        concluido = true,
                    )
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
                _estado.update { it.copy(carregando = false, erro = "Não foi possível salvar a senha agora. Tente de novo em instantes.") }
            }
        }.also { pedido = it }
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when {
        erro.codigoOriginal == "weak_password" || erro.codigoOriginal == "senha_fraca" ->
            "Escolha uma senha mais forte, combinando letras e números."
        erro.codigoOriginal == "same_password" || erro.codigoOriginal == "senha_igual" ->
            "Escolha uma senha diferente da atual."
        erro.codigoOriginal == "reauthentication_needed" || erro.codigoOriginal == "reautenticacao_necessaria" ->
            "Por segurança, confirme um novo código no seu e-mail antes de trocar a senha."
        erro.codigoOriginal == "dispositivo_nao_verificado" ->
            "Confirme este dispositivo com um código por e-mail antes de continuar."
        erro.codigo == CodigoErroAPI.SEM_REDE ->
            "Sem conexão. Verifique sua internet e tente de novo."
        erro.codigo == CodigoErroAPI.LIMITE_EXCEDIDO ->
            "Muitas tentativas em pouco tempo. Aguarde alguns minutos e tente de novo."
        else ->
            "Não foi possível salvar a senha agora. Tente de novo em instantes."
    }

    companion object {
        const val TAMANHO_MINIMO_SENHA = 8
    }
}

private fun SessaoDto.paraSessaoDefinir(vinculoId: String?): Sessao = Sessao(
    accessToken = accessToken,
    refreshToken = refreshToken,
    tokenType = tokenType,
    expiresIn = expiresIn,
    vinculoId = vinculoId,
)
