package br.com.frila.feature.conta

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ProtocoloDto
import br.com.frila.core.rede.SituacaoDaContaDto
import java.time.Instant
import java.time.ZoneId
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class EstadoContaSuspensa(
    val carregando: Boolean = false,
    val motivo: String? = null,
    /** O dia em que a suspensão começou, já formatado. */
    val desde: String? = null,
    /** A contestação já feita para esta suspensão, em análise ou respondida. */
    val protocolo: ProtocoloExibido? = null,
    val emAnalise: Boolean = false,
    val formularioAberto: Boolean = false,
    val relato: String = "",
    val enviando: Boolean = false,
    val mensagemErro: String? = null,
    /** O servidor disse que já há contestação (`409`), e ela ainda não chegou na leitura da situação. */
    val contestacaoJaExiste: Boolean = false,
    val contaReativada: Boolean = false,
) {
    val relatoValido: Boolean get() = relato.trim().length >= MINIMO_DO_RELATO

    /** Uma contestação por suspensão pelo app (0.2.36): com protocolo ou depois do `409`, não se oferece outra. */
    val podeContestar: Boolean get() = protocolo == null && !contestacaoJaExiste && !enviando && !contaReativada
}

/**
 * Conta suspensa (RF24, RN13; paridade com o `ContaSuspensaViewModel` do iOS): lê `situacao_da_conta` para mostrar
 * o motivo, a data e o protocolo da contestação, e envia `contestar_suspensao`. Se a leitura disser que a conta
 * voltou a ficar ativa, ou a contestação responder `sem_suspensao_ativa`, [aoReativar] leva a pessoa de volta ao app.
 * O resultado da análise nunca vem ao app: a resposta da Equipe Frila vai por e-mail.
 *
 * [buscarSituacao] é `ServicoConta.situacaoDaConta`; [contestar], `ServicoConta.contestarSuspensao`.
 * `escopo`: mesma razão do `ExclusaoDeContaViewModel`.
 */
class ContaSuspensaViewModel(
    private val buscarSituacao: suspend () -> SituacaoDaContaDto,
    private val contestar: suspend (relato: String) -> ProtocoloDto,
    private val aoReativar: () -> Unit = {},
    private val relogio: () -> Instant = Instant::now,
    private val zona: ZoneId = FUSO_DA_CONTA,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoContaSuspensa())
    val estado: StateFlow<EstadoContaSuspensa> = _estado.asStateFlow()

    private var leitura: Job? = null

    /** Lê a situação da conta. Sem efeito se já há uma leitura em voo. */
    fun carregar(): Job {
        leitura?.takeIf { it.isActive }?.let { return it }
        return escopoDeTrabalho.launch { ler() }.also { leitura = it }
    }

    private suspend fun ler() {
        _estado.update { it.copy(carregando = true) }
        try {
            aplicar(buscarSituacao())
        } catch (erro: CancellationException) {
            throw erro
        } catch (erro: Exception) {
            _estado.update { it.copy(carregando = false, mensagemErro = mensagemDaLeitura(erro)) }
        }
    }

    private fun aplicar(situacao: SituacaoDaContaDto) {
        if (situacao.estado == ESTADO_ATIVA) {
            reativar()
            return
        }
        val suspensao = situacao.suspensao
        val protocolo = suspensao?.contestacao?.paraExibicao(zona)
        _estado.update {
            it.copy(
                carregando = false,
                motivo = suspensao?.motivo?.takeIf(String::isNotBlank),
                desde = suspensao?.desde?.let { desde -> formatarDia(desde, zona) },
                protocolo = protocolo ?: it.protocolo,
                emAnalise = (protocolo ?: it.protocolo)?.emAnalise(relogio(), zona) == true,
                formularioAberto = it.formularioAberto && protocolo == null,
            )
        }
    }

    private fun reativar() {
        _estado.update { it.copy(carregando = false, enviando = false, formularioAberto = false, contaReativada = true) }
        aoReativar()
    }

    fun abrirFormulario() = _estado.update { if (it.podeContestar) it.copy(formularioAberto = true, mensagemErro = null) else it }

    fun cancelarFormulario() = _estado.update { it.copy(formularioAberto = false, mensagemErro = null) }

    fun mudarRelato(texto: String) = _estado.update { it.copy(relato = texto, mensagemErro = null) }

    /** Envia a contestação. `null` se o relato não serve (a tela diz por quê) ou se não há mais o que contestar. */
    fun enviarContestacao(): Job? {
        val atual = _estado.value
        val relato = atual.relato.trim()
        val recusaLocal = when {
            relato.isEmpty() -> TextosContaSuspensa.RELATO_OBRIGATORIO
            relato.length < MINIMO_DO_RELATO -> TextosContaSuspensa.RELATO_MINIMO
            else -> null
        }
        if (recusaLocal != null) {
            _estado.update { it.copy(mensagemErro = recusaLocal) }
            return null
        }
        if (!atual.podeContestar) return null
        _estado.update { it.copy(enviando = true, mensagemErro = null) }
        return escopoDeTrabalho.launch {
            try {
                val protocolo = contestar(relato).paraExibicao(zona)
                _estado.update {
                    it.copy(enviando = false, formularioAberto = false, protocolo = protocolo, emAnalise = protocolo.emAnalise(relogio(), zona))
                }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
                recusar(erro)
            }
        }
    }

    private suspend fun recusar(erro: Exception) {
        when ((erro as? ErroDaApi)?.codigo) {
            CodigoErroAPI.CONTESTACAO_JA_ABERTA -> {
                _estado.update { it.copy(enviando = false, formularioAberto = false, contestacaoJaExiste = true) }
                // A contestação que já existe vem na situação: a tela troca o aviso pelo protocolo.
                ler()
            }
            CodigoErroAPI.SEM_SUSPENSAO_ATIVA -> reativar()
            CodigoErroAPI.CAMPO_INVALIDO -> falhar(TextosContaSuspensa.RELATO_MINIMO)
            CodigoErroAPI.CAMPO_OBRIGATORIO -> falhar(TextosContaSuspensa.RELATO_OBRIGATORIO)
            CodigoErroAPI.SEM_REDE -> falhar(TextosContaSuspensa.ERRO_SEM_REDE)
            CodigoErroAPI.NAO_AUTENTICADO -> falhar(TextosContaSuspensa.ERRO_SESSAO)
            else -> falhar(TextosContaSuspensa.ERRO_GENERICO)
        }
    }

    private fun falhar(mensagem: String) = _estado.update { it.copy(enviando = false, mensagemErro = mensagem) }

    private fun mensagemDaLeitura(erro: Exception): String = when ((erro as? ErroDaApi)?.codigo) {
        CodigoErroAPI.SEM_REDE -> TextosContaSuspensa.ERRO_SEM_REDE
        CodigoErroAPI.NAO_AUTENTICADO -> TextosContaSuspensa.ERRO_SESSAO
        else -> TextosContaSuspensa.ERRO_GENERICO
    }

    private companion object {
        const val ESTADO_ATIVA = "ativa"
    }
}
