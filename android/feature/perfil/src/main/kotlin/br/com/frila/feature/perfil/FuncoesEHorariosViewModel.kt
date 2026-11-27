package br.com.frila.feature.perfil

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.AlteracaoDoPerfilProfissionalDto
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.DadosDoPerfilProfissionalDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.JanelaDeDisponibilidadeDto
import br.com.frila.core.rede.PerfilProfissionalDto
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class EstadoFuncoesEHorarios(
    val carregando: Boolean = false,
    val salvando: Boolean = false,
    val salvo: Boolean = false,
    val erro: String? = null,
    val erroValidacaoHorario: String? = null,
    val funcoesDisponiveis: List<FuncaoDto> = emptyList(),
    val funcoesSelecionadas: Set<String> = emptySet(),
    val disponibilidades: List<JanelaDeDisponibilidadeDto> = emptyList(),
    val diaSelecionado: Int = 1, // 1 = Segunda-feira
    val semPerfil: Boolean = false,
    val pontoBaseExistente: CoordenadaDto? = null,
) {
    /**
     * Sem perfil profissional cadastrado e sem ponto base salvo, o salvar não pode criar
     * perfil com coordenadas fictícias. A pessoa deve definir o ponto base antes.
     */
    val precisaDefinirPontoBase: Boolean
        get() = semPerfil && pontoBaseExistente == null
}

/**
 * Funções e horários de disponibilidade (Item #17 da Paridade, Lote B).
 * Permite ao profissional visualizar e editar as funções do catálogo que exerce
 * e a grade semanal de disponibilidade (7 dias, início e fim).
 */
