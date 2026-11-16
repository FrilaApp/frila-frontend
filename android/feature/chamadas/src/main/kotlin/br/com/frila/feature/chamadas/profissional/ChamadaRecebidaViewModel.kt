package br.com.frila.feature.chamadas.profissional

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ChamadaDetalheDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ResultadoChamadaDto
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant

/** Motivos de recusa do contrato (`motivo_recusa`), na ordem da folha do iOS. */
val MOTIVOS_DE_RECUSA: List<String> = listOf("agenda", "distancia", "valor", "tipo_de_servico", "outro")

data class EstadoChamadaRecebida(
    val chamadaId: String,
    val carregando: Boolean = true,
    val respondendo: Boolean = false,
    val detalhe: ChamadaDetalheDto? = null,
    /** Só existe depois de responder; no aceite traz o turno e o que a RN36 libera (local e responsável). */
    val resultado: ResultadoChamadaDto? = null,
    /** Falha que deixa tentar de novo (rede, recurso desligado). */
    val erro: String? = null,
    /** Chamada que já não se responde (expirou, cancelada, encerrada): explica e não oferece botão. */
    val mensagemDeConcorrencia: String? = null,
    val mostrarRecusa: Boolean = false,
    val motivoSelecionado: String? = null,
) {
    val podeResponder: Boolean
        get() = detalhe?.estado == "aberta" && resultado == null && mensagemDeConcorrencia == null &&
            !respondendo && !carregando
}

/**
 * Chamada recebida pelo profissional (CD-I5b; paridade com `ChamadaRecebidaViewModel.swift`): lê
 * `detalhe_chamada` e responde por `responder_chamada` (aceitar, ou recusar com motivo opcional). A recusa
 * não penaliza (RN34). O servidor decide: `409 chamada_indisponivel` (`details`: `expirada`, `cancelada`,
 * `encerrada`...), `422 inelegivel` (`funcao_incompativel`, `turno_sobreposto`), `404` (bloqueio) e
 * `403 conta_suspensa` viram cada um uma mensagem própria, e nenhuma falha deixa a tela em "respondendo".
 *
 * [detalhar] é `ServicoChamadaDireta.detalheChamada` e [responder] é `responderChamada`; [agora] é injetado
 * para o teste decidir o que é "expirada".
 */
