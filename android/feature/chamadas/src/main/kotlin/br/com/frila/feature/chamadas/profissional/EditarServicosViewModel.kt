package br.com.frila.feature.chamadas.profissional

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.EspecialidadeDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.PerfilProfissionalDetalhadoDto
import br.com.frila.core.rede.ServicoNoPerfilDto
import br.com.frila.core.rede.ServicoOferecidoDto
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Unidades de preço do contrato, na ordem do seletor do iOS. */
val UNIDADES_DE_PRECO: List<String> = listOf("hora", "diaria", "evento", "pacote", "por_pessoa", "a_combinar")

val OPCOES_LEVA_MATERIAL: List<String> = listOf("sim", "nao", "depende")

const val MAXIMO_DE_ESPECIALIDADES = 8

/** Recusa local de um campo, no mesmo formato do `422 campo_invalido` do servidor (`details` = o campo). */
class CampoInvalido(val campo: String) : Exception(campo)

/**
 * Um serviço no rascunho, uma linha por função marcada no perfil. Os campos numéricos ficam como texto: é o
 * que a pessoa digitou, e só [oferta] converte (e recusa o que o servidor recusaria).
 */
data class ServicoEmEdicao(
    val funcao: FuncaoDto,
    val habilitado: Boolean = false,
    val unidade: String = "a_combinar",
    /** Em reais, como se digita: `150` ou `150,50`. */
    val valor: String = "",
    val valorMaximo: String = "",
    val horasIncluidas: String = "",
    val minimoHoras: String = "",
    val duracaoTipicaH: String = "",
    val atePessoas: String = "",
    val minimoPessoas: String = "",
    val descricaoPacote: String = "",
    val levaMaterial: String? = null,
    val inclui: String = "",
    val especialidadeIds: Set<String> = emptySet(),
) {
    /** Trocar a unidade zera o que só fazia sentido na anterior e põe o padrão da nova (diária: 8 h; por pessoa: 1). */
    fun comUnidade(nova: String): ServicoEmEdicao = copy(
        unidade = nova,
        valorMaximo = "",
        horasIncluidas = if (nova == "diaria") "8" else "",
        minimoHoras = "",
        duracaoTipicaH = "",
        atePessoas = "",
        minimoPessoas = if (nova == "por_pessoa") "1" else "",
        descricaoPacote = "",
    )

    /** O que `definir_servicos` recebe, ou [CampoInvalido] com o campo que o servidor recusaria (RN27, RN44). */
    fun oferta(): ServicoOferecidoDto {
        fun exigir(condicao: Boolean, campo: String) {
            if (!condicao) throw CampoInvalido(campo)
        }

        val valorEmCentavos = if (unidade == "a_combinar") null else centavos(valor, "valor_centavos")
        val maximoEmCentavos = centavos(valorMaximo, "valor_max_centavos")
        exigir(unidade == "a_combinar" || valorEmCentavos in 1_000L..1_000_000L, "valor_centavos")
        exigir(
            maximoEmCentavos == null ||
                (unidade in listOf("hora", "diaria", "pacote") && maximoEmCentavos in (valorEmCentavos ?: 1_000L)..1_000_000L),
            "valor_max_centavos",
        )
        val horas = inteiro(horasIncluidas, "horas_incluidas")
        exigir(if (unidade == "diaria") horas in 4..12 else horas == null, "horas_incluidas")
        val minimoDeHoras = inteiro(minimoHoras, "minimo_horas")
        exigir(minimoDeHoras == null || (unidade == "hora" && minimoDeHoras in 1..12), "minimo_horas")
        val duracao = inteiro(duracaoTipicaH, "duracao_tipica_h")
        exigir(duracao == null || (unidade == "evento" && duracao in 1..24), "duracao_tipica_h")
        val ate = inteiro(atePessoas, "ate_pessoas")
        exigir(ate == null || (unidade == "evento" && ate in 1..2000), "ate_pessoas")
        val minimoDePessoas = inteiro(minimoPessoas, "minimo_pessoas")
        exigir(if (unidade == "por_pessoa") minimoDePessoas in 1..2000 else minimoDePessoas == null, "minimo_pessoas")
        val pacote = descricaoPacote.trim()
        exigir(if (unidade == "pacote") pacote.isNotEmpty() && pacote.length <= 120 else pacote.isEmpty(), "descricao_pacote")
        exigir(inclui.length <= 300, "inclui")
        exigir(especialidadeIds.size <= MAXIMO_DE_ESPECIALIDADES, "especialidade_ids")
        return ServicoOferecidoDto(
            funcaoId = funcao.id,
            unidade = unidade,
            valorCentavos = valorEmCentavos,
            valorMaxCentavos = maximoEmCentavos,
            horasIncluidas = horas,
            minimoHoras = minimoDeHoras,
            duracaoTipicaH = duracao,
            atePessoas = ate,
            minimoPessoas = minimoDePessoas,
            descricaoPacote = pacote.takeIf { it.isNotEmpty() },
            inclui = inclui.trim().takeIf { it.isNotEmpty() },
            levaMaterial = levaMaterial,
            especialidadeIds = especialidadeIds.sorted().takeIf { it.isNotEmpty() },
        )
    }

    companion object {
        fun de(funcao: FuncaoDto, existente: ServicoNoPerfilDto?): ServicoEmEdicao {
            if (existente == null) return ServicoEmEdicao(funcao = funcao)
            return ServicoEmEdicao(
                funcao = funcao,
                habilitado = true,
                unidade = existente.unidade,
                valor = existente.valorCentavos?.let(::texto).orEmpty(),
                valorMaximo = existente.valorMaxCentavos?.let(::texto).orEmpty(),
                horasIncluidas = existente.horasIncluidas?.toString().orEmpty(),
                minimoHoras = existente.minimoHoras?.toString().orEmpty(),
                duracaoTipicaH = existente.duracaoTipicaH?.toString().orEmpty(),
                atePessoas = existente.atePessoas?.toString().orEmpty(),
                minimoPessoas = existente.minimoPessoas?.toString().orEmpty(),
                descricaoPacote = existente.descricaoPacote.orEmpty(),
                levaMaterial = existente.levaMaterial,
                inclui = existente.inclui.orEmpty(),
                especialidadeIds = existente.especialidades.orEmpty().map { it.id }.toSet(),
            )
        }

        private fun texto(centavos: Long): String = "${centavos / 100},${(centavos % 100).toString().padStart(2, '0')}"

        private val padraoDeValor = Regex("^[0-9]{1,5}(,[0-9]{1,2})?$")

        /** `"150"` e `"150,5"` são reais; vazio é "sem valor"; o resto é recusado como o servidor recusaria. */
        internal fun centavos(texto: String, campo: String): Long? {
            val limpo = texto.trim()
            if (limpo.isEmpty()) return null
            if (!padraoDeValor.matches(limpo)) throw CampoInvalido(campo)
            val partes = limpo.split(",")
            val centavosDaParte = partes.getOrNull(1)?.padEnd(2, '0')?.toLong() ?: 0L
            return partes[0].toLong() * 100 + centavosDaParte
        }

        private fun inteiro(texto: String, campo: String): Int? {
            val limpo = texto.trim()
            if (limpo.isEmpty()) return null
            return limpo.toIntOrNull() ?: throw CampoInvalido(campo)
        }
    }
}

