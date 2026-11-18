package br.com.frila.feature.turnos.contratante

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.ResultadoCancelamento
import br.com.frila.core.dominio.regra.instanteDoServidor
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
    /** L2-2: a posição do painel (`posicao.id`), o que `reabrir_por_atraso` recebe; `null` fora do painel. */
    val posicaoId: String? = null,
    /** L2-2: `confirmada`, `cancelada`… (`posicao.estado`); só a confirmada pode ser reaberta. */
    val estadoDaPosicao: String? = null,
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
                posicaoId = posicao.id,
                estadoDaPosicao = posicao.estado,
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

/** O que a reabertura devolveu: a falta sempre fica registrada; `reaberta = false` é o turno que ficou descoberto. */
data class ResultadoDaReabertura(val reaberta: Boolean)

/** O que a última tentativa de reabrir a vaga deixou para a tela dizer (L2-2). */
enum class AvisoDaReabertura(val mensagem: String, val erro: Boolean) {
    REABERTA(TextosTurnoDoContratante.VAGA_REABERTA, false),
    FALTA_SEM_REABERTURA(TextosTurnoDoContratante.FALTA_SEM_REABERTURA, false),
    ANTES_DA_TOLERANCIA(TextosTurnoDoContratante.ERRO_ANTES_DA_TOLERANCIA, true),
    CHECKIN_REGISTRADO(TextosTurnoDoContratante.ERRO_CHECKIN_REGISTRADO, true),
    SITUACAO_MUDOU(TextosTurnoDoContratante.ERRO_SITUACAO_MUDOU, true),
    SEM_PERMISSAO(TextosTurnoDoContratante.ERRO_REABRIR_SEM_PERMISSAO, true),
    SESSAO_EXPIRADA(TextosTurnoDoContratante.ERRO_SESSAO, true),
    RESULTADO_INCERTO(TextosTurnoDoContratante.ERRO_REABRIR_RESULTADO_INCERTO, true),
}

