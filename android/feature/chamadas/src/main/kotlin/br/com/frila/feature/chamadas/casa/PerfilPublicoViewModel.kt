package br.com.frila.feature.chamadas.casa

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.PerfilPublicoDto
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout

sealed interface EstadoPerfilPublico {
    data object Carregando : EstadoPerfilPublico
    data class Carregado(val perfil: PerfilPublicoDto) : EstadoPerfilPublico

    /** Bloqueio entre as partes ou id inexistente: o servidor responde `404 nao_encontrado` (RN15). */
    data object Indisponivel : EstadoPerfilPublico
    data class Falha(val mensagem: String) : EstadoPerfilPublico
}

/**
 * Perfil público de um profissional ou estabelecimento (paridade com `PerfilPublicoViewModel` do iOS): serviços
 * com preço, regiões, reputação e apresentação. `nome` já chega só com o primeiro nome e a inicial para a casa
 * sem candidatura, turno ou equipe com o profissional (0.2.88); o ViewModel não reescreve o nome.
 *
 * [buscar] é `ServicoChamadaDireta.perfilPublico`. Todo carregamento tem prazo e nenhuma falha deixa a tela
 * em "Carregando".
 */
class PerfilPublicoViewModel(
    private val id: String,
    private val buscar: suspend (id: String) -> PerfilPublicoDto,
    private val prazoMs: Long = ChamadaDiretaViewModel.PRAZO_PADRAO_MS,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow<EstadoPerfilPublico>(EstadoPerfilPublico.Carregando)
    val estado: StateFlow<EstadoPerfilPublico> = _estado.asStateFlow()

    private var carregando = false

    /** Também serve de "tentar novamente". Duas cargas ao mesmo tempo viram uma. */
    fun carregar(): Job {
        if (carregando) return escopoDeTrabalho.launch { }
        carregando = true
        _estado.value = EstadoPerfilPublico.Carregando
        return escopoDeTrabalho.launch {
            try {
                val perfil = withTimeout(prazoMs) { buscar(id) }
                _estado.value = EstadoPerfilPublico.Carregado(perfil)
            } catch (erro: TimeoutCancellationException) {
                _estado.value = EstadoPerfilPublico.Falha(TextosChamadaCasa.ERRO_GENERICO)
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.value = when (erro.codigo) {
                    CodigoErroAPI.NAO_ENCONTRADO -> EstadoPerfilPublico.Indisponivel
                    CodigoErroAPI.SEM_REDE -> EstadoPerfilPublico.Falha(TextosChamadaCasa.SEM_REDE)
                    else -> EstadoPerfilPublico.Falha(TextosChamadaCasa.ERRO_GENERICO)
                }
            } catch (_: Exception) {
                _estado.value = EstadoPerfilPublico.Falha(TextosChamadaCasa.ERRO_GENERICO)
            } finally {
                carregando = false
            }
        }
    }
}