data class EstadoEditarServicos(
    val carregando: Boolean = true,
    val carregou: Boolean = false,
    val salvando: Boolean = false,
    val sucesso: Boolean = false,
    val rascunhos: List<ServicoEmEdicao> = emptyList(),
    /** Especialidades ativas de cada função, por `funcao_id`. */
    val especialidades: Map<String, List<EspecialidadeDto>> = emptyMap(),
    val erro: String? = null,
    /** A função da linha onde o erro de campo aparece; `null` quando o erro não é de uma linha. */
    val funcaoComErro: String? = null,
    /** O campo do contrato recusado (`details`), para a tela destacar. */
    val campoComErro: String? = null,
)

/**
 * Serviços com preço do profissional (RN27, RN44; paridade com `ServicosDoProfissionalViewModel.swift`): uma
 * linha por função marcada no perfil, com unidade de preço, valor e o que a unidade pede, e `definir_servicos`
 * que **substitui** o conjunto (até 10). Valida no aparelho o mesmo que o servidor valida, mas a palavra
 * final é do servidor: `422 campo_invalido` (campo em `details`) e `422 funcao_nao_marcada` viram mensagem.
 *
 * [carregarPerfil] é `meuPerfilDetalhado`; [listarEspecialidades] devolve as ativas de uma função
 * (`GET /especialidade`); [definir] é `definirServicos`.
 */
