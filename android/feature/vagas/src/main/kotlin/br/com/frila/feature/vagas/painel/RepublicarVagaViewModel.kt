package br.com.frila.feature.vagas.painel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.VagaPublicadaDto
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
    val enviando: Boolean = false,
    /** Depois de uma falha passageira o horário trava: o reenvio sai com a mesma chave e o mesmo horário. */
    val camposBloqueados: Boolean = false,
    val mensagemErro: String? = null,
    /** A vaga nova, quando a republicação deu certo. */
    val vagaPublicadaId: String? = null,
) {
    val podeConfirmar: Boolean get() = !enviando && vagaPublicadaId == null
    val podeMudarHorario: Boolean get() = !enviando && !camposBloqueados && vagaPublicadaId == null
}

/**
 * Republicar uma vaga anterior com nova data e horário (`republicar_vaga`, RF05; paridade com o
 * `RepublicarVagaViewModel` do iOS). O servidor copia os dados da vaga de origem; aqui só se escolhe o período.
 * O início sugerido é daqui a 3 horas (25 no modo seleção, que exige 24 de antecedência), com a duração da vaga
 * de origem. A chave de idempotência nasce no primeiro envio e só troca depois de sucesso ou de recusa definitiva:
 * repetir depois de queda de rede não publica duas vagas. O Android ainda não tem fila de ações sem rede.
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
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(estadoInicial(duracaoOriginal))
    val estado: StateFlow<EstadoRepublicarVaga> = _estado.asStateFlow()

    private var chave: String? = null

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
        if (!_estado.value.podeConfirmar) return null
        // Com chave guardada é reenvio da mesma tentativa: o horário está travado e quem o julga é o servidor.
        if (chave == null && !validar()) return null
        val chaveDoEnvio = chave ?: novaChave().also { chave = it }
        val envio = _estado.value
        _estado.update { it.copy(enviando = true, mensagemErro = null) }
        return escopoDeTrabalho.launch {
            try {
                val publicada = republicar(vagaId, envio.inicio, envio.fim, chaveDoEnvio)
                chave = null
                _estado.update { it.copy(enviando = false, camposBloqueados = false, vagaPublicadaId = publicada.vagaId) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
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
