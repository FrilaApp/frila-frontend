package br.com.frila.core.dominio.modelo

import java.time.Duration
import java.time.Instant
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Resultado canônico do cancelamento de uma posição confirmada. */
@Serializable
data class ResultadoCancelamento(
    @SerialName("posicao_id") val posicaoId: String,
    val falta: Boolean,
    val reaberta: Boolean,
    @SerialName("nova_posicao_id") val novaPosicaoId: String? = null,
)

/** Motivos oferecidos ao profissional. O servidor recebe a descrição, não o nome do enum. */
enum class MotivoCancelamento(val descricao: String) {
    SAUDE("Problema de saúde"),
    IMPREVISTO_PESSOAL("Imprevisto pessoal"),
    TRANSPORTE("Dificuldade de transporte / deslocamento"),
    OUTRO_COMPROMISSO("Outro compromisso"),
    OUTRO("Outro motivo"),
    ;

    val exigeDetalhes: Boolean
        get() = this == OUTRO
}

/** Regra RN12 pura: apenas antecedência estritamente menor que 24 horas conta como falta. */
object RegraCancelamentoTurno {
    private val ANTECEDENCIA_SEM_FALTA: Duration = Duration.ofHours(24)

    fun contaComoFalta(inicioTurno: Instant, agora: Instant): Boolean =
        Duration.between(agora, inicioTurno) < ANTECEDENCIA_SEM_FALTA
}