class EditarServicosViewModel(
    private val carregarPerfil: suspend () -> PerfilProfissionalDetalhadoDto,
    private val listarEspecialidades: suspend (funcaoId: String) -> List<EspecialidadeDto>,
    private val definir: suspend (List<ServicoOferecidoDto>) -> PerfilProfissionalDetalhadoDto,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoEditarServicos())
    val estado: StateFlow<EstadoEditarServicos> = _estado.asStateFlow()

    private var carregandoAgora = false

    /** Também serve de "tentar novamente". Duas cargas ao mesmo tempo viram uma. */
    fun carregar(): Job {
        if (carregandoAgora || _estado.value.carregou) return escopoDeTrabalho.launch { }
        carregandoAgora = true
        _estado.update { it.copy(carregando = true, erro = null) }
        return escopoDeTrabalho.launch {
            try {
                val perfil = carregarPerfil()
                val catalogo = perfil.funcoes.associate { funcao ->
                    funcao.id to listarEspecialidades(funcao.id).filter { it.ativo != false && it.funcaoId == funcao.id }
                }
                _estado.update {
                    it.copy(
                        carregando = false,
                        carregou = true,
                        especialidades = catalogo,
                        rascunhos = perfil.funcoes.map { funcao ->
                            ServicoEmEdicao.de(funcao, perfil.servicos.firstOrNull { s -> s.funcao.id == funcao.id })
                        },
                    )
                }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(carregando = false, erro = mensagemDeErro(erro)) }
            } catch (_: Exception) {
                _estado.update { it.copy(carregando = false, erro = TextosChamadaProfissional.ERRO) }
            } finally {
                carregandoAgora = false
            }
        }
    }

    /** Muda o rascunho da função e apaga o aviso de "salvo", que deixou de ser verdade. */
    fun editar(funcaoId: String, mudanca: (ServicoEmEdicao) -> ServicoEmEdicao) {
        _estado.update { tela ->
            tela.copy(
                rascunhos = tela.rascunhos.map { if (it.funcao.id == funcaoId) mudanca(it) else it },
                sucesso = false,
            )
        }
    }

    fun alternarEspecialidade(funcaoId: String, especialidadeId: String, marcada: Boolean) = editar(funcaoId) { linha ->
        val ids = linha.especialidadeIds
        when {
            marcada && ids.size < MAXIMO_DE_ESPECIALIDADES -> linha.copy(especialidadeIds = ids + especialidadeId)
            !marcada -> linha.copy(especialidadeIds = ids - especialidadeId)
            else -> linha
        }
    }

    /** Sem efeito antes de carregar ou com outro salvamento em voo. */
    fun salvar(): Job {
        val atual = _estado.value
        if (!atual.carregou || atual.salvando) return escopoDeTrabalho.launch { }
        val ofertas = mutableListOf<ServicoOferecidoDto>()
        for (linha in atual.rascunhos.filter { it.habilitado }) {
            try {
                ofertas += linha.oferta()
            } catch (invalido: CampoInvalido) {
                _estado.update {
                    it.copy(erro = TextosChamadaProfissional.campo(invalido.campo), funcaoComErro = linha.funcao.id, campoComErro = invalido.campo, sucesso = false)
                }
                return escopoDeTrabalho.launch { }
            }
        }
        _estado.update { it.copy(salvando = true, sucesso = false, erro = null, funcaoComErro = null, campoComErro = null) }
        return escopoDeTrabalho.launch {
            try {
                definir(ofertas)
                _estado.update { it.copy(salvando = false, sucesso = true) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { it.copy(salvando = false, erro = mensagemDeErro(erro), campoComErro = campoDoErro(erro)) }
            } catch (_: Exception) {
                _estado.update { it.copy(salvando = false, erro = TextosChamadaProfissional.ERRO) }
            }
        }
    }

    private fun campoDoErro(erro: ErroDaApi): String? =
        erro.detalhes.takeIf { erro.codigo == CodigoErroAPI.CAMPO_INVALIDO }

    private fun mensagemDeErro(erro: ErroDaApi): String = when {
        erro.recursoDesligado -> TextosChamadaProfissional.DESLIGADO
        erro.contaSuspensa -> TextosChamadaProfissional.CONTA_SUSPENSA
        erro.codigo == CodigoErroAPI.PERFIL_INCOMPATIVEL -> TextosChamadaProfissional.SO_PROFISSIONAL
        erro.codigo == CodigoErroAPI.FUNCAO_NAO_MARCADA -> TextosChamadaProfissional.SERVICOS_FUNCAO_NAO_MARCADA
        erro.codigo == CodigoErroAPI.CAMPO_INVALIDO -> TextosChamadaProfissional.campo(erro.detalhes)
        else -> TextosChamadaProfissional.ERRO
    }
}
