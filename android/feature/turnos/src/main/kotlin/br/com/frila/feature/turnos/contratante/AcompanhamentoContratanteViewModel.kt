package br.com.frila.feature.turnos.contratante

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.PosicaoNoPainelDto
import br.com.frila.core.rede.ResultadoRegistroDto
import br.com.frila.core.rede.VagaResumoDto
import java.time.Instant
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Em que pé está a chegada do profissional ao turno, pelo que o painel diz dela. */
enum class PresencaDoTurno { AGUARDANDO, A_CAMINHO, EM_ATRASO, CHECKIN_MANUAL_PENDENTE, VERIFICADA, NAO_VERIFICADA }

/**
 * O turno como a casa o vê: a vaga e a posição do painel (`painel_estabelecimento`). O Android não tem
 * leitura de turno para o contratante; quem abre a tela entrega a linha do painel ([dePainel]).
 */
data class ContextoDoTurnoContratante(
    val turnoId: String,
    val funcao: String,
    val local: String,
    val inicio: Instant?,
    val fim: Instant?,
    val profissional: PerfilPublicoDto?,
    val aCaminhoEm: Instant?,
    val checkinEm: Instant?,
    /** `geolocalizado`, `manual` ou `codigo`; valor que o app não conhece conta como check-in feito. */
    val checkinTipo: String?,
    /** `pendente`, `verificado`, `nao_verificado` ou `null` sem check-in. */
    val verificacao: String?,
    val emAtraso: Boolean,
) {
    companion object {
        /** `null` se a posição ainda não tem turno (aberta, ou cancelada sem profissional). */
        fun dePainel(vaga: VagaResumoDto, posicao: PosicaoNoPainelDto): ContextoDoTurnoContratante? {
            val turnoId = posicao.turnoId ?: return null
            return ContextoDoTurnoContratante(
                turnoId = turnoId,
                funcao = vaga.funcao,
                local = vaga.local,
                inicio = lerInstante(vaga.inicioEm),
                fim = lerInstante(vaga.fimEm),
                profissional = posicao.profissional,
                aCaminhoEm = posicao.aCaminhoEm?.let(::lerInstante),
                checkinEm = posicao.checkinEm?.let(::lerInstante),
                checkinTipo = posicao.checkinTipo,
                verificacao = posicao.verificacao,
                emAtraso = posicao.emAtraso,
            )
        }
    }
}

/**
 * A presença a mostrar, por prioridade: verificada; check-in feito e ainda pendente (a casa confirma);
 * não verificada; atraso de 15 minutos sem check-in; a caminho; aguardando.
 */
fun presencaDe(contexto: ContextoDoTurnoContratante): PresencaDoTurno = when {
    contexto.verificacao == "verificado" -> PresencaDoTurno.VERIFICADA
    contexto.verificacao == "pendente" && contexto.checkinTipo != null -> PresencaDoTurno.CHECKIN_MANUAL_PENDENTE
    contexto.verificacao == "nao_verificado" -> PresencaDoTurno.NAO_VERIFICADA
    contexto.emAtraso -> PresencaDoTurno.EM_ATRASO
    contexto.aCaminhoEm != null -> PresencaDoTurno.A_CAMINHO
    else -> PresencaDoTurno.AGUARDANDO
}

/** O que a última tentativa de confirmar a presença deixou para a tela dizer. */
enum class AvisoDaConfirmacao(val mensagem: String, val erro: Boolean) {
    CONFIRMADA_AGORA(TextosTurnoDoContratante.CONFIRMADA_AGORA, false),
    JA_CONFIRMADA(TextosTurnoDoContratante.JA_CONFIRMADA, false),
    CHECKIN_PENDENTE(TextosTurnoDoContratante.ERRO_CHECKIN_PENDENTE, true),
    NAO_ENCONTRADO(TextosTurnoDoContratante.ERRO_NAO_ENCONTRADO, true),
    SEM_PERMISSAO(TextosTurnoDoContratante.ERRO_SEM_PERMISSAO, true),
    SESSAO_EXPIRADA(TextosTurnoDoContratante.ERRO_SESSAO, true),
    SEM_REDE(TextosTurnoDoContratante.ERRO_SEM_REDE, true),
    GENERICO(TextosTurnoDoContratante.ERRO_GENERICO, true),
}

