package br.com.frila.feature.entrada.codigo

/** Modo operacional da tela de código OTP. */
enum class ModoCodigo(val chave: String) {
    /** Fluxo legado/compatibilidade de entrada direta. */
    ENTRADA("entrada"),
    /** Criação de conta nova: confirmação única de e-mail (`create_user: true`) antes de definir senha. */
    CRIACAO("criacao"),
    /** Recuperação de senha ou migração de conta legada OTP-only (`create_user: false`). */
    RECUPERACAO("recuperacao"),
    /** Contas de demonstração da Play Store (endpoint dedicado, sem password/recovery). */
    DEMO("demo"),
    ;

    companion object {
        fun deChave(chave: String?): ModoCodigo = entries.firstOrNull { it.chave == chave } ?: ENTRADA
    }
}

/** Estado da tela de código (verificação do OTP de 6 dígitos ou entrada em modo demo). */
data class EstadoCodigo(
    val email: String,
    val codigo: String = "",
    val carregando: Boolean = false,
    val erro: String? = null,
    val autenticado: Boolean = false,
    val reenviado: Boolean = false,
    val mensagemReenvio: String? = null,
    /** Quantos reenvios deram certo: a tela recomeça a contagem de 60 s a cada um. */
    val reenviosFeitos: Int = 0,
)
