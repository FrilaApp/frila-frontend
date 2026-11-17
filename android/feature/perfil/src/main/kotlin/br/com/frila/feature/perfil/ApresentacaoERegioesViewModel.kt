package br.com.frila.feature.perfil

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ApresentacaoDoProfissionalDto
import br.com.frila.core.rede.DefinirRegioesAtendidasDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.PerfilProfissionalDetalhadoDto
import br.com.frila.core.rede.RegiaoAdministrativaDto
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive

/** O rascunho e o estado da tela de apresentação e regiões do profissional. */
data class EstadoApresentacaoERegioes(
    val carregando: Boolean = false,
    val salvando: Boolean = false,
    val sucesso: Boolean = false,
    val erroGeral: String? = null,
    val erroSobreMim: String? = null,
    val erroOndeTrabalhei: String? = null,
    val erroCursos: String? = null,
    val erroRegioes: String? = null,
    val sobreMim: String = "",
    val ondeTrabalhei: String = "",
    /** `menos_de_1_ano`... `mais_de_10_anos`; `null` = não informado. */
    val experienciaFaixa: String? = null,
    val cursos: List<String> = emptyList(),
    val novoCurso: String = "",
    /** `portugues`, `ingles`, `espanhol`, `libras`, `outro`. */
    val idiomas: Set<String> = emptySet(),
    val atendeTodoDf: Boolean = false,
    val regioesSelecionadas: Set<Int> = emptySet(),
    val regioesDisponiveis: List<RegiaoAdministrativaDto> = emptyList(),
)

/**
 * "Sobre mim", experiência, onde já trabalhou, cursos, idiomas e regiões atendidas (RN26/RN38/RN39/RN44; contrato 0.2.52 e
 * 0.2.53). Paridade com `ApresentacaoERegioesViewModel.swift`. Os limites são os do contrato: 600 caracteres em "Sobre mim", 400 em
 * "Onde já trabalhei", até 5 cursos de até 80 caracteres, contados em letras (um emoji vale um).
 *
 * As quatro operações chegam por função, para não amarrar o ViewModel a um serviço (a ligação é do L1-7): [carregarPerfil] é
 * `meu_perfil_detalhado`, [carregarRegioes] é `ServicoPerfil.regioesAdministrativas`, [salvarApresentacao] e [salvarRegioes] são
 * `ServicoPerfil.atualizarApresentacaoProfissional` e `definirRegioesAtendidas`.
 *
 * Salvar manda a apresentação e depois as regiões; se a apresentação falhar, as regiões não vão. Texto e experiência vazios saem
 * como `null`, que é o que limpa o campo no servidor (omitido deixaria como estava).
 */
