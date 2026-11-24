package br.com.frila.feature.vagas.painel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.regra.instanteDoServidor
import br.com.frila.core.rede.AcaoPendente
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.EventoDeTelemetria
import br.com.frila.core.rede.FilaDeAcoes
import br.com.frila.core.rede.RepublicarVagaDto
import br.com.frila.core.rede.TipoAcaoPendente
import br.com.frila.core.rede.VagaPublicadaDto
import java.io.IOException
import java.time.Duration
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.UUID
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class EstadoRepublicarVaga(
    val inicio: Instant,
    val fim: Instant,
    val erroInicio: String? = null,
    val erroFim: String? = null,
    val naFila: Boolean = false,
    val enviadaPelaFila: Boolean = false,
    val enviando: Boolean = false,
    /** Depois de uma falha passageira o horário trava: o reenvio sai com a mesma chave e o mesmo horário. */
    val camposBloqueados: Boolean = false,
    val mensagemErro: String? = null,
    /** A vaga nova, quando a republicação deu certo. */
    val vagaPublicadaId: String? = null,
) {
    val podeConfirmar: Boolean get() = !enviando && !naFila && !enviadaPelaFila && vagaPublicadaId == null
    val podeMudarHorario: Boolean get() = podeConfirmar && !camposBloqueados
}

/**
 * Republicar uma vaga anterior com nova data e horário (`republicar_vaga`, RF05; paridade com o
 * `RepublicarVagaViewModel` do iOS). O servidor copia os dados da vaga de origem; aqui só se escolhe o período.
 * O início sugerido é daqui a 3 horas (25 no modo seleção, que exige 24 de antecedência), com a duração da vaga
 * de origem. A chave de idempotência nasce no primeiro envio e só troca depois de sucesso ou de recusa definitiva:
 * repetir depois de queda de rede não publica duas vagas. Sem rede, a tentativa continua na fila da conta.
 *
 * [republicar] é `ServicoVagas.republicarVaga`. `escopo`: mesma razão do `MinhasVagasViewModel`.
 */
