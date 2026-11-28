package br.com.frila.feature.turnos

/** Status do envio da avaliação binária de turno (RF15/RN07). */
/** `JA_AVALIADO`: o servidor respondeu `409 avaliacao_ja_registrada`. Estado final, sem botões (a pergunta já foi respondida deste lado do turno). */
enum class StatusAvaliacao { OCIOSO, ENVIANDO, NA_FILA, SUCESSO, ERRO, JA_AVALIADO }

/** Estado da tela de avaliação de um turno específico. */
data class EstadoAvaliacao(
    val status: StatusAvaliacao = StatusAvaliacao.OCIOSO,
    val respostaRegistrada: Boolean? = null,
    val mensagemErro: String? = null,
)

/** Textos do iOS por extenso (`TextosDoProfissional.swift:357`, `TextosDaPresenca.swift:112`). */
object TextosDaFilaDeAvaliacao {
    const val NA_FILA = "Avaliação salva. Será enviada quando a internet voltar."
    const val RECUSADA = "A avaliação guardada neste aparelho não foi registrada. Você pode tentar novamente quando a avaliação estiver disponível."
}
