package br.com.frila.feature.vagas.painel

import br.com.frila.core.dominio.modelo.MotivoDeCancelamentoDaCasa
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.AcaoPendente
import br.com.frila.core.rede.FilaDeAcoes
import br.com.frila.core.rede.TipoAcaoPendente
import br.com.frila.core.rede.EventoDeTelemetria
import java.io.IOException
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.VagaCanceladaDto
import java.time.Duration
import java.time.Instant
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Os motivos que a casa escolhe ao cancelar: os mesmos da posição (`MotivoDeCancelamentoDaCasa`, em `:core:dominio`). */
typealias MotivoDeCancelamentoDaVaga = MotivoDeCancelamentoDaCasa

data class EstadoCancelarVaga(
    /** O que acontece se confirmar, dito antes do toque (RN12). */
    val aviso: String,
    val motivo: MotivoDeCancelamentoDaVaga? = null,
    val detalhes: String = "",
    val enviando: Boolean = false,
    val concluida: Boolean = false,
    val erro: String? = null,
    val naFila: Boolean = false,
) {
    /** O texto que vai ao servidor: o motivo e, se houver, o detalhe depois de dois pontos. `null` enquanto não dá para enviar. */
    val motivoCompleto: String? get() = motivo?.textoParaOServidor(detalhes)

    /** Sem motivo não se cancela. Depois de uma falha dá para tentar de novo; depois de concluído, não. */
    val podeConfirmar: Boolean get() = !enviando && !concluida && !naFila && motivoCompleto != null
}

/**
 * Cancelar a vaga inteira (`cancelar_vaga`, RN12, UC08; paridade com o `CancelamentoViewModel` do iOS no alvo "vaga").
 * Pede o motivo, avisa o efeito antes do toque e mostra a recusa do servidor em texto do Frila. Quem decide é o
 * servidor: o aviso é só a leitura local da antecedência. Sem rede, guarda o motivo para reenviar.
 *
 * [cancelar] é `ServicoVagas.cancelarVaga`. `escopo`: mesma razão do `MinhasVagasViewModel`.
 */
