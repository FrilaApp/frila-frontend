package br.com.frila.feature.suporte

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.BloqueioDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ItemBloqueioDto
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** O que a lista mostra. `Erro` carrega a mensagem já mapeada: a tela não decide texto. */
sealed interface EstadoBloqueios {
    data object Carregando : EstadoBloqueios
    data object Vazio : EstadoBloqueios
    data class Conteudo(val itens: List<ItemBloqueioDto>) : EstadoBloqueios
    data object SemRede : EstadoBloqueios
    data class Erro(val mensagem: String) : EstadoBloqueios
}

data class EstadoTelaBloqueios(
    val estado: EstadoBloqueios = EstadoBloqueios.Carregando,
    /** A chave ([chaveDoBloqueio]) do item cujo desbloqueio está em voo. */
    val desbloqueando: String? = null,
    val mensagemErro: String? = null,
    /** CLD9Yg3e: uma recarga em curso com a lista na tela (o indicador do puxar para atualizar). A carga de abertura não conta. */
    val atualizando: Boolean = false,
)

/** O par (tipo, id) é o que identifica um bloqueio; o id sozinho pode se repetir entre profissional e estabelecimento. */
fun chaveDoBloqueio(item: ItemBloqueioDto): String = "${item.alvoTipo}:${item.alvoId}"

/**
 * "Pessoas e locais bloqueados" (RF26, decisão A8; paridade com `BloqueiosViewModel.swift`): lista os bloqueios que a
 * pessoa criou e desfaz um por vez. O servidor decide: cada recusa (conta suspensa, sem rede) vira uma mensagem própria,
 * e nenhuma falha deixa a tela em "carregando" ou "desbloqueando". Uma recarga que falha com a lista na tela mantém a lista.
 *
 * [listar] e [desfazer] são as chamadas de `ServicoConfianca`. `escopo`: mesma razão do `EquipeDeConfiancaViewModel`.
 */
class BloqueiosViewModel(
    private val listar: suspend () -> List<ItemBloqueioDto>,
    private val desfazer: suspend (alvoTipo: String, alvoId: String) -> BloqueioDto,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoTelaBloqueios())
    val estado: StateFlow<EstadoTelaBloqueios> = _estado.asStateFlow()

    private var carregando = false

    /** Também serve de "tentar novamente". Duas cargas ao mesmo tempo viram uma. */
    fun carregar(): Job {
        if (carregando) return escopoDeTrabalho.launch { }
        carregando = true
        val itensAtuais = (_estado.value.estado as? EstadoBloqueios.Conteudo)?.itens.orEmpty()
        _estado.update {
            it.copy(
                estado = if (itensAtuais.isEmpty()) EstadoBloqueios.Carregando else it.estado,
                mensagemErro = null,
                // Com a lista na tela é uma atualização (o indicador do puxar); sem ela, o próprio "Carregando" aparece.
                atualizando = itensAtuais.isNotEmpty(),
            )
        }
        return escopoDeTrabalho.launch {
            try {
                val itens = listar()
                _estado.update { it.copy(estado = if (itens.isEmpty()) EstadoBloqueios.Vazio else EstadoBloqueios.Conteudo(itens)) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                falhouAoCarregar(itensAtuais, erro)
            } catch (_: Exception) {
                // Corpo não-JSON de gateway ou campo ausente escapam do ErroDaApi; sem isto a tela ficaria em "Carregando".
                falhouAoCarregar(itensAtuais, null)
            } finally {
                carregando = false
                _estado.update { it.copy(atualizando = false) }
            }
        }
    }

    /**
     * Puxar para atualizar (iOS `.refreshable`). Sem efeito com um desbloqueio em voo: a lista lida antes dele traria de volta quem acabou
     * de sair. O contrário vale em [desbloquear]: sem desbloqueio durante a recarga, pelo mesmo motivo.
     */
    fun atualizar(): Job {
        if (_estado.value.desbloqueando != null) return escopoDeTrabalho.launch { }
        return carregar()
    }

    /** Sem efeito com outro desbloqueio em voo, com a lista sendo atualizada ou fora da lista: o segundo toque não dispara outro pedido. */
    fun desbloquear(item: ItemBloqueioDto): Job {
        val atual = _estado.value
        if (atual.desbloqueando != null || atual.atualizando || atual.estado !is EstadoBloqueios.Conteudo) return escopoDeTrabalho.launch { }
        val chave = chaveDoBloqueio(item)
        _estado.update { it.copy(desbloqueando = chave, mensagemErro = null) }
        return escopoDeTrabalho.launch {
            try {
                desfazer(item.alvoTipo, item.alvoId)
                _estado.update { tela ->
                    val restantes = (tela.estado as? EstadoBloqueios.Conteudo)?.itens.orEmpty().filter { chaveDoBloqueio(it) != chave }
                    tela.copy(
                        desbloqueando = null,
                        estado = if (restantes.isEmpty()) EstadoBloqueios.Vazio else EstadoBloqueios.Conteudo(restantes),
                    )
                }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(desbloqueando = null, mensagemErro = mensagemAoDesbloquear(erro)) }
            } catch (_: Exception) {
                _estado.update { it.copy(desbloqueando = null, mensagemErro = TextosBloqueios.ERRO_DESBLOQUEAR) }
            }
        }
    }

    private fun falhouAoCarregar(itensAtuais: List<ItemBloqueioDto>, erro: ErroDaApi?) {
        val mensagem = when {
            erro?.codigo == CodigoErroAPI.SEM_REDE -> TextosBloqueios.SEM_REDE
            erro != null && ehContaSuspensa(erro) -> TextosBloqueios.CONTA_SUSPENSA
            else -> TextosBloqueios.ERRO_CARREGAR
        }
        _estado.update {
            when {
                itensAtuais.isNotEmpty() -> it.copy(mensagemErro = mensagem)
                erro?.codigo == CodigoErroAPI.SEM_REDE -> it.copy(estado = EstadoBloqueios.SemRede)
                else -> it.copy(estado = EstadoBloqueios.Erro(mensagem))
            }
        }
    }

    /** `desbloquear`: `403 conta_suspensa` e sem rede têm texto próprio; `404` e `422` ficam no genérico, sem o corpo cru (RN15). */
    private fun mensagemAoDesbloquear(erro: ErroDaApi): String = when {
        erro.codigo == CodigoErroAPI.SEM_REDE -> TextosBloqueios.SEM_REDE
        ehContaSuspensa(erro) -> TextosBloqueios.CONTA_SUSPENSA
        else -> TextosBloqueios.ERRO_DESBLOQUEAR
    }

    private fun ehContaSuspensa(erro: ErroDaApi): Boolean =
        erro.codigo == CodigoErroAPI.CONTA_SUSPENSA ||
            (erro.codigo == CodigoErroAPI.SEM_PERMISSAO && erro.detalhes == "conta_suspensa")
}
