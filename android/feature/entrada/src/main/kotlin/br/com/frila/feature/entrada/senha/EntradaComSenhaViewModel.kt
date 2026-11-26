package br.com.frila.feature.entrada.senha

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.DemonstracaoContas
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ProvedorSocial
import br.com.frila.core.rede.ResultadoCallbackOAuth
import br.com.frila.core.rede.ResultadoEntradaComSenha
import br.com.frila.core.rede.SegurancaOAuthSocial
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.SessaoDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.ArmazenamentoOAuthPendente
import br.com.frila.core.seguranca.ArmazenamentoOAuthPendenteEmMemoria
import br.com.frila.core.seguranca.ProvedorOAuthSocial
import br.com.frila.core.seguranca.Sessao
import br.com.frila.core.seguranca.TransacaoOAuthPendente
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

/** Desafio de OTP pendente quando o dispositivo é novo ou teve a confiança vencida/revogada. */
data class DesafioOtpPendente(
    val email: String,
    val desafioId: String,
)

/** Estado da tela de login rotineiro por e-mail e senha. A senha existe só em memória enquanto o usuário digita. */
data class EstadoEntradaComSenha(
    val email: String = "",
    val senha: String = "",
    val carregando: Boolean = false,
    val erro: String? = null,
    val autenticado: Boolean = false,
    val precisaDefinirSenha: Boolean = false,
    val desafioOtp: DesafioOtpPendente? = null,
    val mostrarLoginSocial: Boolean = false,
)

