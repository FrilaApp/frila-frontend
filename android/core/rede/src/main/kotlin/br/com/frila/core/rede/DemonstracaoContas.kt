package br.com.frila.core.rede

/**
 * Contas de revisão da Google Play (`docs/android/04-seguranca-e-sessao.md` §3): permitem
 * que o time de revisão da Play Store teste o app sem acesso a caixa de e-mail real.
 */
object DemonstracaoContas {
    const val EMAIL_PROFISSIONAL = "revisao-profissional@frila.app"
    const val EMAIL_CONTRATANTE = "revisao-contratante@frila.app"

    private val EMAILS_DE_DEMONSTRACAO = setOf(EMAIL_PROFISSIONAL, EMAIL_CONTRATANTE)

    /** O app habilita o domínio de teste só em debug; o padrão mantém apenas as contas da Play Store. */
    fun ehContaDeDemonstracao(email: String, permitirDominioDeTeste: Boolean = false): Boolean {
        val normalizado = email.trim().lowercase()
        return normalizado in EMAILS_DE_DEMONSTRACAO ||
            (permitirDominioDeTeste && normalizado.endsWith("@frila.test"))
    }
}
