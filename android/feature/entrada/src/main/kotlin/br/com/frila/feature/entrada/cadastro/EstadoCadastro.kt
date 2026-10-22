package br.com.frila.feature.entrada.cadastro

import br.com.frila.core.dominio.modelo.DataCivil
import br.com.frila.core.dominio.regra.ValidadorMaioridade

/** Mensagem fixa de recusa por idade (RN20) — nunca varia por locale ou texto solto na tela. */
const val MENSAGEM_MENOR_DE_IDADE = "O Frila é exclusivo para maiores de 18 anos."

/** Estado da tela de cadastro do profissional. */
data class EstadoCadastro(
    val nome: String = "",
    val telefone: String = "",
    val nascimento: DataCivil? = null,
    val aceitouTermos: Boolean = false,
    val erro: String? = null,
    val concluido: Boolean = false,
) {
    /** `false` só quando há data de nascimento preenchida e ela indica menor de idade (RN20). */
    val nascimentoValido: Boolean
        get() = nascimento?.let { ValidadorMaioridade.ehMaiorDeIdade(it) } ?: true
}
