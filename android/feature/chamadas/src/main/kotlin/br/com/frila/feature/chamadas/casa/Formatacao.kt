package br.com.frila.feature.chamadas.casa

import br.com.frila.core.dominio.modelo.Dinheiro
import br.com.frila.core.rede.ServicoNoPerfilDto
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.time.format.ResolverStyle
import java.util.Locale

/** O horário de Brasília: a casa vê as datas no fuso do DF, os instantes do contrato seguem em UTC (RN18). */
internal val FusoDoFrila: ZoneId = ZoneId.of("America/Sao_Paulo")

private val FormatoDataEHora = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm", Locale("pt", "BR")).withZone(FusoDoFrila)
private val FormatoHora = DateTimeFormatter.ofPattern("HH:mm", Locale("pt", "BR")).withZone(FusoDoFrila)

private val LeituraDeDataEHora = DateTimeFormatter.ofPattern("dd/MM/uuuu HH:mm", Locale("pt", "BR"))
    .withResolverStyle(ResolverStyle.STRICT)

internal fun dataEHora(instante: Instant): String = FormatoDataEHora.format(instante)

/** "16/11/2026 18:30" no fuso do DF; `null` para texto ilegível ou data que não existe (31/02). */
internal fun lerDataEHora(texto: String): Instant? = try {
    LocalDateTime.parse(texto.trim(), LeituraDeDataEHora).atZone(FusoDoFrila).toInstant()
} catch (_: DateTimeParseException) {
    null
}
internal fun hora(instante: Instant): String = FormatoHora.format(instante)

/** "R$ 1.500,00", o mesmo texto de [Dinheiro.formatado] (pt-BR fixo, sem depender do `Locale` do aparelho). */
internal fun dinheiro(centavos: Long): String = Dinheiro(centavos).formatado()

/** O resumo do serviço no perfil: "R$ 150,00 por diária de 8 h", "R$ 40,00 • Hora" ou "A combinar". */
internal fun resumoDoServico(servico: ServicoNoPerfilDto): String? {
    val valor = servico.valorCentavos
    return when {
        servico.unidade == "diaria" && valor != null && servico.horasIncluidas != null ->
            "${dinheiro(valor)} por diária de ${servico.horasIncluidas} h"
        servico.unidade == "a_combinar" -> TextosChamadaCasa.unidadeDoServico("a_combinar")
        valor == null -> TextosChamadaCasa.unidadeDoServico(servico.unidade)
        else -> "${dinheiro(valor)} • ${TextosChamadaCasa.unidadeDoServico(servico.unidade)}"
    }
}
