package br.com.frila.feature.vagas.feed

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.VagaAbertaDto
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Feed de vagas abertas (RF07). `escopo` é nulo em produção (usa `viewModelScope`); testes
 * injetam um escopo próprio e esperam o `Job` devolvido com `.join()` — ver a nota detalhada em
 * `br.com.frila.feature.entrada.entrada.EntradaViewModel` sobre por que isso é necessário com
 * o cliente Ktor de `:core:rede`.
 */
class FeedVagasViewModel(
    private val servicoVagas: ServicoVagas,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoFeed())
    val estado: StateFlow<EstadoFeed> = _estado.asStateFlow()

    private var vagasCarregadas: List<VagaAbertaDto> = emptyList()

    fun carregar(): Job {
        _estado.update { it.copy(status = StatusFeed.CARREGANDO, mensagemErro = null) }
        return escopoDeTrabalho.launch {
            try {
                vagasCarregadas = servicoVagas.listarVagasAbertas()
                aplicarFiltros()
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(status = StatusFeed.ERRO, mensagemErro = mensagemDeErro(erro)) }
            }
        }
    }

    /** Mesma operação de [carregar]; nome próprio só para deixar a intenção explícita na tela de erro. */
    fun tentarNovamente(): Job = carregar()

    /**
     * Vaga já carregada pelo feed, pelo id — usado pela navegação para abrir o detalhe sem
     * refazer a chamada de `/rpc/vagas_abertas` só para reler o mesmo objeto.
     */
    fun encontrarVagaPorId(id: String): VagaAbertaDto? = vagasCarregadas.firstOrNull { it.id == id }

    fun aoSelecionarFiltroDistancia(filtro: FiltroDistancia) {
        _estado.update { it.copy(filtroDistancia = filtro) }
        aplicarFiltros()
    }

    /** `null` seleciona "todas as funções". */
    fun aoSelecionarFiltroFuncao(funcao: String?) {
        _estado.update { it.copy(filtroFuncao = funcao) }
        aplicarFiltros()
    }

    private fun aplicarFiltros() {
        val filtroAtual = _estado.value

        val filtradas = vagasCarregadas
            .filter { vaga ->
                val limite = filtroAtual.filtroDistancia.limiteKm
                limite == null || vaga.distanciaKm <= limite
            }
            .filter { vaga ->
                filtroAtual.filtroFuncao == null || vaga.funcao.nome == filtroAtual.filtroFuncao
            }
            .sortedBy { it.distanciaKm }
            .map { it.paraItem() }

        val funcoesDisponiveis = vagasCarregadas.map { it.funcao.nome }.distinct().sorted()

        _estado.update {
            it.copy(
                status = if (filtradas.isEmpty()) StatusFeed.VAZIO else StatusFeed.SUCESSO,
                vagas = filtradas,
                funcoesDisponiveis = funcoesDisponiveis,
            )
        }
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo.name) {
        "SEM_REDE" -> "Sem conexão. Verifique sua internet e tente de novo."
        else -> "Não foi possível carregar as vagas. Tente de novo em instantes."
    }
}
