package br.com.frila.feature.vagas.painel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
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

/** Os motivos que a casa escolhe ao cancelar. O texto é o `motivo` que vai ao servidor; `OUTRO` exige o campo livre. */
enum class MotivoDeCancelamentoDaVaga(val texto: String, val exigeDetalhes: Boolean = false) {
    MOVIMENTO_MENOR(TextosCancelarVaga.MOTIVO_MOVIMENTO_MENOR),
    PREENCHIDA_FORA(TextosCancelarVaga.MOTIVO_PREENCHIDA_FORA),
    MUDANCA_DE_PLANOS(TextosCancelarVaga.MOTIVO_MUDANCA_DE_PLANOS),
    PROBLEMA_NO_LOCAL(TextosCancelarVaga.MOTIVO_PROBLEMA_NO_LOCAL),
    OUTRO(TextosCancelarVaga.MOTIVO_OUTRO, exigeDetalhes = true),
}

data class EstadoCancelarVaga(
    /** O que acontece se confirmar, dito antes do toque (RN12). */
    val aviso: String,
    val motivo: MotivoDeCancelamentoDaVaga? = null,
    val detalhes: String = "",
    val enviando: Boolean = false,
    val concluida: Boolean = false,
    val erro: String? = null,
) {
    /** O texto que vai ao servidor: o motivo e, se houver, o detalhe depois de dois pontos. `null` enquanto não dá para enviar. */
    val motivoCompleto: String?
        get() {
            val escolhido = motivo ?: return null
            val detalhe = detalhes.trim()
            if (escolhido.exigeDetalhes) return detalhe.takeIf { it.length >= MINIMO_DO_MOTIVO }
            return if (detalhe.isEmpty()) escolhido.texto else "${escolhido.texto}: $detalhe"
        }

    /** Sem motivo não se cancela. Depois de uma falha dá para tentar de novo; depois de concluído, não. */
    val podeConfirmar: Boolean get() = !enviando && !concluida && motivoCompleto != null

    private companion object {
        const val MINIMO_DO_MOTIVO = 3
    }
}

/**
 * Cancelar a vaga inteira (`cancelar_vaga`, RN12, UC08; paridade com o `CancelamentoViewModel` do iOS no alvo "vaga").
 * Pede o motivo, avisa o efeito antes do toque e mostra a recusa do servidor em texto do Frila. Quem decide é o
 * servidor: o aviso é só a leitura local da antecedência. O Android ainda não tem fila de ações sem rede, então sem
 * conexão o cancelamento não é enviado e a tela diz isso.
 *
 * [cancelar] é `ServicoVagas.cancelarVaga`. `escopo`: mesma razão do `MinhasVagasViewModel`.
 */
class CancelarVagaViewModel(
    val vagaId: String,
    inicioDaVaga: Instant?,
    private val cancelar: suspend (vagaId: String, motivo: String) -> VagaCanceladaDto,
    relogio: () -> Instant = Instant::now,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoCancelarVaga(aviso = avisoDoCancelamento(inicioDaVaga, relogio())))
    val estado: StateFlow<EstadoCancelarVaga> = _estado.asStateFlow()

    val motivos: List<MotivoDeCancelamentoDaVaga> = MotivoDeCancelamentoDaVaga.entries

    fun escolherMotivo(motivo: MotivoDeCancelamentoDaVaga) = _estado.update { it.copy(motivo = motivo, erro = null) }

    fun mudarDetalhes(texto: String) = _estado.update { it.copy(detalhes = texto, erro = null) }

    /** Envia o cancelamento. `null` se não há o que enviar (sem motivo, já enviando ou já concluído). */
    fun confirmar(): Job? {
        val atual = _estado.value
        val motivo = atual.motivoCompleto
        if (!atual.podeConfirmar || motivo == null) return null
        _estado.update { it.copy(enviando = true, erro = null) }
        return escopoDeTrabalho.launch {
            try {
                cancelar(vagaId, motivo)
                _estado.update { it.copy(enviando = false, concluida = true) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
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
