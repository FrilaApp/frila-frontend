package br.com.frila.feature.equipe

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.MembroDaEquipeDto
import br.com.frila.core.rede.PerfilPublicoDto
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** O que a lista mostra. `Erro` carrega a mensagem já mapeada: a tela não decide texto. */
sealed interface EstadoEquipe {
    data object Carregando : EstadoEquipe
    data object Vazio : EstadoEquipe
    data class Conteudo(val membros: List<PerfilPublicoDto>) : EstadoEquipe
    data object SemRede : EstadoEquipe
    data class Erro(val mensagem: String) : EstadoEquipe
}

data class EstadoTelaEquipe(
    val estado: EstadoEquipe = EstadoEquipe.Carregando,
    /** O `id` do profissional cuja remoção está em voo. */
    val removendo: String? = null,
    val saindo: Boolean = false,
    val saiu: Boolean = false,
    val aviso: String? = null,
    val mensagemErro: String? = null,
) {
    val ocupado: Boolean get() = removendo != null || saindo
}

/**
 * Equipe de confiança de um estabelecimento (RF18, RN16, UC11; paridade com
 * `EquipeDeConfiancaViewModel.swift`): lista, remove com confirmação na tela e, para o profissional,
 * sai da equipe (0.2.72, LGPD art. 18). O servidor decide quem pode o quê: aqui cada recusa
 * (`403 sem_permissao`, conta suspensa, sem rede) vira uma mensagem própria, e nenhuma falha deixa
 * a tela em "carregando" ou "removendo".
 *
 * [listar], [removerMembro] e [sair] são as chamadas de `ServicoConfianca`. `escopo`: mesma razão do
 * `PerfilViewModel` (teste injeta um escopo próprio).
 */
