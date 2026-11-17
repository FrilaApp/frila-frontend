package br.com.frila.feature.conta

import br.com.frila.core.dominio.regra.instanteDoServidor
import br.com.frila.core.rede.ProtocoloDto
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Fuso em que o Frila conta os prazos da Equipe Frila (dias civis de São Paulo). */
val FUSO_DA_CONTA: ZoneId = ZoneId.of("America/Sao_Paulo")

/** Mínimo do relato de uma contestação (`contestar_suspensao` e `pedir_revisao_despacho`). */
const val MINIMO_DO_RELATO = 10

private val FORMATO_DE_DATA = DateTimeFormatter.ofPattern("dd/MM/yyyy", Locale.forLanguageTag("pt-BR"))

/** O protocolo de uma contestação como a tela o mostra. O desfecho nunca vem ao app (RN07): a resposta vai por e-mail. */
data class ProtocoloExibido(
    /** O protocolo curto que a pessoa cita: os 8 primeiros hexadecimais do id, sem hífen, em maiúsculas. */
    val numero: String,
    val enviadoEm: String,
    val prazoRespostaAte: String,
    /** O dia do prazo, para saber se ainda está em análise; `null` se o servidor mandou uma data ilegível. */
    val prazo: LocalDate?,
) {
    /** Dentro do prazo (o último dia conta), a contestação está em análise. Sem data legível, não se afirma isso. */
    fun emAnalise(agora: Instant, zona: ZoneId = FUSO_DA_CONTA): Boolean =
        prazo != null && !agora.atZone(zona).toLocalDate().isAfter(prazo)
}

internal fun ProtocoloDto.paraExibicao(zona: ZoneId = FUSO_DA_CONTA): ProtocoloExibido {
    val prazo = runCatching { LocalDate.parse(prazoRespostaAte.take(10)) }.getOrNull()
    return ProtocoloExibido(
        numero = ocorrenciaId.replace("-", "").take(8).uppercase(),
        enviadoEm = formatarDia(criadaEm, zona) ?: criadaEm,
        prazoRespostaAte = prazo?.format(FORMATO_DE_DATA) ?: prazoRespostaAte,
        prazo = prazo,
    )
}

/** "10/11/2026" no fuso do Frila, ou `null` se o servidor mandou um instante ilegível. */
internal fun formatarDia(instante: String, zona: ZoneId = FUSO_DA_CONTA): String? =
    runCatching { instanteDoServidor(instante).atZone(zona).format(FORMATO_DE_DATA) }.getOrNull()
