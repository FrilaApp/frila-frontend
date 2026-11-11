package br.com.frila.feature.vagas.publicacao

import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Fuso em que o contratante pensa o turno (contrato: `HoraDoDia` em America/Sao_Paulo). */
val FUSO_DA_VAGA: ZoneId = ZoneId.of("America/Sao_Paulo")

private val FORMATO_DATA = DateTimeFormatter.ofPattern("dd/MM/yyyy", Locale.forLanguageTag("pt-BR"))
private val FORMATO_HORA = DateTimeFormatter.ofPattern("HH:mm", Locale.forLanguageTag("pt-BR"))

fun formatarData(instante: Instant, fuso: ZoneId = FUSO_DA_VAGA): String = instante.atZone(fuso).format(FORMATO_DATA)

fun formatarHora(instante: Instant, fuso: ZoneId = FUSO_DA_VAGA): String = instante.atZone(fuso).format(FORMATO_HORA)

/**
 * Troca o dia de [instante] pelo dia escolhido no `DatePicker` do Material 3, que devolve a meia-noite
 * UTC do dia tocado ([dataEscolhidaUtcMs]). A hora local é mantida.
 */
fun trocarData(instante: Instant, dataEscolhidaUtcMs: Long, fuso: ZoneId = FUSO_DA_VAGA): Instant {
    val data = Instant.ofEpochMilli(dataEscolhidaUtcMs).atZone(ZoneOffset.UTC).toLocalDate()
    return combinar(data, instante.atZone(fuso).toLocalTime(), fuso)
}

/** Troca a hora local de [instante], mantendo o dia local. */
fun trocarHora(instante: Instant, hora: Int, minuto: Int, fuso: ZoneId = FUSO_DA_VAGA): Instant =
    combinar(instante.atZone(fuso).toLocalDate(), LocalTime.of(hora, minuto), fuso)

private fun combinar(data: LocalDate, hora: LocalTime, fuso: ZoneId): Instant = data.atTime(hora).atZone(fuso).toInstant()

/** Meia-noite UTC do dia local de [instante], que é o que o `DatePicker` espera como data inicial. */
fun dataParaSeletorUtcMs(instante: Instant, fuso: ZoneId = FUSO_DA_VAGA): Long =
    instante.atZone(fuso).toLocalDate().atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()

/** "6 h", "1 h 30 min", "45 min". */
fun formatarDuracao(duracao: Duration): String {
    val minutos = duracao.toMinutes().coerceAtLeast(0)
    val horas = minutos / 60
    val resto = minutos % 60
    return when {
        horas == 0L -> "$resto min"
        resto == 0L -> "$horas h"
        else -> "$horas h $resto min"
    }
}

/** "R$ 1.260,00". Só o formato; o valor nunca passa por ponto flutuante. */
fun formatarReais(centavos: Long): String {
    val reais = centavos / 100
    val resto = centavos % 100
    val comMilhar = reais.toString().reversed().chunked(3).joinToString(".").reversed()
    return "R$ $comMilhar,${resto.toString().padStart(2, '0')}"
}

/**
 * Lê o valor digitado em reais e devolve centavos: "140", "140,5", "140.50", "R$ 1.400,00".
 * `null` se não for um valor positivo com até duas casas decimais. O ponto é milhar só quando
 * há vírgula ("1.400,00"); sem vírgula, "140.50" é decimal.
 */
fun lerCentavos(texto: String): Long? {
    val limpo = texto.trim().removePrefix("R$").trim()
    val normalizado = if (',' in limpo) limpo.replace(".", "").replace(',', '.') else limpo
    val partes = normalizado.split('.')
    if (partes.size > 2) return null
    val inteiro = partes[0]
    val fracao = partes.getOrNull(1) ?: ""
    if (inteiro.isEmpty() || inteiro.length > 9 || !inteiro.all(Char::isDigit)) return null
    if (fracao.length > 2 || !fracao.all(Char::isDigit)) return null
    val centavos = inteiro.toLong() * 100 + fracao.padEnd(2, '0').toLong()
    return centavos.takeIf { it > 0 }
}
