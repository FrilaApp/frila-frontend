package br.com.frila.feature.vagas.painel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.VagaPublicadaDto
import java.util.UUID
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class EstadoRepublicarPosicoesRestantes(
    val posicoesRestantes: Int,
    val carregando: Boolean = false,
    val erro: String? = null,
    /** A vaga nova de urgência, quando a republicação deu certo. */
    val vagaPublicadaId: String? = null,
)

/**
 * Republicar em urgência as posições que a seleção deixou vazias (`republicar_posicoes_restantes`, D1-C; paridade com
 * o `RepublicarPosicoesRestantesViewModel` do iOS). O servidor decide modo, horário, valor e quantidade. A chave de
 * idempotência nasce no primeiro toque e só troca depois do sucesso: repetir depois de uma falha devolve a mesma vaga.
 *
 * [republicar] é `ServicoVagas.republicarPosicoesRestantes`. [aoRepublicar] recebe o id da vaga nova;
 * [aoMudarOPainel] avisa que a lista de vagas precisa ser relida (deu certo, ou o servidor disse que o atalho já não
 * vale). `escopo`: mesma razão do `MinhasVagasViewModel`.
 */
class RepublicarPosicoesRestantesViewModel(
    val vagaId: String,
    posicoesRestantes: Int,
    private val republicar: suspend (vagaId: String, chave: String) -> VagaPublicadaDto,
    private val aoRepublicar: (novaVagaId: String) -> Unit = {},
    private val aoMudarOPainel: () -> Unit = {},
    private val novaChave: () -> String = { UUID.randomUUID().toString() },
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoRepublicarPosicoesRestantes(posicoesRestantes))
    val estado: StateFlow<EstadoRepublicarPosicoesRestantes> = _estado.asStateFlow()

    private var chave: String? = null

    /** Republica. `null` se já há um envio em voo ou se já deu certo. */
    fun executar(): Job? {
        val atual = _estado.value
        if (atual.carregando || atual.vagaPublicadaId != null) return null
        val chaveDoEnvio = chave ?: novaChave().also { chave = it }
        _estado.update { it.copy(carregando = true, erro = null) }
        return escopoDeTrabalho.launch {
            try {
                val publicada = republicar(vagaId, chaveDoEnvio)
                chave = null
                _estado.update { it.copy(carregando = false, vagaPublicadaId = publicada.vagaId) }
                aoMudarOPainel()
                aoRepublicar(publicada.vagaId)
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
                _estado.update { it.copy(carregando = false, erro = mensagemDaFalha(erro)) }
                if ((erro as? ErroDaApi)?.codigo == CodigoErroAPI.REPUBLICACAO_INDISPONIVEL) aoMudarOPainel()
            }
        }
    }

    private fun mensagemDaFalha(erro: Exception): String {
        val daApi = erro as? ErroDaApi ?: return TextosRepublicarPosicoesRestantes.ERRO_GENERICO
        return when (daApi.codigo) {
            CodigoErroAPI.REPUBLICACAO_INDISPONIVEL -> when (daApi.detalhesComoCodigo) {
                CodigoErroAPI.JA_REPUBLICADA -> TextosRepublicarPosicoesRestantes.JA_REPUBLICADA
                CodigoErroAPI.SEM_POSICOES_RESTANTES -> TextosRepublicarPosicoesRestantes.SEM_POSICOES_RESTANTES
                CodigoErroAPI.SELECAO_EM_CURSO -> TextosRepublicarPosicoesRestantes.SELECAO_EM_CURSO
                CodigoErroAPI.JA_COMECOU -> TextosRepublicarPosicoesRestantes.JA_COMECOU
                CodigoErroAPI.VAGA_CANCELADA -> TextosRepublicarPosicoesRestantes.VAGA_CANCELADA
                CodigoErroAPI.NAO_E_SELECAO -> TextosRepublicarPosicoesRestantes.NAO_E_SELECAO
                else -> TextosRepublicarPosicoesRestantes.INDISPONIVEL
            }
            CodigoErroAPI.VAGA_OCULTA -> TextosRepublicarPosicoesRestantes.VAGA_OCULTA
            CodigoErroAPI.SEM_PERMISSAO ->
                if (daApi.detalhes == "conta_suspensa") TextosRepublicarPosicoesRestantes.CONTA_SUSPENSA else TextosRepublicarPosicoesRestantes.SEM_PERMISSAO
            CodigoErroAPI.CONTA_SUSPENSA -> TextosRepublicarPosicoesRestantes.CONTA_SUSPENSA
            CodigoErroAPI.NAO_ENCONTRADO -> TextosRepublicarPosicoesRestantes.NAO_ENCONTRADO
            CodigoErroAPI.PERFIL_INCOMPATIVEL -> TextosRepublicarPosicoesRestantes.PERFIL_INCOMPATIVEL
            CodigoErroAPI.SEM_REDE -> TextosRepublicarPosicoesRestantes.SEM_REDE
            CodigoErroAPI.NAO_AUTENTICADO -> TextosRepublicarPosicoesRestantes.SESSAO_EXPIRADA
            else -> TextosRepublicarPosicoesRestantes.ERRO_GENERICO
        }
    }
}
