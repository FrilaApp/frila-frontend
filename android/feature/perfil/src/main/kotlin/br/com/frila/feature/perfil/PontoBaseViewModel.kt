package br.com.frila.feature.perfil

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.dominio.regra.CoberturaDoDF
import br.com.frila.core.rede.AlteracaoDoPerfilProfissionalDto
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.DadosDoPerfilProfissionalDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.PerfilProfissionalDto
import kotlin.math.abs
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Uma opção de ponto base: o nome que a pessoa lê e o ponto que vai ao servidor. */
data class OpcaoDePontoBase(val nome: String, val coordenada: Coordenada)

data class EstadoPontoBase(
    val carregando: Boolean = false,
    val salvando: Boolean = false,
    val salvo: Boolean = false,
    val erro: String? = null,
    val opcoes: List<OpcaoDePontoBase> = emptyList(),
    val escolhida: OpcaoDePontoBase? = null,
    /** O perfil já tinha ponto base ao abrir (pode não ser o centro de nenhuma região da lista). */
    val temPontoBaseSalvo: Boolean = false,
    /** Sem perfil profissional: o contrato só cria o perfil com ao menos uma função, então a tela as pede. */
    val semPerfil: Boolean = false,
    val funcoes: List<FuncaoDto> = emptyList(),
    val funcoesEscolhidas: Set<String> = emptySet(),
    /** O ponto base salvo ao abrir fica fora do DF (gravado por outro app, como o iOS, que aceita e avisa: decisão A6 da PO). */
    val pontoSalvoForaDoDF: Boolean = false,
) {
    /**
     * Aviso informativo, nunca bloqueante: o ponto que vale agora (o escolhido ou, sem escolha, o salvo) fica fora do DF.
     * Salvar continua permitido; o servidor aceita qualquer ponto base dentro da faixa de latitude e longitude.
     */
    val avisoForaDoDF: Boolean
        get() = escolhida?.let { CoberturaDoDF.estaForaDoDF(it.coordenada) } ?: pontoSalvoForaDoDF
}

/**
 * Ponto base do profissional: de onde o servidor mede a distância até as vagas. A pessoa escolhe uma região numa lista que já
 * está no app ([opcoes]) e o centro dela vira o ponto base. Nada aqui lê a posição do aparelho nem consulta serviço de endereço.
 *
 * Grava como o iOS (`PerfilProfissionalViewModel.salvar`): com perfil, `atualizar_perfil_profissional` só com o `ponto_base`
 * (o omitido fica como está); sem perfil (`meu_perfil_profissional` responde 404), `criar_perfil_profissional` com as funções
 * escolhidas, o ponto base e a grade vazia, que o contrato aceita. As operações chegam por função, como no
 * [ApresentacaoERegioesViewModel]; a ligação com o serviço é do `ModulosKoin`.
 */
