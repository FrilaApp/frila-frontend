package br.com.frila.feature.vagas.publicacao

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.NovaVagaDto
import br.com.frila.core.rede.VagaPublicadaDto
import java.time.Duration
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.UUID
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Como a vaga é preenchida (RN24). [chave] é o valor do contrato (`ModoPreenchimento`). */
enum class ModoDaVaga(val chave: String) { URGENCIA("urgencia"), SELECAO("selecao") }

/** Campos do formulário que podem receber uma recusa. */
enum class CampoPublicacao { ESTABELECIMENTO, FUNCAO, INICIO, FIM, LOCAL, VALOR, POSICOES, RESPONSAVEL, MODO, TRAJE, OBSERVACOES }

/** Erro que não é de um campo só, mostrado acima do botão. */
enum class ErroGlobalPublicacao(val mensagem: String) {
    CONFIRA_CAMPOS(TextosPublicarVaga.ERRO_CONFIRA_CAMPOS),
    SELECAO_SEM_ANTECEDENCIA(TextosPublicarVaga.ERRO_SELECAO_SEM_ANTECEDENCIA),
    PERFIL_INCOMPATIVEL(TextosPublicarVaga.ERRO_PERFIL_INCOMPATIVEL),
    SEM_PERMISSAO(TextosPublicarVaga.ERRO_SEM_PERMISSAO),
    CONTA_SUSPENSA(TextosPublicarVaga.ERRO_CONTA_SUSPENSA),
    SESSAO_EXPIRADA(TextosPublicarVaga.ERRO_SESSAO),
    SEM_REDE(TextosPublicarVaga.ERRO_SEM_REDE),
    GENERICO(TextosPublicarVaga.ERRO_GENERICO),
}

/**
 * O estabelecimento em nome do qual a vaga é publicada. Endereço, Região Administrativa e ponto vêm
 * do cadastro (contrato 0.2.20: o turno nasce com os do estabelecimento); o contratante só ajusta o
 * texto do endereço.
 */
data class EstabelecimentoDaVaga(
    val id: String,
    val endereco: String,
    val regiaoAdministrativa: String,
    val ponto: CoordenadaDto,
)

data class EstadoPublicarVaga(
    val funcoes: List<FuncaoDto> = emptyList(),
    val carregandoFuncoes: Boolean = false,
    val falhaAoCarregarFuncoes: Boolean = false,
    val funcaoId: String? = null,
    val inicio: Instant,
    val fim: Instant,
    val modo: ModoDaVaga = ModoDaVaga.URGENCIA,
    val local: String = "",
    /** Texto digitado, em reais. */
    val valor: String = "",
    val posicoes: String = "1",
    val incluiRefeicao: Boolean = false,
    val incluiTransporte: Boolean = false,
    val exigeMaterialProprio: Boolean = false,
    val responsavelLocal: String = "",
    val traje: String = "",
    val observacoes: String = "",
    val participaRateio: Boolean = false,
    val enviando: Boolean = false,
    /** Mensagem por campo, preenchida pela validação local ou pela recusa do servidor. */
    val errosDeCampo: Map<CampoPublicacao, String> = emptyMap(),
    val erro: ErroGlobalPublicacao? = null,
    val publicada: VagaPublicadaDto? = null,
    /**
     * A publicação já montada, com a `chave` de idempotência, enquanto o resultado é incerto (sem rede,
     * resposta ilegível). Reenviar manda exatamente este corpo: a mesma vaga, nunca uma segunda.
     */
    val pendente: NovaVagaDto? = null,
    /** O relógio do aparelho no último cálculo; só a tela de seleção depende dele. */
    val agora: Instant,
) {
    val concluida: Boolean get() = publicada != null
    val podeEditar: Boolean get() = !enviando && !concluida && pendente == null
    val valorCentavos: Long? get() = lerCentavos(valor)
    val posicoesNumero: Int? get() = posicoes.toIntOrNull()?.takeIf { it in POSICOES_MIN..POSICOES_MAX }
    val duracao: Duration get() = Duration.between(inicio, fim)

    /** Valor por pessoa vezes as posições (RN01: o profissional recebe o valor integral). */
    val valorTotalCentavos: Long? get() {
        val centavos = valorCentavos ?: return null
        val quantidade = posicoesNumero ?: return null
        return centavos * quantidade
    }

    /** Referência para o contratante: o valor anunciado é por turno, não por hora. `null` sem duração válida. */
    val valorPorHoraCentavos: Long? get() {
        val centavos = valorCentavos ?: return null
        val minutos = duracao.toMinutes()
        if (minutos <= 0) return null
        return (centavos * 60 + minutos / 2) / minutos
    }

    /** RN24: a seleção só existe com o início a mais de 24 horas. */
    val selecaoDisponivel: Boolean get() = inicio.isAfter(agora.plus(ANTECEDENCIA_DA_SELECAO))

    companion object {
        const val POSICOES_MIN = 1
        const val POSICOES_MAX = 200
        val ANTECEDENCIA_DA_SELECAO: Duration = Duration.ofHours(24)
    }
}

