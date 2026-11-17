package br.com.frila.feature.entrada.codigo

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.rede.DemonstracaoContas
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.SessaoDto
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.core.seguranca.Sessao
import br.com.frila.feature.entrada.entrada.MENSAGEM_LIMITE_DE_CODIGOS
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.Instant

private const val TAMANHO_CODIGO = 6

/** Quanto tempo o código vale depois de enviado: 10 min, igual a `CodigoViewModel.validadeDoCodigo` do iOS. */
private val VALIDADE_DO_CODIGO: Duration = Duration.ofSeconds(600)

/** Espera entre um pedido de código e o próximo: 60 s, igual ao temporizador do iOS. */
private val ESPERA_PARA_REENVIAR: Duration = Duration.ofSeconds(60)

/** O Auth responde `otp_expired` tanto para o código errado quanto para o vencido. */
private const val ERRO_DO_AUTH_CODIGO_RECUSADO = "otp_expired"

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
    private val agora: () -> Instant = Instant::now,
    /** Depois da entrada (sessão já salva): no app, registra o aparelho para o push (C0-10). */
    private val aoEntrar: suspend () -> Unit = {},
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    // Minúsculas e sem espaços, como o iOS: é o mesmo e-mail que a tela de entrada mandou ao pedir o código.
    private val _estado = MutableStateFlow(EstadoCodigo(email = email.trim().lowercase()))
    val estado: StateFlow<EstadoCodigo> = _estado.asStateFlow()

    /** Quando o último código foi pedido (primeiro envio ou reenvio): separa "incorreto" de "expirado". */
    private var codigoPedidoEm: Instant = agora()

    /**
     * Segundos que faltam para poder pedir outro código: 60 s depois do último pedido (primeiro envio ou
     * reenvio), como no iOS. A tela usa este valor para a contagem do botão.
     */
    fun segundosParaReenviar(): Long {
        val liberadoEm = codigoPedidoEm.plus(ESPERA_PARA_REENVIAR)
        val falta = Duration.between(agora(), liberadoEm)
        // Arredonda para cima: com 0,4 s faltando a tela ainda mostra 1.
        return if (falta.isNegative || falta.isZero) 0 else (falta.toMillis() + 999) / 1000
    }

    /** A verificação em voo: um segundo toque não manda de novo. */
    private var verificacao: Job? = null

    /** Devolve a verificação disparada quando o código chega aos 6 dígitos (como o iOS), ou `null`. */
    fun aoMudarCodigo(novoCodigo: String): Job? {
        val somenteDigitos = novoCodigo.filter { it.isDigit() }.take(TAMANHO_CODIGO)
        val mudou = somenteDigitos != _estado.value.codigo
        _estado.update { it.copy(codigo = somenteDigitos, erro = null) }
        return if (mudou && somenteDigitos.length == TAMANHO_CODIGO) confirmarCodigo() else null
    }

    fun confirmarCodigo(): Job? {
        verificacao?.takeIf { it.isActive }?.let { return it }
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
                // O registro do aparelho não segura nem desfaz a entrada: falhou, tenta de novo na próxima abertura.
                try {
                    aoEntrar()
                } catch (cancelado: CancellationException) {
                    throw cancelado
                } catch (_: Exception) {
                }
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(carregando = false, erro = mensagemDaVerificacao(erro)) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (_: Exception) {
                // Resposta 200 que não decodifica não é ErroDaApi: sem isto a tela ficava em "Confirmando…".
                _estado.update {
                    it.copy(carregando = false, erro = "Não foi possível confirmar o código. Tente de novo em instantes.")
                }
            }
        }.also { verificacao = it }
    }

    fun reenviarCodigo(): Job? {
        if (segundosParaReenviar() > 0 || _estado.value.carregando) return null
        val email = _estado.value.email

        if (DemonstracaoContas.ehContaDeDemonstracao(email)) {
            codigoPedidoEm = agora()
            _estado.update { it.copy(reenviado = true, erro = null, reenviosFeitos = it.reenviosFeitos + 1) }
            return null
        }

        return escopoDeTrabalho.launch {
            _estado.update { it.copy(carregando = true, erro = null, reenviado = false) }
            try {
                servicoAutenticacao.solicitarOtp(email)
                codigoPedidoEm = agora()
                _estado.update {
                    it.copy(carregando = false, reenviado = true, codigo = "", reenviosFeitos = it.reenviosFeitos + 1)
                }
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(carregando = false, erro = mensagemDeErro(erro)) }
            }
        }
    }

    /**
     * Igual ao iOS (`tratarErroDeVerificacao`): o Auth devolve `otp_expired` para o código errado e para o
     * vencido, e só o tempo desde o pedido separa os dois. Dentro da validade, o que se digitou está errado.
     */
    private fun mensagemDaVerificacao(erro: ErroDaApi): String {
        val recusadoPeloAuth = erro.codigoOriginal == ERRO_DO_AUTH_CODIGO_RECUSADO
        val codigoRecusado = recusadoPeloAuth ||
            erro.codigo.name in setOf("NAO_AUTENTICADO", "NAO_ENCONTRADO", "CAMPO_INVALIDO")
        if (!codigoRecusado) return mensagemDeErro(erro)
        val vencido = Duration.between(codigoPedidoEm, agora()) >= VALIDADE_DO_CODIGO
        return if (recusadoPeloAuth && vencido) {
            "Código expirado. Peça um novo código para continuar."
        } else {
            "Código incorreto. Confira os números e tente novamente."
        }
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo.name) {
        "SEM_REDE" -> "Sem conexão. Verifique sua internet e tente de novo."
        "LIMITE_EXCEDIDO" -> MENSAGEM_LIMITE_DE_CODIGOS
        else -> "Não foi possível confirmar o código. Tente de novo em instantes."
    }
}

private fun SessaoDto.paraSessao(): Sessao = Sessao(
    accessToken = accessToken,
    refreshToken = refreshToken,
    tokenType = tokenType,
    expiresIn = expiresIn,
)