class PontoBaseViewModel(
    private val opcoes: List<OpcaoDePontoBase>,
    private val carregarPerfil: suspend () -> PerfilProfissionalDto,
    private val carregarFuncoes: suspend () -> List<FuncaoDto>,
    private val criarPerfil: suspend (DadosDoPerfilProfissionalDto) -> PerfilProfissionalDto,
    private val atualizarPerfil: suspend (AlteracaoDoPerfilProfissionalDto) -> PerfilProfissionalDto,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoPontoBase(opcoes = opcoes))
    val estado: StateFlow<EstadoPontoBase> = _estado.asStateFlow()

    fun carregar(): Job {
        _estado.update { it.copy(carregando = true, erro = null) }
        return escopoDeTrabalho.launch {
            try {
                val pontoSalvo = try {
                    carregarPerfil().pontoBase
                } catch (erro: ErroDaApi) {
                    if (erro.codigo != CodigoErroAPI.NAO_ENCONTRADO) throw erro
                    prepararCriacao(mensagem = null)
                    return@launch
                }
                _estado.update {
                    it.copy(
                        carregando = false,
                        temPontoBaseSalvo = pontoSalvo != null,
                        pontoSalvoForaDoDF = pontoSalvo != null && CoberturaDoDF.estaForaDoDF(pontoSalvo.latitude, pontoSalvo.longitude),
                        escolhida = it.escolhida ?: pontoSalvo?.let(::opcaoNoPonto),
                    )
                }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
                _estado.update { it.copy(carregando = false, erro = mensagemDe(erro, TextosPontoBase.ERRO_CARREGAR)) }
            }
        }
    }

    fun escolher(opcao: OpcaoDePontoBase) = _estado.update { it.copy(escolhida = opcao, erro = null) }

    fun alternarFuncao(id: String) = _estado.update {
        it.copy(funcoesEscolhidas = if (id in it.funcoesEscolhidas) it.funcoesEscolhidas - id else it.funcoesEscolhidas + id, erro = null)
    }

    fun salvar(): Job {
        val atual = _estado.value
        val escolhida = atual.escolhida
        val recusa = when {
            atual.salvando -> return escopoDeTrabalho.launch { }
            escolhida == null -> TextosPontoBase.ERRO_SEM_PONTO_BASE
            atual.semPerfil && atual.funcoesEscolhidas.isEmpty() -> TextosPontoBase.ERRO_SEM_FUNCAO
            else -> null
        }
        if (escolhida == null || recusa != null) {
            _estado.update { it.copy(erro = recusa) }
            return escopoDeTrabalho.launch { }
        }
        val ponto = CoordenadaDto(escolhida.coordenada.latitude, escolhida.coordenada.longitude)
        _estado.update { it.copy(salvando = true, erro = null) }
        return escopoDeTrabalho.launch {
            try {
                if (atual.semPerfil) criar(atual.funcoesEscolhidas, ponto) else atualizar(ponto)
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: Exception) {
                _estado.update { it.copy(salvando = false, erro = mensagemDe(erro, TextosPontoBase.ERRO_SALVAR)) }
            }
        }
    }

    private suspend fun criar(funcoes: Set<String>, ponto: CoordenadaDto) {
        try {
            criarPerfil(DadosDoPerfilProfissionalDto(funcoes = funcoes.toList(), pontoBase = ponto, disponibilidades = emptyList()))
        } catch (erro: ErroDaApi) {
            // O perfil nasceu por outro caminho entre abrir e salvar: o ponto escolhido aqui é o que vale.
            if (erro.codigo != CodigoErroAPI.PERFIL_JA_EXISTE) throw erro
            atualizarPerfil(AlteracaoDoPerfilProfissionalDto(pontoBase = ponto))
        }
        _estado.update { it.copy(salvando = false, salvo = true) }
    }

    private suspend fun atualizar(ponto: CoordenadaDto) {
        try {
            atualizarPerfil(AlteracaoDoPerfilProfissionalDto(pontoBase = ponto))
        } catch (erro: ErroDaApi) {
            if (erro.codigo != CodigoErroAPI.NAO_ENCONTRADO) throw erro
            // A carga do perfil falhou ou o perfil não existe: para criar, o contrato pede as funções.
            prepararCriacao(mensagem = TextosPontoBase.ERRO_SEM_FUNCAO)
            return
        }
        _estado.update { it.copy(salvando = false, salvo = true) }
    }

    private suspend fun prepararCriacao(mensagem: String?) {
        val funcoes = carregarFuncoes()
        _estado.update { it.copy(carregando = false, salvando = false, semPerfil = true, funcoes = funcoes, erro = mensagem) }
    }

    private fun opcaoNoPonto(ponto: CoordenadaDto): OpcaoDePontoBase? = opcoes.firstOrNull {
        abs(it.coordenada.latitude - ponto.latitude) < TOLERANCIA_GRAUS && abs(it.coordenada.longitude - ponto.longitude) < TOLERANCIA_GRAUS
    }

    private fun mensagemDe(erro: Exception, padrao: String): String =
        if ((erro as? ErroDaApi)?.codigo == CodigoErroAPI.SEM_REDE) TextosPontoBase.ERRO_SEM_REDE else padrao

    private companion object {
        /** Cerca de 10 cm: só para reconhecer um ponto que saiu desta mesma lista. */
        const val TOLERANCIA_GRAUS = 0.000001
    }
}
