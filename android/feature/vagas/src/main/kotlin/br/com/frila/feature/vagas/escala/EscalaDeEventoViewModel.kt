package br.com.frila.feature.vagas.escala

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.EscalaPublicadaDto
import br.com.frila.core.rede.EventoDaEscalaDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.ItemEscalaDto
import br.com.frila.core.rede.NovaEscalaDto
import br.com.frila.feature.vagas.publicacao.EstabelecimentoDaVaga
import br.com.frila.feature.vagas.publicacao.FUSO_DA_VAGA
import br.com.frila.feature.vagas.publicacao.ModoDaVaga
import br.com.frila.feature.vagas.publicacao.lerCentavos
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.temporal.ChronoUnit
import java.util.UUID
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.flow.updateAndGet
import kotlinx.coroutines.launch

/** Campos do evento que podem receber uma recusa. */
enum class CampoDoEvento { ESTABELECIMENTO, NOME, DATA }

/** Campos de uma vaga da escala que podem receber uma recusa. */
enum class CampoDoItem { FUNCAO, INICIO, FIM, VALOR, POSICOES, RESPONSAVEL, MODO, TRAJE, OBSERVACOES }

/** Erro que não é de um campo só, mostrado junto ao botão. */
enum class ErroGlobalEscala(val mensagem: String) {
    CONFIRA_CAMPOS(TextosEscala.ERRO_CONFIRA_CAMPOS),
    QUANTIDADE(TextosEscala.ERRO_QUANTIDADE),
    SOMA_DE_POSICOES(TextosEscala.ERRO_SOMA_DE_POSICOES),
    CADASTRO_DA_CASA(TextosEscala.ERRO_CADASTRO_DA_CASA),
    PERFIL_INCOMPATIVEL(TextosEscala.ERRO_PERFIL_INCOMPATIVEL),
    SEM_PERMISSAO(TextosEscala.ERRO_SEM_PERMISSAO),
    CONTA_SUSPENSA(TextosEscala.ERRO_CONTA_SUSPENSA),
    SESSAO_EXPIRADA(TextosEscala.ERRO_SESSAO),
    SEM_REDE(TextosEscala.ERRO_SEM_REDE),
    LIMITE_EXCEDIDO(TextosEscala.ERRO_LIMITE_EXCEDIDO),
    GENERICO(TextosEscala.ERRO_GENERICO),
}

/** Uma vaga da escala. [id] é só da tela (a chave da lista e do erro); não vai ao servidor. */
data class ItemDaEscala(
    val id: Int,
    val funcaoId: String? = null,
    val inicio: Instant,
    val fim: Instant,
    val modo: ModoDaVaga = ModoDaVaga.URGENCIA,
    /** Texto digitado, em reais, por pessoa. */
    val valor: String = "",
    val posicoes: String = "1",
    val incluiRefeicao: Boolean = false,
    val incluiTransporte: Boolean = false,
    val exigeMaterialProprio: Boolean = false,
    val responsavelLocal: String = "",
    val traje: String = "",
    val observacoes: String = "",
) {
    val valorCentavos: Long? get() = lerCentavos(valor)

    /** De 1 a 100: na escala o limite por vaga é 100, e não 200 como na vaga avulsa. */
    val posicoesNumero: Int? get() = posicoes.toIntOrNull()?.takeIf { it in EstadoEscalaDeEvento.POSICOES_MIN..EstadoEscalaDeEvento.POSICOES_MAX }
}

