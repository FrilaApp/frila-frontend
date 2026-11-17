package br.com.frila.feature.vagas.candidaturas

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.regra.instanteDoServidor
import br.com.frila.core.rede.CandidaturaDto
import br.com.frila.core.rede.ErroDaApi
import java.time.Instant
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Para onde o toque numa candidatura leva (`destinoAoTocar` do iOS). */
sealed interface DestinoDaCandidatura {
    data class Vaga(val vagaId: String) : DestinoDaCandidatura

    /** Candidatura aceita: o turno que nasceu dela (0.2.32). */
    data class Turno(val turnoId: String) : DestinoDaCandidatura

    /** Aceita, mas sem `turno_id` na resposta (servidor antigo): a lista de turnos. */
    data object MeusTurnos : DestinoDaCandidatura

    val dica: String
        get() = when (this) {
            is Vaga -> TextosCandidaturas.ABRE_A_VAGA
            is Turno -> TextosCandidaturas.ABRE_O_TURNO
            MeusTurnos -> TextosCandidaturas.ABRE_MEUS_TURNOS
        }
}

/** Uma candidatura como a lista a mostra. */
data class ItemCandidatura(
    val id: String,
    val vagaId: String,
    val funcao: String,
    val local: String,
    /** `null` se o servidor mandou um instante ilegível. */
    val inicio: Instant?,
    val fim: Instant?,
    val valorCentavos: Long,
    /** Só a pendente pode ser retirada. */
    val pendente: Boolean,
    val textoDoEstado: String,
    val destino: DestinoDaCandidatura,
)

sealed interface ListaDeCandidaturas {
    data object Carregando : ListaDeCandidaturas
    data object Vazia : ListaDeCandidaturas
    data class Carregadas(val pendentes: List<ItemCandidatura>, val anteriores: List<ItemCandidatura>) : ListaDeCandidaturas
    data class Erro(val mensagem: String, val podeTentarDeNovo: Boolean) : ListaDeCandidaturas
}

data class EstadoMinhasCandidaturas(
    val lista: ListaDeCandidaturas = ListaDeCandidaturas.Carregando,
    /** Releitura com a lista já na tela (puxar para atualizar). */
    val atualizando: Boolean = false,
    /** A última releitura falhou com candidaturas na tela: o que aparece pode estar velho. */
    val desatualizada: Boolean = false,
)

/**
 * As candidaturas do profissional (`minhas_candidaturas`; paridade com `MinhasCandidaturasViewModel` do iOS): as que
 * aguardam resposta primeiro, as anteriores depois, na ordem em que o servidor as manda (da mais nova para a mais
 * antiga). A aceita leva ao turno que nasceu dela; as outras, à vaga. Candidatura com estado que este app não conhece
 * fica fora da lista, como no iOS, em vez de derrubá-la. Falha de releitura não apaga o que já está na tela.
 *
 * [buscar] é `ServicoVagas.minhasCandidaturas()`. `escopo`: mesma razão do `MinhasVagasViewModel`.
 */
