package br.com.frila.feature.vagas.painel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.regra.instanteDoServidor
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.PainelDto
import br.com.frila.core.rede.ResultadoRegistroDto
import br.com.frila.core.rede.VagaNoPainelDto
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** As seções de Minhas vagas, na ordem em que a tela as mostra (paridade com `SecaoMinhasVagas`). */
enum class SecaoMinhasVagas(val titulo: String) {
    EM_ALERTA(TextosMinhasVagas.EM_ALERTA),
    HOJE(TextosMinhasVagas.HOJE),
    PROXIMAS(TextosMinhasVagas.PROXIMAS),
    ENCERRADAS(TextosMinhasVagas.ENCERRADAS),
}

/** Por que o painel não carregou. */
enum class ErroMinhasVagas(val mensagem: String, val podeTentarDeNovo: Boolean) {
    SEM_REDE(TextosMinhasVagas.ERRO_SEM_REDE, true),
    SEM_PERMISSAO(TextosMinhasVagas.ERRO_SEM_PERMISSAO, false),
    SESSAO_EXPIRADA(TextosMinhasVagas.ERRO_SESSAO, false),
    SEM_ESTABELECIMENTO(TextosMinhasVagas.ERRO_SEM_ESTABELECIMENTO, false),
    GENERICO(TextosMinhasVagas.ERRO_GENERICO, true),
}

/** Uma posição com turno (confirmada ou cumprida): o que a tela precisa para abrir o acompanhamento dele. */
data class TurnoDoItem(val posicaoId: String, val nomeProfissional: String?)

/** Uma vaga como a lista a mostra: o painel já lido, classificado e com as contagens feitas. */
data class ItemMinhaVaga(
    val id: String,
    val funcao: String,
    val local: String,
    /** `null` se o servidor mandou um instante ilegível. */
    val inicio: Instant?,
    val fim: Instant?,
    val valorCentavos: Long,
    val selecao: Boolean,
    val oculta: Boolean,
    val alertaVagaVazia: Boolean,
    val candidatosPendentes: Int,
    val totalPosicoes: Int,
    val confirmadas: Int,
    val posicoesAbertas: Int,
    val emAtraso: Int,
    val secao: SecaoMinhasVagas,
    val recemPublicada: Boolean,
    /** Só vaga `publicada` tem candidatos a escolher: com pendentes, ou em modo seleção (RN24). */
    val podeVerCandidatos: Boolean,
    /** Quanto falta para o início, só quando a vaga precisa de atenção. */
    val comecaEm: Duration?,
    /** As posições com turno, para "Acompanhar turno". Vazia se ninguém foi confirmado. */
    val turnos: List<TurnoDoItem> = emptyList(),
    /** A casa ainda pode cancelar a vaga inteira: nem cancelada, nem encerrada, e antes do início (RN12). */
    val podeCancelar: Boolean = false,
    /** A vaga nasceu de uma chamada direta (`origem = chamada_direta`): é daqui que a casa acompanha as chamadas dela (CD-RF09). */
    val chamadaDireta: Boolean = false,
    /** Vaga encerrada, cancelada ou com o fim no passado: dá para republicar com outro horário (RF05). */
    val podeRepublicar: Boolean = false,
    /** Quantas posições a seleção deixou vazias e dá para republicar em urgência (0.2.41). Zero esconde o atalho. */
    val republicavelEmUrgencia: Int = 0,
)

/**
 * Um check-in manual esperando a confirmação da casa (`Painel.checkins_pendentes`), com o que o cartão de "Presenças a confirmar"
 * mostra e o que abre o turno (paridade com `pendentes` do `AcompanhamentoViewModel` do iOS).
 */
data class PresencaAConfirmar(
    val turnoId: String,
    val vagaId: String,
    val posicaoId: String,
    val nomeProfissional: String?,
    val funcao: String,
    val inicio: Instant?,
    val fim: Instant?,
)

