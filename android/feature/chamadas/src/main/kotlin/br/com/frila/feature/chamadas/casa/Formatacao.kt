package br.com.frila.feature.chamadas.casa

import br.com.frila.core.rede.ServicoNoPerfilDto
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** O horário de Brasília: a casa vê as datas no fuso do DF, os instantes do contrato seguem em UTC (RN18). */
internal val FusoDoFrila: ZoneId = ZoneId.of("America/Sao_Paulo")

private val FormatoDataEHora = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm", Locale("pt", "BR")).withZone(FusoDoFrila)
private val FormatoHora = DateTimeFormatter.ofPattern("HH:mm", Locale("pt", "BR")).withZone(FusoDoFrila)

internal fun dataEHora(instante: Instant): String = FormatoDataEHora.format(instante)
internal fun hora(instante: Instant): String = FormatoHora.format(instante)

/** "R$ 1.500,00": reais com ponto de milhar e sempre 2 casas, sem depender do `Locale` do aparelho. */
internal fun dinheiro(centavos: Long): String {
    val reais = (centavos / 100).toString().reversed().chunked(3).joinToString(".").reversed()
    return "R$ $reais,${(centavos % 100).toString().padStart(2, '0')}"
}

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