class FuncoesEHorariosViewModel(
    private val carregarPerfil: suspend () -> PerfilProfissionalDto,
    private val carregarFuncoes: suspend () -> List<FuncaoDto>,
    private val criarPerfil: suspend (DadosDoPerfilProfissionalDto) -> PerfilProfissionalDto,
    private val atualizarPerfil: suspend (AlteracaoDoPerfilProfissionalDto) -> PerfilProfissionalDto,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoFuncoesEHorarios())
    val estado: StateFlow<EstadoFuncoesEHorarios> = _estado.asStateFlow()

    fun carregar(): Job {
        _estado.update { it.copy(carregando = true, erro = null) }
        return escopoDeTrabalho.launch {
            try {
                val funcoes = carregarFuncoes()
                val perfil = try {
                    carregarPerfil()
                } catch (erro: ErroDaApi) {
                    if (erro.codigo != CodigoErroAPI.NAO_ENCONTRADO) throw erro
                    null
                }
                if (perfil == null) {
                    _estado.update {
                        it.copy(
                            carregando = false,
                            funcoesDisponiveis = funcoes,
                            funcoesSelecionadas = emptySet(),
                            disponibilidades = emptyList(),
                            semPerfil = true,
                            pontoBaseExistente = null,
                            erro = TextosFuncoesEHorarios.ERRO_SEM_PONTO_BASE,
                        )
                    }
                } else {
                    _estado.update {
                        it.copy(
                            carregando = false,
                            funcoesDisponiveis = funcoes,
                            funcoesSelecionadas = perfil.funcoes.map { f -> f.id }.toSet(),
                            disponibilidades = perfil.disponibilidades,
                            pontoBaseExistente = perfil.pontoBase,
                            semPerfil = false,
                            erro = if (perfil.pontoBase == null) TextosFuncoesEHorarios.ERRO_SEM_PONTO_BASE else null,
                        )
                    }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: ErroDaApi) {
                _estado.update { it.copy(carregando = false, erro = mensagemDoErro(e)) }
            } catch (e: Exception) {
                _estado.update { it.copy(carregando = false, erro = TextosFuncoesEHorarios.ERRO_CARREGAR) }
            }
        }
    }

    fun alternarFuncao(id: String) {
        _estado.update {
            val novas = if (id in it.funcoesSelecionadas) it.funcoesSelecionadas - id else it.funcoesSelecionadas + id
            it.copy(funcoesSelecionadas = novas, erro = if (it.precisaDefinirPontoBase) TextosFuncoesEHorarios.ERRO_SEM_PONTO_BASE else null)
        }
    }

    fun selecionarDia(dia: Int) {
        if (dia in 0..6) {
            _estado.update { it.copy(diaSelecionado = dia, erroValidacaoHorario = null) }
        }
    }

    fun adicionarJanela(diaSemana: Int, inicio: String, fim: String): Boolean {
        if (diaSemana !in 0..6) {
            _estado.update { it.copy(erroValidacaoHorario = TextosFuncoesEHorarios.ERRO_DIA_INVALIDO) }
            return false
        }
        val iniFormatado = padronizarHora(inicio)
        val fimFormatado = padronizarHora(fim)
        val regex = Regex("^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$")
        if (!regex.matches(iniFormatado) || !regex.matches(fimFormatado)) {
            _estado.update { it.copy(erroValidacaoHorario = TextosFuncoesEHorarios.ERRO_FORMATO_HORA) }
            return false
        }
        if (iniFormatado == fimFormatado) {
            _estado.update { it.copy(erroValidacaoHorario = TextosFuncoesEHorarios.ERRO_HORARIOS_IGUAIS) }
            return false
        }
        val nova = JanelaDeDisponibilidadeDto(
            diaSemana = diaSemana,
            inicio = iniFormatado,
            fim = fimFormatado,
        )
        val atual = _estado.value
        val jaExiste = atual.disponibilidades.any {
            it.diaSemana == nova.diaSemana && it.inicio == nova.inicio && it.fim == nova.fim
        }
        if (jaExiste) {
            _estado.update { it.copy(erroValidacaoHorario = TextosFuncoesEHorarios.ERRO_JANELA_DUPLICADA) }
            return false
        }
        val listaOrdenada = (atual.disponibilidades + nova).sortedWith(
            compareBy({ it.diaSemana }, { converterParaMinutos(it.inicio) }, { converterParaMinutos(it.fim) }),
        )
        _estado.update {
            it.copy(
                disponibilidades = listaOrdenada,
                erroValidacaoHorario = null,
                erro = if (it.precisaDefinirPontoBase) TextosFuncoesEHorarios.ERRO_SEM_PONTO_BASE else null,
            )
        }
        return true
    }

    fun removerJanela(janela: JanelaDeDisponibilidadeDto) {
        _estado.update {
            it.copy(
                disponibilidades = it.disponibilidades - janela,
                erro = if (it.precisaDefinirPontoBase) TextosFuncoesEHorarios.ERRO_SEM_PONTO_BASE else null,
            )
        }
    }

    fun salvar(): Job {
        val atual = _estado.value
        if (atual.salvando) return escopoDeTrabalho.launch {}
        if (atual.semPerfil && atual.pontoBaseExistente == null) {
            _estado.update { it.copy(erro = TextosFuncoesEHorarios.ERRO_SEM_PONTO_BASE) }
            return escopoDeTrabalho.launch {}
        }
        if (atual.funcoesSelecionadas.isEmpty()) {
            _estado.update { it.copy(erro = TextosFuncoesEHorarios.ERRO_SEM_FUNCAO) }
            return escopoDeTrabalho.launch {}
        }
        _estado.update { it.copy(salvando = true, erro = null) }
        return escopoDeTrabalho.launch {
            try {
                if (atual.semPerfil) {
                    val pontoBase = checkNotNull(atual.pontoBaseExistente)
                    criarPerfil(
                        DadosDoPerfilProfissionalDto(
                            funcoes = atual.funcoesSelecionadas.toList(),
                            pontoBase = pontoBase,
                            disponibilidades = atual.disponibilidades,
                        ),
                    )
                } else {
                    atualizarPerfil(
                        AlteracaoDoPerfilProfissionalDto(
                            funcoes = atual.funcoesSelecionadas.toList(),
                            disponibilidades = atual.disponibilidades,
                        ),
                    )
                }
                _estado.update { it.copy(salvando = false, salvo = true, erro = null) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: ErroDaApi) {
                _estado.update { it.copy(salvando = false, erro = mensagemDoErro(e)) }
            } catch (e: Exception) {
                _estado.update { it.copy(salvando = false, erro = TextosFuncoesEHorarios.ERRO_SALVAR) }
            }
        }
    }

    /** Texto fixo por código, como o iOS (`MensagemDoErroAPI.texto`): o campo e a mensagem técnica da recusa nunca vão para a tela. */
    private fun mensagemDoErro(erro: ErroDaApi): String = when (erro.codigo) {
        CodigoErroAPI.SEM_REDE -> TextosFuncoesEHorarios.ERRO_SEM_REDE
        CodigoErroAPI.NAO_AUTENTICADO -> TextosFuncoesEHorarios.ERRO_SESSAO
        CodigoErroAPI.SEM_PERMISSAO, CodigoErroAPI.PERFIL_INCOMPATIVEL -> TextosFuncoesEHorarios.ERRO_SEM_PERMISSAO
        CodigoErroAPI.LIMITE_EXCEDIDO -> TextosFuncoesEHorarios.ERRO_LIMITE
        else -> TextosFuncoesEHorarios.ERRO_GENERICO
    }

    internal fun padronizarHora(hora: String): String {
        val limpa = hora.trim()
        val partes = limpa.split(":")
        return if (partes.size == 2) {
            val h = partes[0].padStart(2, '0')
            val m = partes[1].padStart(2, '0')
            "$h:$m"
        } else limpa
    }

    internal fun converterParaMinutos(hora: String): Int {
        val (h, m) = hora.split(":").map { it.toInt() }
        return h * 60 + m
    }
}
