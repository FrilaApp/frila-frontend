package br.com.frila.feature.entrada.cadastro

import br.com.frila.core.dominio.modelo.DataCivil
import br.com.frila.core.dominio.regra.ValidadorCpf
import br.com.frila.core.dominio.regra.ValidadorMaioridade
import br.com.frila.core.dominio.regra.ValidadorTelefone

/** Mensagem fixa de recusa por idade (RN20) — nunca varia por locale ou texto solto na tela. */
const val MENSAGEM_MENOR_DE_IDADE = "O Frila é exclusivo para maiores de 18 anos."
const val MENSAGEM_CPF_INVALIDO = "Informe um CPF válido."
const val MENSAGEM_TELEFONE_INVALIDO = "Informe um telefone válido com DDD."

/** Perfil da conta (`PerfilConta` do contrato), escolhido no cadastro e fixo depois (RN25). */
enum class PerfilDaConta(val chave: String) {
    PROFISSIONAL("profissional"),
    CONTRATANTE("contratante"),
}

/** Textos da escolha do perfil, iguais aos do iOS (`TelaCadastro.swift`, `escolhaDoPerfil`). */
object TextosEscolhaDoPerfil {
    const val PERGUNTA = "Como você quer usar o Frila?"
    const val PROFISSIONAL_TITULO = "Quero trabalhar em turnos"
    const val PROFISSIONAL_DESCRICAO = "Perfil de profissional: receba vagas perto de você e candidate-se sem formulário."
    const val CONTRATANTE_TITULO = "Quero publicar vagas"
    const val CONTRATANTE_DESCRICAO = "Perfil de contratante: publique vagas e acompanhe quem vai trabalhar."

    /** RN25: no iOS a primeira frase vem em negrito; aqui ela é o título do aviso. */
    const val AVISO_FIXO_TITULO = "O perfil fica fixo nesta conta."
    const val AVISO_FIXO = "Para usar o outro lado, crie outra conta, com outro e-mail. O telefone pode ser o mesmo."
}

/** Estado da tela de cadastro (profissional ou contratante). */
data class EstadoCadastro(
    /** Como no iOS, começa em profissional; a pessoa troca antes de concluir. */
    val perfil: PerfilDaConta = PerfilDaConta.PROFISSIONAL,
    val nome: String = "",
    val cpf: String = "",
    val telefone: String = "",
    val nascimento: DataCivil? = null,
    val aceitouTermos: Boolean = false,
    val erro: String? = null,
    val concluido: Boolean = false,
    /** `true` enquanto `criar_conta` está em voo: bloqueia um segundo envio. */
    val enviando: Boolean = false,
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
