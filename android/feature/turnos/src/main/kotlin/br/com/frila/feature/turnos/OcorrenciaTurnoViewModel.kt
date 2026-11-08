package br.com.frila.feature.turnos

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.MotivoOcorrencia
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ServicoTurnos
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * Chamado de ocorrência do turno (RF12/RF23/RN15, UC14): o profissional escolhe um motivo
 * normativo, escreve um relato e opcionalmente anexa uma foto — só o motivo (`categoria`) vai
 * à RPC `abrir_suporte`; o relato e a foto nunca são enviados a nenhuma RPC/armazenamento do
 * Frila, e seguem só pelo e-mail que a tela abre depois do protocolo (fora deste ViewModel).
 *
 * `geradorDeChave`: chave de idempotência enviada a cada tentativa de envio — uma por toque
 * em "Enviar", não reaproveitada entre toques, para que um reenvio depois de erro não colida
 * com um chamado já aberto por outra tentativa concorrente.
 *
 * `escopo`: ver nota em `br.com.frila.feature.entrada.entrada.EntradaViewModel` sobre por que
 * testes injetam um escopo próprio em vez de depender de `viewModelScope`/`Dispatchers.Main`.
 */
class OcorrenciaTurnoViewModel(
    private val turnoId: String,
    private val servicoTurnos: ServicoTurnos,
    private val geradorDeChave: () -> String = { UUID.randomUUID().toString() },
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoOcorrencia())
    val estado: StateFlow<EstadoOcorrencia> = _estado.asStateFlow()

    fun selecionarMotivo(motivo: MotivoOcorrencia) {
        _estado.update { it.copy(motivo = motivo) }
    }

    fun atualizarRelato(relato: String) {
        _estado.update { it.copy(relato = relato) }
    }

    fun anexarFoto(uri: String?) {
        _estado.update { it.copy(anexoUri = uri) }
    }

    /** `null` sem motivo selecionado — o botão de enviar fica desabilitado nesse caso na tela. */
    fun enviar(): Job? {
        val motivo = _estado.value.motivo ?: return null
        _estado.update { it.copy(status = StatusOcorrencia.ENVIANDO, mensagemErro = null) }
        return escopoDeTrabalho.launch {
            try {
                val protocolo = servicoTurnos.abrirSuporte(
                    turnoId = turnoId,
                    categoria = motivo.categoria,
                    chave = geradorDeChave(),
                )
                _estado.update { it.copy(status = StatusOcorrencia.SUCESSO, protocolo = protocolo) }
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(status = StatusOcorrencia.ERRO, mensagemErro = mensagemDeErro(erro)) }
            }
        }
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.LIMITE_EXCEDIDO -> "Limite diário de chamados atingido. Tente de novo amanhã."
        CodigoErroAPI.NAO_ENCONTRADO -> "Não encontramos este turno."
        CodigoErroAPI.SEM_PERMISSAO -> "Você não tem permissão para abrir este chamado."
        CodigoErroAPI.SEM_REDE -> "Sem conexão. Verifique sua internet e tente de novo."
        else -> "Não foi possível abrir o chamado. Tente de novo."
    }
}
