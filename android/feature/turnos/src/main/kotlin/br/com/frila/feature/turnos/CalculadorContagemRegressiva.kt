package br.com.frila.feature.turnos

import java.time.Duration
import java.time.Instant

/**
 * Estado calculado da contagem regressiva para a abertura da janela de check-in (RF11/RN06).
 */
sealed interface EstadoContagemRegressiva {
    /** Check-in ainda não liberado: faltam mais de 60 minutos para o início do turno. */
    data class AguardandoJanela(
        val tempoRestante: Duration,
        val textoFormatado: String,
    ) : EstadoContagemRegressiva

    /** Dentro da janela de tolerância de check-in (a partir de 60 minutos antes do início até o término). */
    data object JanelaAberta : EstadoContagemRegressiva

    /** Turno ultrapassou o horário de término previsto. */
    data object TurnoFinalizado : EstadoContagemRegressiva
}

/**
 * Calculador defensivo da contagem regressiva para o início do turno (RF11/RN06).
 *
 * A janela de check-in abre 60 minutos antes do início previsto (`inicio - 60 min`).
 * Tratamento defensivo contra relógio adiantado/atrasado: durações negativas ou drift
 * transicionam diretamente para `JanelaAberta` sem crash ou texto anômalo.
 */
object CalculadorContagemRegressiva {

    /** Janela de antecedência permitida para o check-in presencial (60 minutos antes do início). */
    val ANTECEDENCIA_CHECKIN: Duration = Duration.ofMinutes(60)

    fun calcular(
        inicioTurno: Instant,
        fimTurno: Instant?,
        instanteAtual: Instant = Instant.now(),
    ): EstadoContagemRegressiva {
        if (fimTurno != null && instanteAtual.isAfter(fimTurno)) {
            return EstadoContagemRegressiva.TurnoFinalizado
        }

        val aberturaJanela = inicioTurno.minus(ANTECEDENCIA_CHECKIN)

        if (!instanteAtual.isBefore(aberturaJanela)) {
            return EstadoContagemRegressiva.JanelaAberta
        }

        val diferenca = Duration.between(instanteAtual, aberturaJanela)
        if (diferenca.isNegative || diferenca.isZero) {
            return EstadoContagemRegressiva.JanelaAberta
        }

        val texto = formatarTempoRestante(diferenca)
        return EstadoContagemRegressiva.AguardandoJanela(
            tempoRestante = diferenca,
            textoFormatado = texto,
        )
    }

    fun formatarTempoRestante(duracao: Duration): String {
        val totalSegundos = duracao.seconds.coerceAtLeast(0)
        val dias = totalSegundos / 86400
        val horas = (totalSegundos % 86400) / 3600
        val minutos = (totalSegundos % 3600) / 60
        val segundos = totalSegundos % 60

        val minPad = minutos.toString().padStart(2, '0')
        val segPad = segundos.toString().padStart(2, '0')

        return when {
            dias > 0 -> "${dias}d ${horas}h"
            horas > 0 -> "${horas}h ${minPad}min"
            minutos > 0 -> "${minutos}min ${segPad}s"
            else -> "${segundos}s"
        }
    }
}