/** O que a última confirmação de presença no cartão deixou para a tela dizer (mesmos textos da tela do turno da casa). */
enum class AvisoDaPresenca(val mensagem: String, val erro: Boolean) {
    CONFIRMADA(TextosMinhasVagas.PRESENCA_CONFIRMADA, false),
    SITUACAO_MUDOU(TextosMinhasVagas.SITUACAO_MUDOU, true),
    NAO_ENCONTRADO(TextosMinhasVagas.ERRO_PRESENCA_NAO_ENCONTRADO, true),
    SEM_PERMISSAO(TextosMinhasVagas.ERRO_PRESENCA_SEM_PERMISSAO, true),
    SESSAO_EXPIRADA(TextosMinhasVagas.ERRO_SESSAO, true),
    SEM_REDE(TextosMinhasVagas.ERRO_PRESENCA_SEM_REDE, true),
    GENERICO(TextosMinhasVagas.ERRO_PRESENCA_GENERICO, true),
}

sealed interface ListaMinhasVagas {
    data object Carregando : ListaMinhasVagas
    data object Vazio : ListaMinhasVagas
    data class Sucesso(val itens: List<ItemMinhaVaga>) : ListaMinhasVagas {
        fun daSecao(secao: SecaoMinhasVagas): List<ItemMinhaVaga> = itens.filter { it.secao == secao }
    }
    data class Erro(val erro: ErroMinhasVagas) : ListaMinhasVagas
}

data class EstadoMinhasVagas(
    val lista: ListaMinhasVagas = ListaMinhasVagas.Carregando,
    /** Releitura com a lista já na tela (puxar para atualizar). */
    val atualizando: Boolean = false,
    /** A última releitura falhou com vagas na tela: o que aparece pode estar velho. */
    val desatualizada: Boolean = false,
    /** Os check-ins manuais que esperam a casa, na ordem do painel; o topo da tela os mostra antes das seções. */
    val presencasAConfirmar: List<PresencaAConfirmar> = emptyList(),
    /** Turnos com a confirmação em voo: o botão deles fica desligado (trava contra o toque duplo). */
    val confirmando: Set<String> = emptySet(),
    /** Turnos que o servidor recusou desde a última leitura do painel: sem botão até o painel ser relido (como o iOS). */
    val recusadas: Set<String> = emptySet(),
    val avisoDaPresenca: AvisoDaPresenca? = null,
) {
    /** O botão "Confirmar presença" só existe para o pendente que o servidor não recusou desde a última leitura. */
    fun podeConfirmar(turnoId: String): Boolean =
        presencasAConfirmar.any { it.turnoId == turnoId } && turnoId !in recusadas
}

/**
 * Minhas vagas do contratante: o painel do estabelecimento na janela de 365 dias para trás e para a
 * frente, em seções (RF20, RN24, UC07; paridade com `MinhasVagasViewModel` de `MinhasVagas.swift`).
 *
 * As seções são decididas aqui, como no iOS: vaga encerrada, cancelada ou com o fim no passado vai para
 * Encerradas; senão, com posição aberta na janela crítica, para Precisa de atenção; senão, Hoje se o
 * início ou o fim cai no dia de hoje em Brasília; senão Próximas se ainda não começou. A classificação
 * vale para o relógio do momento da leitura; puxar para atualizar a refaz. O painel de outro
 * estabelecimento (id diferente do pedido) é recusado, e nenhuma falha, inclusive resposta que não é
 * JSON, deixa a tela em "Carregando".
 *
 * [buscarPainel] é `ServicoVagas.painelEstabelecimento`. `escopo`: mesma razão do `PerfilViewModel`.
 */
