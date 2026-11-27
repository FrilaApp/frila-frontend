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
 * O que a tela sabe dos turnos futuros. [NaoConsultados]: a tela foi montada sem consulta (nada a mostrar além do texto geral).
 * [Indisponivel]: a leitura falhou; a tela avisa e **não bloqueia** a exclusão.
 */
sealed interface TurnosFuturosDaExclusao {
    data object NaoConsultados : TurnosFuturosDaExclusao
    data object Carregando : TurnosFuturosDaExclusao
    data class Lista(val turnos: List<TurnoFuturoDaExclusao>) : TurnosFuturosDaExclusao
    data object Indisponivel : TurnosFuturosDaExclusao
}