class ApresentacaoERegioesViewModel(
    private val carregarPerfil: suspend () -> PerfilProfissionalDetalhadoDto,
    private val carregarRegioes: suspend () -> List<RegiaoAdministrativaDto>,
    private val salvarApresentacao: suspend (ApresentacaoDoProfissionalDto) -> PerfilProfissionalDetalhadoDto,
    private val salvarRegioes: suspend (DefinirRegioesAtendidasDto) -> PerfilProfissionalDetalhadoDto,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoApresentacaoERegioes())
    val estado: StateFlow<EstadoApresentacaoERegioes> = _estado.asStateFlow()

    fun carregar(): Job {
        _estado.update { it.copy(carregando = true, erroGeral = null) }
        return escopoDeTrabalho.launch {
            val (perfil, catalogo) = try {
                coroutineScope {
                    val p = async { runCatching { carregarPerfil() } }
                    val c = async { runCatching { carregarRegioes() } }
                    p.await() to c.await()
                }
            } catch (erro: CancellationException) {
                throw erro
            }
            (perfil.exceptionOrNull() as? CancellationException)?.let { throw it }
            (catalogo.exceptionOrNull() as? CancellationException)?.let { throw it }
            val erroDoPerfil = perfil.exceptionOrNull()
            val erroDoCatalogo = catalogo.exceptionOrNull()
            when {
                erroDoCatalogo != null -> falharAoCarregar(erroDoCatalogo)
                // Quem ainda não tem perfil só precisa do catálogo para marcar as regiões.
                (erroDoPerfil as? ErroDaApi)?.codigo == CodigoErroAPI.NAO_ENCONTRADO ->
                    _estado.update { it.copy(carregando = false, regioesDisponiveis = catalogo.getOrThrow()) }
                erroDoPerfil != null -> falharAoCarregar(erroDoPerfil)
                else -> aplicarPerfil(perfil.getOrThrow(), catalogo.getOrThrow())
            }
        }
    }

    private fun falharAoCarregar(erro: Throwable) {
        val mensagem = if ((erro as? ErroDaApi)?.codigo == CodigoErroAPI.SEM_REDE) {
            TextosApresentacaoERegioes.ERRO_SEM_REDE
        } else {
            TextosApresentacaoERegioes.ERRO_CARREGAR
        }
        _estado.update { it.copy(carregando = false, erroGeral = mensagem) }
    }

    private fun aplicarPerfil(perfil: PerfilProfissionalDetalhadoDto, catalogo: List<RegiaoAdministrativaDto>) {
        _estado.update {
            it.copy(
                carregando = false,
                regioesDisponiveis = catalogo,
                sobreMim = perfil.apresentacao.orEmpty(),
                ondeTrabalhei = perfil.ondeTrabalhei.orEmpty(),
                experienciaFaixa = perfil.experienciaFaixa,
                cursos = perfil.cursos,
                idiomas = perfil.idiomas.toSet(),
                atendeTodoDf = perfil.atendeTodoDf,
                regioesSelecionadas = perfil.regioes.map { r -> r.id }.toSet(),
            )
        }
    }

    fun alterarSobreMim(texto: String) = _estado.update { it.copy(sobreMim = texto, erroSobreMim = null) }

    fun alterarOndeTrabalhei(texto: String) = _estado.update { it.copy(ondeTrabalhei = texto, erroOndeTrabalhei = null) }

    fun escolherExperiencia(faixa: String?) = _estado.update { it.copy(experienciaFaixa = faixa) }

    fun alterarNovoCurso(texto: String) = _estado.update { it.copy(novoCurso = texto, erroCursos = null) }

    fun adicionarCurso() {
        _estado.update { atual ->
            val curso = atual.novoCurso.trim()
            when {
                curso.isEmpty() -> atual
                atual.cursos.size >= LIMITE_CURSOS -> atual.copy(erroCursos = TextosApresentacaoERegioes.LIMITE_CURSOS)
                letras(curso) > LIMITE_CURSO_CARACTERES -> atual.copy(erroCursos = TextosApresentacaoERegioes.CURSO_MUITO_LONGO)
                else -> atual.copy(cursos = atual.cursos + curso, novoCurso = "", erroCursos = null)
            }
        }
    }

    fun removerCurso(indice: Int) {
        _estado.update { atual ->
            if (indice !in atual.cursos.indices) atual
            else atual.copy(cursos = atual.cursos.filterIndexed { i, _ -> i != indice }, erroCursos = null)
        }
    }

    fun alternarIdioma(idioma: String) {
        _estado.update { it.copy(idiomas = if (idioma in it.idiomas) it.idiomas - idioma else it.idiomas + idioma) }
    }

    /** Ligar "todo o DF" limpa as regiões marcadas (o servidor ignora a lista nesse caso). */
    fun alternarTodoDf(ligado: Boolean) {
        _estado.update {
            it.copy(atendeTodoDf = ligado, regioesSelecionadas = if (ligado) emptySet() else it.regioesSelecionadas, erroRegioes = null)
        }
    }

    /** Marcar uma região com "todo o DF" ligado desliga o "todo o DF" e marca só ela. */
    fun alternarRegiao(id: Int) {
        _estado.update {
            val base = if (it.atendeTodoDf) emptySet() else it.regioesSelecionadas
            it.copy(
                atendeTodoDf = false,
                regioesSelecionadas = if (id in base) base - id else base + id,
                erroRegioes = null,
            )
        }
    }

    fun salvar(): Job {
        val atual = _estado.value
        if (atual.salvando) return escopoDeTrabalho.launch { }
        val invalido = validar(atual)
        if (invalido != null) {
            _estado.update { invalido }
            return escopoDeTrabalho.launch { }
        }
        // Curso digitado e não adicionado entra junto, como no iOS.
        val pendente = atual.novoCurso.trim()
        val cursos = if (pendente.isNotEmpty() && atual.cursos.size < LIMITE_CURSOS && letras(pendente) <= LIMITE_CURSO_CARACTERES) {
            atual.cursos + pendente
        } else {
            atual.cursos
        }
        var iniciou = false
        _estado.update {
            iniciou = !it.salvando
            if (iniciou) {
                it.copy(
                    salvando = true, sucesso = false, cursos = cursos, novoCurso = if (cursos.size > it.cursos.size) "" else it.novoCurso,
                    erroGeral = null, erroSobreMim = null, erroOndeTrabalhei = null, erroCursos = null, erroRegioes = null,
                )
            } else {
                it
            }
        }
        if (!iniciou) return escopoDeTrabalho.launch { }
        val apresentacao = ApresentacaoDoProfissionalDto(
            apresentacao = textoOuNulo(atual.sobreMim),
            ondeTrabalhei = textoOuNulo(atual.ondeTrabalhei),
            experienciaFaixa = atual.experienciaFaixa?.let { JsonPrimitive(it) } ?: JsonNull,
            cursos = cursos,
            idiomas = IDIOMAS.filter { it in atual.idiomas },
        )
        val regioes = DefinirRegioesAtendidasDto(
            regioes = if (atual.atendeTodoDf) emptyList() else atual.regioesSelecionadas.sorted(),
            atendeTodoDf = atual.atendeTodoDf,
        )
        return escopoDeTrabalho.launch {
            try {
                salvarApresentacao(apresentacao)
                salvarRegioes(regioes)
                _estado.update { it.copy(sucesso = true) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { aplicarErroDaApi(it, erro) }
            } catch (erro: Exception) {
                // Resposta 200 ilegível não é ErroDaApi: sem isto o botão ficaria preso em "Salvando…".
                _estado.update { it.copy(erroGeral = TextosApresentacaoERegioes.ERRO_SALVAR) }
            } finally {
                _estado.update { it.copy(salvando = false) }
            }
        }
    }

    private fun validar(e: EstadoApresentacaoERegioes): EstadoApresentacaoERegioes? = when {
        letras(e.sobreMim) > LIMITE_SOBRE_MIM -> e.copy(erroSobreMim = TextosApresentacaoERegioes.LIMITE_SOBRE_MIM)
        letras(e.ondeTrabalhei) > LIMITE_ONDE_TRABALHEI -> e.copy(erroOndeTrabalhei = TextosApresentacaoERegioes.LIMITE_ONDE_TRABALHEI)
        e.cursos.size > LIMITE_CURSOS -> e.copy(erroCursos = TextosApresentacaoERegioes.LIMITE_CURSOS)
        e.cursos.any { letras(it) > LIMITE_CURSO_CARACTERES } -> e.copy(erroCursos = TextosApresentacaoERegioes.CURSO_MUITO_LONGO)
        else -> null
    }

    private fun aplicarErroDaApi(e: EstadoApresentacaoERegioes, erro: ErroDaApi): EstadoApresentacaoERegioes = when (erro.codigo) {
        CodigoErroAPI.CAMPO_INVALIDO -> when (erro.detalhes?.lowercase()) {
            "onde_trabalhei" -> e.copy(erroOndeTrabalhei = TextosApresentacaoERegioes.ERRO_ANTI_CONTATO)
            "cursos" -> e.copy(erroCursos = TextosApresentacaoERegioes.ERRO_ANTI_CONTATO)
            "regioes" -> e.copy(erroRegioes = TextosApresentacaoERegioes.ERRO_REGIOES)
            // `apresentacao`, `sobre`, `sobre_mim` e o que o app não conhece: o filtro de contato pega mais no "Sobre mim".
            else -> e.copy(erroSobreMim = TextosApresentacaoERegioes.ERRO_ANTI_CONTATO)
        }
        CodigoErroAPI.SEM_REDE -> e.copy(erroGeral = TextosApresentacaoERegioes.ERRO_SEM_REDE)
        else -> e.copy(erroGeral = TextosApresentacaoERegioes.ERRO_SALVAR)
    }

    companion object {
        const val LIMITE_SOBRE_MIM = 600
        const val LIMITE_ONDE_TRABALHEI = 400
        const val LIMITE_CURSOS = 5
        const val LIMITE_CURSO_CARACTERES = 80
        val EXPERIENCIAS = listOf("menos_de_1_ano", "de_1_a_3_anos", "de_3_a_5_anos", "de_5_a_10_anos", "mais_de_10_anos")
        val IDIOMAS = listOf("portugues", "ingles", "espanhol", "libras", "outro")

        /** Letras como a pessoa conta: um emoji vale um, não dois. */
        internal fun letras(texto: String): Int = texto.codePointCount(0, texto.length)

        private fun textoOuNulo(texto: String) = texto.trim().takeIf { it.isNotEmpty() }?.let { JsonPrimitive(it) } ?: JsonNull
    }
}