class MinhasVagasViewModel(
    val estabelecimentoId: String,
    val nomeEstabelecimento: String? = null,
    private val vagaRecemPublicadaId: String? = null,
    private val buscarPainel: suspend (estabelecimentoId: String, de: Instant, ate: Instant) -> Result<PainelDto>,
    /** `ServicoTurnos.confirmarCheckinManual`. Nulo: o cartão de "Presenças a confirmar" não oferece confirmar. */
    private val confirmarCheckin: (suspend (turnoId: String) -> Result<ResultadoRegistroDto>)? = null,
    private val relogio: () -> Instant = Instant::now,
    private val zona: ZoneId = FUSO_DO_PAINEL,
    escopo: CoroutineScope? = null,
) : ViewModel() {

    private val escopoDeTrabalho: CoroutineScope = escopo ?: viewModelScope

    private val _estado = MutableStateFlow(EstadoMinhasVagas())
    val estado: StateFlow<EstadoMinhasVagas> = _estado.asStateFlow()

    private var leitura: Job? = null

    /** Primeira leitura e "Tentar de novo". Sem efeito se já há uma leitura em voo. */
    fun carregar(): Job = iniciarLeitura()

    /** Puxar para atualizar: mantém as vagas na tela e mostra o indicador. */
    fun atualizar(): Job = iniciarLeitura()

    /**
     * Releitura automática (volta do segundo plano, push): troca as vagas sem indicador, e uma falha deixa a lista como está, sem
     * erro e sem marcá-la como desatualizada. Sem efeito com outra leitura em voo.
     */
    fun atualizarEmSilencio(): Job {
        leitura?.takeIf { it.isActive }?.let { return it }
        // Só com a lista na tela (como o iOS): em Carregando disputaria a carga e em Erro tiraria a tela do erro sem ser pedido. Com
        // outra leitura em voo a de cima devolve a própria, e por isso o estado não muda entre o começo e o fim desta.
        if (_estado.value.lista !is ListaMinhasVagas.Sucesso && _estado.value.lista != ListaMinhasVagas.Vazio) {
            return escopoDeTrabalho.launch { }
        }
        return escopoDeTrabalho.launch { ler(silencioso = true) }.also { leitura = it }
    }

    private fun iniciarLeitura(): Job {
        leitura?.takeIf { it.isActive }?.let { return it }
        _estado.update {
            when (it.lista) {
                is ListaMinhasVagas.Sucesso, ListaMinhasVagas.Vazio -> it.copy(atualizando = true)
                else -> it.copy(lista = ListaMinhasVagas.Carregando)
            }
        }
        return escopoDeTrabalho.launch { ler() }.also { leitura = it }
    }

    private suspend fun ler(silencioso: Boolean = false) {
        val agora = relogio()
        val resultado = try {
            val hoje = agora.atZone(zona)
            buscarPainel(estabelecimentoId, hoje.minusDays(JANELA_EM_DIAS).toInstant(), hoje.plusDays(JANELA_EM_DIAS).toInstant())
        } catch (erro: CancellationException) {
            throw erro
        } catch (erro: Exception) {
            // Quem chama devolve Result, mas um lançamento escapa; sem isto a tela ficaria em "Carregando".
            Result.failure(erro)
        }
        resultado
            .onSuccess { painel -> aplicar(painel, agora) }
            .onFailure { erro -> if (!silencioso) falhar(erro) }
    }

    private fun aplicar(painel: PainelDto, agora: Instant) {
        if (painel.estabelecimentoId != estabelecimentoId) {
            falhar(erro = null, tipo = ErroMinhasVagas.SEM_ESTABELECIMENTO)
            return
        }
        val itens = painel.vagas
            .map { it.paraItem(agora) }
            .sortedWith(
                compareBy<ItemMinhaVaga> { !it.recemPublicada }
                    .thenBy(nullsLast()) { it.inicio },
            )
        _estado.update {
            it.copy(
                lista = if (itens.isEmpty()) ListaMinhasVagas.Vazio else ListaMinhasVagas.Sucesso(itens),
                atualizando = false,
                desatualizada = false,
                presencasAConfirmar = presencasAConfirmar(painel),
                recusadas = emptySet(),
            )
        }
    }

    /** Cada turno de `checkins_pendentes` com a vaga e a posição dele no painel; um id que o painel não traz fica de fora. */
    private fun presencasAConfirmar(painel: PainelDto): List<PresencaAConfirmar> =
        painel.checkinsPendentes.distinct().mapNotNull { turnoId ->
            painel.vagas.firstNotNullOfOrNull { vagaNoPainel ->
                vagaNoPainel.posicoes.firstOrNull { it.turnoId == turnoId }?.let { posicao ->
                    PresencaAConfirmar(
                        turnoId = turnoId,
                        vagaId = vagaNoPainel.vaga.id,
                        posicaoId = posicao.id,
                        nomeProfissional = posicao.profissional?.nome,
                        funcao = vagaNoPainel.vaga.funcao,
                        inicio = lerInstante(vagaNoPainel.vaga.inicioEm),
                        fim = lerInstante(vagaNoPainel.vaga.fimEm),
                    )
                }
            }
        }

    /** Ainda há quem confirme pelo cartão (o caminho do servidor está ligado). */
    val confirmaPeloCartao: Boolean get() = confirmarCheckin != null

    /**
     * "Confirmar presença" no cartão de "Presenças a confirmar" (`confirmar_checkin_manual`, RN22; paridade com
     * `confirmarPresenca` do `AcompanhamentoViewModel` do iOS). Um toque por turno: com a confirmação em voo, ou depois de
     * uma recusa do servidor desde a última leitura, não envia. Confirmada, o cartão sai na hora e o painel é relido.
     * `409 checkin_ja_confirmado` ou `checkin_pendente` quer dizer que o painel estava velho: o botão some e o painel é
     * relido. Qualquer outra falha deixa o botão para tentar de novo (confirmar duas vezes só devolve o 409). Como no iOS, o
     * `Job` só termina depois da releitura.
     */
    fun confirmarPresenca(turnoId: String): Job {
        val confirmar = confirmarCheckin
        val atual = _estado.value
        if (confirmar == null || !atual.podeConfirmar(turnoId) || turnoId in atual.confirmando) return escopoDeTrabalho.launch { }
        _estado.update { it.copy(confirmando = it.confirmando + turnoId, avisoDaPresenca = null) }
        return escopoDeTrabalho.launch {
            val resultado = try {
                confirmar(turnoId)
            } catch (erro: CancellationException) {
                _estado.update { it.copy(confirmando = it.confirmando - turnoId) }
                throw erro
            } catch (erro: Exception) {
                Result.failure(erro)
            }
            resultado
                .onSuccess {
                    _estado.update {
                        it.copy(
                            confirmando = it.confirmando - turnoId,
                            presencasAConfirmar = it.presencasAConfirmar.filterNot { presenca -> presenca.turnoId == turnoId },
                            avisoDaPresenca = AvisoDaPresenca.CONFIRMADA,
                        )
                    }
                    relerDepoisDaConfirmacao().join()
                }
                .onFailure { erro ->
                    val codigo = (erro as? ErroDaApi)?.codigo
                    val situacaoMudou = codigo == CodigoErroAPI.CHECKIN_JA_CONFIRMADO || codigo == CodigoErroAPI.CHECKIN_PENDENTE
                    _estado.update {
                        it.copy(
                            confirmando = it.confirmando - turnoId,
                            recusadas = if (situacaoMudou) it.recusadas + turnoId else it.recusadas,
                            avisoDaPresenca = when {
                                situacaoMudou -> AvisoDaPresenca.SITUACAO_MUDOU
                                codigo == CodigoErroAPI.NAO_ENCONTRADO -> AvisoDaPresenca.NAO_ENCONTRADO
                                codigo == CodigoErroAPI.SEM_PERMISSAO -> AvisoDaPresenca.SEM_PERMISSAO
                                codigo == CodigoErroAPI.NAO_AUTENTICADO -> AvisoDaPresenca.SESSAO_EXPIRADA
                                codigo == CodigoErroAPI.SEM_REDE -> AvisoDaPresenca.SEM_REDE
                                else -> AvisoDaPresenca.GENERICO
                            },
                        )
                    }
                    if (situacaoMudou) relerDepoisDaConfirmacao().join()
                }
        }
    }

    /**
     * Relê o painel depois de uma confirmação (ou da recusa dela). Uma leitura que já estava em voo começou antes e traria o
     * pendente de volta: é cancelada e dá lugar a esta (o `geracao` do iOS). Falhar aqui deixa a lista como está.
     */
    private fun relerDepoisDaConfirmacao(): Job {
        leitura?.cancel()
        _estado.update { it.copy(atualizando = false) }
        return escopoDeTrabalho.launch { ler(silencioso = true) }.also { leitura = it }
    }

    private fun falhar(erro: Throwable?, tipo: ErroMinhasVagas = tipoDoErro(erro)) {
        _estado.update {
            when (it.lista) {
                // Com vagas na tela, a falha não as apaga: avisa que podem estar velhas.
                is ListaMinhasVagas.Sucesso, ListaMinhasVagas.Vazio -> it.copy(atualizando = false, desatualizada = true)
                else -> it.copy(lista = ListaMinhasVagas.Erro(tipo), atualizando = false)
            }
        }
    }

    private fun tipoDoErro(erro: Throwable?): ErroMinhasVagas = when ((erro as? ErroDaApi)?.codigo) {
        CodigoErroAPI.SEM_REDE -> ErroMinhasVagas.SEM_REDE
        CodigoErroAPI.SEM_PERMISSAO -> ErroMinhasVagas.SEM_PERMISSAO
        CodigoErroAPI.NAO_AUTENTICADO -> ErroMinhasVagas.SESSAO_EXPIRADA
        else -> ErroMinhasVagas.GENERICO
    }

    private fun VagaNoPainelDto.paraItem(agora: Instant): ItemMinhaVaga {
        val inicio = lerInstante(vaga.inicioEm)
        val fim = lerInstante(vaga.fimEm)
        val secao = classificarVaga(estado, inicio, fim, alertaVagaVazia, agora, zona)
        return ItemMinhaVaga(
            id = vaga.id,
            funcao = vaga.funcao,
            local = vaga.local,
            inicio = inicio,
            fim = fim,
            valorCentavos = vaga.valorCentavos,
            selecao = modo == MODO_SELECAO,
            oculta = oculta,
            alertaVagaVazia = alertaVagaVazia,
            candidatosPendentes = candidatosPendentes,
            totalPosicoes = posicoes.size,
            confirmadas = posicoes.count { it.estado == POSICAO_CONFIRMADA || it.estado == POSICAO_CUMPRIDA },
            posicoesAbertas = posicoes.count { it.estado == POSICAO_ABERTA },
            emAtraso = posicoes.count { it.emAtraso },
            secao = secao,
            recemPublicada = vaga.id == vagaRecemPublicadaId,
            podeVerCandidatos = estado == VAGA_PUBLICADA && (candidatosPendentes > 0 || modo == MODO_SELECAO),
            comecaEm = if (secao == SecaoMinhasVagas.EM_ALERTA && inicio != null) Duration.between(agora, inicio) else null,
            turnos = posicoes
                .filter { it.turnoId != null && (it.estado == POSICAO_CONFIRMADA || it.estado == POSICAO_CUMPRIDA) }
                .map { TurnoDoItem(posicaoId = it.id, nomeProfissional = it.profissional?.nome) },
            podeCancelar = estado != VAGA_CANCELADA && estado != VAGA_ENCERRADA && inicio != null && inicio.isAfter(agora),
            chamadaDireta = vaga.origem == ORIGEM_CHAMADA_DIRETA,
            podeRepublicar = inicio != null && fim != null &&
                (estado == VAGA_ENCERRADA || estado == VAGA_CANCELADA || !fim.isAfter(agora)),
            republicavelEmUrgencia = (republicavelEmUrgencia ?: 0).coerceAtLeast(0),
        )
    }

    companion object {
        val FUSO_DO_PAINEL: ZoneId = ZoneId.of("America/Sao_Paulo")
        const val JANELA_EM_DIAS = 365L
        private const val MODO_SELECAO = "selecao"
        private const val ORIGEM_CHAMADA_DIRETA = "chamada_direta"
        private const val VAGA_PUBLICADA = "publicada"
        private const val VAGA_ENCERRADA = "encerrada"
        private const val VAGA_CANCELADA = "cancelada"
        private const val POSICAO_ABERTA = "aberta"
        private const val POSICAO_CONFIRMADA = "confirmada"
        private const val POSICAO_CUMPRIDA = "cumprida"
    }
}

private fun lerInstante(texto: String): Instant? = runCatching { instanteDoServidor(texto) }.getOrNull()

/**
 * Em que seção a vaga fica, no relógio [agora] (`MinhasVagasViewModel.classificar` do iOS). Instante
 * ilegível não tem o que mostrar como atual: vai para Encerradas.
 */
internal fun classificarVaga(
    estado: String,
    inicio: Instant?,
    fim: Instant?,
    alertaVagaVazia: Boolean,
    agora: Instant,
    zona: ZoneId,
): SecaoMinhasVagas {
    if (inicio == null || fim == null) return SecaoMinhasVagas.ENCERRADAS
    if (estado == "encerrada" || estado == "cancelada" || !fim.isAfter(agora)) return SecaoMinhasVagas.ENCERRADAS
    if (alertaVagaVazia) return SecaoMinhasVagas.EM_ALERTA
    val hoje = agora.atZone(zona).toLocalDate()
    if (inicio.atZone(zona).toLocalDate() == hoje || fim.atZone(zona).toLocalDate() == hoje) return SecaoMinhasVagas.HOJE
    if (inicio.isAfter(agora)) return SecaoMinhasVagas.PROXIMAS
    return SecaoMinhasVagas.ENCERRADAS
}
