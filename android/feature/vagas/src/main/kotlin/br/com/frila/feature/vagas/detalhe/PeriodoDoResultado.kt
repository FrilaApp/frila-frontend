package br.com.frila.feature.vagas.detalhe

import br.com.frila.core.dominio.regra.instanteDoServidor
import br.com.frila.core.rede.VagaAbertaDto
import java.time.Duration
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

private val FUSO_BRASILIA = ZoneId.of("America/Sao_Paulo")
private val PT_BR = Locale.forLanguageTag("pt-BR")
private val FORMATO_DATA = DateTimeFormatter.ofPattern("EEEE, d 'de' MMMM 'de' yyyy", PT_BR)
private val FORMATO_HORA = DateTimeFormatter.ofPattern("HH:mm", PT_BR)

/** A data, o horário e a duração da vaga como o resultado da candidatura os mostra: "Sábado, 21 de novembro de 2026\ndas 15:00 às 21:00" e "6 h". */
internal class PeriodoDoResultado(val periodo: String, val duracao: String)

/**
 * O período da vaga no fuso de Brasília, ou `null` quando não há período de verdade: início ou fim ilegível, ou fim que não é posterior ao início. Nesse caso
 * a tela esconde a linha, em vez de inventar um horário (antes, o início ilegível virava `Instant.now()` e a duração saía negativa). O iOS tem a mesma regra
 * mais cedo: a vaga nem é decodificada com a data ilegível, e `Periodo` exige `fim > inicio` (`DTOsContrato.swift:863-864,899-902`, `ObjetosDeValor.swift:107-111`).
 */
internal fun periodoDoResultado(vaga: VagaAbertaDto): PeriodoDoResultado? {
    val inicio = runCatching { instanteDoServidor(vaga.inicioEm).atZone(FUSO_BRASILIA) }.getOrNull() ?: return null
    val fim = runCatching { instanteDoServidor(vaga.fimEm).atZone(FUSO_BRASILIA) }.getOrNull() ?: return null
    if (!fim.isAfter(inicio)) return null
    val duracao = Duration.between(inicio, fim)
    val horas = duracao.toHours()
    val minutos = duracao.toMinutes() % 60
    val textoDuracao = if (minutos == 0L) "$horas h" else "$horas h $minutos min"
    val dataExtenso = FORMATO_DATA.format(inicio.toLocalDate()).replaceFirstChar { it.titlecase(PT_BR) }
    return PeriodoDoResultado(
        periodo = "$dataExtenso\ndas ${FORMATO_HORA.format(inicio)} às ${FORMATO_HORA.format(fim)}",
        duracao = textoDuracao,
    )
}