class MinhasCandidaturasViewModel(
    private val buscar: suspend () -> List<CandidaturaDto>,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoMinhasCandidaturas())
    val estado: StateFlow<EstadoMinhasCandidaturas> = _estado.asStateFlow()

    private var leitura: Job? = null

    /** Primeira leitura e "Tentar de novo". Sem efeito se já há uma leitura em voo. */
    fun carregar(): Job = iniciarLeitura()

    /** Puxar para atualizar, e a releitura depois de retirar uma candidatura: mantém a lista na tela. */
    fun atualizar(): Job = iniciarLeitura()

    private fun iniciarLeitura(): Job {
        leitura?.takeIf { it.isActive }?.let { return it }
        _estado.update {
            if (it.lista.temConteudo) it.copy(atualizando = true) else it.copy(lista = ListaDeCandidaturas.Carregando)
        }
        return escopoDeTrabalho.launch {
            try {
                aplicar(buscar())
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
                falhar(erro)
            }
        }.also { leitura = it }
    }

    private fun aplicar(candidaturas: List<CandidaturaDto>) {
        val itens = candidaturas.mapNotNull { it.paraItem() }
        val (pendentes, anteriores) = itens.partition { it.pendente }
        _estado.value = EstadoMinhasCandidaturas(
            lista = if (itens.isEmpty()) ListaDeCandidaturas.Vazia else ListaDeCandidaturas.Carregadas(pendentes, anteriores),
        )
    }

    private fun falhar(erro: Exception) {
        _estado.update {
            if (it.lista.temConteudo) {
                it.copy(atualizando = false, desatualizada = true)
            } else {
                it.copy(lista = erroDe(erro), atualizando = false)
            }
        }
    }

    private fun erroDe(erro: Exception): ListaDeCandidaturas.Erro = when ((erro as? ErroDaApi)?.codigo) {
        CodigoErroAPI.SEM_REDE -> ListaDeCandidaturas.Erro(TextosCandidaturas.ERRO_SEM_REDE, podeTentarDeNovo = true)
        CodigoErroAPI.NAO_AUTENTICADO -> ListaDeCandidaturas.Erro(TextosCandidaturas.SESSAO_EXPIRADA, podeTentarDeNovo = false)
        CodigoErroAPI.PERFIL_INCOMPATIVEL, CodigoErroAPI.SEM_PERMISSAO, CodigoErroAPI.CONTA_SUSPENSA ->
            ListaDeCandidaturas.Erro(TextosCandidaturas.CONTA_NAO_PODE, podeTentarDeNovo = false)
        else -> ListaDeCandidaturas.Erro(TextosCandidaturas.ERRO_GENERICO, podeTentarDeNovo = true)
    }

    private val ListaDeCandidaturas.temConteudo: Boolean
        get() = this is ListaDeCandidaturas.Carregadas || this == ListaDeCandidaturas.Vazia

    private fun CandidaturaDto.paraItem(): ItemCandidatura? {
        val texto = textoDoEstadoDaCandidatura(estado) ?: return null
        val aceita = estado == ESTADO_ACEITA
        val turno = turnoId
        return ItemCandidatura(
            id = id,
            vagaId = vaga.id,
            funcao = vaga.funcao,
            local = vaga.local,
            inicio = lerInstante(vaga.inicioEm),
            fim = lerInstante(vaga.fimEm),
            valorCentavos = vaga.valorCentavos,
            pendente = estado == ESTADO_PENDENTE,
            textoDoEstado = texto,
            destino = when {
                aceita && turno != null -> DestinoDaCandidatura.Turno(turno)
                aceita -> DestinoDaCandidatura.MeusTurnos
                else -> DestinoDaCandidatura.Vaga(vaga.id)
            },
        )
    }
}

internal const val ESTADO_PENDENTE = "pendente"
internal const val ESTADO_ACEITA = "aceita"
internal const val ESTADO_RECUSADA = "recusada"
internal const val ESTADO_RETIRADA = "retirada"
internal const val ESTADO_EXPIRADA = "expirada"

/** O texto de cada estado do contrato; `null` para estado que este app ainda não conhece. */
internal fun textoDoEstadoDaCandidatura(estado: String): String? = when (estado) {
    ESTADO_PENDENTE -> TextosCandidaturas.ESTADO_PENDENTE
    ESTADO_ACEITA -> TextosCandidaturas.ESTADO_ACEITA
    ESTADO_RECUSADA -> TextosCandidaturas.ESTADO_RECUSADA
    ESTADO_RETIRADA -> TextosCandidaturas.ESTADO_RETIRADA
    ESTADO_EXPIRADA -> TextosCandidaturas.ESTADO_EXPIRADA
    else -> null
}

private fun lerInstante(texto: String): Instant? = runCatching { instanteDoServidor(texto) }.getOrNull()
