package br.com.frila.feature.entrada.cadastro

import androidx.lifecycle.ViewModel
import br.com.frila.core.dominio.modelo.DataCivil
import br.com.frila.core.dominio.regra.ValidadorCpf
import br.com.frila.core.dominio.regra.ValidadorMaioridade
import br.com.frila.core.dominio.regra.ValidadorTelefone
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * Tela de cadastro do profissional: Nome, CPF, Telefone, Data de Nascimento, aceite de termos.
 * Validação de maioridade (RN20), dígitos verificadores de CPF e formato de telefone com DDD.
 */
class CadastroViewModel : ViewModel() {

    private val _estado = MutableStateFlow(EstadoCadastro())
    val estado: StateFlow<EstadoCadastro> = _estado.asStateFlow()

    fun aoMudarNome(novoNome: String) {
        _estado.update { it.copy(nome = novoNome, erro = null) }
    }

    fun aoMudarCpf(novoCpf: String) {
        val digitos = novoCpf.filter { it.isDigit() }.take(11)
        val valido = digitos.length < 11 || ValidadorCpf.ehValido(digitos)
        _estado.update {
            it.copy(
                cpf = digitos,
                erro = if (valido) null else MENSAGEM_CPF_INVALIDO,
            )
        }
    }

    fun aoMudarTelefone(novoTelefone: String) {
        val digitos = novoTelefone.filter { it.isDigit() }.take(11)
        val valido = digitos.length < 10 || ValidadorTelefone.ehValido(digitos)
        _estado.update {
            it.copy(
                telefone = digitos,
                erro = if (valido) null else MENSAGEM_TELEFONE_INVALIDO,
            )
        }
    }

    fun aoMudarNascimento(novaData: DataCivil) {
        val maiorDeIdade = ValidadorMaioridade.ehMaiorDeIdade(novaData)
        _estado.update {
            it.copy(
                nascimento = novaData,
                erro = if (maiorDeIdade) null else MENSAGEM_MENOR_DE_IDADE,
            )
        }
    }

    fun aoMudarAceiteDeTermos(aceitou: Boolean) {
        _estado.update { it.copy(aceitouTermos = aceitou, erro = null) }
    }

    fun concluirCadastro() {
        val atual = _estado.value

        val nascimento = atual.nascimento
        if (nascimento == null) {
            _estado.update { it.copy(erro = "Informe sua data de nascimento.") }
            return
        }

        if (!ValidadorMaioridade.ehMaiorDeIdade(nascimento)) {
            // RN20: bloqueio inegociável
            _estado.update { it.copy(erro = MENSAGEM_MENOR_DE_IDADE, concluido = false) }
            return
        }

        if (atual.nome.isBlank()) {
            _estado.update { it.copy(erro = "Informe seu nome.") }
            return
        }

        if (atual.cpf.isBlank()) {
            _estado.update { it.copy(erro = "Informe seu CPF.") }
            return
        }

        if (!ValidadorCpf.ehValido(atual.cpf)) {
            _estado.update { it.copy(erro = MENSAGEM_CPF_INVALIDO) }
            return
        }

        if (atual.telefone.isBlank()) {
            _estado.update { it.copy(erro = "Informe seu telefone.") }
            return
        }

        if (!ValidadorTelefone.ehValido(atual.telefone)) {
            _estado.update { it.copy(erro = MENSAGEM_TELEFONE_INVALIDO) }
            return
        }

        if (!atual.aceitouTermos) {
            _estado.update { it.copy(erro = "Você precisa aceitar os termos para continuar.") }
            return
        }

        _estado.update { it.copy(erro = null, concluido = true) }
    }
}