class CancelarVagaViewModel(
    val vagaId: String,
    inicioDaVaga: Instant?,
    private val cancelar: suspend (vagaId: String, motivo: String) -> VagaCanceladaDto,
    private val relogio: () -> Instant = Instant::now,
    escopo: CoroutineScope? = null,
    private val filaDeAcoes: FilaDeAcoes? = null,
    private val contaAtual: () -> String? = { null },
    private val registrarEvento: (EventoDeTelemetria, String?, String?) -> Unit = { _, _, _ -> },
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoCancelarVaga(aviso = avisoDoCancelamento(inicioDaVaga, relogio())))
    val estado: StateFlow<EstadoCancelarVaga> = _estado.asStateFlow()

    private var contaObservada = contaAtual()
    init {
        reconciliarComAFila()
        filaDeAcoes?.let { fila -> escopoDeTrabalho.launch { fila.versao.collect { reconciliarComAFila() } } }
    }

    private fun reconciliarComAFila() {
        val fila = filaDeAcoes ?: return
        val conta = contaAtual()
        if (conta != contaObservada) {
            contaObservada = conta
            _estado.update { EstadoCancelarVaga(aviso = it.aviso) }
        }
        if (conta == null) return
        synchronized(fila) {
            val pendente = fila.pendentes().any { it.tipo == TipoAcaoPendente.CANCELAMENTO_VAGA && it.alvoId == vagaId && it.contaId == conta }
            val recusada = fila.recusadas().any { it.tipo == TipoAcaoPendente.CANCELAMENTO_VAGA && it.vagaId == vagaId && it.contaId == conta }
            _estado.update { e -> when {
                pendente -> e.copy(naFila = true, enviando = false, erro = TextosCancelarVaga.NA_FILA)
                recusada && e.naFila -> EstadoCancelarVaga(aviso = e.aviso, erro = TextosCancelarVaga.RECUSADA)
                recusada -> e.copy(erro = TextosCancelarVaga.RECUSADA)
                e.naFila -> e.copy(naFila = false, concluida = true, erro = null)
                else -> e
            } }
        }
    }

    private fun guardarNaFila(motivo: String, toque: Instant, conta: String?): Boolean {
        val fila = filaDeAcoes ?: return false
        if (conta == null || contaAtual() != conta) return false
        return try {
            synchronized(fila) {
                val existe = fila.pendentes().any { it.tipo == TipoAcaoPendente.CANCELAMENTO_VAGA && it.alvoId == vagaId && it.contaId == conta }
                if (!existe) {
                    fila.enfileirar(AcaoPendente(TipoAcaoPendente.CANCELAMENTO_VAGA, conta, toque.toString(), alvoId = vagaId, motivo = motivo))
                    registrarEvento(EventoDeTelemetria.ACAO_ENFILEIRADA_OFFLINE, vagaId, null)
                }
                _estado.update { it.copy(naFila = true, enviando = false, erro = TextosCancelarVaga.NA_FILA) }
            }
            true
        } catch (_: IOException) { false }
    }

    val motivos: List<MotivoDeCancelamentoDaVaga> = MotivoDeCancelamentoDaVaga.entries

    fun escolherMotivo(motivo: MotivoDeCancelamentoDaVaga) = _estado.update { if (it.naFila) it else it.copy(motivo = motivo, erro = null) }

    fun mudarDetalhes(texto: String) = _estado.update { if (it.naFila) it else it.copy(detalhes = texto, erro = null) }

    /** Envia o cancelamento. `null` se não há o que enviar (sem motivo, já enviando ou já concluído). */
    fun confirmar(): Job? {
        reconciliarComAFila()
        val atual = _estado.value
        val motivo = atual.motivoCompleto
        if (!atual.podeConfirmar || motivo == null) return null
        val toque = relogio()
        val conta = contaAtual()
        filaDeAcoes?.let { fila -> runCatching { fila.recusadas().filter {
            it.tipo == TipoAcaoPendente.CANCELAMENTO_VAGA && it.vagaId == vagaId && it.contaId == conta
        }.forEach { fila.reconhecerRecusa(it.id) } } }
        _estado.update { it.copy(enviando = true, erro = null) }
        return escopoDeTrabalho.launch {
            try {
                cancelar(vagaId, motivo)
                _estado.update { it.copy(enviando = false, concluida = true) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
                if (erro is ErroDaApi && erro.codigo == CodigoErroAPI.SEM_REDE && guardarNaFila(motivo, toque, conta)) return@launch
                _estado.update { it.copy(enviando = false, erro = mensagemDaFalha(erro)) }
            }
        }
    }

    private fun mensagemDaFalha(erro: Exception): String {
        val daApi = erro as? ErroDaApi ?: return TextosCancelarVaga.FALHA_GENERICA
        val sobreOMotivo = daApi.detalhes == "motivo"
        return when (daApi.codigo) {
            CodigoErroAPI.VAGA_ENCERRADA -> TextosCancelarVaga.VAGA_JA_FECHADA
            CodigoErroAPI.CAMPO_INVALIDO -> if (sobreOMotivo) TextosCancelarVaga.MOTIVO_RECUSADO else TextosCancelarVaga.FALHA_GENERICA
            CodigoErroAPI.CAMPO_OBRIGATORIO -> if (sobreOMotivo) TextosCancelarVaga.DETALHES_OBRIGATORIOS else TextosCancelarVaga.FALHA_GENERICA
            CodigoErroAPI.SEM_REDE -> TextosCancelarVaga.SEM_REDE
            CodigoErroAPI.NAO_AUTENTICADO -> TextosCancelarVaga.SESSAO_EXPIRADA
            CodigoErroAPI.SEM_PERMISSAO, CodigoErroAPI.PERFIL_INCOMPATIVEL -> TextosCancelarVaga.CONTA_NAO_PODE
            else -> TextosCancelarVaga.FALHA_GENERICA
        }
    }
}

/**
 * "Faltam 5 h para o início." mais o efeito de cancelar a vaga inteira. Horas inteiras para baixo; abaixo de uma
 * hora, "menos de 1 h"; depois do início, "O turno já começou." (`TextosDoCancelamento.aviso` do iOS). Sem início
 * legível, só o efeito.
 */
internal fun avisoDoCancelamento(inicio: Instant?, agora: Instant): String {
    if (inicio == null) return TextosCancelarVaga.EFEITO
    val antecedencia = Duration.between(agora, inicio)
    if (antecedencia <= Duration.ZERO) return "${TextosCancelarVaga.JA_COMECOU} ${TextosCancelarVaga.EFEITO_COMECADA}"
    val tempo = if (antecedencia < Duration.ofHours(1)) TextosCancelarVaga.MENOS_DE_UMA_HORA else TextosCancelarVaga.HORAS.format(antecedencia.toHours())
    return "${TextosCancelarVaga.FALTAM_PARA_O_INICIO.format(tempo)} ${TextosCancelarVaga.EFEITO}"
}
