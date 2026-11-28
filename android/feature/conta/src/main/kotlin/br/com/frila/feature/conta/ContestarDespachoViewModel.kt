package br.com.frila.feature.conta

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ProtocoloDto
import java.time.ZoneId
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class EstadoContestarDespacho(
    val relato: String = "",
    val enviando: Boolean = false,
    /** O pedido que acabou de ser aceito. */
    val protocolo: ProtocoloExibido? = null,
    /** O servidor disse que já há contestação deste despacho (`409`): pelo app não há outra. */
    val contestacaoJaAberta: Boolean = false,
    val mensagemErro: String? = null,
) {
    val relatoValido: Boolean get() = caracteresDoRelato(relato) >= MINIMO_DO_RELATO

    /** Enviado ou recusado por `409`, o app não oferece outro pedido (0.2.37). */
    val podeContestar: Boolean get() = protocolo == null && !contestacaoJaAberta && !enviando
}

/**
 * Contestar o despacho (`pedir_revisao_despacho`, RF27): o "Contestar" de "Por que recebo vagas". Paridade com a
 * parte de contestação do `PorQueReceboVagasViewModel` do iOS. A Equipe Frila responde por e-mail em até 5 dias
 * úteis; o app guarda só o protocolo. A leitura dos critérios (`criterios_de_notificacao`) é de outro item do lote.
 *
 * [pedirRevisao] é `ServicoConta.pedirRevisaoDespacho`. `escopo`: mesma razão do `ExclusaoDeContaViewModel`.
 */
class ContestarDespachoViewModel(
    private val pedirRevisao: suspend (relato: String) -> ProtocoloDto,
    private val zona: ZoneId = FUSO_DA_CONTA,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoContestarDespacho())
    val estado: StateFlow<EstadoContestarDespacho> = _estado.asStateFlow()

    fun mudarRelato(texto: String) = _estado.update { it.copy(relato = texto, mensagemErro = null) }

    /** Envia o pedido. `null` se o relato não serve (a tela diz por quê) ou se não há mais o que pedir. */
    fun contestar(): Job? {
        val atual = _estado.value
        val relato = atual.relato.trim()
        val recusaLocal = when {
            relato.isEmpty() -> TextosContestarDespacho.RELATO_OBRIGATORIO
            caracteresDoRelato(relato) < MINIMO_DO_RELATO -> TextosContestarDespacho.RELATO_MINIMO
            else -> null
        }
        if (recusaLocal != null) {
            _estado.update { it.copy(mensagemErro = recusaLocal) }
            return null
        }
        if (!atual.podeContestar) return null
        _estado.update { it.copy(enviando = true, mensagemErro = null) }
        return escopoDeTrabalho.launch {
            try {
                val protocolo = pedirRevisao(relato).paraExibicao(zona)
                _estado.update { it.copy(enviando = false, protocolo = protocolo) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
                _estado.update { recusa(it, erro) }
            }
        }
    }

    private fun recusa(estado: EstadoContestarDespacho, erro: Exception): EstadoContestarDespacho {
        val daApi = erro as? ErroDaApi
        if (daApi?.codigo == CodigoErroAPI.CONTESTACAO_JA_ABERTA) return estado.copy(enviando = false, contestacaoJaAberta = true)
        val suspensa = daApi?.codigo == CodigoErroAPI.CONTA_SUSPENSA ||
            (daApi?.codigo == CodigoErroAPI.SEM_PERMISSAO && daApi.detalhes == "conta_suspensa")
        val mensagem = when {
            suspensa -> TextosContestarDespacho.CONTA_SUSPENSA
            daApi?.codigo == CodigoErroAPI.CAMPO_OBRIGATORIO -> TextosContestarDespacho.RELATO_OBRIGATORIO
            daApi?.codigo == CodigoErroAPI.CAMPO_INVALIDO -> TextosContestarDespacho.RELATO_MINIMO
            daApi?.codigo == CodigoErroAPI.LIMITE_EXCEDIDO -> TextosContestarDespacho.LIMITE_EXCEDIDO
            daApi?.codigo == CodigoErroAPI.SEM_REDE -> TextosContestarDespacho.ERRO_SEM_REDE
            daApi?.codigo == CodigoErroAPI.NAO_AUTENTICADO -> TextosContestarDespacho.ERRO_SESSAO
            else -> TextosContestarDespacho.ERRO_ENVIAR
        }
        return estado.copy(enviando = false, mensagemErro = mensagem)
    }
}
