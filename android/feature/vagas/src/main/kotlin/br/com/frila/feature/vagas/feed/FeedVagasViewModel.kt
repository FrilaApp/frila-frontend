package br.com.frila.feature.vagas.feed

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.VagaAbertaDto
import java.time.Duration
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
 * Feed de vagas abertas (RF05/RF07/RN01). `escopo` é nulo em produção (usa `viewModelScope`); testes
 * injetam um escopo próprio e esperam o `Job` devolvido com `.join()` — ver a nota detalhada em
 * `br.com.frila.feature.entrada.entrada.EntradaViewModel` sobre por que isso é necessário com
 * o cliente Ktor de `:core:rede`.
 */
class FeedVagasViewModel(
    private val servicoVagas: ServicoVagas,
    private val provedorDeLocalizacao: ProvedorDeLocalizacao,
    private val armazenamentoPreferencias: ArmazenamentoPreferenciasFiltro = ArmazenamentoPreferenciasFiltroEmMemoria(),
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoFeed())
    val estado: StateFlow<EstadoFeed> = _estado.asStateFlow()

    private var vagasCarregadas: List<VagaAbertaDto> = emptyList()

    init {
        armazenamentoPreferencias.obterFaixaRemuneracaoHora()?.let { salva ->
            _estado.update {
                it.copy(
                    faixaRemuneracaoHora = FaixaRemuneracaoHora(
                        minima = salva.minima,
                        maxima = salva.maxima,
                        ativa = salva.ativa,
                    ),
                )
            }
        }
    }

    fun carregar(): Job {
        _estado.update { it.copy(status = StatusFeed.CARREGANDO, mensagemErro = null) }
        return escopoDeTrabalho.launch {
            try {
                val coordenada = provedorDeLocalizacao.obterCoordenadaAtual()
                // distanciaMaxKm fica de fora de propósito (achado bloqueante do Shisui): restringir no
                // servidor impede ampliar o raio sem forçar um recarregamento — vagasCarregadas precisa
                // conter todo o raio possível para que aplicarFiltros() seja reativo em qualquer chip.
                vagasCarregadas = servicoVagas.listarVagasAbertas(coordenada = coordenada)
                aplicarFiltros()
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(status = StatusFeed.ERRO, mensagemErro = mensagemDeErro(erro)) }
            }
        }
    }

    /** Mesma operação de [carregar]; nome próprio só para deixar a intenção explícita na tela de erro. */
    fun tentarNovamente(): Job = carregar()

    /**
     * Recarregamento reativo via pull-to-refresh (RNF10). Preserva a lista e filtros ativos
     * enquanto atualiza os dados em segundo plano com indicador de progresso no topo.
     */
    fun atualizar(): Job {
        _estado.update { it.copy(atualizando = true, mensagemErro = null) }
        return escopoDeTrabalho.launch {
            try {
                val coordenada = provedorDeLocalizacao.obterCoordenadaAtual()
                vagasCarregadas = servicoVagas.listarVagasAbertas(coordenada = coordenada)
                aplicarFiltros()
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(mensagemErro = mensagemDeErro(erro)) }
            } catch (t: Throwable) {
                _estado.update { it.copy(mensagemErro = "Não foi possível carregar as vagas. Tente de novo em instantes.") }
            } finally {
                _estado.update { it.copy(atualizando = false) }
            }
        }
    }

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

    /**
     * RF05/RN01: Atualiza a faixa de remuneração líquida por hora através do RangeSlider
     * e persiste a preferência localmente.
     */
    fun aoAlterarFaixaRemuneracaoHora(faixa: ClosedFloatingPointRange<Float>, ativa: Boolean = true) {
        _estado.update {
            it.copy(
                faixaRemuneracaoHora = FaixaRemuneracaoHora(
                    minima = faixa.start,
                    maxima = faixa.endInclusive,
                    ativa = ativa,
                ),
            )
        }
        armazenamentoPreferencias.salvarFaixaRemuneracaoHora(
            minimo = faixa.start,
            maximo = faixa.endInclusive,
            ativa = ativa,
        )
        aplicarFiltros()
    }

    /** Desativa o filtro de faixa por hora sem apagar os limites configurados. */
    fun aoDesativarFaixaRemuneracaoHora() {
        _estado.update {
            it.copy(
                faixaRemuneracaoHora = it.faixaRemuneracaoHora.copy(ativa = false),
            )
        }
        armazenamentoPreferencias.salvarFaixaRemuneracaoHora(
            minimo = _estado.value.faixaRemuneracaoHora.minima,
            maximo = _estado.value.faixaRemuneracaoHora.maxima,
            ativa = false,
        )
        aplicarFiltros()
    }

    fun aoSelecionarFiltroPeriodo(filtro: FiltroPeriodo) {
        _estado.update { it.copy(filtroPeriodo = filtro) }
        aplicarFiltros()
    }

    fun aoLimparFiltrosAvancados() {
        armazenamentoPreferencias.limparFaixaRemuneracaoHora()
        _estado.update {
            it.copy(
                filtroRemuneracao = FiltroRemuneracao.QUALQUER,
                filtroPeriodo = FiltroPeriodo.QUALQUER,
                faixaRemuneracaoHora = FaixaRemuneracaoHora.PADRAO,
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
            .filter { vaga ->
                val faixaHora = filtroAtual.faixaRemuneracaoHora
                if (!faixaHora.ativa) {
                    true
                } else {
                    val valorHora = vaga.calcularValorHoraReais()
                    valorHora >= faixaHora.minima && valorHora <= faixaHora.maxima
                }
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

/**
 * Calcula o valor líquido por hora de uma vaga em reais (RF05/RN01).
 * O valor anunciado é integral sem comissões da plataforma (RN01).
 */
fun VagaAbertaDto.calcularValorHoraReais(): Double {
    val inicio = runCatching { Instant.parse(inicioEm) }.getOrNull()
    val fim = runCatching { Instant.parse(fimEm) }.getOrNull()
    val duracaoHoras = if (inicio != null && fim != null) {
        val minutos = Duration.between(inicio, fim).toMinutes()
        if (minutos > 0) minutos / 60.0 else 1.0
    } else {
        1.0
    }
    val totalReais = valorCentavos / 100.0
    return totalReais / duracaoHoras
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
