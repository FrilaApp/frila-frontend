package br.com.frila.feature.chamadas.casa

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ChamadaDto
import br.com.frila.core.rede.ChamarProfissionalDto
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.MeuEstabelecimentoDto
import java.time.Duration
import java.time.Instant
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

/**
 * A folha "Chamar profissional" (UC de contratação direta, J7, RN02/RN29; paridade com
 * `ChamadaDiretaViewModel.swift`). Os campos têm a ordem e os limites do iOS: função, local da casa, início e
 * término (2 a 16 h; início a 2 h ou mais), responsável, valor total e a confirmação dele, inclusos e recado.
 */
data class EstadoChamadaDireta(
    val funcoes: List<FuncaoDto> = emptyList(),
    val funcaoId: String? = null,
    /** Endereço da casa; a folha só mostra, não edita. */
    val local: String = "",
    val inicio: Instant,
    val fim: Instant,
    /** O valor como a pessoa digita, em reais ("180" ou "180,50"). */
    val valorTexto: String = "",
    val totalConfirmado: Boolean = false,
    val recado: String = "",
    val responsavel: String = "",
    val refeicao: Boolean = false,
    val transporte: Boolean = false,
    val materialProprio: Boolean = false,
    val carregando: Boolean = false,
    val enviando: Boolean = false,
    /** Ligado só depois de a chave `chamada_direta` e a casa carregarem. Sem ele a folha não mostra os campos. */
    val recursoHabilitado: Boolean = false,
    val resultado: ChamadaDto? = null,
    val erro: String? = null,
    /** O aviso J7 da 3ª chamada em 7 dias (casa pessoa física); a tela mostra e chama [ChamadaDiretaViewModel.enviar]. */
    val mostrarJ7: Boolean = false,
    /** Já existe um pedido montado (com a chave de idempotência): os campos ficam travados até a recusa definitiva. */
    val travado: Boolean = false,
    /** O relógio do aparelho na última mudança; só as regras de horário dependem dele. */
    val agora: Instant,
    internal val pontoDaCasa: CoordenadaDto? = null,
    internal val regiaoDaCasa: String = "",
) {
    val valorCentavos: Long get() = ValorEmReais.centavos(valorTexto) ?: 0L
    val duracao: Duration get() = Duration.between(inicio, fim)
    private val antecedenciaOk: Boolean get() = Duration.between(agora, inicio) >= ANTECEDENCIA_MINIMA
    private val duracaoOk: Boolean get() = duracao in DURACAO_MINIMA..DURACAO_MAXIMA

    val podeEditar: Boolean get() = !enviando && !travado && resultado == null

    val podeEnviar: Boolean
        get() = !carregando && !enviando && resultado == null && recursoHabilitado && totalConfirmado &&
            funcaoId != null && pontoDaCasa != null && valorCentavos > 0 && recado.length <= TAMANHO_MAXIMO_DO_RECADO &&
            responsavel.isNotBlank() && antecedenciaOk && duracaoOk

    /** O primeiro motivo que impede o envio, para o botão desligado não ficar sem explicação. */
    val oQueFalta: String?
        get() = when {
            !recursoHabilitado || carregando || enviando || resultado != null -> null
            valorCentavos <= 0 -> TextosChamadaCasa.FALTA_VALOR
            !totalConfirmado -> TextosChamadaCasa.FALTA_CONFIRMAR_TOTAL
            responsavel.isBlank() -> TextosChamadaCasa.FALTA_RESPONSAVEL
            !antecedenciaOk -> TextosChamadaCasa.FALTA_ANTECEDENCIA
            !duracaoOk -> TextosChamadaCasa.FALTA_DURACAO
            else -> null
        }

    val recadoLongo: Boolean get() = recado.length > TAMANHO_MAXIMO_DO_RECADO

    companion object {
        val ANTECEDENCIA_MINIMA: Duration = Duration.ofHours(2)
        val DURACAO_MINIMA: Duration = Duration.ofHours(2)
        val DURACAO_MAXIMA: Duration = Duration.ofHours(16)
        const val TAMANHO_MAXIMO_DO_RECADO = 300
    }
}

/**
 * [recursoHabilitado] é a chave `RecursosDoApp.chamada_direta` (`consultarConfiguracaoDoApp`); [buscarCasa] é
 * `ServicoMembros.meuEstabelecimento`; [buscarFuncoes] é `ServicoVagas.listarFuncoes`; [chamar] é
 * `ServicoChamadaDireta.chamarProfissional`. [regiaoId] é o da busca, quando a chamada nasce dela.
 *
 * Idempotência: a `chave` nasce uma vez. Se a resposta se perde (sem rede, corpo ilegível, prazo), a folha
 * trava e o reenvio manda exatamente o mesmo pedido; o servidor devolve a mesma chamada. Só uma recusa do
 * servidor (já aberta, indisponível, limite...) destrava os campos, e a próxima tentativa leva chave nova.
 * Todo `await` de rede tem prazo ([prazoMs]) e nenhuma falha deixa a folha em "Carregando" ou "Enviando".
 */