data class EstadoEscalaDeEvento(
    val funcoes: List<FuncaoDto> = emptyList(),
    val carregandoFuncoes: Boolean = false,
    val falhaAoCarregarFuncoes: Boolean = false,
    val nome: String = "",
    val data: LocalDate,
    val itens: List<ItemDaEscala>,
    val enviando: Boolean = false,
    val errosDoEvento: Map<CampoDoEvento, String> = emptyMap(),
    /** Recusas por vaga, pelo [ItemDaEscala.id]: sobrevivem a remover outra vaga. */
    val errosDosItens: Map<Int, Map<CampoDoItem, String>> = emptyMap(),
    val erro: ErroGlobalEscala? = null,
    val publicada: EscalaPublicadaDto? = null,
    /**
     * A escala já montada, com a `chave` de idempotência, enquanto o resultado é incerto (sem rede, resposta
     * ilegível). Reenviar manda exatamente este corpo: a mesma escala, nunca uma segunda.
     */
    val pendente: NovaEscalaDto? = null,
    /** O relógio do aparelho no último cálculo; a seleção (RN24) depende dele. */
    val agora: Instant,
) {
    val concluida: Boolean get() = publicada != null
    val podeEditar: Boolean get() = !enviando && !concluida && pendente == null
    val podeAdicionar: Boolean get() = podeEditar && itens.size < MAXIMO_DE_VAGAS
    val podeRemover: Boolean get() = podeEditar && itens.size > 1

    /** Soma das posições que já são números válidos; é o que o aviso de total mostra. */
    val totalDePessoas: Int get() = itens.sumOf { it.posicoesNumero ?: 0 }

    /** RN24: a seleção só existe com o início a mais de 24 horas. */
    fun selecaoDisponivel(item: ItemDaEscala): Boolean = item.inicio.isAfter(agora.plus(ANTECEDENCIA_DA_SELECAO))

    companion object {
        const val MAXIMO_DE_VAGAS = 10
        const val POSICOES_MIN = 1
        const val POSICOES_MAX = 100
        val ANTECEDENCIA_DA_SELECAO: Duration = Duration.ofHours(24)
    }
}

/**
 * Publicação de uma escala de evento pela casa (RF19, `publicar_escala`, contrato 0.2.96): o evento e de 1 a 10
 * vagas de uma vez, tudo ou nada. Valida o que o contrato exige antes da rede e mostra todos os campos errados
 * de uma vez; o servidor continua sendo a regra (soma de posições, antecedência, termos).
 *
 * Idempotência: a `chave` é uma só para a escala inteira e nasce uma vez por publicação. Se a resposta se perde
 * (sem rede, corpo que não é JSON), o formulário trava e "Tentar novamente" reenvia o mesmo corpo com a mesma
 * `chave`: o servidor devolve a mesma escala. Só uma recusa que prova que nada foi gravado descarta o corpo e libera a
 * edição, com `chave` nova na próxima tentativa (ver [soltaAEscala], igual ao iOS). Nenhuma falha deixa o botão preso.
 *
 * [buscarFuncoes] é `ServicoVagas.listarFuncoes`; [enviarEscala] é `ServicoVagas.publicarEscala`. [relogio] e
 * [novaChave] existem para o teste. [escopo]: mesma razão do `PublicarVagaViewModel`.
 */
