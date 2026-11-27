package br.com.frila.feature.conta

import java.time.Instant

/** Um turno futuro que a exclusão da conta cancelaria, como a tela o lista (paridade com a lista de `ExclusaoDeContaViewModel.swift`). */
data class TurnoFuturoDaExclusao(
    val id: String,
    val funcao: String,
    val contraparte: String,
    val inicio: Instant,
    val fim: Instant,
    val local: String,
)

/**
 * O que a consulta devolve: os turnos (ainda sem filtrar por data) e se a consulta é **limitada** (a da casa olha só os próximos 12 meses
 * do painel, então a lista pode estar incompleta).
 */
data class ConsultaDeTurnosDaExclusao(val turnos: List<TurnoFuturoDaExclusao>, val limitada: Boolean = false)

/**
 * O que a tela sabe dos turnos futuros. [NaoConsultados]: a tela foi montada sem consulta (nada a mostrar além do texto geral).
 * [Indisponivel]: a leitura falhou; a tela avisa e **não bloqueia** a exclusão.
 */
sealed interface TurnosFuturosDaExclusao {
    data object NaoConsultados : TurnosFuturosDaExclusao
    data object Carregando : TurnosFuturosDaExclusao
    data class Lista(val turnos: List<TurnoFuturoDaExclusao>, val limitada: Boolean = false) : TurnosFuturosDaExclusao
    data object Indisponivel : TurnosFuturosDaExclusao
}
