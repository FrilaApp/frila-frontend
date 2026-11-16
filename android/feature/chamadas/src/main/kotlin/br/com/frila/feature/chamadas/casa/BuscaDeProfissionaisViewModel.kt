package br.com.frila.feature.chamadas.casa

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.BuscarProfissionaisDto
import br.com.frila.core.rede.CartaoProfissionalDto
import br.com.frila.core.rede.ChamadaDto
import br.com.frila.core.rede.ChamarProfissionalDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.MeuEstabelecimentoDto
import br.com.frila.core.rede.PaginaDeProfissionaisDto
import br.com.frila.core.rede.RegiaoAdministrativaDto
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.UUID
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout

/** O horário do filtro. `inicio_em` e `fim_em` vão sempre juntos; a busca só vale com o término depois do início. */
data class HorarioDaBusca(val inicio: Instant, val fim: Instant) {
    val valido: Boolean get() = fim.isAfter(inicio)
}

/** O que a tela de publicar usa para abrir a vaga normal já com o que foi buscado (CD-RN35). */
data class RascunhoDeVagaDaBusca(
    val estabelecimentoId: String,
    val funcaoId: String,
    val regiaoId: Int? = null,
    val horario: HorarioDaBusca? = null,
)

sealed interface EstadoDaBusca {
    data object Ocioso : EstadoDaBusca
    data object Carregando : EstadoDaBusca
    data object Resultados : EstadoDaBusca

    /** A busca terminou sem ninguém: oferece "Publicar para todos". */
    data object Vazio : EstadoDaBusca

    /** A chave `busca_profissionais` está desligada (ou o servidor recusou com `recurso_desligado`). */
    data object Indisponivel : EstadoDaBusca
    data class Erro(val mensagem: String) : EstadoDaBusca
}

/** O que a busca devolveu para um profissional escolhido ao chamar. */
sealed interface ResultadoDaChamadaDaBusca {
    data class Enviada(val chamada: ChamadaDto) : ResultadoDaChamadaDaBusca

    /** J7: o servidor pediu a confirmação da recorrência; reenvie com `confirmoRecorrencia = true`. */
    data object PedeConfirmacaoDeRecorrencia : ResultadoDaChamadaDaBusca
    /** [incerto]: a chamada pode ter sido criada (prazo, sem rede, resposta ilegível); reenviar repete a mesma chave. */
    data class Erro(val mensagem: String, val incerto: Boolean = false) : ResultadoDaChamadaDaBusca

    /** O pedido que leva o trabalho terminou incerto: este nem saiu, para não criar outra vaga. Tente de novo. */
    data object NaoEnviada : ResultadoDaChamadaDaBusca
}

data class EstadoBusca(
    // Filtros: o serviço é obrigatório; região e horário são opcionais.
    val funcaoId: String? = null,
    val regiaoId: Int? = null,
    val horario: HorarioDaBusca? = null,
    /** Catálogos dos filtros e a casa de quem chama (carregados por [BuscaDeProfissionaisViewModel.carregarCatalogos]). */
    val funcoes: List<FuncaoDto> = emptyList(),
    val regioes: List<RegiaoAdministrativaDto> = emptyList(),
    val casa: MeuEstabelecimentoDto? = null,
    val carregandoCatalogos: Boolean = false,
    val falhaDeCatalogos: Boolean = false,
    val estado: EstadoDaBusca = EstadoDaBusca.Ocioso,
    /** Na ordem do servidor. O app nunca reordena: reputação não ordena a busca (D2). */
    val resultados: List<CartaoProfissionalDto> = emptyList(),
    val carregandoMais: Boolean = false,
    val erroAoCarregarMais: String? = null,
    /** Há próxima página e o teto de 200 não foi atingido. */
    val temMais: Boolean = false,
    val selecionados: List<String> = emptyList(),
    /** Ligado quando alguém tenta entrar como 4º; a tela mostra o aviso e apaga com `dispensarAvisoDeLimite`. */
    val avisoDeLimiteDeSelecao: String? = null,
    val enviando: Boolean = false,
    val resultadosDaChamada: Map<String, ResultadoDaChamadaDaBusca> = emptyMap(),
    val mostrarJ7: Boolean = false,
    /** Os filtros da última busca que deu certo; o "publicar para todos" e o "carregar mais" partem deles. */
    internal val filtroDaBusca: RascunhoDeVagaDaBusca? = null,
) {
    val horarioValido: Boolean get() = horario?.valido ?: true
    val podeBuscar: Boolean
        get() = funcaoId != null && horarioValido && estado != EstadoDaBusca.Carregando && !carregandoMais && !enviando
    val podeChamar: Boolean get() = selecionados.isNotEmpty() && !enviando && estado == EstadoDaBusca.Resultados
    fun estaSelecionado(id: String): Boolean = id in selecionados

    /** Há quem possa ser reenviado: resultado incerto ou que nem saiu. O reenvio repete a chave de cada um. */
    val podeReenviar: Boolean
        get() = !enviando && resultadosDaChamada.values.any {
            it == ResultadoDaChamadaDaBusca.NaoEnviada || (it is ResultadoDaChamadaDaBusca.Erro && it.incerto)
        }

    /** "Publicar para todos" só existe com a busca vazia. */
    val rascunhoParaPublicarParaTodos: RascunhoDeVagaDaBusca?
        get() = if (estado == EstadoDaBusca.Vazio) filtroDaBusca else null
}

