package br.com.frila.feature.vagas.detalhe

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.core.rede.VagaDto
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/** Textos de abrir uma vaga pelo id (link ou aviso). */
object TextosAberturaDeVaga {
    const val CARREGANDO = "Carregando a vaga."
    const val ERRO_TITULO = "Não foi possível abrir a vaga."
    const val TENTAR_DE_NOVO = "Tentar de novo"
    const val ERRO_GENERICO = "Não foi possível carregar a vaga. Tente novamente."
    const val SEM_REDE = "Sem conexão. Tente novamente quando a internet voltar."
    const val SESSAO_EXPIRADA = "Sua sessão expirou. Entre novamente para continuar."
    const val CONTA_NAO_PODE = "Sua conta não pode realizar esta ação."
    const val DETALHES = "Mais sobre a vaga"
    const val POSICOES_ABERTAS = "Posições abertas"
    const val POSICOES_DE = "%d de %d"
    const val RESPONSAVEL_NO_LOCAL = "Responsável no local"
    const val RATEIO = "Rateio dos 10%"
    const val SIM = "Sim"
    const val NAO = "Não"
    const val TRAJE = "Traje"
    const val OBSERVACOES = "Observações"
}

sealed interface EstadoAberturaDeVaga {
    data object Carregando : EstadoAberturaDeVaga

    /** A vaga aceita candidatura: `publicada` e com posição aberta, como o servidor diz (nunca pelo relógio do aparelho). */
    data class Aberta(val vaga: VagaDto) : EstadoAberturaDeVaga

    /** Não dá mais para pegar: preenchida, encerrada, cancelada ou não encontrada (`404`). */
    data class Indisponivel(
        val motivo: MotivoIndisponibilidadeVaga,
        val modo: ModoPreenchimentoVaga? = null,
        val vagaCancelada: Boolean = false,
    ) : EstadoAberturaDeVaga

    data class Falha(val mensagem: String, val podeTentarDeNovo: Boolean) : EstadoAberturaDeVaga
}

/**
 * Abre uma vaga só com o id, lendo `detalhe_vaga` do servidor (UC03): é o caminho do link `frila://` e do toque num
 * aviso, quando a vaga não está na lista já carregada. Paridade com `DetalheVagaViewModel` e
 * `IndisponibilidadeDaVaga` do iOS: `404` é vaga não encontrada, e só há candidatura com `publicada` e posição aberta.
 *
 * [buscarDetalhe] é `ServicoVagas.detalheVaga`. `escopo`: ver nota em `DetalheVagaViewModel`.
 */
class AberturaDeVagaViewModel(
    val vagaId: String,
    private val buscarDetalhe: suspend (vagaId: String) -> VagaDto,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow<EstadoAberturaDeVaga>(EstadoAberturaDeVaga.Carregando)
    val estado: StateFlow<EstadoAberturaDeVaga> = _estado.asStateFlow()

    private var leitura: Job? = null

    /** Primeira leitura e "Tentar de novo". Sem efeito se já há uma leitura em voo. */
    fun carregar(): Job {
        leitura?.takeIf { it.isActive }?.let { return it }
        _estado.value = EstadoAberturaDeVaga.Carregando
        return escopoDeTrabalho.launch {
            _estado.value = try {
                situacaoDa(buscarDetalhe(vagaId))
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
                falhaDe(erro)
            }
        }.also { leitura = it }
    }

    private fun situacaoDa(vaga: VagaDto): EstadoAberturaDeVaga {
        if (vaga.estado == ESTADO_PUBLICADA && vaga.posicoesAbertas > 0) return EstadoAberturaDeVaga.Aberta(vaga)
        return EstadoAberturaDeVaga.Indisponivel(
            motivo = if (vaga.estado == ESTADO_PREENCHIDA) MotivoIndisponibilidadeVaga.PREENCHIDA else MotivoIndisponibilidadeVaga.ENCERRADA,
            modo = if (vaga.modo == MODO_SELECAO) ModoPreenchimentoVaga.SELECAO else ModoPreenchimentoVaga.URGENCIA,
            vagaCancelada = vaga.estado == ESTADO_CANCELADA,
        )
    }

    private fun falhaDe(erro: Exception): EstadoAberturaDeVaga = when ((erro as? ErroDaApi)?.codigo) {
        CodigoErroAPI.NAO_ENCONTRADO -> EstadoAberturaDeVaga.Indisponivel(MotivoIndisponibilidadeVaga.NAO_ENCONTRADA)
        CodigoErroAPI.SEM_REDE -> EstadoAberturaDeVaga.Falha(TextosAberturaDeVaga.SEM_REDE, podeTentarDeNovo = true)
        CodigoErroAPI.NAO_AUTENTICADO -> EstadoAberturaDeVaga.Falha(TextosAberturaDeVaga.SESSAO_EXPIRADA, podeTentarDeNovo = false)
        CodigoErroAPI.PERFIL_INCOMPATIVEL, CodigoErroAPI.SEM_PERMISSAO, CodigoErroAPI.CONTA_SUSPENSA ->
            EstadoAberturaDeVaga.Falha(TextosAberturaDeVaga.CONTA_NAO_PODE, podeTentarDeNovo = false)
        else -> EstadoAberturaDeVaga.Falha(TextosAberturaDeVaga.ERRO_GENERICO, podeTentarDeNovo = true)
    }

    private companion object {
        const val ESTADO_PUBLICADA = "publicada"
        const val ESTADO_PREENCHIDA = "preenchida"
        const val ESTADO_CANCELADA = "cancelada"
        const val MODO_SELECAO = "selecao"
    }
}

/**
 * A vaga lida por `detalhe_vaga` no formato que a tela de detalhe e a candidatura já usam (`VagaNaLista`). A distância
 * pode não vir no detalhe (o contrato a deixa nula): vai `0.0` aqui e a tela a esconde quando recebe o detalhe sem ela.
 */
fun VagaDto.paraVagaAberta(): VagaAbertaDto = VagaAbertaDto(
    id = id,
    funcao = funcao,
    estabelecimento = estabelecimento,
    inicioEm = inicioEm,
    fimEm = fimEm,
    local = local,
    regiaoAdministrativa = regiaoAdministrativa,
    distanciaKm = distanciaKm ?: 0.0,
    valorCentavos = valorCentavos,
    posicoesAbertas = posicoesAbertas,
    inclusos = inclusos,
    modo = modo,
)
