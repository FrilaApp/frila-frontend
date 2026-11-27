package br.com.frila.feature.chamadas.casa

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ChamadaDto
import br.com.frila.core.rede.ChamadaResumoDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.PaginaDeChamadasDto
import br.com.frila.core.rede.VagaPublicadaDto
import br.com.frila.feature.chamadas.profissional.FormatoChamada
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

data class EstadoAcompanharChamadas(
    val chamadas: List<ChamadaResumoDto> = emptyList(),
    val carregando: Boolean = false,
    /** Cancelar ou publicar em voo: nenhuma outra ação dispara. */
    val acaoEmVoo: Boolean = false,
    val erro: String? = null,
    val sucesso: String? = null,
    /** A vaga normal aberta a partir da chamada (`publicar_a_partir_da_chamada`). */
    val vagaPublicadaId: String? = null,
    /** A vaga direta já fechou ([vagaJaEncerrada], ou o servidor recusou com `409 vaga_encerrada`): não há o que publicar. */
    val vagaEncerrada: Boolean = false,
) {
    val temChamadaAceita: Boolean get() = chamadas.any { it.estado == ESTADO_ACEITA }

    /** Todas as chamadas da vaga terminaram sem aceite: a casa pode abrir a vaga para todos. */
    val podePublicarParaTodos: Boolean
        get() = chamadas.isNotEmpty() && !temChamadaAceita && vagaPublicadaId == null && !acaoEmVoo && !vagaEncerrada &&
            chamadas.all { it.estado in ESTADOS_SEM_ACEITE }

    fun rotuloDoEstado(estado: String): String = when (estado) {
        "aberta" -> TextosChamadaCasa.STATUS_ABERTA
        "aceita" -> TextosChamadaCasa.STATUS_ACEITA
        "recusada" -> TextosChamadaCasa.STATUS_RECUSADA
        "expirada" -> TextosChamadaCasa.STATUS_EXPIRADA
        "cancelada" -> TextosChamadaCasa.STATUS_CANCELADA
        "encerrada" -> TextosChamadaCasa.STATUS_ENCERRADA
        else -> estado
    }

    companion object {
        const val ESTADO_ABERTA = "aberta"
        const val ESTADO_ACEITA = "aceita"
        private val ESTADOS_SEM_ACEITE = setOf("recusada", "expirada", "cancelada", "encerrada")
    }
}

/**
 * A vaga direta já fechou pelo que a lista mostra, e `publicar_a_partir_da_chamada` responderia `409 vaga_encerrada`:
 * o turno já começou, ou a última chamada a fechar expirou (`expirar_chamadas` encerra a vaga direta quando a última
 * chamada aberta expira; recusa e cancelamento não a encerram). Sem `respondida_em`, não dá para saber, e o botão fica.
 */
internal fun vagaJaEncerrada(chamadas: List<ChamadaResumoDto>, agora: Instant): Boolean {
    if (chamadas.any { c -> FormatoChamada.instante(c.inicioEm)?.let { !it.isAfter(agora) } == true }) return true
    val ultima = chamadas.maxByOrNull { c -> c.respondidaEm?.let(FormatoChamada::instante) ?: Instant.MIN } ?: return false
    return ultima.estado == "expirada" && ultima.respondidaEm?.let(FormatoChamada::instante) != null
}

/** O texto do motivo que o profissional escolheu ao recusar; nunca o código do contrato. */
fun textoDoMotivoDeRecusa(motivo: String): String = when (motivo) {
    "agenda" -> TextosChamadaCasa.MOTIVO_AGENDA
    "distancia" -> TextosChamadaCasa.MOTIVO_DISTANCIA
    "valor" -> TextosChamadaCasa.MOTIVO_VALOR
    "tipo_de_servico" -> TextosChamadaCasa.MOTIVO_TIPO_DE_SERVICO
    else -> TextosChamadaCasa.MOTIVO_OUTRO
}

/**
 * Acompanhar as chamadas de uma vaga direta, cancelar uma aberta e "publicar para todos" (paridade com
 * `AcompanharChamadasViewModel.swift`, CD-RF09).
 *
 * [listar] é `ServicoChamadaDireta.minhasChamadas` (estado, cursor, limite); a lista é de todas as chamadas da
 * casa, então o ViewModel segue o cursor até achar o fim (no máximo [PAGINAS_MAXIMAS] páginas) e fica só com as
 * de [vagaId]. [cancelarChamada] e [publicarAPartirDaChamada] são as de mesmo nome do serviço (modo `urgencia`).
 *
 * A `chave` de "publicar para todos" nasce uma vez por vaga: se a resposta se perde, tocar de novo reenvia a
 * mesma chave e o servidor devolve a mesma vaga, nunca uma segunda.
 */