data class EstadoTurnoDoContratante(
    val contexto: ContextoDoTurnoContratante,
    val enviando: Boolean = false,
    val aviso: AvisoDaConfirmacao? = null,
    /** L2-2: verdadeiro só quando quem abriu a tela entregou a chamada de reabertura; sem ela o botão não existe. */
    val reaberturaDisponivel: Boolean = false,
    /** A pergunta "Reabrir a vaga?" está na tela: reabrir conta como falta e não tem volta. */
    val pedindoReabertura: Boolean = false,
    val reabrindo: Boolean = false,
    val reabertura: ResultadoDaReabertura? = null,
    val avisoDaReabertura: AvisoDaReabertura? = null,
    /** O servidor recusou a reabertura, ou o resultado ficou incerto: o botão só volta quando o painel for relido. */
    val reaberturaRecusada: Boolean = false,
) {
    val presenca: PresencaDoTurno get() = presencaDe(contexto)
    val podeConfirmar: Boolean get() = presenca == PresencaDoTurno.CHECKIN_MANUAL_PENDENTE && !enviando

    /**
     * Só o atraso do painel (15 minutos do início, sem check-in) na posição confirmada libera a reabertura, uma vez, com
     * nenhuma outra em voo e sem recusa do servidor desde a última leitura (paridade com `podeReabrir` do iOS).
     */
    val podeReabrir: Boolean
        get() = reaberturaDisponivel && contexto.posicaoId != null && contexto.estadoDaPosicao == "confirmada" &&
            presenca == PresencaDoTurno.EM_ATRASO && !reabrindo && !reaberturaRecusada && reabertura == null
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
    /**
     * L2-2: `ServicoTurnos.reabrirPorAtraso`. Nulo (o padrão, até a fiação do L2-8) esconde a reabertura. A chamada não
     * é idempotente e o contrato não tem chave de idempotência: a proteção é a pergunta, um envio por vez e nunca repetir.
     */
    private val reabrir: (suspend (posicaoId: String) -> ResultadoCancelamento)? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoTurnoDoContratante(contexto, reaberturaDisponivel = reabrir != null))
    val estado: StateFlow<EstadoTurnoDoContratante> = _estado.asStateFlow()

    /** Incorpora o painel relido sem recriar o acompanhamento nem interromper a confirmação em voo. */
    fun atualizarContexto(contexto: ContextoDoTurnoContratante) {
        _estado.update { atual ->
            // Uma releitura iniciada antes da confirmação pode chegar depois dela.
            if (atual.contexto.turnoId == contexto.turnoId &&
                atual.presenca == PresencaDoTurno.VERIFICADA &&
                presencaDe(contexto) != PresencaDoTurno.VERIFICADA
            ) atual else atual.copy(contexto = contexto, reaberturaRecusada = false)
        }
    }

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

    /** Reabrir conta como falta e não tem volta: a tela pergunta antes. */
    fun pedirReabertura() {
        _estado.update { if (it.podeReabrir) it.copy(pedindoReabertura = true) else it }
    }

    fun desistirDaReabertura() {
        _estado.update { it.copy(pedindoReabertura = false) }
    }

    /**
     * Só reabre o que passou por [pedirReabertura] e continua em atraso no painel de agora. Devolve `null` quando não
     * envia. A pergunta fecha já no toque, e só uma reabertura anda por vez; uma reabertura feita não se repete.
     */
    fun confirmarReabertura(): Job? {
        val chamada = reabrir ?: return null
        val atual = _estado.value
        val posicaoId = atual.contexto.posicaoId
        if (!atual.pedindoReabertura || !atual.podeReabrir || posicaoId == null) {
            _estado.update { it.copy(pedindoReabertura = false) }
            return null
        }
        _estado.update { it.copy(pedindoReabertura = false, reabrindo = true, avisoDaReabertura = null) }
        return escopoDeTrabalho.launch {
            try {
                val cancelamento = chamada(posicaoId)
                _estado.update {
                    it.copy(
                        reabrindo = false,
                        reabertura = ResultadoDaReabertura(cancelamento.reaberta),
                        contexto = it.contexto.copy(estadoDaPosicao = "cancelada"),
                        avisoDaReabertura = if (cancelamento.reaberta) AvisoDaReabertura.REABERTA else AvisoDaReabertura.FALTA_SEM_REABERTURA,
                    )
                }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                aplicarFalhaDaReabertura(erro)
            } catch (_: Exception) {
                // Resposta que não decodifica (HTML de portal, campo omitido) não é ErroDaApi: nunca o corpo cru (RN15). O
                // servidor pode já ter reaberto e registrado a falta, então o resultado é incerto, como na falha de rede.
                _estado.update {
                    it.copy(reabrindo = false, avisoDaReabertura = AvisoDaReabertura.RESULTADO_INCERTO, reaberturaRecusada = true)
                }
            }
        }
    }

    /**
     * As recusas do contrato escondem o botão até o painel ser relido. Falha de rede (inclusive timeout depois do envio) e
     * resposta ilegível também: o servidor pode ter reaberto e registrado a falta, que não tem volta, então o resultado é
     * incerto e nada é reenviado sozinho. O 5xx com envelope (inclusive o 502 do gateway) e o código desconhecido têm o mesmo
     * tratamento: o servidor pode ter gravado antes de falhar. Só o 401 (a chamada nem chegou a valer) deixa tentar de novo.
     */
    private fun aplicarFalhaDaReabertura(erro: ErroDaApi) {
        val (aviso, recusada) = when (erro.codigo) {
            CodigoErroAPI.REABERTURA_ANTES_DA_TOLERANCIA -> AvisoDaReabertura.ANTES_DA_TOLERANCIA to true
            CodigoErroAPI.POSICAO_NAO_CANCELAVEL ->
                (if (erro.detalhes == "checkin_registrado") AvisoDaReabertura.CHECKIN_REGISTRADO else AvisoDaReabertura.SITUACAO_MUDOU) to true
            CodigoErroAPI.SEM_PERMISSAO -> AvisoDaReabertura.SEM_PERMISSAO to true
            CodigoErroAPI.NAO_AUTENTICADO -> AvisoDaReabertura.SESSAO_EXPIRADA to false
            // Rede, resposta ilegível, 5xx e código novo: o servidor pode ter gravado antes da queda ou do 502.
            else -> AvisoDaReabertura.RESULTADO_INCERTO to true
        }
        _estado.update { it.copy(reabrindo = false, avisoDaReabertura = aviso, reaberturaRecusada = recusada) }
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

private fun lerInstante(texto: String): Instant? = runCatching { instanteDoServidor(texto) }.getOrNull()