data class EstadoTurnoDoContratante(
    val contexto: ContextoDoTurnoContratante,
    val enviando: Boolean = false,
    val aviso: AvisoDaConfirmacao? = null,
) {
    val presenca: PresencaDoTurno get() = presencaDe(contexto)
    val podeConfirmar: Boolean get() = presenca == PresencaDoTurno.CHECKIN_MANUAL_PENDENTE && !enviando
}

/**
 * Acompanhamento do turno pela casa e confirmação do check-in manual (RF13, RF20, RN22, UC05, UC07;
 * paridade com `TelaTurnoDoContratante.swift`, sem o código de check-in da 0.2.68).
 *
 * [confirmar] é `ServicoTurnos.confirmarCheckinManual`. Só confirma quando o painel diz que há check-in
 * manual esperando, e um segundo toque com a chamada em voo não envia outra. `409 checkin_ja_confirmado`
 * não é falha: a presença já valia, e a tela passa a mostrá-la verificada. `409 checkin_pendente` diz
 * que o painel que a tela recebeu está velho: o check-in não existe, e o botão some. Nenhuma falha,
 * inclusive resposta que não é JSON, deixa o botão preso em "Confirmando…". `escopo`: mesma razão do
 * `PerfilViewModel`.
 */
class AcompanhamentoContratanteViewModel(
    contexto: ContextoDoTurnoContratante,
    private val confirmar: suspend (turnoId: String) -> Result<ResultadoRegistroDto>,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoTurnoDoContratante(contexto))
    val estado: StateFlow<EstadoTurnoDoContratante> = _estado.asStateFlow()

    fun confirmarPresenca(): Job {
        val atual = _estado.value
        if (!atual.podeConfirmar) return escopoDeTrabalho.launch { }
        _estado.update { it.copy(enviando = true, aviso = null) }
        return escopoDeTrabalho.launch {
            val resultado = try {
                confirmar(atual.contexto.turnoId)
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
                // Quem chama devolve Result, mas um lançamento escapa; sem isto o botão ficaria preso.
                Result.failure(erro)
            }
            resultado
                .onSuccess { registro ->
                    _estado.update {
                        it.copy(
                            contexto = it.contexto.copy(verificacao = registro.verificacao, checkinTipo = registro.tipo),
                            enviando = false,
                            aviso = AvisoDaConfirmacao.CONFIRMADA_AGORA,
                        )
                    }
                }
                .onFailure { erro -> aplicarFalha(erro) }
        }
    }

    private fun aplicarFalha(erro: Throwable) {
        _estado.update {
            val limpo = it.copy(enviando = false)
            when ((erro as? ErroDaApi)?.codigo) {
                CodigoErroAPI.CHECKIN_JA_CONFIRMADO -> limpo.copy(
                    contexto = it.contexto.copy(verificacao = "verificado"),
                    aviso = AvisoDaConfirmacao.JA_CONFIRMADA,
                )
                CodigoErroAPI.CHECKIN_PENDENTE -> limpo.copy(
                    contexto = it.contexto.copy(checkinEm = null, checkinTipo = null, verificacao = null),
                    aviso = AvisoDaConfirmacao.CHECKIN_PENDENTE,
                )
                CodigoErroAPI.NAO_ENCONTRADO -> limpo.copy(aviso = AvisoDaConfirmacao.NAO_ENCONTRADO)
                CodigoErroAPI.SEM_PERMISSAO -> limpo.copy(aviso = AvisoDaConfirmacao.SEM_PERMISSAO)
                CodigoErroAPI.NAO_AUTENTICADO -> limpo.copy(aviso = AvisoDaConfirmacao.SESSAO_EXPIRADA)
                CodigoErroAPI.SEM_REDE -> limpo.copy(aviso = AvisoDaConfirmacao.SEM_REDE)
                else -> limpo.copy(aviso = AvisoDaConfirmacao.GENERICO)
            }
        }
    }
}

private fun lerInstante(texto: String): Instant? = runCatching { Instant.parse(texto) }.getOrNull()