class AcompanharChamadasViewModel(
    private val vagaId: String,
    private val listar: suspend (estado: String?, cursor: String?, limite: Int?) -> PaginaDeChamadasDto,
    private val cancelarChamada: suspend (chamadaId: String) -> ChamadaDto,
    private val publicarAPartirDaChamada: suspend (vagaId: String, chave: String, modo: String?) -> VagaPublicadaDto,
    private val novaChave: () -> String = { UUID.randomUUID().toString() },
    private val prazoMs: Long = ChamadaDiretaViewModel.PRAZO_PADRAO_MS,
    private val relogio: () -> Instant = Instant::now,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoAcompanharChamadas())
    val estado: StateFlow<EstadoAcompanharChamadas> = _estado.asStateFlow()

    private var chaveDaPublicacao: String? = null

    /** Também serve de "tentar novamente". Duas cargas ao mesmo tempo viram uma. */
    fun carregar(): Job {
        if (_estado.value.carregando) return escopoDeTrabalho.launch { }
        _estado.update { it.copy(carregando = true, erro = null) }
        return escopoDeTrabalho.launch { recarregar() }
    }

    private suspend fun recarregar() {
        try {
            val todas = withTimeout(prazoMs) { lerTodasAsPaginas() }
            val daVaga = todas.filter { c -> c.vagaId == vagaId }
            _estado.update {
                it.copy(carregando = false, chamadas = daVaga, vagaEncerrada = it.vagaEncerrada || vagaJaEncerrada(daVaga, relogio()))
            }
        } catch (erro: TimeoutCancellationException) {
            _estado.update { it.copy(carregando = false, erro = TextosChamadaCasa.ERRO) }
        } catch (erro: CancellationException) {
            throw erro
        } catch (erro: ErroDaApi) {
            _estado.update { it.copy(carregando = false, erro = mensagemAoCarregar(erro)) }
        } catch (_: Exception) {
            _estado.update { it.copy(carregando = false, erro = TextosChamadaCasa.ERRO) }
        }
    }

    private suspend fun lerTodasAsPaginas(): List<ChamadaResumoDto> {
        val itens = mutableListOf<ChamadaResumoDto>()
        var cursor: String? = null
        repeat(PAGINAS_MAXIMAS) {
            val pagina = listar(null, cursor, TAMANHO_DA_PAGINA)
            itens += pagina.itens
            cursor = pagina.proximoCursor ?: return itens
        }
        return itens
    }

    private fun mensagemAoCarregar(erro: ErroDaApi): String =
        if (recursoDesligado(erro)) TextosChamadaCasa.DESLIGADO else TextosChamadaCasa.ERRO

    /** Só chamada `aberta` cancela. Sem efeito com outra ação em voo. */
    fun cancelar(chamadaId: String): Job {
        val atual = _estado.value
        if (atual.acaoEmVoo || atual.chamadas.none { it.id == chamadaId && it.estado == EstadoAcompanharChamadas.ESTADO_ABERTA }) {
            return escopoDeTrabalho.launch { }
        }
        _estado.update { it.copy(acaoEmVoo = true, erro = null, sucesso = null) }
        return escopoDeTrabalho.launch {
            try {
                withTimeout(prazoMs) { cancelarChamada(chamadaId) }
                _estado.update { it.copy(acaoEmVoo = false, sucesso = TextosChamadaCasa.CHAMADA_CANCELADA_SUCESSO) }
            } catch (erro: TimeoutCancellationException) {
                _estado.update { it.copy(acaoEmVoo = false, erro = TextosChamadaCasa.ERRO) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                val mensagem = if (erro.codigo == CodigoErroAPI.CHAMADA_INDISPONIVEL) {
                    TextosChamadaCasa.CHAMADA_JA_RESPONDIDA
                } else {
                    TextosChamadaCasa.ERRO
                }
                _estado.update { it.copy(acaoEmVoo = false, erro = mensagem) }
            } catch (_: Exception) {
                _estado.update { it.copy(acaoEmVoo = false, erro = TextosChamadaCasa.ERRO) }
            }
            // Recusada ou não, a lista é relida: o estado da chamada pode ter mudado do outro lado.
            recarregar()
        }
    }

    /** "Publicar para todos": só quando [EstadoAcompanharChamadas.podePublicarParaTodos]. */
    fun publicarParaTodos(): Job {
        if (!_estado.value.podePublicarParaTodos) return escopoDeTrabalho.launch { }
        val chave = chaveDaPublicacao ?: novaChave().also { chaveDaPublicacao = it }
        _estado.update { it.copy(acaoEmVoo = true, erro = null, sucesso = null) }
        return escopoDeTrabalho.launch {
            try {
                val publicada = withTimeout(prazoMs) { publicarAPartirDaChamada(vagaId, chave, "urgencia") }
                _estado.update {
                    it.copy(acaoEmVoo = false, vagaPublicadaId = publicada.vagaId, sucesso = TextosChamadaCasa.VAGA_PUBLICADA_SUCESSO)
                }
                recarregar()
            } catch (erro: TimeoutCancellationException) {
                _estado.update { it.copy(acaoEmVoo = false, erro = TextosChamadaCasa.ERRO) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                // Recusa do servidor é definitiva: a próxima tentativa leva chave nova.
                if (!resultadoIncerto(erro)) chaveDaPublicacao = null
                if (erro.codigo == CodigoErroAPI.VAGA_ENCERRADA) {
                    // Vaga direta cancelada, encerrada ou preenchida, ou fora da janela (RN35): o botão some e a lista é
                    // relida, porque as chamadas podem ter mudado do outro lado.
                    _estado.update { it.copy(acaoEmVoo = false, vagaEncerrada = true, erro = TextosChamadaCasa.VAGA_ENCERRADA_AO_PUBLICAR) }
                    recarregar()
                } else {
                    _estado.update { it.copy(acaoEmVoo = false, erro = TextosChamadaCasa.ERRO) }
                }
            } catch (_: Exception) {
                _estado.update { it.copy(acaoEmVoo = false, erro = TextosChamadaCasa.ERRO) }
            }
        }
    }

    companion object {
        const val TAMANHO_DA_PAGINA = 20
        const val PAGINAS_MAXIMAS = 10
    }
}
