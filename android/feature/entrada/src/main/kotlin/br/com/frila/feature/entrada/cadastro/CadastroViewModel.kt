package br.com.frila.feature.entrada.cadastro

import androidx.lifecycle.ViewModel
import br.com.frila.core.dominio.modelo.DataCivil
import br.com.frila.core.dominio.regra.ValidadorMaioridade
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * Tela de cadastro do profissional: Nome, Telefone, Data de Nascimento, aceite de termos.
 * Validação de maioridade (RN20) é em tempo real, a cada mudança de data — nunca só no
 * botão de concluir, para a tela já mostrar o bloqueio visual antes do envio.
 */
class CadastroViewModel : ViewModel() {

    private val _estado = MutableStateFlow(EstadoCadastro())
    val estado: StateFlow<EstadoCadastro> = _estado.asStateFlow()

    fun aoMudarNome(novoNome: String) {
        _estado.update { it.copy(nome = novoNome, erro = null) }
    }

    fun aoMudarTelefone(novoTelefone: String) {
        _estado.update { it.copy(telefone = novoTelefone, erro = null) }
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
            // RN20: bloqueio inegociável — nunca deixa concluir=true para menor de idade,
            // mesmo que o estado anterior tenha ficado inconsistente por algum motivo.
            _estado.update { it.copy(erro = MENSAGEM_MENOR_DE_IDADE, concluido = false) }
            return
        }

        if (atual.nome.isBlank()) {
            _estado.update { it.copy(erro = "Informe seu nome.") }
            return
        }

        if (atual.telefone.isBlank()) {
            _estado.update { it.copy(erro = "Informe seu telefone.") }
            return
        }

        if (!atual.aceitouTermos) {
            _estado.update { it.copy(erro = "Você precisa aceitar os termos para continuar.") }
            return
        }

        _estado.update { it.copy(erro = null, concluido = true) }
    }
}
