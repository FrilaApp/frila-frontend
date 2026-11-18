package br.com.frila.feature.equipe

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
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

enum class SituacaoNaEquipe { DESCONHECIDA, FORA_DA_EQUIPE, NA_EQUIPE }

data class EstadoIncluirNaEquipe(
    val situacao: SituacaoNaEquipe = SituacaoNaEquipe.DESCONHECIDA,
    val incluindo: Boolean = false,
    val mensagemErro: String? = null,
)

/**
 * "Incluir na equipe" onde a casa vê um profissional que cumpriu turno nela (RF18, UC11; paridade com
 * `IncluirNaEquipeViewModel` do iOS). Lê a equipe só para saber se o profissional já está nela; a inclusão é
 * decidida pelo servidor: cada recusa (`403` sem turno cumprido, conta suspensa ou não administrador, `404`, sem
 * rede) vira uma mensagem própria. Um envio por vez, e nenhuma falha deixa o botão preso em "incluindo".
 *
 * [listar] e [incluirMembro] são as chamadas de `ServicoConfianca`. `escopo`: mesma razão do
 * `EquipeDeConfiancaViewModel` (teste injeta um escopo próprio).
 */
class IncluirNaEquipeViewModel(
    private val estabelecimentoId: String,
    private val profissionalId: String,
    private val listar: suspend (estabelecimentoId: String) -> List<PerfilPublicoDto>,
    private val incluirMembro: suspend (estabelecimentoId: String, profissionalId: String) -> MembroDaEquipeDto,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoIncluirNaEquipe())
    val estado: StateFlow<EstadoIncluirNaEquipe> = _estado.asStateFlow()

    /** Falhou a leitura: o botão aparece mesmo assim, e o servidor responde na inclusão. */
    fun carregar(): Job {
        if (_estado.value.incluindo) return escopoDeTrabalho.launch { }
        return escopoDeTrabalho.launch { lerSituacao() }
    }

    /** Sem efeito com outra inclusão em voo ou com o profissional já na equipe. */
    fun incluir(): Job {
        val atual = _estado.value
        if (atual.incluindo || atual.situacao == SituacaoNaEquipe.NA_EQUIPE) return escopoDeTrabalho.launch { }
        _estado.update { it.copy(incluindo = true, mensagemErro = null) }
        return escopoDeTrabalho.launch {
            try {
                incluirMembro(estabelecimentoId, profissionalId)
                _estado.update { it.copy(situacao = SituacaoNaEquipe.NA_EQUIPE, incluindo = false) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(incluindo = false, mensagemErro = mensagemDeErroDaEquipe(erro)) }
                lerSituacao()
            } catch (_: Exception) {
                // Corpo não-JSON de gateway ou campo ausente escapam do ErroDaApi (RN15: nunca o corpo cru).
                _estado.update { it.copy(incluindo = false, mensagemErro = TextosEquipe.ERRO) }
            }
        }
    }

    private suspend fun lerSituacao() {
        val situacao = try {
            if (listar(estabelecimentoId).any { it.id == profissionalId }) SituacaoNaEquipe.NA_EQUIPE else SituacaoNaEquipe.FORA_DA_EQUIPE
        } catch (erro: CancellationException) {
            throw erro
        } catch (_: Exception) {
            SituacaoNaEquipe.FORA_DA_EQUIPE
        }
        _estado.update { if (it.incluindo) it else it.copy(situacao = situacao) }
    }
}
