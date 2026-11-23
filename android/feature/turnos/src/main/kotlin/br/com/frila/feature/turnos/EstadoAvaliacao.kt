package br.com.frila.feature.turnos

/** Status do envio da avaliação binária de turno (RF15/RN07). */
enum class StatusAvaliacao { OCIOSO, ENVIANDO, NA_FILA, SUCESSO, ERRO }

/** Estado da tela de avaliação de um turno específico. */
data class EstadoAvaliacao(
    val status: StatusAvaliacao = StatusAvaliacao.OCIOSO,
    val respostaRegistrada: Boolean? = null,
    val mensagemErro: String? = null,
)

/** Mesmo sentido dos avisos de avaliação offline e recusa do iOS. */
object TextosDaFilaDeAvaliacao {
    const val NA_FILA = "Sua avaliação está guardada neste aparelho e será enviada quando a internet voltar."
    const val RECUSADA = "A avaliação guardada neste aparelho não foi registrada. Esse envio não será repetido."
}
