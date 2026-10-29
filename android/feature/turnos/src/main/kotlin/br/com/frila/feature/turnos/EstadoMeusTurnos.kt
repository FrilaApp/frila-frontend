package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.ComprovanteCheckin
import br.com.frila.core.dominio.modelo.MotivoCancelamento
import java.time.Instant

/** Status da tela de meus turnos. */
enum class StatusMeusTurnos { CARREGANDO, SUCESSO, VAZIO, ERRO }

/** Aba selecionada: Agendados (`confirmada`) ou Histórico (`cumprida`/`cancelada`). */
enum class AbaDeTurnos { AGENDADOS, HISTORICO }

/** Item de turno já formatado para o cartão da lista. */
data class ItemTurno(
    val turnoId: String,
    val posicaoId: String,
    val inicio: Instant,
    val fim: Instant? = null,
    val funcaoNome: String,
    val estabelecimentoNome: String,
    val dataHorarioFormatado: String,
    val valorFormatado: String,
    val estado: String,
    /** RF15/RN11: verdadeiro só depois do fim previsto, com presença verificada e sem avaliação deste lado. */
    val podeAvaliar: Boolean = false,
    /** Resposta já registrada (RN07); `null` enquanto não avaliado. */
    val avaliacaoResposta: Boolean? = null,
    /** Comprovante de check-in emitido (RN06/RN22); `null` antes do registro. */
    val comprovante: ComprovanteCheckin? = null,
)

/** Estado do diálogo RN12 enquanto o profissional decide e envia o cancelamento. */
data class EstadoCancelamentoTurno(
    val turno: ItemTurno,
    val contaComoFalta: Boolean,
    val motivoSelecionado: MotivoCancelamento? = null,
    val detalhes: String = "",
    val enviando: Boolean = false,
    val mensagemErro: String? = null,
) {
    val motivoCompleto: String?
        get() {
            val motivo = motivoSelecionado ?: return null
            if (!motivo.exigeDetalhes) return motivo.descricao
            return detalhes.trim().takeIf { it.length >= 3 }
        }

    val podeConfirmar: Boolean
        get() = motivoCompleto != null && !enviando
}

/** RF16: tamanho de cada fatia da paginação progressiva do histórico. */
const val TAMANHO_PAGINA_HISTORICO = 10

/** Estado da tela de meus turnos: listas já separadas por aba, prontas para a `LazyColumn`. */
data class EstadoMeusTurnos(
    val status: StatusMeusTurnos = StatusMeusTurnos.CARREGANDO,
    val abaSelecionada: AbaDeTurnos = AbaDeTurnos.AGENDADOS,
    val agendados: List<ItemTurno> = emptyList(),
    /** RF16: histórico completo vindo da API, já ordenado (mais recente primeiro); nunca exibido
     * de uma vez — a UI lê sempre [historicoPaginado]. */
    val historicoCompleto: List<ItemTurno> = emptyList(),
    /** Quantas fatias de [TAMANHO_PAGINA_HISTORICO] já foram liberadas para a UI. */
    val paginaHistorico: Int = 1,
    /** Verdadeiro enquanto [carregarMaisHistorico][MeusTurnosViewModel.carregarMaisHistorico] prepara a próxima fatia. */
    val carregandoMaisHistorico: Boolean = false,
    /** Verdadeiro durante o pull-to-refresh (`PullToRefreshBox.isRefreshing`). */
    val atualizando: Boolean = false,
    val mensagemErro: String? = null,
    val cancelamento: EstadoCancelamentoTurno? = null,
    val mensagemFeedback: String? = null,
) {
    /** Fatia do histórico já liberada para a UI (RF16: paginação progressiva de 10 em 10). */
    val historicoPaginado: List<ItemTurno>
        get() = historicoCompleto.take(paginaHistorico * TAMANHO_PAGINA_HISTORICO)

    /** Verdadeiro enquanto existir mais histórico completo do que o já paginado. */
    val temMaisHistorico: Boolean
        get() = historicoPaginado.size < historicoCompleto.size

    /** A lista que a aba atualmente selecionada deve mostrar. */
    val itensDaAbaAtual: List<ItemTurno>
        get() = if (abaSelecionada == AbaDeTurnos.AGENDADOS) agendados else historicoPaginado
}
