package br.com.frila.feature.entrada.cadastro

import br.com.frila.core.rede.EventoDeTelemetria
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.DataCivil
import br.com.frila.core.dominio.regra.ValidadorCpf
import br.com.frila.core.dominio.regra.ValidadorMaioridade
import br.com.frila.core.dominio.regra.ValidadorTelefone
import br.com.frila.core.rede.CriarContaDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoConta
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Versão publicada dos Termos e da Política que o cadastro registra (`criar_conta.termos_versao`). */
const val TERMOS_VERSAO_ATUAL = "2026-11-16"

/** Versão anterior, ainda aceita pelo servidor (contrato 0.2.91). */
const val TERMOS_VERSAO_ANTERIOR = "2026-11-13"

private const val MENSAGEM_CADASTRO_INDISPONIVEL = "Não foi possível concluir o cadastro. Tente de novo em instantes."

/**
 * Tela de cadastro do profissional: Nome, CPF, Telefone, Data de Nascimento, aceite de termos.
 * Validação de maioridade (RN20), dígitos verificadores de CPF e formato de telefone com DDD.
 * Passando a validação local, cria a conta com `criar_conta` (RF01); o CPF não vai: nenhum
 * documento é pedido no cadastro (RN14).
 *
 * `escopo` é nulo em produção (usa `viewModelScope`); testes injetam um escopo dedicado.
 * [concluirCadastro] devolve o [Job] do envio (ou `null` quando a validação recusa antes da rede).
 * Sem [servicoConta] o cadastro não conclui: nunca marca `concluido` sem ter criado a conta.
 */
class CadastroViewModel(
    private val servicoConta: ServicoConta? = null,
    escopo: CoroutineScope? = null,
    private val termosVersao: String = TERMOS_VERSAO_ATUAL,
    private val hoje: () -> DataCivil = DataCivil::hoje,
    private val registrarEvento: (EventoDeTelemetria, String?, String?) -> Unit = { _, _, _ -> },
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

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
        val maiorDeIdade = ValidadorMaioridade.ehMaiorDeIdade(novaData, hoje())
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

    fun concluirCadastro(): Job? {
        val atual = _estado.value
        if (atual.enviando) return null

        val nascimento = atual.nascimento
        if (nascimento == null) {
            _estado.update { it.copy(erro = "Informe sua data de nascimento.") }
            return null
        }

        if (!ValidadorMaioridade.ehMaiorDeIdade(nascimento, hoje())) {
            // RN20: bloqueio inegociável
            _estado.update { it.copy(erro = MENSAGEM_MENOR_DE_IDADE, concluido = false) }
            return null
        }

        if (atual.nome.isBlank()) {
            _estado.update { it.copy(erro = "Informe seu nome.") }
            return null
        }

        if (atual.cpf.isBlank()) {
            _estado.update { it.copy(erro = "Informe seu CPF.") }
            return null
        }

        if (!ValidadorCpf.ehValido(atual.cpf)) {
            _estado.update { it.copy(erro = MENSAGEM_CPF_INVALIDO) }
            return null
        }

        if (atual.telefone.isBlank()) {
            _estado.update { it.copy(erro = "Informe seu telefone.") }
            return null
        }

        if (!ValidadorTelefone.ehValido(atual.telefone)) {
            _estado.update { it.copy(erro = MENSAGEM_TELEFONE_INVALIDO) }
            return null
        }

        if (!atual.aceitouTermos) {
            _estado.update { it.copy(erro = "Você precisa aceitar os termos para continuar.") }
            return null
        }

        val telefoneE164 = ValidadorTelefone.paraE164(atual.telefone)
        val servico = servicoConta
        if (telefoneE164 == null || servico == null) {
            _estado.update { it.copy(erro = if (telefoneE164 == null) MENSAGEM_TELEFONE_INVALIDO else MENSAGEM_CADASTRO_INDISPONIVEL) }
            return null
        }

        val dados = CriarContaDto(
            perfil = PERFIL_PROFISSIONAL,
            nome = atual.nome.trim(),
            telefone = telefoneE164,
            nascimento = nascimento.data.toString(),
            termosVersao = termosVersao,
        )
        _estado.update { it.copy(erro = null, enviando = true) }
        return escopoDeTrabalho.launch {
            try {
                servico.criarConta(dados)
                registrarEvento(EventoDeTelemetria.CADASTRO_CONCLUIDO, null, null)
                _estado.update { it.copy(enviando = false, concluido = true) }
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(enviando = false, erro = mensagemDeErro(erro)) }
            }
        }
    }

    /** `criar_conta` recusa com `422` (campo ou idade) e `409` (conta ou perfil já existentes). */
    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.MENOR_DE_IDADE -> MENSAGEM_MENOR_DE_IDADE
        CodigoErroAPI.CONTA_EXISTENTE, CodigoErroAPI.PERFIL_JA_EXISTE ->
            "Já existe uma conta com este e-mail. Entre com o código para continuar."
        CodigoErroAPI.CAMPO_INVALIDO, CodigoErroAPI.CAMPO_OBRIGATORIO -> when (erro.detalhes) {
            "nome" -> "Informe um nome válido."
            "telefone" -> MENSAGEM_TELEFONE_INVALIDO
            "nascimento" -> "Informe uma data de nascimento válida."
            else -> MENSAGEM_CADASTRO_INDISPONIVEL
        }
        CodigoErroAPI.NAO_AUTENTICADO -> "Sua sessão expirou. Entre de novo para continuar."
        CodigoErroAPI.SEM_REDE -> "Sem conexão. Confira a internet e tente de novo."
        else -> MENSAGEM_CADASTRO_INDISPONIVEL
    }

    private companion object {
        const val PERFIL_PROFISSIONAL = "profissional"
    }
}
