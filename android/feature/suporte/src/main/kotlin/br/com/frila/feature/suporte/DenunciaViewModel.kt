package br.com.frila.feature.suporte

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.MotivoDenuncia
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.BloqueioDto
import br.com.frila.core.rede.DenunciarDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ProtocoloDto
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.UUID
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** O relato mínimo vale no contrato: `relato` com menos de 10 caracteres recebe `422 campo_invalido`. */
const val RELATO_MINIMO_CARACTERES = 10

data class EstadoDenuncia(
    val motivo: MotivoDenuncia = MotivoDenuncia.ASSEDIO,
    val relato: String = "",
    val enviando: Boolean = false,
    val protocolo: ProtocoloDto? = null,
    val erroDenuncia: String? = null,
    val dialogoBloqueioAberto: Boolean = false,
    val bloqueando: Boolean = false,
    val bloqueado: Boolean = false,
    val erroBloqueio: String? = null,
) {
    val relatoValido: Boolean get() = relato.trim().length >= RELATO_MINIMO_CARACTERES
    val podeEnviar: Boolean get() = relatoValido && !enviando && protocolo == null
}

/**
 * Denúncia e bloqueio de outra parte (RF26, UC17). O par [alvoTipo] + [alvoId] é o `id` do
 * `PerfilPublico` como chegou à tela, nunca o id de conta (RN10). [turnoId] e [chamadaId] são
 * opcionais e só associam a denúncia a um turno ou a uma chamada direta (contrato 0.2.71: a
 * chamada precisa envolver as duas partes, senão `422 campo_invalido` com `details: chamada_id`).
 *
 * A `chave` de idempotência é gerada uma vez por conteúdo: repetir o envio depois de perder a
 * resposta reutiliza a chave e não abre uma segunda ocorrência; editar motivo ou relato inicia
 * outra denúncia, e uma chave nunca serve a dois corpos diferentes.
 *
 * `escopo`: mesma razão do `PerfilViewModel` (teste injeta um escopo próprio).
 */
class DenunciaViewModel(
    private val alvoTipo: TipoDeAlvo,
    private val alvoId: String,
    private val denunciar: suspend (DenunciarDto) -> ProtocoloDto,
    private val bloquear: suspend (alvoTipo: String, alvoId: String) -> BloqueioDto,
    private val turnoId: String? = null,
    private val chamadaId: String? = null,
    private val gerarChave: () -> String = { UUID.randomUUID().toString() },
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoDenuncia())
    val estado: StateFlow<EstadoDenuncia> = _estado.asStateFlow()

    /** Corpo e chave do último envio; a chave só é reaproveitada se o corpo for o mesmo. */
    private var tentativa: DenunciarDto? = null

    val associadaAoTurno: Boolean get() = turnoId != null
    val associadaAChamada: Boolean get() = chamadaId != null

    fun escolherMotivo(motivo: MotivoDenuncia) {
        _estado.update { if (it.enviando || it.protocolo != null) it else it.copy(motivo = motivo) }
    }

    fun editarRelato(relato: String) {
        _estado.update {
            if (it.enviando || it.protocolo != null) it else it.copy(relato = relato, erroDenuncia = null)
        }
    }

    fun enviarDenuncia(): Job {
        val atual = _estado.value
        if (atual.enviando || atual.protocolo != null) return escopoDeTrabalho.launch { }
        if (!atual.relatoValido) {
            _estado.update { it.copy(erroDenuncia = TextosSuporte.RELATO_MINIMO) }
            return escopoDeTrabalho.launch { }
        }
        val corpo = corpoDe(atual)
        _estado.update { it.copy(enviando = true, erroDenuncia = null) }
        return escopoDeTrabalho.launch {
            try {
                val protocolo = denunciar(corpo)
                _estado.update { it.copy(enviando = false, protocolo = protocolo) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(enviando = false, erroDenuncia = mensagemDeErro(erro)) }
            } catch (_: Exception) {
                // Corpo não-JSON de gateway escapa do ErroDaApi; sem isto a tela ficaria em
                // "Enviando…" para sempre. A mensagem nunca carrega o corpo cru (RN15).
                _estado.update { it.copy(enviando = false, erroDenuncia = TextosSuporte.ERRO_GENERICO) }
            }
        }
    }

    private fun corpoDe(atual: EstadoDenuncia): DenunciarDto {
        val relato = atual.relato.trim()
        val anterior = tentativa
        val chave = if (anterior != null && anterior.motivo == atual.motivo.chave && anterior.relato == relato) {
            anterior.chave
        } else {
            gerarChave()
        }
        return DenunciarDto(
            alvoTipo = alvoTipo.chave,
            alvoId = alvoId,
            turnoId = turnoId,
            motivo = atual.motivo.chave,
            relato = relato,
            chave = chave,
            chamadaId = chamadaId,
        ).also { tentativa = it }
    }

    fun abrirDialogoBloqueio() {
        _estado.update {
            if (it.bloqueado || it.bloqueando) it else it.copy(dialogoBloqueioAberto = true, erroBloqueio = null)
        }
    }

    fun cancelarBloqueio() {
        _estado.update { it.copy(dialogoBloqueioAberto = false) }
    }

    /** Idempotente no servidor; aqui, sem segundo pedido se já bloqueou ou se há um em curso. */
    fun confirmarBloqueio(): Job {
        val atual = _estado.value
        if (atual.bloqueado || atual.bloqueando) return escopoDeTrabalho.launch { }
        _estado.update { it.copy(dialogoBloqueioAberto = false, bloqueando = true, erroBloqueio = null) }
        return escopoDeTrabalho.launch {
            try {
                bloquear(alvoTipo.chave, alvoId)
                _estado.update { it.copy(bloqueando = false, bloqueado = true) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(bloqueando = false, erroBloqueio = mensagemDeErro(erro)) }
            } catch (_: Exception) {
                _estado.update { it.copy(bloqueando = false, erroBloqueio = TextosSuporte.ERRO_GENERICO) }
            }
        }
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.SEM_REDE -> TextosSuporte.ERRO_SEM_REDE
        CodigoErroAPI.CAMPO_OBRIGATORIO, CodigoErroAPI.CAMPO_INVALIDO ->
            if (erro.detalhes == "relato") TextosSuporte.RELATO_MINIMO else TextosSuporte.ERRO_DADOS
        CodigoErroAPI.NAO_ENCONTRADO -> TextosSuporte.INDISPONIVEL
        else -> TextosSuporte.ERRO_GENERICO
    }
}

/** Protocolo curto (contrato `Protocolo`): 8 primeiros hexadecimais de `ocorrencia_id`, sem hifens, em maiúsculas. */
val ProtocoloDto.protocoloCurto: String
    get() = ocorrenciaId.replace("-", "").take(8).uppercase()

/** `prazo_resposta_ate` chega como data (`2026-11-17`); mostra `17/11/2026` e cai no texto cru se vier outro formato. */
fun formatarPrazo(prazo: String): String =
    runCatching { LocalDate.parse(prazo.take(10)).format(DateTimeFormatter.ofPattern("dd/MM/yyyy")) }
        .getOrDefault(prazo)
