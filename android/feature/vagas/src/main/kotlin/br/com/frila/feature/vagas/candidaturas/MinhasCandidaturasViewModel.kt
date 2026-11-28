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
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
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
    /** Aceita, mas o turno que nasceu dela foi cancelado (`meus_turnos`, cruzado por `turno_id`). */
    val turnoCancelado: Boolean = false,
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
 * [buscar] é `ServicoVagas.minhasCandidaturas()`. [buscarEstadosDosTurnos] é `meus_turnos` reduzido a `turno id -> estado` (o
 * `estado` é opcional no contrato: ausente vem `null`, e não se supõe nem `confirmada` nem `cancelada`). A candidatura aceita
 * cujo turno (`turno_id`, não a vaga) está `cancelada` sai com [ItemCandidatura.turnoCancelado]. A leitura dos turnos corre em
 * paralelo com a das candidaturas e a falha dela é silenciosa: a lista aparece como antes, e o que já se sabia dos turnos fica.
 * `escopo`: mesma razão do `MinhasVagasViewModel`.
 */
class MinhasCandidaturasViewModel(
    private val buscar: suspend () -> List<CandidaturaDto>,
    private val buscarEstadosDosTurnos: (suspend () -> Map<String, String?>)? = null,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoMinhasCandidaturas())
    val estado: StateFlow<EstadoMinhasCandidaturas> = _estado.asStateFlow()

    private var leitura: Job? = null

    /** `turno id -> estado`, da última leitura de `meus_turnos` que deu certo. */
    private var estadosDosTurnos: Map<String, String?> = emptyMap()

    /** Primeira leitura e "Tentar de novo". Sem efeito se já há uma leitura em voo. */
    fun carregar(): Job = iniciarLeitura()

    /** Puxar para atualizar, e a releitura depois de retirar uma candidatura: mantém a lista na tela. */
    fun atualizar(): Job = iniciarLeitura()

    /**
     * Releitura automática (volta do segundo plano, push): troca a lista sem indicador, e uma falha deixa a lista como está, sem
     * marcá-la como desatualizada (paridade com a releitura em silêncio do iOS). Sem efeito com outra leitura em voo.
     */
    fun atualizarEmSilencio(): Job {
        leitura?.takeIf { it.isActive }?.let { return it }
        // Só com a lista na tela (como o iOS): em Carregando disputaria a carga e em Erro tiraria a tela do erro sem ser pedido. Com
        // outra leitura em voo a de cima devolve a própria, e por isso o estado não muda entre o começo e o fim desta.
        if (_estado.value.lista !is ListaDeCandidaturas.Carregadas && _estado.value.lista !is ListaDeCandidaturas.Vazia) {
            return escopoDeTrabalho.launch { }
        }
        return escopoDeTrabalho.launch {
            try {
                lerEAplicar()
            } catch (erro: CancellationException) {
                throw erro
            } catch (_: Exception) {
                // Segue com o que já está na tela.
            }
        }.also { leitura = it }
    }

    private fun iniciarLeitura(): Job {
        leitura?.takeIf { it.isActive }?.let { return it }
        _estado.update {
            if (it.lista.temConteudo) it.copy(atualizando = true) else it.copy(lista = ListaDeCandidaturas.Carregando)
        }
        return escopoDeTrabalho.launch {
            try {
                lerEAplicar()
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
                falhar(erro)
            }
        }.also { leitura = it }
    }

    /** As candidaturas e os turnos em paralelo. Só a falha das candidaturas sobe; a dos turnos vira `null` e o mapa anterior fica. */
    private suspend fun lerEAplicar() = coroutineScope {
        val turnos = buscarEstadosDosTurnos?.let { lerTurnos ->
            async {
                try {
                    lerTurnos()
                } catch (erro: CancellationException) {
                    throw erro
                } catch (_: Exception) {
                    null
                }
            }
        }
        val candidaturas = buscar()
        turnos?.await()?.let { estadosDosTurnos = it }
        aplicar(candidaturas)
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
        val turnoCancelado = aceita && turno != null && estadosDosTurnos[turno] == ESTADO_TURNO_CANCELADO
        return ItemCandidatura(
            id = id,
            vagaId = vaga.id,
            funcao = vaga.funcao,
            local = vaga.local,
            inicio = lerInstante(vaga.inicioEm),
            fim = lerInstante(vaga.fimEm),
            valorCentavos = vaga.valorCentavos,
            pendente = estado == ESTADO_PENDENTE,
            textoDoEstado = if (turnoCancelado) TextosCandidaturas.ESTADO_TURNO_CANCELADO else texto,
            destino = when {
                aceita && turno != null -> DestinoDaCandidatura.Turno(turno)
                aceita -> DestinoDaCandidatura.MeusTurnos
                else -> DestinoDaCandidatura.Vaga(vaga.id)
            },
            turnoCancelado = turnoCancelado,
        )
    }
}

internal const val ESTADO_PENDENTE = "pendente"
internal const val ESTADO_ACEITA = "aceita"
internal const val ESTADO_RECUSADA = "recusada"
internal const val ESTADO_RETIRADA = "retirada"
internal const val ESTADO_EXPIRADA = "expirada"

/** `Turno.estado` de `meus_turnos` para o turno cancelado (RN12). */
internal const val ESTADO_TURNO_CANCELADO = "cancelada"

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