class ChamadaRecebidaViewModel(
    private val chamadaId: String,
    private val detalhar: suspend (chamadaId: String) -> ChamadaDetalheDto,
    private val responder: suspend (chamadaId: String, resposta: String, motivoRecusa: String?) -> ResultadoChamadaDto,
    private val agora: () -> Instant = { Instant.now() },
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoChamadaRecebida(chamadaId = chamadaId))
    val estado: StateFlow<EstadoChamadaRecebida> = _estado.asStateFlow()

    private var carregandoAgora = false

    /** Também serve de "tentar novamente". Duas cargas ao mesmo tempo viram uma. */
    fun carregar(): Job {
        if (carregandoAgora) return escopoDeTrabalho.launch { }
        carregandoAgora = true
        _estado.update { it.copy(carregando = true, erro = null) }
        return escopoDeTrabalho.launch {
            try {
                val detalhe = detalhar(chamadaId)
                _estado.update { it.copy(carregando = false, detalhe = detalhe, mensagemDeConcorrencia = concorrenciaDe(detalhe)) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(carregando = false, erro = mensagemAoCarregar(erro)) }
            } catch (_: Exception) {
                _estado.update { it.copy(carregando = false, erro = TextosChamadaProfissional.ERRO) }
            } finally {
                carregandoAgora = false
            }
        }
    }

    fun abrirRecusa() = _estado.update { if (it.podeResponder) it.copy(mostrarRecusa = true) else it }

    fun fecharRecusa() = _estado.update { it.copy(mostrarRecusa = false) }

    fun escolherMotivo(motivo: String?) = _estado.update { it.copy(motivoSelecionado = motivo) }

    fun aceitar(): Job = responderCom("aceitar", motivo = null)

    fun recusar(): Job = responderCom("recusar", motivo = _estado.value.motivoSelecionado)

    private fun responderCom(resposta: String, motivo: String?): Job {
        val atual = _estado.value
        val detalhe = atual.detalhe
        if (detalhe != null && detalhe.estado == "aberta" && jaExpirou(detalhe)) {
            _estado.update { it.copy(mensagemDeConcorrencia = TextosChamadaProfissional.CHAMADA_EXPIRADA, mostrarRecusa = false) }
            return escopoDeTrabalho.launch { }
        }
        if (!atual.podeResponder) return escopoDeTrabalho.launch { }
        _estado.update { it.copy(respondendo = true, erro = null) }
        return escopoDeTrabalho.launch {
            try {
                val resultado = responder(chamadaId, resposta, motivo)
                _estado.update { tela ->
                    tela.copy(
                        respondendo = false,
                        mostrarRecusa = false,
                        resultado = resultado,
                        detalhe = tela.detalhe?.depoisDeResponder(resultado, motivo),
                    )
                }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { aplicarErroAoResponder(it.copy(respondendo = false, mostrarRecusa = false), erro) }
            } catch (_: Exception) {
                _estado.update { it.copy(respondendo = false, erro = TextosChamadaProfissional.ERRO) }
            }
        }
    }

    private fun jaExpirou(detalhe: ChamadaDetalheDto): Boolean =
        FormatoChamada.instante(detalhe.expiraEm)?.let { !agora().isBefore(it) } == true

    private fun concorrenciaDe(detalhe: ChamadaDetalheDto): String? = when {
        detalhe.estado == "aceita" || detalhe.estado == "encerrada" -> TextosChamadaProfissional.CHAMADA_ENCERRADA
        detalhe.estado == "recusada" -> TextosChamadaProfissional.CHAMADA_RECUSADA
        detalhe.estado == "expirada" || (detalhe.estado == "aberta" && jaExpirou(detalhe)) ->
            TextosChamadaProfissional.CHAMADA_EXPIRADA
        detalhe.estado == "cancelada" -> TextosChamadaProfissional.CHAMADA_CANCELADA
        else -> null
    }

    private fun ChamadaDetalheDto.depoisDeResponder(resultado: ResultadoChamadaDto, motivo: String?): ChamadaDetalheDto =
        copy(
            estado = resultado.chamada.estado,
            motivoRecusa = motivo.takeIf { resultado.chamada.estado == "recusada" },
            respondidaEm = resultado.chamada.respondidaEm,
            local = resultado.local,
            ponto = resultado.ponto,
            responsavelLocal = resultado.responsavelLocal,
            turnoId = resultado.turnoId,
        )

    private fun mensagemAoCarregar(erro: ErroDaApi): String = when {
        erro.recursoDesligado -> TextosChamadaProfissional.DESLIGADO
        erro.codigo == CodigoErroAPI.SEM_REDE -> TextosChamadaProfissional.ERRO
        erro.codigo == CodigoErroAPI.NAO_ENCONTRADO -> TextosChamadaProfissional.INDISPONIVEL
        erro.contaSuspensa -> TextosChamadaProfissional.CONTA_SUSPENSA
        else -> TextosChamadaProfissional.ERRO
    }

    private fun aplicarErroAoResponder(tela: EstadoChamadaRecebida, erro: ErroDaApi): EstadoChamadaRecebida = when {
        erro.codigo == CodigoErroAPI.CHAMADA_INDISPONIVEL || erro.codigo == CodigoErroAPI.POSICAO_JA_PREENCHIDA ||
            erro.codigo == CodigoErroAPI.VAGA_ENCERRADA -> tela.copy(
            mensagemDeConcorrencia = when (erro.detalhes) {
                "expirada" -> TextosChamadaProfissional.CHAMADA_EXPIRADA
                "cancelada" -> TextosChamadaProfissional.CHAMADA_CANCELADA
                else -> TextosChamadaProfissional.CHAMADA_ENCERRADA
            },
        )
        erro.codigo == CodigoErroAPI.INELEGIVEL || erro.codigo == CodigoErroAPI.FUNCAO_INCOMPATIVEL -> tela.copy(
            erro = if (erro.detalhes == "turno_sobreposto") {
                TextosChamadaProfissional.INELEGIVEL_TURNO_SOBREPOSTO
            } else {
                TextosChamadaProfissional.INELEGIVEL_FUNCAO
            },
        )
        erro.recursoDesligado -> tela.copy(erro = TextosChamadaProfissional.DESLIGADO)
        erro.contaSuspensa -> tela.copy(erro = TextosChamadaProfissional.CONTA_SUSPENSA)
        // Bloqueio entre as partes: o servidor devolve 404 e a chamada some do alcance (RF26).
        erro.codigo == CodigoErroAPI.NAO_ENCONTRADO -> tela.copy(erro = TextosChamadaProfissional.INDISPONIVEL)
        else -> tela.copy(erro = TextosChamadaProfissional.ERRO)
    }
}