class EscalaDeEventoViewModel(
    private val estabelecimento: EstabelecimentoDaVaga,
    private val buscarFuncoes: suspend () -> List<FuncaoDto>,
    private val enviarEscala: suspend (NovaEscalaDto) -> EscalaPublicadaDto,
    private val relogio: () -> Instant = Instant::now,
    private val novaChave: () -> String = { UUID.randomUUID().toString() },
    escopo: CoroutineScope? = null,
    /** A escala pendente de cada casa, acima da tela: ver [GuardaDaEscala]. Sem ela, a pendência some com o view model. */
    private val guarda: GuardaDaEscala? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope
    private var proximoId = 0

    /** O endereço da casa, onde o evento acontece (vem do cadastro; a tela só o mostra). */
    val enderecoDoEvento: String get() = estabelecimento.endereco

    /** A escala que a visita anterior desta casa deixou e a geração em que esta visita nasceu ([GuardaDaEscala]), lidas juntas. */
    private val visitaGuardada: Pair<EstadoEscalaDeEvento?, Int>? = guarda?.abrir(estabelecimento.id)
    private val geracaoDaVisita: Int = visitaGuardada?.second ?: 0

    private val _estado = MutableStateFlow(visitaGuardada?.first?.let(::restaurar) ?: estadoInicial())
    val estado: StateFlow<EstadoEscalaDeEvento> = _estado.asStateFlow()

    private fun estadoInicial(): EstadoEscalaDeEvento {
        val agora = relogio()
        val data = agora.atZone(FUSO_DA_VAGA).toLocalDate().plusDays(DIAS_ATE_O_EVENTO)
        return EstadoEscalaDeEvento(data = data, itens = listOf(itemNovo(data)), agora = agora)
    }

    /**
     * Volta à escala que ficou pendente (o formulário como estava e o corpo com a mesma `chave`). Sem envio em curso: o toque anterior
     * foi interrompido e o resultado dele é desconhecido, então só "Tentar novamente" reenvia, e com o corpo guardado.
     */
    private fun restaurar(guardado: EstadoEscalaDeEvento): EstadoEscalaDeEvento {
        proximoId = (guardado.itens.maxOfOrNull { it.id } ?: -1) + 1
        return guardado.copy(enviando = false)
    }

    /** Muda o estado e mantém a guarda em dia: com pendência ela guarda o estado; sem (sucesso, recusa definitiva), a casa sai. */
    private fun atualizarGuardando(mudar: (EstadoEscalaDeEvento) -> EstadoEscalaDeEvento) {
        val novo = _estado.updateAndGet(mudar)
        if (novo.pendente != null) {
            guarda?.guardar(estabelecimento.id, novo, geracaoDaVisita)
        } else {
            guarda?.remover(estabelecimento.id, geracaoDaVisita)
        }
    }

    private fun itemNovo(data: LocalDate, modelo: ItemDaEscala? = null): ItemDaEscala {
        val inicio = modelo?.inicio ?: data.atTime(INICIO_PADRAO).atZone(FUSO_DA_VAGA).toInstant()
        val fim = modelo?.fim ?: inicio.plus(DURACAO_PADRAO)
        return ItemDaEscala(id = proximoId++, inicio = inicio, fim = fim, responsavelLocal = modelo?.responsavelLocal.orEmpty())
    }

    private fun editar(mudar: EstadoEscalaDeEvento.() -> EstadoEscalaDeEvento) {
        _estado.update { if (it.podeEditar) it.mudar().copy(erro = null, agora = relogio()) else it }
    }

    private fun editarItem(
        id: Int,
        vararg campos: CampoDoItem,
        mudar: ItemDaEscala.() -> ItemDaEscala,
    ) = editar {
        copy(
            itens = itens.map { if (it.id == id) it.mudar() else it },
            errosDosItens = errosDosItens.limpar(id, campos.toSet()),
        )
    }

    private fun Map<Int, Map<CampoDoItem, String>>.limpar(id: Int, campos: Set<CampoDoItem>): Map<Int, Map<CampoDoItem, String>> {
        val restantes = this[id].orEmpty() - campos
        return if (restantes.isEmpty()) this - id else this + (id to restantes)
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
                _estado.update { it.copy(carregandoFuncoes = false, falhaAoCarregarFuncoes = true) }
            }
        }
    }

    fun editarNome(texto: String) = editar { copy(nome = texto, errosDoEvento = errosDoEvento - CampoDoEvento.NOME) }

    /** Mudar o dia do evento leva o início e o fim de todas as vagas junto, pelo mesmo número de dias. */
    fun editarData(nova: LocalDate) = editar {
        val dias = ChronoUnit.DAYS.between(data, nova)
        copy(
            data = nova,
            itens = itens.map { it.copy(inicio = it.inicio.somarDias(dias), fim = it.fim.somarDias(dias)) },
            errosDoEvento = errosDoEvento - CampoDoEvento.DATA,
            errosDosItens = errosDosItens.mapValues { (_, erros) -> erros - CampoDoItem.INICIO - CampoDoItem.MODO },
        )
    }

    private fun Instant.somarDias(dias: Long): Instant = atZone(FUSO_DA_VAGA).plusDays(dias).toInstant()

    /** A vaga nova nasce com o horário e o responsável da última, para a escala não pedir tudo de novo. */
    fun adicionarVaga() = editar {
        if (itens.size >= EstadoEscalaDeEvento.MAXIMO_DE_VAGAS) this else copy(itens = itens + itemNovo(data, itens.lastOrNull()))
    }

    fun removerVaga(id: Int) = editar {
        if (itens.size <= 1) this else copy(itens = itens.filterNot { it.id == id }, errosDosItens = errosDosItens - id)
    }

    fun escolherFuncao(id: Int, funcaoId: String) = editarItem(id, CampoDoItem.FUNCAO) { copy(funcaoId = funcaoId) }

    /** Mover o início leva o fim junto, para a duração não mudar. */
    fun editarInicio(id: Int, inicio: Instant) = editar {
        copy(
            itens = itens.map { item ->
                if (item.id != id) {
                    item
                } else {
                    val duracao = if (item.fim.isAfter(item.inicio)) Duration.between(item.inicio, item.fim) else DURACAO_PADRAO
                    val movido = item.copy(inicio = inicio, fim = inicio.plus(duracao))
                    // A seleção deixou de caber com o novo início: volta para urgência, que é o que a tela oferece.
                    val agoraDoCalculo = relogio()
                    if (movido.modo == ModoDaVaga.SELECAO && !movido.inicio.isAfter(agoraDoCalculo.plus(EstadoEscalaDeEvento.ANTECEDENCIA_DA_SELECAO))) {
                        movido.copy(modo = ModoDaVaga.URGENCIA)
                    } else {
                        movido
                    }
                }
            },
            errosDosItens = errosDosItens.limpar(id, setOf(CampoDoItem.INICIO, CampoDoItem.FIM, CampoDoItem.MODO)),
        )
    }

    fun editarFim(id: Int, fim: Instant) = editarItem(id, CampoDoItem.FIM) { copy(fim = fim) }

    fun escolherModo(id: Int, modo: ModoDaVaga) {
        _estado.update { atual ->
            val item = atual.itens.firstOrNull { it.id == id }
            when {
                !atual.podeEditar || item == null -> atual
                modo == ModoDaVaga.SELECAO && !atual.copy(agora = relogio()).selecaoDisponivel(item) ->
                    atual.copy(errosDosItens = atual.errosDosItens + (id to (atual.errosDosItens[id].orEmpty() + (CampoDoItem.MODO to TextosEscala.SELECAO_SEM_ANTECEDENCIA_CAMPO))))
                else -> atual.copy(
                    itens = atual.itens.map { if (it.id == id) it.copy(modo = modo) else it },
                    errosDosItens = atual.errosDosItens.limpar(id, setOf(CampoDoItem.MODO, CampoDoItem.INICIO)),
                    erro = null,
                )
            }
        }
    }

    fun editarValor(id: Int, texto: String) = editarItem(id, CampoDoItem.VALOR) { copy(valor = texto) }

    fun editarPosicoes(id: Int, texto: String) = editarItem(id, CampoDoItem.POSICOES) { copy(posicoes = texto.filter(Char::isDigit).take(3)) }

    fun alternarRefeicao(id: Int, incluida: Boolean) = editarItem(id) { copy(incluiRefeicao = incluida) }

    fun alternarTransporte(id: Int, incluido: Boolean) = editarItem(id) { copy(incluiTransporte = incluido) }

    fun alternarMaterialProprio(id: Int, exige: Boolean) = editarItem(id) { copy(exigeMaterialProprio = exige) }

    fun editarResponsavel(id: Int, texto: String) = editarItem(id, CampoDoItem.RESPONSAVEL) { copy(responsavelLocal = texto) }

    fun editarTraje(id: Int, texto: String) = editarItem(id, CampoDoItem.TRAJE) { copy(traje = texto) }

    fun editarObservacoes(id: Int, texto: String) = editarItem(id, CampoDoItem.OBSERVACOES) { copy(observacoes = texto) }

    /**
     * Valida e publica a escala inteira. Sem efeito durante o envio ou depois de publicada: o segundo toque não cria
     * duas escalas. Com uma publicação [EstadoEscalaDeEvento.pendente], reenvia o mesmo corpo sem validar de novo.
     */
    fun publicar(): Job {
        val atual = _estado.value
        if (atual.enviando || atual.concluida) return escopoDeTrabalho.launch { }

        // Com um corpo pendente este envio é o reenvio de uma tentativa que pode ter gravado (resposta perdida, app reaberto).
        val reenvio = atual.pendente != null
        val corpo = atual.pendente ?: run {
            val hora = relogio()
            val validado = atual.copy(agora = hora)
            val resultado = validar(validado)
            if (resultado.temErro) {
                _estado.update {
                    it.copy(
                        errosDoEvento = resultado.evento,
                        errosDosItens = resultado.itens,
                        erro = resultado.global ?: ErroGlobalEscala.CONFIRA_CAMPOS,
                        agora = hora,
                    )
                }
                return escopoDeTrabalho.launch { }
            }
            montarCorpo(validado)
        }
        atualizarGuardando { it.copy(enviando = true, errosDoEvento = emptyMap(), errosDosItens = emptyMap(), erro = null, pendente = corpo) }
        return escopoDeTrabalho.launch {
            try {
                val publicada = enviarEscala(corpo)
                atualizarGuardando { it.copy(enviando = false, publicada = publicada, pendente = null) }
            } catch (erro: CancellationException) {
                throw erro
            } catch (erro: ErroDaApi) {
                atualizarGuardando { aplicarRecusa(it.copy(enviando = false), erro, reenvio) }
            } catch (_: Exception) {
                // Corpo não-JSON de gateway ou campo ausente escapam do ErroDaApi; sem isto o botão ficaria em
                // "Publicando…" para sempre. O resultado é incerto: o corpo (e a chave) ficam pendentes para um
                // reenvio idempotente. A mensagem nunca carrega o corpo cru.
                atualizarGuardando { it.copy(enviando = false, erro = ErroGlobalEscala.GENERICO) }
            }
        }
    }

    private fun montarCorpo(estado: EstadoEscalaDeEvento): NovaEscalaDto = NovaEscalaDto(
        estabelecimentoId = estabelecimento.id,
        evento = EventoDaEscalaDto(
            nome = estado.nome.trim(),
            data = estado.data.toString(),
            local = estabelecimento.endereco.trim(),
            regiaoAdministrativa = estabelecimento.regiaoAdministrativa,
            ponto = estabelecimento.ponto,
        ),
        vagas = estado.itens.map { item ->
            ItemEscalaDto(
                funcaoId = item.funcaoId!!,
                inicioEm = item.inicio.truncatedTo(ChronoUnit.SECONDS).toString(),
                fimEm = item.fim.truncatedTo(ChronoUnit.SECONDS).toString(),
                valorCentavos = item.valorCentavos!!,
                posicoes = item.posicoesNumero!!,
                incluiRefeicao = item.incluiRefeicao,
                incluiTransporte = item.incluiTransporte,
                exigeMaterialProprio = item.exigeMaterialProprio,
                responsavelLocal = item.responsavelLocal.trim(),
                traje = item.traje.trim().ifEmpty { null },
                observacoes = item.observacoes.trim().ifEmpty { null },
                modo = item.modo.chave,
            )
        },
        chave = novaChave(),
    )

    private class ResultadoDaValidacao(
        val evento: Map<CampoDoEvento, String>,
        val itens: Map<Int, Map<CampoDoItem, String>>,
        val global: ErroGlobalEscala?,
    ) {
        val temErro: Boolean get() = evento.isNotEmpty() || itens.isNotEmpty() || global != null
    }

    private fun validar(estado: EstadoEscalaDeEvento): ResultadoDaValidacao {
        val evento = buildMap {
            if (estabelecimento.id.isBlank() || estabelecimento.endereco.isBlank() || estabelecimento.regiaoAdministrativa.isBlank() ||
                !estabelecimento.ponto.latitude.isFinite() || !estabelecimento.ponto.longitude.isFinite()
            ) {
                put(CampoDoEvento.ESTABELECIMENTO, TextosEscala.ESTABELECIMENTO_CAMPO)
            }
            if (estado.nome.trim().length !in NOME_MIN..NOME_MAX) put(CampoDoEvento.NOME, TextosEscala.NOME_CAMPO)
        }
        val itens = buildMap<Int, Map<CampoDoItem, String>> {
            estado.itens.forEach { item ->
                val erros = validarItem(item, estado)
                if (erros.isNotEmpty()) put(item.id, erros)
            }
        }
        val global = when {
            estado.itens.isEmpty() || estado.itens.size > EstadoEscalaDeEvento.MAXIMO_DE_VAGAS -> ErroGlobalEscala.QUANTIDADE
            itens.isEmpty() && estado.totalDePessoas > EstadoEscalaDeEvento.POSICOES_MAX -> ErroGlobalEscala.SOMA_DE_POSICOES
            else -> null
        }
        return ResultadoDaValidacao(evento, itens, global)
    }

    private fun validarItem(item: ItemDaEscala, estado: EstadoEscalaDeEvento): Map<CampoDoItem, String> = buildMap {
        if (estado.funcoes.none { it.id == item.funcaoId }) put(CampoDoItem.FUNCAO, TextosEscala.FUNCAO_CAMPO)
        if (!item.inicio.isAfter(estado.agora)) {
            put(CampoDoItem.INICIO, TextosEscala.QUANDO_CAMPO_INICIO)
        } else if (item.modo == ModoDaVaga.SELECAO && !estado.selecaoDisponivel(item)) {
            // O relógio que vale é o do servidor; esta conferência só poupa a viagem.
            put(CampoDoItem.INICIO, TextosEscala.SELECAO_SEM_ANTECEDENCIA_CAMPO)
        }
        if (!item.fim.isAfter(item.inicio)) put(CampoDoItem.FIM, TextosEscala.QUANDO_CAMPO_FIM)
        if (item.valorCentavos == null) put(CampoDoItem.VALOR, TextosEscala.VALOR_CAMPO)
        if (item.posicoesNumero == null) put(CampoDoItem.POSICOES, TextosEscala.POSICOES_CAMPO)
        if (item.responsavelLocal.isBlank()) put(CampoDoItem.RESPONSAVEL, TextosEscala.RESPONSAVEL_CAMPO)
    }

    /**
     * Quando a recusa solta o corpo e a `chave` (a edição volta, a próxima tentativa nasce com `chave` nova). O servidor confere, nesta
     * ordem: autenticação (401), quem pode (perfil, conta suspensa, membro), a `chave` (já usada: devolve a escala gravada e para) e só
     * então o corpo. O limite de escrita (429) sai antes da função rodar.
     *  - Recusa de CONTEÚDO vem depois da `chave`: prova que nada foi gravado, na primeira tentativa e no reenvio.
     *  - As demais recusas definitivas, 401 e 429 saem antes de a `chave` ser olhada: na primeira tentativa nada foi gravado e soltam;
     *    no reenvio de uma tentativa incerta não provam nada sobre ela. Soltar então deixaria o próximo envio sair com `chave` nova e
     *    publicar a escala em dobro; o corpo e a `chave` ficam (PublicarEscalaViewModel.swift:293-327).
     */
    private fun soltaAEscala(erro: ErroDaApi, reenvio: Boolean): Boolean = when {
        erro.codigo in RECUSAS_DE_CONTEUDO -> true
        reenvio -> false
        else -> erro.codigo.recusaDefinitivaDePublicacao || erro.codigo == CodigoErroAPI.LIMITE_EXCEDIDO ||
            erro.codigo == CodigoErroAPI.NAO_AUTENTICADO
    }

    private fun aplicarRecusa(estado: EstadoEscalaDeEvento, erro: ErroDaApi, reenvio: Boolean): EstadoEscalaDeEvento {
        val liberado = if (soltaAEscala(erro, reenvio)) estado.copy(pendente = null) else estado
        val caminho = CaminhoDoErro.de(erro.detalhes)
        val idDoItem = caminho.indice?.let { liberado.itens.getOrNull(it)?.id }
        return when (erro.codigo) {
            CodigoErroAPI.SELECAO_SEM_ANTECEDENCIA -> liberado.comErroDeItem(
                idDoItem,
                mapOf(CampoDoItem.INICIO to TextosEscala.SELECAO_SEM_ANTECEDENCIA_CAMPO, CampoDoItem.MODO to TextosEscala.SELECAO_SEM_ANTECEDENCIA_CAMPO),
            )
            CodigoErroAPI.HORARIO_INVALIDO -> liberado.comErroDeItem(
                idDoItem,
                mapOf(CampoDoItem.INICIO to TextosEscala.QUANDO_CAMPO_INICIO, CampoDoItem.FIM to TextosEscala.QUANDO_CAMPO_FIM),
            )
            CodigoErroAPI.CAMPO_OBRIGATORIO, CodigoErroAPI.CAMPO_INVALIDO -> {
                val mensagem = if (erro.codigo == CodigoErroAPI.CAMPO_OBRIGATORIO) TextosEscala.CAMPO_OBRIGATORIO else TextosEscala.CAMPO_INVALIDO
                liberado.aplicarCampo(caminho, idDoItem, mensagem)
            }
            CodigoErroAPI.FUNCAO_INCOMPATIVEL -> liberado.comErroDeItem(idDoItem, mapOf(CampoDoItem.FUNCAO to TextosEscala.CAMPO_INVALIDO))
            CodigoErroAPI.PERFIL_INCOMPATIVEL -> liberado.copy(erro = ErroGlobalEscala.PERFIL_INCOMPATIVEL)
            CodigoErroAPI.CONTA_SUSPENSA -> liberado.copy(erro = ErroGlobalEscala.CONTA_SUSPENSA)
            CodigoErroAPI.SEM_PERMISSAO -> liberado.copy(
                erro = if (erro.detalhes == "conta_suspensa") ErroGlobalEscala.CONTA_SUSPENSA else ErroGlobalEscala.SEM_PERMISSAO,
            )
            CodigoErroAPI.NAO_AUTENTICADO -> liberado.copy(erro = ErroGlobalEscala.SESSAO_EXPIRADA)
            CodigoErroAPI.SEM_REDE -> liberado.copy(erro = ErroGlobalEscala.SEM_REDE)
            // 429: o limite de escrita. Só a mensagem; quem solta a escala é soltaAEscala (primeira tentativa solta, reenvio mantém).
            CodigoErroAPI.LIMITE_EXCEDIDO -> liberado.copy(erro = ErroGlobalEscala.LIMITE_EXCEDIDO)
            else -> liberado.copy(erro = ErroGlobalEscala.GENERICO)
        }
    }

    /** Sem item identificável, a recusa de item vira o erro geral "confira os campos": melhor que apontar a vaga errada. */
    private fun EstadoEscalaDeEvento.comErroDeItem(id: Int?, erros: Map<CampoDoItem, String>): EstadoEscalaDeEvento =
        if (id == null) copy(erro = ErroGlobalEscala.CONFIRA_CAMPOS) else copy(errosDosItens = mapOf(id to erros), erro = ErroGlobalEscala.CONFIRA_CAMPOS)

    private fun EstadoEscalaDeEvento.aplicarCampo(caminho: CaminhoDoErro, idDoItem: Int?, mensagem: String): EstadoEscalaDeEvento {
        if (caminho.indice != null) {
            val campo = CAMPOS_DO_ITEM[caminho.campo]
            return if (idDoItem != null && campo != null) comErroDeItem(idDoItem, mapOf(campo to mensagem)) else copy(erro = ErroGlobalEscala.CONFIRA_CAMPOS)
        }
        return when (caminho.bruto) {
            "evento.nome" -> copy(errosDoEvento = mapOf(CampoDoEvento.NOME to TextosEscala.NOME_CAMPO), erro = ErroGlobalEscala.CONFIRA_CAMPOS)
            "evento.data" -> copy(errosDoEvento = mapOf(CampoDoEvento.DATA to TextosEscala.DATA_CAMPO), erro = ErroGlobalEscala.CONFIRA_CAMPOS)
            // Endereço, região e ponto vêm do cadastro da casa: a pessoa conserta lá, não nesta tela.
            "evento.local", "evento.regiao_administrativa", "evento.ponto" -> copy(erro = ErroGlobalEscala.CADASTRO_DA_CASA)
            "vagas" -> copy(erro = ErroGlobalEscala.QUANTIDADE)
            "posicoes" -> copy(erro = ErroGlobalEscala.SOMA_DE_POSICOES)
            else -> copy(erro = ErroGlobalEscala.CONFIRA_CAMPOS)
        }
    }

    /** `details` da recusa: `evento.nome`, `vagas[2].valor_centavos`, `vagas[1]`, `vagas`, `posicoes`. */
    private class CaminhoDoErro(val bruto: String?, val indice: Int?, val campo: String?) {
        companion object {
            private val DO_ITEM = Regex("""^vagas\[(\d+)](?:\.(\w+))?$""")

            fun de(detalhes: String?): CaminhoDoErro {
                val achado = detalhes?.let { DO_ITEM.find(it) } ?: return CaminhoDoErro(detalhes, null, null)
                return CaminhoDoErro(detalhes, achado.groupValues[1].toIntOrNull(), achado.groupValues[2].ifEmpty { null })
            }
        }
    }

    private companion object {
        const val NOME_MIN = 3
        const val NOME_MAX = 100
        const val DIAS_ATE_O_EVENTO = 7L
        val INICIO_PADRAO: LocalTime = LocalTime.of(18, 0)
        val DURACAO_PADRAO: Duration = Duration.ofHours(4)

        /** Recusas da conferência do corpo, que o servidor faz depois de olhar a `chave` (iguais às do iOS, `recusaDeConteudo`). */
        val RECUSAS_DE_CONTEUDO = setOf(
            CodigoErroAPI.CAMPO_OBRIGATORIO, CodigoErroAPI.CAMPO_INVALIDO, CodigoErroAPI.HORARIO_INVALIDO,
            CodigoErroAPI.SELECAO_SEM_ANTECEDENCIA, CodigoErroAPI.FUNCAO_INCOMPATIVEL,
        )

        val CAMPOS_DO_ITEM = mapOf(
            "funcao_id" to CampoDoItem.FUNCAO,
            "inicio_em" to CampoDoItem.INICIO,
            "fim_em" to CampoDoItem.FIM,
            "valor_centavos" to CampoDoItem.VALOR,
            "posicoes" to CampoDoItem.POSICOES,
            "modo" to CampoDoItem.MODO,
            "responsavel_local" to CampoDoItem.RESPONSAVEL,
            "traje" to CampoDoItem.TRAJE,
            "observacoes" to CampoDoItem.OBSERVACOES,
        )
    }
}