class ChamadaDiretaViewModel(
    private val profissionalId: String,
    private val estabelecimentoId: String,
    private val recursoHabilitado: suspend () -> Boolean,
    private val buscarCasa: suspend (estabelecimentoId: String) -> MeuEstabelecimentoDto,
    private val buscarFuncoes: suspend () -> List<FuncaoDto>,
    private val chamar: suspend (ChamarProfissionalDto) -> ChamadaDto,
    private val regiaoId: Int? = null,
    private val relogio: () -> Instant = Instant::now,
    private val novaChave: () -> String = { UUID.randomUUID().toString() },
    private val prazoMs: Long = PRAZO_PADRAO_MS,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(estadoInicial())
    val estado: StateFlow<EstadoChamadaDireta> = _estado.asStateFlow()

    private var tentativa: ChamarProfissionalDto? = null
    private var recorrenciaPendente = false
    private var carregou = false

    private fun estadoInicial(): EstadoChamadaDireta {
        val agora = relogio()
        val inicio = agora.plus(Duration.ofHours(24))
        return EstadoChamadaDireta(inicio = inicio, fim = inicio.plus(Duration.ofHours(4)), agora = agora)
    }

    /** O início mais cedo que o seletor oferece: agora + 2 h. Um turno que já começou nem aparece. */
    fun inicioMinimo(): Instant = relogio().plus(EstadoChamadaDireta.ANTECEDENCIA_MINIMA)

    /** O término que o seletor oferece: de 2 a 16 h depois do início. */
    fun faixaDoTermino(): ClosedRange<Instant> {
        val inicio = _estado.value.inicio
        return inicio.plus(EstadoChamadaDireta.DURACAO_MINIMA)..inicio.plus(EstadoChamadaDireta.DURACAO_MAXIMA)
    }

    private inline fun atualizar(transformar: (EstadoChamadaDireta) -> EstadoChamadaDireta) {
        _estado.update { transformar(it).copy(agora = relogio()) }
    }

    private inline fun editar(crossinline transformar: (EstadoChamadaDireta) -> EstadoChamadaDireta) {
        if (_estado.value.podeEditar) atualizar { transformar(it) }
    }

    // --- Campos ------------------------------------------------------------------------------------

    fun definirFuncao(funcaoId: String) = editar { tela ->
        if (tela.funcoes.none { it.id == funcaoId }) tela else tela.copy(funcaoId = funcaoId)
    }

    /** Mudar o início leva o término junto, com a mesma duração, dentro de 2 a 16 h. */
    fun definirInicio(inicio: Instant) = editar { tela ->
        val duracao = tela.duracao.coerceIn(EstadoChamadaDireta.DURACAO_MINIMA, EstadoChamadaDireta.DURACAO_MAXIMA)
        tela.copy(inicio = inicio, fim = inicio.plus(duracao))
    }

    fun definirFim(fim: Instant) = editar { it.copy(fim = fim) }

    /** O valor limpo como no iOS: só algarismos e uma vírgula. Mudar o valor desfaz a confirmação do total. */
    fun definirValor(texto: String) = editar { tela ->
        val limpo = ValorEmReais.digitado(texto, anterior = tela.valorTexto)
        val mudou = ValorEmReais.centavos(limpo) != ValorEmReais.centavos(tela.valorTexto)
        tela.copy(valorTexto = limpo, totalConfirmado = tela.totalConfirmado && !mudou)
    }

    fun confirmarTotal(confirmado: Boolean) = editar { it.copy(totalConfirmado = confirmado) }
    fun definirResponsavel(texto: String) = editar { it.copy(responsavel = texto) }
    fun definirRecado(texto: String) = editar { it.copy(recado = texto) }
    fun definirRefeicao(valor: Boolean) = editar { it.copy(refeicao = valor) }
    fun definirTransporte(valor: Boolean) = editar { it.copy(transporte = valor) }
    fun definirMaterialProprio(valor: Boolean) = editar { it.copy(materialProprio = valor) }

    // --- Carregar ----------------------------------------------------------------------------------

    /** Chave desligada, casa e catálogo de funções, com prazo. Também serve de "tentar novamente". */
    fun carregar(): Job {
        val atual = _estado.value
        if (atual.carregando || carregou) return escopoDeTrabalho.launch { }
        atualizar { it.copy(carregando = true, erro = null) }
        return escopoDeTrabalho.launch {
            try {
                val dados = withTimeout(prazoMs) {
                    if (!recursoHabilitado()) return@withTimeout null
                    val casa = buscarCasa(estabelecimentoId)
                    casa to buscarFuncoes()
                }
                if (dados == null) {
                    atualizar { it.copy(carregando = false, erro = TextosChamadaCasa.DESLIGADO) }
                    return@launch
                }
                val (casa, funcoes) = dados
                carregou = true
                atualizar {
                    it.copy(
                        carregando = false,
                        funcoes = funcoes,
                        funcaoId = it.funcaoId?.takeIf { id -> funcoes.any { f -> f.id == id } } ?: funcoes.firstOrNull()?.id,
                        local = casa.endereco,
                        responsavel = casa.nome,
                        pontoDaCasa = casa.ponto,
                        regiaoDaCasa = casa.regiaoAdministrativa,
                        recursoHabilitado = true,
                    )
                }
            } catch (erro: TimeoutCancellationException) {
                atualizar { it.copy(carregando = false, erro = TextosChamadaCasa.ERRO) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                atualizar { it.copy(carregando = false, erro = mensagemDaChamada(erro)) }
            } catch (_: Exception) {
                atualizar { it.copy(carregando = false, erro = TextosChamadaCasa.ERRO) }
            }
        }
    }

    // --- Enviar ------------------------------------------------------------------------------------

    /**
     * Cria a chamada. [confirmoRecorrencia] só vale depois da recusa `409 recorrencia_nao_confirmada` (J7): o
     * reenvio usa o mesmo pedido e a mesma chave, com o aviso confirmado. Sem efeito com um envio em voo ou com
     * os campos ainda incompletos; o segundo toque não dispara outro pedido.
     */
    fun enviar(confirmoRecorrencia: Boolean = false): Job {
        val atual = _estado.value.copy(agora = relogio())
        if (!atual.podeEnviar || (confirmoRecorrencia && !recorrenciaPendente)) return escopoDeTrabalho.launch { }
        val pedido = (tentativa ?: montarPedido(atual)).let { original ->
            if (confirmoRecorrencia) original.copy(confirmoRecorrencia = true) else original
        }
        tentativa = pedido
        atualizar { it.copy(enviando = true, travado = true, erro = null, mostrarJ7 = false) }
        return escopoDeTrabalho.launch {
            try {
                val chamada = withTimeout(prazoMs) { chamar(pedido) }
                recorrenciaPendente = false
                atualizar { it.copy(enviando = false, resultado = chamada, mostrarJ7 = false) }
            } catch (erro: TimeoutCancellationException) {
                // A chamada pode ter sido criada: a tentativa fica, e o reenvio leva a mesma chave.
                atualizar { it.copy(enviando = false, erro = TextosChamadaCasa.ERRO) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                when {
                    erro.codigo == CodigoErroAPI.RECORRENCIA_NAO_CONFIRMADA -> {
                        recorrenciaPendente = true
                        atualizar { it.copy(enviando = false, mostrarJ7 = true) }
                    }
                    resultadoIncerto(erro) ->
                        atualizar { it.copy(enviando = false, erro = mensagemDaChamada(erro)) }
                    else -> {
                        tentativa = null
                        recorrenciaPendente = false
                        atualizar { it.copy(enviando = false, travado = false, erro = mensagemDaChamada(erro)) }
                    }
                }
            } catch (_: Exception) {
                atualizar { it.copy(enviando = false, erro = TextosChamadaCasa.ERRO) }
            }
        }
    }

    /** A pessoa fechou o aviso J7 sem confirmar: nada é enviado, e o pedido continua guardado para um reenvio. */
    fun dispensarJ7() = atualizar { it.copy(mostrarJ7 = false) }

    private fun montarPedido(tela: EstadoChamadaDireta): ChamarProfissionalDto {
        val trabalho = TrabalhoDaChamada(
            funcaoId = requireNotNull(tela.funcaoId),
            inicio = tela.inicio,
            fim = tela.fim,
            local = tela.local,
            regiaoAdministrativa = tela.regiaoDaCasa,
            ponto = requireNotNull(tela.pontoDaCasa),
            valorCentavos = tela.valorCentavos,
            incluiRefeicao = tela.refeicao,
            incluiTransporte = tela.transporte,
            exigeMaterialProprio = tela.materialProprio,
            responsavelLocal = tela.responsavel,
        )
        return trabalho.paraPedido(
            profissionalId = profissionalId,
            estabelecimentoId = estabelecimentoId,
            chave = novaChave(),
            recado = tela.recado.trim(),
            regiaoId = regiaoId,
        )
    }

    companion object {
        const val PRAZO_PADRAO_MS = 15_000L
    }
}