/**
 * Busca de profissionais pela casa (CD-B01..B11): filtros (serviço, região, horário), páginas de 20 por cursor
 * opaco até 200 resultados, selo `disponivel_no_horario` vindo do servidor, até 3 selecionados para chamar e
 * "publicar para todos" com a busca vazia. A tela é PROVISÓRIA (`TelaBuscaDeProfissionais`); os textos também.
 *
 * [recursoHabilitado] é a chave `busca_profissionais`; [buscarProfissionais] e [chamarProfissional] são as de mesmo nome
 * de `ServicoChamadaDireta`. A chamada de cada selecionado leva a sua chave de idempotência e o `regiao_id`
 * da busca (0.2.88). Todo `await` de rede tem prazo ([prazoMs]) e nenhuma falha deixa a busca em "Carregando".
 */
class BuscaDeProfissionaisViewModel(
    private val estabelecimentoId: String,
    private val recursoHabilitado: suspend () -> Boolean,
    private val buscarProfissionais: suspend (BuscarProfissionaisDto) -> PaginaDeProfissionaisDto,
    private val chamarProfissional: suspend (ChamarProfissionalDto) -> ChamadaDto,
    private val novaChave: () -> String = { UUID.randomUUID().toString() },
    private val prazoMs: Long = ChamadaDiretaViewModel.PRAZO_PADRAO_MS,
    /** `ServicoVagas.listarFuncoes`, `ServicoDeRegioes.regioesAtivas` e `ServicoMembros.meuEstabelecimento`. */
    private val listarFuncoes: suspend () -> List<FuncaoDto> = { emptyList() },
    private val listarRegioes: suspend () -> List<RegiaoAdministrativaDto> = { emptyList() },
    private val buscarCasa: (suspend (estabelecimentoId: String) -> MeuEstabelecimentoDto)? = null,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoBusca())
    val estado: StateFlow<EstadoBusca> = _estado.asStateFlow()

    private var proximoCursor: String? = null
    private var recursoConfirmado = false
    private val tentativas = mutableMapOf<String, ChamarProfissionalDto>()

    /** A vaga direta criada pela 1ª chamada desta busca; as seguintes vão pelo `vaga_id` dela. */
    private var vagaDoTrabalho: String? = null

    // --- Catálogos ---------------------------------------------------------------------------------

    /**
     * Confere a chave `busca_profissionais` e carrega funções, regiões (opcionais: sem elas o filtro some) e a casa.
     * Chave desligada: o estado vira [EstadoDaBusca.Indisponivel]. Serve também de "tentar novamente".
     */
    fun carregarCatalogos(): Job {
        val tela = _estado.value
        if (tela.carregandoCatalogos || (tela.funcoes.isNotEmpty() && tela.casa != null)) return escopoDeTrabalho.launch { }
        _estado.update { it.copy(carregandoCatalogos = true, falhaDeCatalogos = false) }
        return escopoDeTrabalho.launch {
            try {
                val dados = withTimeout(prazoMs) {
                    if (!recursoHabilitado()) return@withTimeout null
                    val funcoes = listarFuncoes()
                    val regioes = try {
                        listarRegioes()
                    } catch (erro: CancellationException) {
                        throw erro
                    } catch (_: Exception) {
                        emptyList()
                    }
                    val casa = buscarCasa?.invoke(estabelecimentoId)
                    Triple(funcoes, regioes, casa)
                }
                if (dados == null) {
                    _estado.update { it.copy(carregandoCatalogos = false, estado = EstadoDaBusca.Indisponivel) }
                    return@launch
                }
                recursoConfirmado = true
                val (funcoes, regioes, casa) = dados
                _estado.update {
                    it.copy(
                        carregandoCatalogos = false, funcoes = funcoes, regioes = regioes, casa = casa,
                        funcaoId = it.funcaoId?.takeIf { id -> funcoes.any { f -> f.id == id } },
                    )
                }
            } catch (erro: CancellationException) {
                if (erro !is TimeoutCancellationException) throw erro
                _estado.update { it.copy(carregandoCatalogos = false, falhaDeCatalogos = true) }
            } catch (erro: ErroDaApi) {
                if (recursoDesligado(erro)) {
                    _estado.update { it.copy(carregandoCatalogos = false, estado = EstadoDaBusca.Indisponivel) }
                } else {
                    _estado.update { it.copy(carregandoCatalogos = false, falhaDeCatalogos = true) }
                }
            } catch (_: Exception) {
                _estado.update { it.copy(carregandoCatalogos = false, falhaDeCatalogos = true) }
            }
        }
    }

    // --- Filtros -----------------------------------------------------------------------------------

    fun definirFuncao(funcaoId: String?) = _estado.update { it.copy(funcaoId = funcaoId) }
    fun definirRegiao(regiaoId: Int?) = _estado.update { it.copy(regiaoId = regiaoId) }
    fun definirHorario(horario: HorarioDaBusca?) = _estado.update { it.copy(horario = horario) }

    // --- Busca -------------------------------------------------------------------------------------

    /** A primeira página com os filtros de agora. Zera a seleção e o resultado anterior. */
    fun buscar(): Job {
        val tela = _estado.value
        val funcaoId = tela.funcaoId
        if (funcaoId == null || !tela.podeBuscar) return escopoDeTrabalho.launch { }
        val filtro = RascunhoDeVagaDaBusca(estabelecimentoId, funcaoId, tela.regiaoId, tela.horario)
        _estado.update { it.copy(estado = EstadoDaBusca.Carregando, erroAoCarregarMais = null) }
        return escopoDeTrabalho.launch {
            try {
                val jaConfirmado = recursoConfirmado
                val pagina = withTimeout(prazoMs) {
                    if (!jaConfirmado && !recursoHabilitado()) return@withTimeout null
                    buscarProfissionais(pedidoDaBusca(filtro, cursor = null, limite = LIMITE_DA_PAGINA))
                }
                if (pagina == null) {
                    limparResultados(EstadoDaBusca.Indisponivel)
                    return@launch
                }
                recursoConfirmado = true
                val itens = semRepetidos(pagina.itens, jaTem = emptySet())
                proximoCursor = cursorSeguinte(pagina, total = itens.size)
                tentativas.clear()
                vagaDoTrabalho = null
                _estado.update {
                    it.copy(
                        estado = if (itens.isEmpty()) EstadoDaBusca.Vazio else EstadoDaBusca.Resultados,
                        resultados = itens,
                        temMais = proximoCursor != null,
                        selecionados = emptyList(),
                        avisoDeLimiteDeSelecao = null,
                        resultadosDaChamada = emptyMap(),
                        mostrarJ7 = false,
                        filtroDaBusca = filtro,
                    )
                }
            } catch (erro: CancellationException) {
                if (erro !is TimeoutCancellationException) throw erro
                limparResultados(EstadoDaBusca.Erro(TextosChamadaCasa.BUSCA_ERRO))
            } catch (erro: ErroDaApi) {
                limparResultados(estadoDoErro(erro))
            } catch (_: Exception) {
                limparResultados(EstadoDaBusca.Erro(TextosChamadaCasa.BUSCA_ERRO))
            }
        }
    }

    /** A página seguinte, com o mesmo filtro da busca. Para no fim ou em 200 resultados. */
    fun carregarMais(): Job {
        val tela = _estado.value
        val filtro = tela.filtroDaBusca
        val cursor = proximoCursor
        if (tela.estado != EstadoDaBusca.Resultados || tela.carregandoMais || tela.enviando || !tela.temMais ||
            filtro == null || cursor == null
        ) {
            return escopoDeTrabalho.launch { }
        }
        _estado.update { it.copy(carregandoMais = true, erroAoCarregarMais = null) }
        val faltam = MAXIMO_DE_RESULTADOS - tela.resultados.size
        val limite = minOf(LIMITE_DA_PAGINA, faltam)
        return escopoDeTrabalho.launch {
            try {
                val pagina = withTimeout(prazoMs) { buscarProfissionais(pedidoDaBusca(filtro, cursor, limite)) }
                val novos = semRepetidos(pagina.itens, jaTem = _estado.value.resultados.map { it.id }.toSet())
                val todos = _estado.value.resultados + novos.take(faltam)
                proximoCursor = cursorSeguinte(pagina, total = todos.size)
                _estado.update { it.copy(carregandoMais = false, resultados = todos, temMais = proximoCursor != null) }
            } catch (erro: CancellationException) {
                if (erro !is TimeoutCancellationException) throw erro
                _estado.update { it.copy(carregandoMais = false, erroAoCarregarMais = TextosChamadaCasa.BUSCA_ERRO_AO_CARREGAR_MAIS) }
            } catch (erro: ErroDaApi) {
                when {
                    // Cursor de outra busca ou de outro dia: refaz a primeira página (contrato 0.2.88).
                    erro.codigo == CodigoErroAPI.CURSOR_INVALIDO -> {
                        _estado.update {
                            it.copy(
                                carregandoMais = false, funcaoId = filtro.funcaoId, regiaoId = filtro.regiaoId,
                                horario = filtro.horario, estado = EstadoDaBusca.Ocioso,
                            )
                        }
                        buscar().join()
                    }
                    erro.codigo == CodigoErroAPI.LIMITE_EXCEDIDO || recursoDesligado(erro) -> {
                        _estado.update { it.copy(carregandoMais = false, estado = estadoDoErro(erro)) }
                    }
                    else -> _estado.update {
                        it.copy(carregandoMais = false, erroAoCarregarMais = TextosChamadaCasa.BUSCA_ERRO_AO_CARREGAR_MAIS)
                    }
                }
            } catch (_: Exception) {
                _estado.update { it.copy(carregandoMais = false, erroAoCarregarMais = TextosChamadaCasa.BUSCA_ERRO_AO_CARREGAR_MAIS) }
            }
        }
    }

    private fun pedidoDaBusca(filtro: RascunhoDeVagaDaBusca, cursor: String?, limite: Int) = BuscarProfissionaisDto(
        estabelecimentoId = filtro.estabelecimentoId,
        funcaoId = filtro.funcaoId,
        regiaoId = filtro.regiaoId,
        inicioEm = filtro.horario?.inicio?.truncatedTo(ChronoUnit.SECONDS)?.toString(),
        fimEm = filtro.horario?.fim?.truncatedTo(ChronoUnit.SECONDS)?.toString(),
        cursor = cursor,
        limite = limite,
    )

    private fun limparResultados(novo: EstadoDaBusca) {
        proximoCursor = null
        vagaDoTrabalho = null
        tentativas.clear()
        _estado.update {
            it.copy(
                estado = novo, resultados = emptyList(), temMais = false, selecionados = emptyList(),
                carregandoMais = false, resultadosDaChamada = emptyMap(), mostrarJ7 = false,
            )
        }
    }

    private fun cursorSeguinte(pagina: PaginaDeProfissionaisDto, total: Int): String? =
        if (total >= MAXIMO_DE_RESULTADOS) null else pagina.proximoCursor

    private fun semRepetidos(itens: List<CartaoProfissionalDto>, jaTem: Set<String>): List<CartaoProfissionalDto> {
        val vistos = jaTem.toMutableSet()
        return itens.filter { vistos.add(it.id) }
    }

    private fun estadoDoErro(erro: ErroDaApi): EstadoDaBusca = when {
        recursoDesligado(erro) -> EstadoDaBusca.Indisponivel
        erro.codigo == CodigoErroAPI.LIMITE_EXCEDIDO -> EstadoDaBusca.Erro(TextosChamadaCasa.BUSCA_LIMITE_DE_BUSCAS)
        else -> EstadoDaBusca.Erro(TextosChamadaCasa.BUSCA_ERRO)
    }

    // --- Seleção -----------------------------------------------------------------------------------

    /** Marca ou desmarca. O 4º não entra: devolve `false` e liga o aviso. */
    fun alternarSelecao(id: String): Boolean {
        val tela = _estado.value
        if (id in tela.selecionados) {
            _estado.update { it.copy(selecionados = it.selecionados - id, avisoDeLimiteDeSelecao = null) }
            return true
        }
        if (tela.resultados.none { it.id == id }) return false
        if (tela.selecionados.size >= MAXIMO_DE_SELECIONADOS) {
            _estado.update { it.copy(avisoDeLimiteDeSelecao = TextosChamadaCasa.BUSCA_LIMITE_DE_SELECAO) }
            return false
        }
        _estado.update { it.copy(selecionados = it.selecionados + id) }
        return true
    }

    fun dispensarAvisoDeLimite() = _estado.update { it.copy(avisoDeLimiteDeSelecao = null) }

    // --- Chamar ------------------------------------------------------------------------------------

    /**
     * Cria a chamada de cada selecionado pela `chamarProfissional`, uma de cada vez, todas para o MESMO trabalho
     * (contrato `chamar_profissional`): a 1ª que der certo leva os campos do trabalho e cria a vaga direta; as
     * seguintes levam só o `vaga_id` dela (nunca os dois), com `recado`, e a vaga guarda a região da busca. Se a
     * 1ª falhar (recusa, erro ou J7 pendente), a próxima que der certo vira a 1ª. Cada profissional leva a sua
     * chave; se o servidor pedir J7, o reenvio ([confirmoRecorrencia]) usa a mesma chave, e quem foi pelo
     * trabalho completo passa a ir pelo `vaga_id` se a vaga já existir (a recusa J7 não cria chamada). Quem já
     * tem chamada enviada não é chamado de novo.
     *
     * DINHEIRO: se o pedido que leva o trabalho (o 1º, ainda sem vaga) termina INCERTO (prazo, sem rede, resposta
     * ilegível, desconhecido), nenhum outro é promovido a 1º: o laço para, os restantes ficam
     * [ResultadoDaChamadaDaBusca.NaoEnviada] e o reenvio (`chamar` de novo) repete a MESMA chave desse pedido; o servidor
     * é idempotente pela chave e devolve a chamada já criada, com o `vaga_id` que os outros usam. Recusa definitiva do
     * servidor continua promovendo o próximo.
     */
    fun chamar(trabalho: TrabalhoDaChamada, recado: String? = null, confirmoRecorrencia: Boolean = false): Job {
        val tela = _estado.value
        val pendentes = tela.selecionados.filter { tela.resultadosDaChamada[it] == ResultadoDaChamadaDaBusca.PedeConfirmacaoDeRecorrencia }
        // A confirmação J7 só vale depois da recusa correspondente, e não enquanto houver pedido incerto que levou o trabalho:
        // a vaga pode já existir, e o J7 iria com o trabalho completo e criaria outra. Reenvie primeiro (podeReenviar).
        if (!tela.podeChamar || (confirmoRecorrencia && (pendentes.isEmpty() || tela.podeReenviar))) return escopoDeTrabalho.launch { }
        val alvos = tela.selecionados.filter { id ->
            when {
                tela.resultadosDaChamada[id] is ResultadoDaChamadaDaBusca.Enviada -> false
                confirmoRecorrencia -> id in pendentes
                else -> true
            }
            // Quem ficou incerto levando o trabalho (pedido guardado, sem vaga) vai primeiro no reenvio, com a mesma chave,
            // para a vaga existir antes de os outros irem pelo vaga_id (a ordem de quem não tem pedido guardado se mantém).
        }.sortedBy { id ->
            val incertoComTrabalho = (tela.resultadosDaChamada[id] as? ResultadoDaChamadaDaBusca.Erro)?.incerto == true &&
                tentativas[id]?.vagaId == null
            if (incertoComTrabalho) 0 else 1
        }
        val regiaoId = tela.filtroDaBusca?.regiaoId
        _estado.update { it.copy(enviando = true, mostrarJ7 = false) }
        return escopoDeTrabalho.launch {
            for ((posicao, id) in alvos.withIndex()) {
                val vagaId = vagaDoTrabalho
                val guardado = tentativas[id]
                val original = when {
                    guardado == null -> pedidoDe(id, trabalho, recado, regiaoId, vagaId)
                    // Quem tem pedido guardado COM o trabalho (J7, ou J7 que virou NaoEnviada) e NÃO ficou incerto, agora que a
                    // vaga existe: mesma chave, só o vaga_id, com ou sem a confirmação. Quem já tem vaga sempre vai pelo
                    // vaga_id: nunca um 2º trabalho completo. O incerto que levou o trabalho repete o pedido como está (o
                    // servidor devolve a chamada já criada pela chave).
                    guardado.vagaId == null && vagaId != null &&
                        (tela.resultadosDaChamada[id] as? ResultadoDaChamadaDaBusca.Erro)?.incerto != true ->
                        pedidoDe(id, trabalho, recado, regiaoId, vagaId, chave = guardado.chave)
                    else -> guardado
                }
                val pedido = if (confirmoRecorrencia) original.copy(confirmoRecorrencia = true) else original
                tentativas[id] = pedido
                var incerto = false
                val resultado = try {
                    val chamada = withTimeout(prazoMs) { chamarProfissional(pedido) }
                    tentativas.remove(id)
                    if (vagaDoTrabalho == null) vagaDoTrabalho = chamada.vagaId
                    ResultadoDaChamadaDaBusca.Enviada(chamada)
                } catch (erro: CancellationException) {
                    if (erro !is TimeoutCancellationException) throw erro
                    incerto = true
                    ResultadoDaChamadaDaBusca.Erro(TextosChamadaCasa.ERRO, incerto = true)
                } catch (erro: ErroDaApi) {
                    when {
                        erro.codigo == CodigoErroAPI.RECORRENCIA_NAO_CONFIRMADA -> ResultadoDaChamadaDaBusca.PedeConfirmacaoDeRecorrencia
                        else -> {
                            incerto = resultadoIncerto(erro)
                            if (!incerto) tentativas.remove(id)
                            ResultadoDaChamadaDaBusca.Erro(mensagemDaChamada(erro), incerto = incerto)
                        }
                    }
                } catch (_: Exception) {
                    incerto = true
                    ResultadoDaChamadaDaBusca.Erro(TextosChamadaCasa.ERRO, incerto = true)
                }
                _estado.update { it.copy(resultadosDaChamada = it.resultadosDaChamada + (id to resultado)) }
                // O pedido que leva o trabalho (ainda sem vaga) ficou incerto: a vaga pode ter sido criada e a resposta se
                // perdido. Promover o próximo criaria outra vaga. Para aqui; o reenvio repete a chave deste, o servidor
                // devolve a chamada já criada (com o vaga_id) e só então os outros vão pelo vaga_id.
                // Recusa definitiva do servidor continua promovendo o próximo.
                if (incerto && pedido.vagaId == null) {
                    val naoEnviados = alvos.drop(posicao + 1).associateWith { ResultadoDaChamadaDaBusca.NaoEnviada }
                    _estado.update { it.copy(resultadosDaChamada = it.resultadosDaChamada + naoEnviados) }
                    break
                }
            }
            _estado.update {
                it.copy(
                    enviando = false,
                    mostrarJ7 = it.resultadosDaChamada.values.any { r -> r == ResultadoDaChamadaDaBusca.PedeConfirmacaoDeRecorrencia },
                )
            }
        }
    }

    /** Sem [vagaId]: o trabalho completo (cria a vaga direta). Com ele: só o `vaga_id` mais o recado, sem os campos da RN02. */
    private fun pedidoDe(
        profissionalId: String,
        trabalho: TrabalhoDaChamada,
        recado: String?,
        regiaoId: Int?,
        vagaId: String?,
        chave: String = novaChave(),
    ): ChamarProfissionalDto {
        val completo = trabalho.paraPedido(
            profissionalId = profissionalId,
            estabelecimentoId = estabelecimentoId,
            chave = chave,
            recado = recado?.trim(),
            regiaoId = regiaoId,
        )
        return if (vagaId == null) {
            completo
        } else {
            ChamarProfissionalDto(
                chave = chave,
                profissionalId = profissionalId,
                estabelecimentoId = estabelecimentoId,
                vagaId = vagaId,
                recado = completo.recado,
            )
        }
    }

    companion object {
        /** Até 3 profissionais por chamada (CD-B09). */
        const val MAXIMO_DE_SELECIONADOS = 3
        const val LIMITE_DA_PAGINA = 20
        const val MAXIMO_DE_RESULTADOS = 200
    }
}
