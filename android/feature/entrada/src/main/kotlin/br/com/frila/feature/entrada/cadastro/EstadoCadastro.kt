package br.com.frila.feature.entrada.cadastro

import br.com.frila.core.dominio.modelo.DataCivil
import br.com.frila.core.dominio.regra.ValidadorCpf
import br.com.frila.core.dominio.regra.ValidadorMaioridade
import br.com.frila.core.dominio.regra.ValidadorTelefone

/** Mensagem fixa de recusa por idade (RN20) — nunca varia por locale ou texto solto na tela. */
const val MENSAGEM_MENOR_DE_IDADE = "O Frila é exclusivo para maiores de 18 anos."
const val MENSAGEM_CPF_INVALIDO = "Informe um CPF válido."
const val MENSAGEM_TELEFONE_INVALIDO = "Informe um telefone válido com DDD."

/** Estado da tela de cadastro do profissional. */
data class EstadoCadastro(
    val nome: String = "",
    val cpf: String = "",
    val telefone: String = "",
    val nascimento: DataCivil? = null,
    val aceitouTermos: Boolean = false,
    val erro: String? = null,
    val concluido: Boolean = false,
) {
    /** `false` só quando há data de nascimento preenchida e ela indica menor de idade (RN20). */
    val nascimentoValido: Boolean
        get() = nascimento?.let { ValidadorMaioridade.ehMaiorDeIdade(it) } ?: true

    /** `false` quando CPF com 11 dígitos possui dígitos verificadores inválidos. */
    val cpfValido: Boolean
        get() = cpf.length < 11 || ValidadorCpf.ehValido(cpf)

    /** `false` quando telefone com 10 ou 11 dígitos é inválido. */
    val telefoneValido: Boolean
        get() = telefone.length < 10 || ValidadorTelefone.ehValido(telefone)
}
