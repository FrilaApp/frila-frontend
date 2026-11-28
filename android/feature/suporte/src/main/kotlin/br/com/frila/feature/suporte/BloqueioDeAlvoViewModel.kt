package br.com.frila.feature.suporte

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.BloqueiosDaSessao
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.BloqueioDto
import br.com.frila.core.rede.ErroDaApi
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class EstadoBloqueioDeAlvo(
    val dialogoAberto: Boolean = false,
    val bloqueando: Boolean = false,
    val bloqueado: Boolean = false,
    val erro: String? = null,
)

/**
 * O bloqueio avulso de outra parte (RF26, CD-RF12), para as telas que oferecem "Bloquear" sem passar pela denúncia: a chamada
 * recebida e o perfil público. O par [alvoTipo] + [alvoId] é o `id` do `PerfilPublico` como chegou à tela (RN10).
 * `escopo`: mesma razão do `DenunciaViewModel`.
 */
class BloqueioDeAlvoViewModel(
    private val alvoTipo: TipoDeAlvo,
    private val alvoId: String,
    private val bloquear: suspend (alvoTipo: String, alvoId: String) -> BloqueioDto,
    /** O que a sessão já bloqueou (I1PonzKJ): a tela abre sabendo se este alvo já foi bloqueado. `null` ignora. */
    private val bloqueios: BloqueiosDaSessao? = null,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoBloqueioDeAlvo(bloqueado = bloqueios?.contem(alvoTipo, alvoId) == true))
    val estado: StateFlow<EstadoBloqueioDeAlvo> = _estado.asStateFlow()

    fun abrirDialogo() {
        _estado.update {
            if (it.bloqueado || it.bloqueando) it else it.copy(dialogoAberto = true, erro = null)
        }
    }

    fun cancelar() {
        _estado.update { it.copy(dialogoAberto = false) }
    }

    /** Idempotente no servidor; aqui, sem segundo pedido se já bloqueou ou se há um em curso. */
    fun confirmar(): Job {
        val atual = _estado.value
        if (atual.bloqueado || atual.bloqueando) return escopoDeTrabalho.launch { }
        _estado.update { it.copy(dialogoAberto = false, bloqueando = true, erro = null) }
        return escopoDeTrabalho.launch {
            try {
                bloquear(alvoTipo.chave, alvoId)
                _estado.update { it.copy(bloqueando = false, bloqueado = true) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(bloqueando = false, erro = mensagemDeErro(erro)) }
            } catch (_: Exception) {
                _estado.update { it.copy(bloqueando = false, erro = TextosSuporte.ERRO_GENERICO) }
            }
        }
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.SEM_REDE -> TextosSuporte.ERRO_SEM_REDE
        CodigoErroAPI.NAO_ENCONTRADO -> TextosSuporte.INDISPONIVEL
        else -> TextosSuporte.ERRO_GENERICO
    }
}
