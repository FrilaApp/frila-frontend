package br.com.frila.feature.entrada.codigo

/** Estado da tela de código (verificação do OTP de 6 dígitos ou entrada em modo demo). */
data class EstadoCodigo(
    val email: String,
    val codigo: String = "",
    val carregando: Boolean = false,
    val erro: String? = null,
    val autenticado: Boolean = false,
    val reenviado: Boolean = false,
)
