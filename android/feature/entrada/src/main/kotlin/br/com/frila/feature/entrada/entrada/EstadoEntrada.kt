package br.com.frila.feature.entrada.entrada

/** Estado da tela de entrada (login por e-mail/OTP). */
data class EstadoEntrada(
    val email: String = "",
    val carregando: Boolean = false,
    val erro: String? = null,
    /** `true` depois que o código foi solicitado (ou, no modo demo, imediatamente) — navega para a tela de código. */
    val otpSolicitado: Boolean = false,
    val ehContaDeDemonstracao: Boolean = false,
)
