package br.com.frila.feature.vagas.painel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.PainelDto
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
)

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
)

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

    private suspend fun ler() {
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
            .onFailure { erro -> falhar(erro) }
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
            )
        }
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
        )
    }

    companion object {
        val FUSO_DO_PAINEL: ZoneId = ZoneId.of("America/Sao_Paulo")
        const val JANELA_EM_DIAS = 365L
        private const val MODO_SELECAO = "selecao"
        private const val VAGA_PUBLICADA = "publicada"
        private const val POSICAO_ABERTA = "aberta"
        private const val POSICAO_CONFIRMADA = "confirmada"
        private const val POSICAO_CUMPRIDA = "cumprida"
    }
}

private fun lerInstante(texto: String): Instant? = runCatching { Instant.parse(texto) }.getOrNull()

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
