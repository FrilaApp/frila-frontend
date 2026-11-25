package br.com.frila.feature.equipe.casa

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.PapelMembro
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.MembroAdicionadoDto
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Só o código: 64 caracteres hexadecimais, nada mais. */
private val SO_O_CODIGO = Regex("^[0-9a-fA-F]{64}$")

/** O link do convite inteiro: `https://<web>/.../convite#<64 hex>`, e nada depois do código. */
private val LINK_DO_CONVITE = Regex("^https://[^\\s/#?]+(?:/[^\\s#?]*)?/convite#([0-9a-fA-F]{64})$")

/**
 * Tira o token do que a pessoa colou. Vale **só** (a) o link do convite inteiro, `.../convite#<token>`, ou (b) só o
 * código de 64 hex, depois de aparar os espaços das pontas. Qualquer outra coisa devolve `null` e não chega ao servidor:
 * texto com mais caracteres em volta, código no miolo de um identificador maior, hex de outro tamanho e mais de um código
 * (o app nunca escolhe um em silêncio). O token sai em minúsculas, como a web.
 */
fun extrairTokenDoConvite(texto: String): String? {
    val colado = texto.trim()
    if (SO_O_CODIGO.matches(colado)) return colado.lowercase()
    return LINK_DO_CONVITE.matchEntire(colado)?.groupValues?.get(1)?.lowercase()
}

data class EstadoTenhoUmConvite(
    val texto: String = "",
    val enviando: Boolean = false,
    /** A recusa em texto do Frila, junto ao botão. */
    val erro: String? = null,
    val aceito: ConviteAceito? = null,
)

/** A casa em que a pessoa entrou e com que papel (o servidor responde os dois; ambos podem faltar). */
data class ConviteAceito(val estabelecimentoId: String?, val papel: PapelMembro?)

/**
 * "Tenho um convite" (RF21; o app não abre o link sozinho, sem deep link): a pessoa cola o link ou o código e o app tira
 * o token e chama `aceitar_convite_membro` ([aceitar]). Texto sem token não chega à rede: vira a mesma mensagem de
 * convite inválido. Cada recusa do servidor (`convite_invalido`, `perfil_incompativel`, sessão, sem rede) vira texto do Frila.
 * Um convite é de uso único: depois de uma falha incerta (sem rede), repetir pode dar `convite_invalido` se o primeiro
 * já tiver sido aceito, e por isso a mensagem de falha incerta avisa onde conferir.
 */
class TenhoUmConviteViewModel(
    private val aceitar: suspend (token: String) -> MembroAdicionadoDto,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoTenhoUmConvite())
    val estado: StateFlow<EstadoTenhoUmConvite> = _estado.asStateFlow()

    fun editar(texto: String) {
        _estado.update { if (it.enviando || it.aceito != null) it else it.copy(texto = texto, erro = null) }
    }

    fun aceitarConvite(): Job {
        val atual = _estado.value
        if (atual.enviando || atual.aceito != null) return escopoDeTrabalho.launch { }
        val token = extrairTokenDoConvite(atual.texto)
        if (token == null) {
            _estado.update { it.copy(erro = TextosEquipeDaCasa.CONVITE_INVALIDO) }
            return escopoDeTrabalho.launch { }
        }
        _estado.update { it.copy(enviando = true, erro = null) }
        return escopoDeTrabalho.launch {
            try {
                val membro = aceitar(token)
                _estado.update {
                    it.copy(enviando = false, texto = "", aceito = ConviteAceito(membro.estabelecimentoId, PapelMembro.deChave(membro.papel)))
                }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(enviando = false, erro = mensagemDeErro(erro)) }
            } catch (_: Exception) {
                _estado.update { it.copy(enviando = false, erro = TextosEquipeDaCasa.CONVITE_INCERTO) }
            }
        }
    }

    private fun mensagemDeErro(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.CONVITE_INVALIDO -> TextosEquipeDaCasa.CONVITE_INVALIDO
        CodigoErroAPI.CONVITE_DE_OUTRO_EMAIL -> TextosEquipeDaCasa.CONVITE_DE_OUTRO_EMAIL
        CodigoErroAPI.PERFIL_INCOMPATIVEL -> TextosEquipeDaCasa.CONVITE_PERFIL_INCOMPATIVEL
        CodigoErroAPI.NAO_AUTENTICADO -> TextosEquipeDaCasa.SESSAO
        CodigoErroAPI.SEM_REDE -> TextosEquipeDaCasa.SEM_REDE
        CodigoErroAPI.CONTA_SUSPENSA -> TextosEquipeDaCasa.CONTA_SUSPENSA
        CodigoErroAPI.SEM_PERMISSAO ->
            if (erro.detalhes == "conta_suspensa") TextosEquipeDaCasa.CONTA_SUSPENSA else TextosEquipeDaCasa.CONVITE_INCERTO
        else -> TextosEquipeDaCasa.CONVITE_INCERTO
    }
}
