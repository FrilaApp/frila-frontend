package br.com.frila.feature.perfil

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.TurnoDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Perfil do profissional e reputação agregada (RF03/RF16/RN07/RN08/RN15, UC09).
 *
 * `escopo`: ver nota em `br.com.frila.feature.entrada.entrada.EntradaViewModel` sobre por que
 * testes injetam um escopo próprio em vez de depender de `viewModelScope`/`Dispatchers.Main`.
 */
class PerfilViewModel(
    private val servicoPerfil: ServicoPerfil,
    private val servicoTurnos: ServicoTurnos,
    private val armazenamentoDeSessao: ArmazenamentoDeSessao,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoPerfil())
    val estado: StateFlow<EstadoPerfil> = _estado.asStateFlow()

    fun carregar(): Job {
        _estado.update { it.copy(status = StatusPerfil.CARREGANDO, mensagemErro = null) }
        return escopoDeTrabalho.launch {
            try {
                val perfil = servicoPerfil.obterMeuPerfilProfissional()
                val resumoFinanceiro = carregarResumoFinanceiro()
                _estado.update {
                    it.copy(status = StatusPerfil.SUCESSO, perfil = perfil, resumoFinanceiro = resumoFinanceiro)
                }
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(status = StatusPerfil.ERRO, mensagemErro = mensagemDeErro(erro)) }
            }
        }
    }

    /**
     * RF16: soma `valor_acordado_centavos` dos turnos `cumprida` (concluído) e `confirmada`
     * (pendente), descartando `cancelada` (RN12). Falha de rede aqui não pode quebrar a tela de
     * perfil inteira — degrada para [ResumoFinanceiroPerfil.VAZIO] e o perfil ainda carrega.
     */
    private suspend fun carregarResumoFinanceiro(): ResumoFinanceiroPerfil {
        val turnos = try {
            servicoTurnos.listarMeusTurnos()
        } catch (_: Throwable) {
            return ResumoFinanceiroPerfil.VAZIO
        }

        val cumpridos = turnos.filter { it.estado == "cumprida" }
        val confirmados = turnos.filter { it.estado == "confirmada" }

        return ResumoFinanceiroPerfil(
            totalConcluidoCentavos = cumpridos.somaCentavos(),
            totalPendenteCentavos = confirmados.somaCentavos(),
            turnosCumpridosQtd = cumpridos.size,
            turnosAgendadosQtd = confirmados.size,
        )
    }

    private fun List<TurnoDto>.somaCentavos(): Long = sumOf { it.valorAcordadoCentavos }

    /** RN15: encerra a sessão local. Não chama a rede — logout é só limpar o que ficou no aparelho. */
    fun aoDeslogar() {
        armazenamentoDeSessao.limparSessao()
    }

    /** RF02: Inicia a edição da biografia profissional copiando o texto atual para o rascunho. */
    fun iniciarEdicaoBio() {
        _estado.update { it.copy(estaEditandoBio = true, bioEmEdicao = it.bio) }
    }

    /**
     * RF02: Atualiza o rascunho da biografia. Rejeita qualquer entrada que exceda
     * o limite máximo de 280 caracteres.
     */
    fun atualizarBioEmEdicao(novoTexto: String) {
        if (novoTexto.length <= EstadoPerfil.LIMITE_MAXIMO_BIO) {
            _estado.update { it.copy(bioEmEdicao = novoTexto) }
        }
    }

    /** RF02: Salva a biografia atualizando o perfil local e fecha o modo de edição. */
    fun salvarBio() {
        _estado.update {
            it.copy(
                bio = it.bioEmEdicao.trim(),
                estaEditandoBio = false,
            )
        }
    }

    /** RF02: Cancela a edição da biografia, descartando alterações não salvas. */
    fun cancelarEdicaoBio() {
        _estado.update {
            it.copy(
                estaEditandoBio = false,
                bioEmEdicao = it.bio,
            )
        }
    }

    /** RF02: Alterna a seleção de uma especialidade (adiciona ou remove do conjunto selecionado). */
    fun alternarEspecialidade(especialidade: String) {
        _estado.update { atual ->
            val novas = if (atual.especialidadesSelecionadas.contains(especialidade)) {
                atual.especialidadesSelecionadas - especialidade
            } else {
                atual.especialidadesSelecionadas + especialidade
            }
            atual.copy(especialidadesSelecionadas = novas)
        }
    }

    /** Abre o diálogo de confirmação de exclusão de conta (RF25/UC16). */
    fun abrirDialogoExclusao() {
        _estado.update { it.copy(statusExclusao = StatusExclusao.DIALOGO_ABERTO, mensagemErroExclusao = null) }
    }

    fun cancelarExclusao() {
        _estado.update { it.copy(statusExclusao = StatusExclusao.OCIOSO) }
    }

    /**
     * Confirma a exclusão definitiva de conta (RF25/RN15/RNF08, UC16): anonimiza dados,
     * cancela turnos futuros sem falta e apaga a credencial. Só limpa a sessão local em caso
     * de sucesso — um erro (ex.: `409 administrador_unico`) mantém a sessão intacta, porque a
     * conta continua existindo e o profissional precisa resolver o bloqueio primeiro.
     */
    fun confirmarExclusao(): Job {
        _estado.update { it.copy(statusExclusao = StatusExclusao.EXCLUINDO, mensagemErroExclusao = null) }
        return escopoDeTrabalho.launch {
            try {
                val resultado = servicoPerfil.excluirConta()
                armazenamentoDeSessao.limparSessao()
                _estado.update {
                    it.copy(statusExclusao = StatusExclusao.SUCESSO, resultadoExclusao = resultado)
                }
            } catch (erro: ErroDaApi) {
                _estado.update {
                    it.copy(statusExclusao = StatusExclusao.ERRO, mensagemErroExclusao = mensagemDeErroExclusao(erro))
                }
            }
        }
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.NAO_AUTENTICADO -> "Sua sessão expirou. Entre de novo."
        CodigoErroAPI.NAO_ENCONTRADO -> "Não encontramos seu perfil."
        CodigoErroAPI.SEM_REDE -> "Sem conexão. Verifique sua internet e tente de novo."
        else -> "Não foi possível carregar seu perfil. Tente de novo em instantes."
    }

    private fun mensagemDeErroExclusao(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.ADMINISTRADOR_UNICO ->
            "Você é o único administrador do estabelecimento. Transfira a administração antes de excluir sua conta."
        CodigoErroAPI.NAO_AUTENTICADO -> "Sua sessão expirou. Entre de novo."
        CodigoErroAPI.SEM_REDE -> "Sem conexão. Verifique sua internet e tente de novo."
        else -> "Não foi possível excluir sua conta. Tente de novo em instantes."
    }
}
