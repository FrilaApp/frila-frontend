package br.com.frila.feature.vagas.feed

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.VagaAbertaDto
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private val FUSO_BRASILIA: ZoneId = ZoneId.of("America/Sao_Paulo")
private val INICIO_MANHA: LocalTime = LocalTime.of(6, 0)
private val INICIO_TARDE: LocalTime = LocalTime.of(12, 0)
private val INICIO_NOITE: LocalTime = LocalTime.of(18, 0)

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

    fun aoAlterarTextoBusca(texto: String) {
        _estado.update { it.copy(textoBusca = texto) }
        aplicarFiltros()
    }

    fun aoLimparBusca() {
        _estado.update { it.copy(textoBusca = "") }
        aplicarFiltros()
    }

    fun aoSelecionarFiltroDistancia(filtro: FiltroDistancia) {
        _estado.update { it.copy(filtroDistancia = filtro) }
        aplicarFiltros()
    }

    /** `null` seleciona "todas as funções". */
    fun aoSelecionarFiltroFuncao(funcao: String?) {
        _estado.update { it.copy(filtroFuncao = funcao) }
        aplicarFiltros()
    }

    fun aoAbrirFiltrosAvancados() {
        _estado.update { it.copy(exibindoFiltrosAvancados = true) }
    }

    fun aoFecharFiltrosAvancados() {
        _estado.update { it.copy(exibindoFiltrosAvancados = false) }
    }

    fun aoSelecionarFiltroRemuneracao(filtro: FiltroRemuneracao) {
        _estado.update { it.copy(filtroRemuneracao = filtro) }
        aplicarFiltros()
    }

    fun aoSelecionarFiltroPeriodo(filtro: FiltroPeriodo) {
        _estado.update { it.copy(filtroPeriodo = filtro) }
        aplicarFiltros()
    }

    fun aoLimparFiltrosAvancados() {
        _estado.update {
            it.copy(
                filtroRemuneracao = FiltroRemuneracao.QUALQUER,
                filtroPeriodo = FiltroPeriodo.QUALQUER,
            )
        }
        aplicarFiltros()
    }

    private fun aplicarFiltros() {
        val filtroAtual = _estado.value
        val termoBusca = filtroAtual.textoBusca.trim()

        val filtradas = vagasCarregadas
            .filter { vaga ->
                termoBusca.isBlank() ||
                    vaga.funcao.nome.contains(termoBusca, ignoreCase = true) ||
                    vaga.estabelecimento.nome.contains(termoBusca, ignoreCase = true)
            }
            .filter { vaga ->
                val limite = filtroAtual.filtroDistancia.limiteKm
                limite == null || vaga.distanciaKm <= limite
            }
            .filter { vaga ->
                filtroAtual.filtroFuncao == null || vaga.funcao.nome == filtroAtual.filtroFuncao
            }
            .filter { vaga ->
                val minimo = filtroAtual.filtroRemuneracao.minimoCentavos
                minimo == null || vaga.valorCentavos >= minimo
            }
            .filter { vaga -> filtroAtual.filtroPeriodo.aceita(vaga.inicioEm) }
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

private fun FiltroPeriodo.aceita(inicioEm: String): Boolean {
    if (this == FiltroPeriodo.QUALQUER) return true

    val horario = Instant.parse(inicioEm).atZone(FUSO_BRASILIA).toLocalTime()
    return when (this) {
        FiltroPeriodo.QUALQUER -> true
        FiltroPeriodo.MANHA -> horario >= INICIO_MANHA && horario < INICIO_TARDE
        FiltroPeriodo.TARDE -> horario >= INICIO_TARDE && horario < INICIO_NOITE
        FiltroPeriodo.NOITE -> horario >= INICIO_NOITE || horario < INICIO_MANHA
    }
}