class EquipeDeConfiancaViewModel(
    private val estabelecimentoId: String,
    private val listar: suspend (estabelecimentoId: String) -> List<PerfilPublicoDto>,
    private val removerMembro: suspend (estabelecimentoId: String, profissionalId: String) -> MembroDaEquipeDto,
    private val sair: suspend (estabelecimentoId: String) -> Unit,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoTelaEquipe())
    val estado: StateFlow<EstadoTelaEquipe> = _estado.asStateFlow()

    private var carregando = false

    /** Também serve de "tentar novamente". Duas cargas ao mesmo tempo viram uma. */
    fun carregar(): Job {
        if (carregando) return escopoDeTrabalho.launch { }
        carregando = true
        _estado.update { it.copy(estado = EstadoEquipe.Carregando, mensagemErro = null) }
        return escopoDeTrabalho.launch {
            try {
                val membros = listar(estabelecimentoId)
                _estado.update {
                    it.copy(estado = if (membros.isEmpty()) EstadoEquipe.Vazio else EstadoEquipe.Conteudo(membros))
                }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(estado = estadoDeErroAoCarregar(erro)) }
            } catch (_: Exception) {
                // Corpo não-JSON de gateway ou campo ausente escapam do ErroDaApi; sem isto a tela
                // ficaria em "Carregando" para sempre. A mensagem nunca carrega o corpo cru (RN15).
                _estado.update { it.copy(estado = EstadoEquipe.Erro(TextosEquipe.ERRO_CARREGAR)) }
            } finally {
                carregando = false
            }
        }
    }

    /** Sem efeito com outra remoção ou saída em voo, ou fora da lista: o segundo toque não dispara outro pedido. */
    fun remover(perfil: PerfilPublicoDto): Job {
        val atual = _estado.value
        if (atual.ocupado || atual.estado !is EstadoEquipe.Conteudo) return escopoDeTrabalho.launch { }
        _estado.update { it.copy(removendo = perfil.id, mensagemErro = null, aviso = null) }
        return escopoDeTrabalho.launch {
            try {
                removerMembro(estabelecimentoId, perfil.id)
                _estado.update { tela ->
                    val restantes = (tela.estado as? EstadoEquipe.Conteudo)?.membros.orEmpty().filter { it.id != perfil.id }
                    tela.copy(
                        removendo = null,
                        estado = if (restantes.isEmpty()) EstadoEquipe.Vazio else EstadoEquipe.Conteudo(restantes),
                        aviso = TextosEquipe.REMOVIDO,
                    )
                }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(removendo = null, mensagemErro = mensagemDeErro(erro)) }
            } catch (_: Exception) {
                _estado.update { it.copy(removendo = null, mensagemErro = TextosEquipe.ERRO) }
            }
        }
    }

    /** O profissional sai da equipe de [estabelecimentoId] por vontade própria; sem penalidade nem aviso à casa. */
    fun sairDaEquipe(estabelecimentoId: String): Job {
        val atual = _estado.value
        if (atual.ocupado || atual.saiu) return escopoDeTrabalho.launch { }
        _estado.update { it.copy(saindo = true, mensagemErro = null, aviso = null) }
        return escopoDeTrabalho.launch {
            try {
                sair(estabelecimentoId)
                _estado.update { it.copy(saindo = false, saiu = true, aviso = TextosEquipe.SAIU) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(saindo = false, mensagemErro = mensagemDeErroAoSair(erro)) }
            } catch (_: Exception) {
                _estado.update { it.copy(saindo = false, mensagemErro = TextosEquipe.ERRO) }
            }
        }
    }

    private fun estadoDeErroAoCarregar(erro: ErroDaApi): EstadoEquipe = when (erro.codigo) {
        CodigoErroAPI.SEM_REDE -> EstadoEquipe.SemRede
        CodigoErroAPI.SEM_PERMISSAO, CodigoErroAPI.CONTA_SUSPENSA, CodigoErroAPI.NAO_ENCONTRADO ->
            EstadoEquipe.Erro(mensagemDeErro(erro))
        else -> EstadoEquipe.Erro(TextosEquipe.ERRO_CARREGAR)
    }

    /** As recusas do contrato para listar e remover; `sem_turno_cumprido` e `conta_suspensa` vêm em `details`. */
    private fun mensagemDeErro(erro: ErroDaApi): String = when {
        erro.codigo == CodigoErroAPI.SEM_PERMISSAO && erro.detalhes == "sem_turno_cumprido" -> TextosEquipe.SEM_TURNO_CUMPRIDO
        erro.codigo == CodigoErroAPI.SEM_PERMISSAO && erro.detalhes == "conta_suspensa" -> TextosEquipe.CONTA_SUSPENSA
        erro.codigo == CodigoErroAPI.CONTA_SUSPENSA -> TextosEquipe.CONTA_SUSPENSA
        erro.codigo == CodigoErroAPI.SEM_PERMISSAO -> TextosEquipe.SO_ADMINISTRADOR
        erro.codigo == CodigoErroAPI.NAO_ENCONTRADO -> TextosEquipe.INDISPONIVEL
        erro.codigo == CodigoErroAPI.SEM_REDE -> TextosEquipe.SEM_REDE
        else -> TextosEquipe.ERRO
    }

    /** `sair_da_equipe`: `403` é "não é profissional"; `422 campo_invalido` em `estabelecimento_id` é "não está na equipe". */
    private fun mensagemDeErroAoSair(erro: ErroDaApi): String = when {
        erro.codigo == CodigoErroAPI.SEM_PERMISSAO && erro.detalhes == "conta_suspensa" -> TextosEquipe.CONTA_SUSPENSA
        erro.codigo == CodigoErroAPI.CONTA_SUSPENSA -> TextosEquipe.CONTA_SUSPENSA
        erro.codigo == CodigoErroAPI.SEM_PERMISSAO -> TextosEquipe.SO_PROFISSIONAL
        erro.codigo == CodigoErroAPI.CAMPO_INVALIDO && erro.detalhes == "estabelecimento_id" -> TextosEquipe.NAO_ESTA_NA_EQUIPE
        erro.codigo == CodigoErroAPI.SEM_REDE -> TextosEquipe.SEM_REDE
        else -> TextosEquipe.ERRO
    }
}
