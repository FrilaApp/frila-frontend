package br.com.frila.feature.turnos

/** Status da tela de meus turnos. */
enum class StatusMeusTurnos { CARREGANDO, SUCESSO, VAZIO, ERRO }

/** Aba selecionada: Agendados (`confirmada`) ou Histórico (`cumprida`/`cancelada`). */
enum class AbaDeTurnos { AGENDADOS, HISTORICO }

/** Item de turno já formatado para o cartão da lista. */
data class ItemTurno(
    val turnoId: String,
    val funcaoNome: String,
    val estabelecimentoNome: String,
    val dataHorarioFormatado: String,
    val valorFormatado: String,
    val estado: String,
)

/** Estado da tela de meus turnos: listas já separadas por aba, prontas para a `LazyColumn`. */
data class EstadoMeusTurnos(
    val status: StatusMeusTurnos = StatusMeusTurnos.CARREGANDO,
    val abaSelecionada: AbaDeTurnos = AbaDeTurnos.AGENDADOS,
    val agendados: List<ItemTurno> = emptyList(),
    val historico: List<ItemTurno> = emptyList(),
    val mensagemErro: String? = null,
) {
    /** A lista que a aba atualmente selecionada deve mostrar. */
    val itensDaAbaAtual: List<ItemTurno>
        get() = if (abaSelecionada == AbaDeTurnos.AGENDADOS) agendados else historico
}
