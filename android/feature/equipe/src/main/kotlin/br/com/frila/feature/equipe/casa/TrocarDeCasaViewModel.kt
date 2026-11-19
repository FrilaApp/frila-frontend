package br.com.frila.feature.equipe.casa

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.PapelMembro
import br.com.frila.core.rede.EstabelecimentoDaContaDto
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Uma casa de que a conta é membro, com o papel dela ali. */
data class CasaDoMembro(val id: String, val nome: String, val papel: PapelMembro?)

internal fun EstabelecimentoDaContaDto.paraCasaDoMembro() = CasaDoMembro(id = id, nome = nome, papel = PapelMembro.deChave(papel))

sealed interface ListaDeCasas {
    data object Carregando : ListaDeCasas
    data class Conteudo(val casas: List<CasaDoMembro>) : ListaDeCasas
    data object Erro : ListaDeCasas
}

/**
 * Trocar de casa, para quem cuida de mais de uma (`meus_estabelecimentos`, ordenada por nome pelo servidor). Não há RPC
 * de troca: escolher uma casa é só dizer ao app de qual delas falar; a tela de destino lê `meu_estabelecimento` da casa
 * escolhida, como sempre. [listar] é `ServicoMembros.listarMeusEstabelecimentos`.
 */
class TrocarDeCasaViewModel(
    private val listar: suspend () -> List<EstabelecimentoDaContaDto>,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow<ListaDeCasas>(ListaDeCasas.Carregando)
    val estado: StateFlow<ListaDeCasas> = _estado.asStateFlow()

    fun carregar(): Job {
        _estado.update { ListaDeCasas.Carregando }
        return escopoDeTrabalho.launch {
            try {
                _estado.update { ListaDeCasas.Conteudo(listar().map { it.paraCasaDoMembro() }) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (_: Exception) {
                _estado.update { ListaDeCasas.Erro }
            }
        }
    }
}