/**
 * Publicação de vaga pelo contratante (RF04, RN02, RN24, UC01; paridade com `PublicarVagaViewModel` de
 * `PublicarVaga.swift`). Valida tudo o que o contrato exige antes de chamar a rede e mostra todos os
 * campos errados de uma vez.
 *
 * Idempotência: a `chave` nasce uma vez por publicação. Se a resposta se perde (sem rede, corpo que
 * não é JSON), o formulário trava e "Tentar novamente" reenvia o mesmo corpo com a mesma `chave`; o
 * servidor devolve a mesma vaga. Só uma recusa definitiva ([CodigoErroAPI.recusaDefinitivaDePublicacao])
 * descarta o corpo e libera a edição, com `chave` nova na próxima tentativa. Nenhuma falha deixa o
 * botão preso em "Publicando…".
 *
 * [buscarFuncoes] é `ServicoVagas.listarFuncoes`; [enviarVaga] é `ServicoVagas.publicarVaga`.
 * `escopo`: mesma razão do `PerfilViewModel`. [relogio] e [novaChave] existem para o teste.
 */
class PublicarVagaViewModel(
    private val estabelecimento: EstabelecimentoDaVaga,
    private val buscarFuncoes: suspend () -> List<FuncaoDto>,
    private val enviarVaga: suspend (NovaVagaDto) -> VagaPublicadaDto,
    private val relogio: () -> Instant = Instant::now,
    private val novaChave: () -> String = { UUID.randomUUID().toString() },
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(estadoInicial())
    val estado: StateFlow<EstadoPublicarVaga> = _estado.asStateFlow()

    private fun estadoInicial(): EstadoPublicarVaga {
        val instanteAtual = relogio()
        val inicio = instanteAtual.plus(INICIO_PADRAO).truncatedTo(ChronoUnit.MINUTES)
        return EstadoPublicarVaga(
            inicio = inicio,
            fim = inicio.plus(DURACAO_PADRAO),
            local = estabelecimento.endereco,
            agora = instanteAtual,
        )
    }

    private fun editar(vararg campos: CampoPublicacao, mudar: EstadoPublicarVaga.() -> EstadoPublicarVaga) {
        _estado.update {
            if (!it.podeEditar) {
                it
            } else {
                it.mudar().let { novo ->
                    novo.copy(errosDeCampo = novo.errosDeCampo - campos.toSet(), erro = null, agora = relogio())
                }
            }
        }
    }

    /** Carrega o catálogo de funções. Sem efeito se já carregou ou se está carregando. */
    fun carregarFuncoes(): Job {
        val atual = _estado.value
        if (atual.carregandoFuncoes || atual.funcoes.isNotEmpty()) return escopoDeTrabalho.launch { }
        _estado.update { it.copy(carregandoFuncoes = true, falhaAoCarregarFuncoes = false) }
        return escopoDeTrabalho.launch {
            try {
                val funcoes = buscarFuncoes()
                _estado.update { it.copy(carregandoFuncoes = false, funcoes = funcoes, falhaAoCarregarFuncoes = funcoes.isEmpty()) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (_: Exception) {
                // ErroDaApi, sem rede ou corpo que não é JSON: o seletor mostra a falha e deixa tentar de novo.
                _estado.update { it.copy(carregandoFuncoes = false, falhaAoCarregarFuncoes = true) }
            }
        }
    }

    fun escolherFuncao(id: String) = editar(CampoPublicacao.FUNCAO) { copy(funcaoId = id) }

    /** Mover o início leva o fim junto, para a duração não mudar (como no iOS). */
    fun editarInicio(inicio: Instant) = editar(CampoPublicacao.INICIO, CampoPublicacao.FIM, CampoPublicacao.MODO) {
        val duracao = if (fim.isAfter(this.inicio)) Duration.between(this.inicio, fim) else DURACAO_PADRAO
        val movido = copy(inicio = inicio, fim = inicio.plus(duracao), agora = relogio())
        // A seleção deixou de caber com o novo início: volta para urgência, que é o que a tela oferece.
        if (movido.modo == ModoDaVaga.SELECAO && !movido.selecaoDisponivel) movido.copy(modo = ModoDaVaga.URGENCIA) else movido
    }

    fun editarFim(fim: Instant) = editar(CampoPublicacao.FIM) { copy(fim = fim) }

    fun escolherModo(modo: ModoDaVaga) {
        _estado.update {
            when {
                !it.podeEditar -> it
                modo == ModoDaVaga.SELECAO && !it.copy(agora = relogio()).selecaoDisponivel ->
                    it.copy(errosDeCampo = it.errosDeCampo + (CampoPublicacao.MODO to TextosPublicarVaga.SELECAO_SEM_ANTECEDENCIA_CAMPO))
                else -> it.copy(modo = modo, errosDeCampo = it.errosDeCampo - CampoPublicacao.MODO - CampoPublicacao.INICIO, erro = null)
            }
        }
    }

    fun editarLocal(local: String) = editar(CampoPublicacao.LOCAL, CampoPublicacao.ESTABELECIMENTO) { copy(local = local) }

    fun editarValor(texto: String) = editar(CampoPublicacao.VALOR) { copy(valor = texto) }

    fun editarPosicoes(texto: String) = editar(CampoPublicacao.POSICOES) { copy(posicoes = texto.filter(Char::isDigit).take(3)) }

    fun maisUmaPosicao() = editar(CampoPublicacao.POSICOES) {
        copy(posicoes = ((posicoes.toIntOrNull() ?: 0) + 1).coerceIn(POSICOES_MIN_UI, POSICOES_MAX_UI).toString())
    }

    fun menosUmaPosicao() = editar(CampoPublicacao.POSICOES) {
        copy(posicoes = ((posicoes.toIntOrNull() ?: 2) - 1).coerceIn(POSICOES_MIN_UI, POSICOES_MAX_UI).toString())
    }

    fun alternarRefeicao(incluida: Boolean) = editar { copy(incluiRefeicao = incluida) }

    fun alternarTransporte(incluido: Boolean) = editar { copy(incluiTransporte = incluido) }

    fun alternarMaterialProprio(exige: Boolean) = editar { copy(exigeMaterialProprio = exige) }

    fun editarResponsavel(texto: String) = editar(CampoPublicacao.RESPONSAVEL) { copy(responsavelLocal = texto) }

    fun editarTraje(texto: String) = editar(CampoPublicacao.TRAJE) { copy(traje = texto) }

    fun editarObservacoes(texto: String) = editar(CampoPublicacao.OBSERVACOES) { copy(observacoes = texto) }

    fun alternarRateio(participa: Boolean) = editar { copy(participaRateio = participa) }

    /**
     * Valida e publica. Sem efeito durante o envio ou depois de publicada: o segundo toque não cria duas
     * vagas. Com uma publicação [EstadoPublicarVaga.pendente], reenvia o mesmo corpo sem validar de novo.
     */
    fun publicar(): Job {
        val atual = _estado.value
        if (atual.enviando || atual.concluida) return escopoDeTrabalho.launch { }

        val corpo = atual.pendente ?: run {
            val hora = relogio()
            val validado = atual.copy(agora = hora)
            val erros = validar(validado)
            if (erros.isNotEmpty()) {
                _estado.update { it.copy(errosDeCampo = erros, erro = null, agora = hora) }
                return escopoDeTrabalho.launch { }
            }
            montarCorpo(validado)
        }
        _estado.update { it.copy(enviando = true, errosDeCampo = emptyMap(), erro = null, pendente = corpo) }
        return escopoDeTrabalho.launch {
            try {
                val publicada = enviarVaga(corpo)
                _estado.update { it.copy(enviando = false, publicada = publicada, pendente = null) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                _estado.update { aplicarRecusa(it.copy(enviando = false), erro) }
            } catch (_: Exception) {
                // Corpo não-JSON de gateway ou campo ausente escapam do ErroDaApi; sem isto o botão
                // ficaria em "Publicando…" para sempre. O resultado é incerto: o corpo (e a chave) ficam
                // pendentes para um reenvio idempotente. A mensagem nunca carrega o corpo cru.
                _estado.update { it.copy(enviando = false, erro = ErroGlobalPublicacao.GENERICO) }
            }
        }
    }

    private fun montarCorpo(estado: EstadoPublicarVaga): NovaVagaDto = NovaVagaDto(
        estabelecimentoId = estabelecimento.id,
        funcaoId = estado.funcaoId!!,
        inicioEm = estado.inicio.truncatedTo(ChronoUnit.SECONDS).toString(),
        fimEm = estado.fim.truncatedTo(ChronoUnit.SECONDS).toString(),
        local = estado.local.trim(),
        regiaoAdministrativa = estabelecimento.regiaoAdministrativa,
        ponto = estabelecimento.ponto,
        valorCentavos = estado.valorCentavos!!,
        posicoes = estado.posicoesNumero!!,
        incluiRefeicao = estado.incluiRefeicao,
        incluiTransporte = estado.incluiTransporte,
        exigeMaterialProprio = estado.exigeMaterialProprio,
        responsavelLocal = estado.responsavelLocal.trim(),
        traje = estado.traje.trim().ifEmpty { null },
        participaRateio = estado.participaRateio,
        observacoes = estado.observacoes.trim().ifEmpty { null },
        modo = estado.modo.chave,
        chave = novaChave(),
    )

    private fun validar(estado: EstadoPublicarVaga): Map<CampoPublicacao, String> = buildMap {
        if (estabelecimento.id.isBlank() || estabelecimento.regiaoAdministrativa.isBlank() ||
            !estabelecimento.ponto.latitude.isFinite() || !estabelecimento.ponto.longitude.isFinite()
        ) {
            put(CampoPublicacao.ESTABELECIMENTO, TextosPublicarVaga.ESTABELECIMENTO_CAMPO)
        }
        if (estado.funcoes.none { it.id == estado.funcaoId }) put(CampoPublicacao.FUNCAO, TextosPublicarVaga.FUNCAO_CAMPO)
        if (!estado.inicio.isAfter(estado.agora)) {
            put(CampoPublicacao.INICIO, TextosPublicarVaga.HORARIO_INICIO_CAMPO)
        } else if (estado.modo == ModoDaVaga.SELECAO && !estado.selecaoDisponivel) {
            // O relógio que vale é o do servidor; esta conferência só poupa a viagem.
            put(CampoPublicacao.INICIO, TextosPublicarVaga.SELECAO_SEM_ANTECEDENCIA_CAMPO)
        }
        if (!estado.fim.isAfter(estado.inicio)) put(CampoPublicacao.FIM, TextosPublicarVaga.HORARIO_FIM_CAMPO)
        if (estado.local.isBlank()) put(CampoPublicacao.LOCAL, TextosPublicarVaga.LOCAL_CAMPO)
        if (estado.valorCentavos == null) put(CampoPublicacao.VALOR, TextosPublicarVaga.VALOR_CAMPO)
        if (estado.posicoesNumero == null) put(CampoPublicacao.POSICOES, TextosPublicarVaga.POSICOES_CAMPO)
        if (estado.responsavelLocal.isBlank()) put(CampoPublicacao.RESPONSAVEL, TextosPublicarVaga.RESPONSAVEL_CAMPO)
    }

    private fun aplicarRecusa(estado: EstadoPublicarVaga, erro: ErroDaApi): EstadoPublicarVaga {
        // Recusa definitiva: repetir o mesmo corpo não pode virar sucesso, então ele sai e a edição volta.
        val liberado = if (erro.codigo.recusaDefinitivaDePublicacao) estado.copy(pendente = null) else estado
        return when (erro.codigo) {
            CodigoErroAPI.SELECAO_SEM_ANTECEDENCIA -> liberado.copy(
                errosDeCampo = mapOf(CampoPublicacao.INICIO to TextosPublicarVaga.SELECAO_SEM_ANTECEDENCIA_CAMPO),
                erro = ErroGlobalPublicacao.SELECAO_SEM_ANTECEDENCIA,
            )
            CodigoErroAPI.HORARIO_INVALIDO -> liberado.copy(
                errosDeCampo = mapOf(
                    CampoPublicacao.INICIO to TextosPublicarVaga.HORARIO_INICIO_CAMPO,
                    CampoPublicacao.FIM to TextosPublicarVaga.HORARIO_FIM_CAMPO,
                ),
                erro = ErroGlobalPublicacao.CONFIRA_CAMPOS,
            )
            CodigoErroAPI.CAMPO_OBRIGATORIO, CodigoErroAPI.CAMPO_INVALIDO -> {
                val mensagem = if (erro.codigo == CodigoErroAPI.CAMPO_OBRIGATORIO) {
                    TextosPublicarVaga.CAMPO_OBRIGATORIO
                } else {
                    TextosPublicarVaga.CAMPO_INVALIDO
                }
                val campos = camposDaRecusa(erro.detalhes)
                liberado.copy(errosDeCampo = campos.associateWith { mensagem }, erro = ErroGlobalPublicacao.CONFIRA_CAMPOS)
            }
            CodigoErroAPI.FUNCAO_INCOMPATIVEL -> liberado.copy(
                errosDeCampo = mapOf(CampoPublicacao.FUNCAO to TextosPublicarVaga.CAMPO_INVALIDO),
                erro = ErroGlobalPublicacao.CONFIRA_CAMPOS,
            )
            CodigoErroAPI.PERFIL_INCOMPATIVEL -> liberado.copy(erro = ErroGlobalPublicacao.PERFIL_INCOMPATIVEL)
            CodigoErroAPI.CONTA_SUSPENSA -> liberado.copy(erro = ErroGlobalPublicacao.CONTA_SUSPENSA)
            CodigoErroAPI.SEM_PERMISSAO -> liberado.copy(
                erro = if (erro.detalhes == "conta_suspensa") ErroGlobalPublicacao.CONTA_SUSPENSA else ErroGlobalPublicacao.SEM_PERMISSAO,
            )
            CodigoErroAPI.NAO_AUTENTICADO -> liberado.copy(erro = ErroGlobalPublicacao.SESSAO_EXPIRADA)
            CodigoErroAPI.SEM_REDE -> liberado.copy(erro = ErroGlobalPublicacao.SEM_REDE)
            else -> liberado.copy(erro = ErroGlobalPublicacao.GENERICO)
        }
    }

    /** O servidor devolve o nome do campo do contrato em `details`. */
    private fun camposDaRecusa(detalhes: String?): Set<CampoPublicacao> = when (detalhes) {
        "estabelecimento_id", "regiao_administrativa", "ponto", "latitude", "longitude" -> setOf(CampoPublicacao.ESTABELECIMENTO)
        "funcao_id" -> setOf(CampoPublicacao.FUNCAO)
        "inicio_em" -> setOf(CampoPublicacao.INICIO)
        "fim_em" -> setOf(CampoPublicacao.FIM)
        "local" -> setOf(CampoPublicacao.LOCAL)
        "valor_centavos" -> setOf(CampoPublicacao.VALOR)
        "posicoes" -> setOf(CampoPublicacao.POSICOES)
        "responsavel_local" -> setOf(CampoPublicacao.RESPONSAVEL)
        "modo" -> setOf(CampoPublicacao.MODO)
        "traje" -> setOf(CampoPublicacao.TRAJE)
        "observacoes" -> setOf(CampoPublicacao.OBSERVACOES)
        else -> emptySet()
    }

    private companion object {
        val INICIO_PADRAO: Duration = Duration.ofHours(3)
        val DURACAO_PADRAO: Duration = Duration.ofHours(3)
        const val POSICOES_MIN_UI = EstadoPublicarVaga.POSICOES_MIN
        const val POSICOES_MAX_UI = EstadoPublicarVaga.POSICOES_MAX
    }
}