class RepublicarVagaViewModel(
    val vagaId: String,
    private val selecao: Boolean,
    duracaoOriginal: Duration,
    private val republicar: suspend (vagaId: String, inicio: Instant, fim: Instant, chave: String) -> VagaPublicadaDto,
    private val relogio: () -> Instant = Instant::now,
    private val novaChave: () -> String = { UUID.randomUUID().toString() },
    escopo: CoroutineScope? = null,
    private val filaDeAcoes: FilaDeAcoes? = null,
    private val contaAtual: () -> String? = { null },
    private val registrarEvento: (EventoDeTelemetria, String?, String?) -> Unit = { _, _, _ -> },
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(estadoInicial(duracaoOriginal))
    val estado: StateFlow<EstadoRepublicarVaga> = _estado.asStateFlow()

    private var chave: String? = null
    private val duracao = duracaoOriginal
    private var contaObservada = contaAtual()
    private var geracaoObservada = filaDeAcoes?.geracao()
    init {
        reconciliarComAFila()
        filaDeAcoes?.let { fila -> escopoDeTrabalho.launch { fila.versao.collect { reconciliarComAFila() } } }
    }

    private fun reconciliarComAFila() {
        val fila = filaDeAcoes ?: return
        val conta = contaAtual()
        if (conta != contaObservada || geracaoObservada != fila.geracao()) {
            contaObservada = conta
            geracaoObservada = fila.geracao()
            chave = null
            _estado.value = estadoInicial(duracao)
        }
        if (conta == null) return
        synchronized(fila) {
            val acao = fila.pendentes().firstOrNull {
                it.tipo == TipoAcaoPendente.REPUBLICACAO_VAGA && it.contaId == conta && it.republicacao?.vagaId == vagaId
            }
            val recusa = fila.recusadas().any {
                it.tipo == TipoAcaoPendente.REPUBLICACAO_VAGA && it.contaId == conta && it.vagaId == vagaId
            }
            if (acao != null) chave = acao.chave
            if (recusa && !_estado.value.enviando) chave = null
            _estado.update { e -> when {
                acao != null -> e.copy(naFila = true, enviando = false, camposBloqueados = true, mensagemErro = null,
                    inicio = instanteDoServidor(acao.republicacao!!.inicioEm), fim = instanteDoServidor(acao.republicacao!!.fimEm))
                recusa && !e.enviando -> e.copy(naFila = false, camposBloqueados = false, mensagemErro = TextosRepublicarVaga.RECUSADA_NA_FILA)
                e.naFila -> e.copy(naFila = false, enviadaPelaFila = true)
                else -> e
            } }
        }
    }

    private fun guardarNaFila(envio: EstadoRepublicarVaga, chave: String, toque: Instant, conta: String?): Boolean {
        val fila = filaDeAcoes ?: return false
        if (conta == null || contaAtual() != conta) return false
        return try {
            synchronized(fila) {
                val existente = fila.pendentes().any {
                    it.tipo == TipoAcaoPendente.REPUBLICACAO_VAGA && it.contaId == conta && it.republicacao?.vagaId == vagaId
                }
                if (!existente) {
                    fila.enfileirar(AcaoPendente(TipoAcaoPendente.REPUBLICACAO_VAGA, conta, toque.toString(), chave = chave,
                        republicacao = RepublicarVagaDto(vagaId, envio.inicio.toString(), envio.fim.toString(), chave)))
                    registrarEvento(EventoDeTelemetria.ACAO_ENFILEIRADA_OFFLINE, vagaId, null)
                }
                reconciliarComAFila()
            }
            true
        } catch (_: IOException) { false }
    }

    private fun estadoInicial(duracao: Duration): EstadoRepublicarVaga {
        val antecedencia = if (selecao) ANTECEDENCIA_SUGERIDA_SELECAO else ANTECEDENCIA_SUGERIDA_URGENCIA
        val inicio = relogio().plus(antecedencia).truncatedTo(ChronoUnit.MINUTES)
        return EstadoRepublicarVaga(inicio = inicio, fim = inicio.plus(duracao))
    }

    /** Mudar o início leva o término junto, mantendo a duração. */
    fun mudarInicio(novo: Instant) = _estado.update {
        if (!it.podeMudarHorario) return@update it
        val duracao = Duration.between(it.inicio, it.fim)
        it.copy(inicio = novo, fim = if (duracao > Duration.ZERO) novo.plus(duracao) else it.fim, erroInicio = null, erroFim = null, mensagemErro = null)
    }

    fun mudarFim(novo: Instant) = _estado.update {
        if (it.podeMudarHorario) it.copy(fim = novo, erroFim = null, mensagemErro = null) else it
    }

    /** As mesmas regras do iOS, antes de ir ao servidor: início no futuro, de 2 a 16 horas, e 24 horas de antecedência na seleção. */
    private fun validar(): Boolean {
        val atual = _estado.value
        val agora = relogio()
        var erroInicio: String? = null
        var erroFim: String? = null
        if (!atual.inicio.isAfter(agora)) erroInicio = TextosRepublicarVaga.INICIO_NO_PASSADO
        val duracao = Duration.between(atual.inicio, atual.fim)
        when {
            duracao <= Duration.ZERO -> erroFim = TextosRepublicarVaga.FIM_ANTES_DO_INICIO
            duracao < DURACAO_MINIMA -> erroFim = TextosRepublicarVaga.TURNO_CURTO
            duracao > DURACAO_MAXIMA -> erroFim = TextosRepublicarVaga.TURNO_LONGO
        }
        if (selecao && !atual.inicio.isAfter(agora.plus(ANTECEDENCIA_MINIMA_SELECAO))) erroInicio = TextosRepublicarVaga.SELECAO_SEM_ANTECEDENCIA
        _estado.update { it.copy(erroInicio = erroInicio, erroFim = erroFim) }
        return erroInicio == null && erroFim == null
    }

    /** Envia a republicação. `null` se não há o que enviar (horário inválido, já enviando ou já republicada). */
    fun republicar(): Job? {
        reconciliarComAFila()
        if (!_estado.value.podeConfirmar) return null
        // Com chave guardada é reenvio da mesma tentativa: o horário está travado e quem o julga é o servidor.
        if (chave == null && !validar()) return null
        val chaveDoEnvio = chave ?: novaChave().also { chave = it }
        val envio = _estado.value
        val toque = relogio()
        val conta = contaAtual()
        val geracao = filaDeAcoes?.geracao()
        filaDeAcoes?.let { fila -> runCatching { fila.recusadas().filter {
            it.tipo == TipoAcaoPendente.REPUBLICACAO_VAGA && it.contaId == conta && it.vagaId == vagaId
        }.forEach { fila.reconhecerRecusa(it.id) } }.onFailure { if (it !is IOException) throw it } }
        _estado.update { it.copy(enviando = true, mensagemErro = null) }
        return escopoDeTrabalho.launch {
            try {
                val publicada = republicar(vagaId, envio.inicio, envio.fim, chaveDoEnvio)
                if (filaDeAcoes != null && (contaAtual() != conta || filaDeAcoes.geracao() != geracao)) { reconciliarComAFila(); return@launch }
                chave = null
                _estado.update { it.copy(enviando = false, camposBloqueados = false, vagaPublicadaId = publicada.vagaId) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
                if (filaDeAcoes != null && (contaAtual() != conta || filaDeAcoes.geracao() != geracao)) { reconciliarComAFila(); return@launch }
                if ((erro as? ErroDaApi)?.codigo == CodigoErroAPI.SEM_REDE && guardarNaFila(envio, chaveDoEnvio, toque, conta)) return@launch
                falhar(erro)
            }
        }
    }

    private fun falhar(erro: Exception) {
        val codigo = (erro as? ErroDaApi)?.codigo
        if (codigo in RECUSAS_DEFINITIVAS) {
            // O servidor recusou este pedido: a próxima tentativa é outra, com chave nova e horário livre.
            chave = null
            val noInicio = when (codigo) {
                CodigoErroAPI.SELECAO_SEM_ANTECEDENCIA -> TextosRepublicarVaga.SELECAO_SEM_ANTECEDENCIA
                CodigoErroAPI.HORARIO_INVALIDO -> TextosRepublicarVaga.HORARIO_INVALIDO
                else -> null
            }
            _estado.update {
                it.copy(
                    enviando = false,
                    camposBloqueados = false,
                    erroInicio = noInicio,
                    erroFim = if (codigo == CodigoErroAPI.HORARIO_INVALIDO) TextosRepublicarVaga.HORARIO_INVALIDO else null,
                    mensagemErro = mensagemDaRecusa(codigo),
                )
            }
            return
        }
        val mensagem = when (codigo) {
            CodigoErroAPI.SEM_REDE -> TextosRepublicarVaga.SEM_REDE
            CodigoErroAPI.NAO_AUTENTICADO -> TextosRepublicarVaga.SESSAO_EXPIRADA
            else -> TextosRepublicarVaga.ERRO_GENERICO
        }
        _estado.update { it.copy(enviando = false, camposBloqueados = true, mensagemErro = mensagem) }
    }

    private fun mensagemDaRecusa(codigo: CodigoErroAPI?): String = when (codigo) {
        CodigoErroAPI.NAO_ENCONTRADO -> TextosRepublicarVaga.NAO_ENCONTRADO
        CodigoErroAPI.SEM_PERMISSAO, CodigoErroAPI.CONTA_SUSPENSA -> TextosRepublicarVaga.SEM_PERMISSAO
        CodigoErroAPI.VAGA_OCULTA -> TextosRepublicarVaga.VAGA_OCULTA
        CodigoErroAPI.PERFIL_INCOMPATIVEL -> TextosRepublicarVaga.PERFIL_INCOMPATIVEL
        CodigoErroAPI.SELECAO_SEM_ANTECEDENCIA -> TextosRepublicarVaga.SELECAO_SEM_ANTECEDENCIA
        CodigoErroAPI.HORARIO_INVALIDO, CodigoErroAPI.CAMPO_OBRIGATORIO, CodigoErroAPI.CAMPO_INVALIDO -> TextosRepublicarVaga.HORARIO_INVALIDO
        else -> TextosRepublicarVaga.ERRO_GENERICO
    }

    companion object {
        val ANTECEDENCIA_SUGERIDA_URGENCIA: Duration = Duration.ofHours(3)
        val ANTECEDENCIA_SUGERIDA_SELECAO: Duration = Duration.ofHours(25)
        val ANTECEDENCIA_MINIMA_SELECAO: Duration = Duration.ofHours(24)
        val DURACAO_MINIMA: Duration = Duration.ofHours(2)
        val DURACAO_MAXIMA: Duration = Duration.ofHours(16)

        /** Recusas em que repetir o mesmo pedido não adianta (`recusaDefinitivaDePublicacao` do iOS, mais `vaga_oculta`). */
        private val RECUSAS_DEFINITIVAS = setOf(
            CodigoErroAPI.CAMPO_OBRIGATORIO, CodigoErroAPI.CAMPO_INVALIDO, CodigoErroAPI.HORARIO_INVALIDO,
            CodigoErroAPI.FUNCAO_INCOMPATIVEL, CodigoErroAPI.PERFIL_INCOMPATIVEL, CodigoErroAPI.SELECAO_SEM_ANTECEDENCIA,
            CodigoErroAPI.SEM_PERMISSAO, CodigoErroAPI.CONTA_SUSPENSA, CodigoErroAPI.NAO_ENCONTRADO, CodigoErroAPI.VAGA_OCULTA,
        )
    }
}