private data class PedidoOAuthEmAndamento(
    val provedor: ProvedorSocial,
    val transacaoId: String,
    val verifier: String,
    val txLocal: String,
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
    mostrarLoginSocial: Boolean = false,
    private val armazenamentoOAuthPendente: ArmazenamentoOAuthPendente = ArmazenamentoOAuthPendenteEmMemoria(),
    private val urlCallbackOAuth: String = SegurancaOAuthSocial.URL_CALLBACK,
    private val permitirCustomSchemeDev: Boolean = true,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope
    private val _estado = MutableStateFlow(
        EstadoEntradaComSenha(email = emailInicial, mostrarLoginSocial = mostrarLoginSocial),
    )
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
        _estado.update { it.copy(autenticado = false, precisaDefinirSenha = false) }
    }

    fun aoConsumirDesafioOtp() {
        _estado.update { it.copy(desafioOtp = null) }
    }

    fun cancelarTentativaAtual(limparOAuth: Boolean = true) {
        tentativaAtual = sequenciaDeTentativa.incrementAndGet()
        pedido?.cancel()
        pedido = null
        if (limparOAuth) {
            armazenamentoOAuthPendente.limpar()
        }
        _estado.update { it.copy(carregando = false) }
    }

    /**
     * Inicia o fluxo OAuth PKCE S256 (Google ou Apple) via `POST /functions/v1/autenticar-social`
     * (`fluxo = "iniciar_pkce"`, contrato 0.2.117), guardando `transacaoId`, `verifier` e `txLocal`
     * em armazenamento seguro isolado com TTL <= 10 min e entregando `url_autorizacao` para abertura
     * via Custom Tabs / navegador do sistema.
     */
    fun iniciarEntradaSocial(
        provedor: ProvedorSocial,
        aoUrlPronta: (String) -> Unit,
    ): Job? {
        if (!_estado.value.mostrarLoginSocial || _estado.value.carregando) return null
        val idTentativa = sequenciaDeTentativa.incrementAndGet()
        tentativaAtual = idTentativa
        val verifier = SegurancaOAuthSocial.gerarVerifierPkce()
        val challenge = SegurancaOAuthSocial.desafioPkceS256(verifier)
        val txLocal = SegurancaOAuthSocial.gerarState()
        val redirectTo = "$urlCallbackOAuth?tx=$txLocal"
        _estado.update { it.copy(carregando = true, erro = null) }

        return escopoDeTrabalho.launch {
            try {
                val inicio = servicoAutenticacao.iniciarLoginSocialPkce(
                    provedor = provedor,
                    codeChallenge = challenge,
                    redirectTo = redirectTo,
                )
                if (tentativaAtual != idTentativa) return@launch
                val provedorSocial = when (provedor) {
                    ProvedorSocial.GOOGLE -> ProvedorOAuthSocial.GOOGLE
                    ProvedorSocial.APPLE -> ProvedorOAuthSocial.APPLE
                }
                armazenamentoOAuthPendente.salvar(
                    TransacaoOAuthPendente(
                        provedor = provedorSocial,
                        transacaoId = inicio.transacaoId,
                        verifier = verifier,
                        txLocal = txLocal,
                        expiraEmMillis = System.currentTimeMillis() + TTL_OAUTH_MILLIS,
                    ),
                )
                _estado.update { it.copy(carregando = false, erro = null) }
                aoUrlPronta(inicio.urlAutorizacao)
            } catch (cancelado: CancellationException) {
                if (tentativaAtual == idTentativa) {
                    _estado.update { it.copy(carregando = false) }
                }
                throw cancelado
            } catch (erro: ErroDaApi) {
                if (tentativaAtual != idTentativa) return@launch
                val mensagem = when (erro.codigo) {
                    CodigoErroAPI.SEM_REDE -> "Sem conexão. Verifique sua internet e tente de novo."
                    CodigoErroAPI.LIMITE_EXCEDIDO -> "Muitas tentativas em pouco tempo. Aguarde alguns minutos e tente de novo."
                    else -> MENSAGEM_ERRO_SOCIAL_PADRAO
                }
                _estado.update { it.copy(carregando = false, erro = mensagem) }
            } catch (_: Exception) {
                if (tentativaAtual != idTentativa) return@launch
                _estado.update { it.copy(carregando = false, erro = MENSAGEM_ERRO_SOCIAL_PADRAO) }
            }
        }.also { pedido = it }
    }

    /**
     * Processa a URL de retorno (`frila-auth://auth/callback?...`) validando esquema, `tx` (P2) e PKCE.
     * Callbacks forjados sem correspondência de `tx` (Ignorado) NÃO apagam `armazenamentoOAuthPendente`.
     * Caso contrário consome o pedido de uso único e conclui via `POST /functions/v1/autenticar-social`.
     */
    fun aoReceberCallbackOAuth(callbackUrl: String): Job? {
        val pendente = armazenamentoOAuthPendente.obter() ?: return null
        val analisado = SegurancaOAuthSocial.analisarCallback(
            callbackUrl,
            stateEsperado = pendente.txLocal,
            permitirCustomSchemeDev = permitirCustomSchemeDev,
        )
        if (analisado is ResultadoCallbackOAuth.Ignorado) {
            return null
        }
        armazenamentoOAuthPendente.limpar()

        return when (analisado) {
            ResultadoCallbackOAuth.Ignorado -> null
            ResultadoCallbackOAuth.Cancelado -> {
                _estado.update { it.copy(carregando = false, erro = null) }
                null
            }
            ResultadoCallbackOAuth.ConflitoDeIdentidade -> {
                _estado.update { it.copy(carregando = false, erro = MENSAGEM_CONFLITO_IDENTIDADE) }
                null
            }
            ResultadoCallbackOAuth.CallbackInvalido -> {
                _estado.update { it.copy(carregando = false, erro = MENSAGEM_ERRO_SOCIAL_PADRAO) }
                null
            }
            is ResultadoCallbackOAuth.Codigo -> {
                val idTentativa = sequenciaDeTentativa.incrementAndGet()
                tentativaAtual = idTentativa
                _estado.update { it.copy(carregando = true, erro = null) }
                escopoDeTrabalho.launch {
                    try {
                        val provedorSocial = when (pendente.provedor) {
                            ProvedorOAuthSocial.GOOGLE -> ProvedorSocial.GOOGLE
                            ProvedorOAuthSocial.APPLE -> ProvedorSocial.APPLE
                        }
                        val resposta = servicoAutenticacao.concluirLoginSocialPkce(
                            provedor = provedorSocial,
                            transacaoId = pendente.transacaoId,
                            codigo = analisado.valor,
                            verifier = pendente.verifier,
                        )
                        if (tentativaAtual != idTentativa) return@launch
                        val emailExtraido = ServicoAutenticacao.extrairEmailDoJwt(resposta.sessao.accessToken)
                        armazenamentoDeSessao.salvarSessao(resposta.sessao.paraSessao(email = emailExtraido))
                        _estado.update {
                            it.copy(
                                carregando = false,
                                senha = "",
                                erro = null,
                                autenticado = true,
                                precisaDefinirSenha = resposta.precisaDefinirSenha,
                                desafioOtp = null,
                            )
                        }
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
                        val mensagem = when {
                            SegurancaOAuthSocial.ehErroConflitoIdentidade(erro) -> MENSAGEM_CONFLITO_IDENTIDADE
                            erro.codigo == CodigoErroAPI.SEM_REDE -> "Sem conexão. Verifique sua internet e tente de novo."
                            erro.codigo == CodigoErroAPI.LIMITE_EXCEDIDO -> "Muitas tentativas em pouco tempo. Aguarde alguns minutos e tente de novo."
                            else -> MENSAGEM_ERRO_SOCIAL_PADRAO
                        }
                        _estado.update { it.copy(carregando = false, erro = mensagem) }
                    } catch (_: Exception) {
                        if (tentativaAtual != idTentativa) return@launch
                        _estado.update { it.copy(carregando = false, erro = MENSAGEM_ERRO_SOCIAL_PADRAO) }
                    }
                }.also { pedido = it }
            }
        }
    }

    /** O e-mail digitado é de uma conta de demonstração (a entrada dela é pela tela de código em modo demo, nunca por senha). */
    fun digitouContaDeDemonstracao(): Boolean =
        DemonstracaoContas.ehContaDeDemonstracao(_estado.value.email, permitirDominioDeTeste)

    /**
     * Qual conta de demonstração abrir: a que foi digitada (profissional ou contratante), como o app fazia antes da
     * senha; sem e-mail de demonstração digitado, a do profissional.
     */
    fun emailDaDemonstracao(): String =
        if (digitouContaDeDemonstracao()) _estado.value.email.trim().lowercase() else DemonstracaoContas.EMAIL_PROFISSIONAL

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
                when (val resultado = servicoAutenticacao.entrarComSenha(email, senha)) {
                    is ResultadoEntradaComSenha.Autenticado -> {
                        if (tentativaAtual != idTentativa) return@launch
                        armazenamentoDeSessao.salvarSessao(resultado.sessao.paraSessao(email = email))
                        _estado.update {
                            it.copy(
                                carregando = false,
                                senha = "",
                                erro = null,
                                autenticado = true,
                                precisaDefinirSenha = resultado.precisaDefinirSenha,
                                desafioOtp = null,
                            )
                        }
                        try {
                            aoEntrar()
                        } catch (cancelado: CancellationException) {
                            throw cancelado
                        } catch (_: Exception) {
                        }
                    }
                    is ResultadoEntradaComSenha.DesafioOtp -> {
                        if (tentativaAtual != idTentativa) return@launch
                        _estado.update {
                            it.copy(
                                carregando = false,
                                senha = "",
                                erro = null,
                                autenticado = false,
                                desafioOtp = DesafioOtpPendente(email = email, desafioId = resultado.desafioId),
                            )
                        }
                    }
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
        const val TTL_OAUTH_MILLIS = 600_000L // 10 minutos
        const val MENSAGEM_CREDENCIAIS_NEUTRA =
            "E-mail ou senha incorretos. Confira os dados ou defina uma senha para sua conta."
        const val MENSAGEM_CONFLITO_IDENTIDADE =
            "Esta conta social não pôde ser vinculada automaticamente. Entre com seu e-mail e senha."
        const val MENSAGEM_ERRO_SOCIAL_PADRAO =
            "Não foi possível concluir a entrada agora. Tente de novo ou use e-mail e senha."
    }
}

private fun SessaoDto.paraSessao(email: String? = null): Sessao = Sessao(
    accessToken = accessToken,
    refreshToken = refreshToken,
    tokenType = tokenType,
    expiresIn = expiresIn,
    email = email?.trim()?.lowercase()?.takeIf { it.isNotBlank() },
)
