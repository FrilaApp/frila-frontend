package br.com.frila.feature.turnos

/** Status do envio da avaliação binária de turno (RF15/RN07). */
enum class StatusAvaliacao { OCIOSO, ENVIANDO, SUCESSO, ERRO }

/** Estado da tela de avaliação de um turno específico. */
data class EstadoAvaliacao(
    val status: StatusAvaliacao = StatusAvaliacao.OCIOSO,
    val respostaRegistrada: Boolean? = null,
    val mensagemErro: String? = null,
)
