package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.ComprovanteCheckin
import br.com.frila.core.dominio.modelo.TipoVerificacaoCheckin
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/** Paridade com `TextosDoProfissional.Avaliacao.liberaAs` do iOS (`Localizable.xcstrings`, "A avaliação libera às %@"). */
object TextosAvaliacao {
    fun liberaAs(hora: String) = "A avaliação libera às $hora"
}

private val FORMATO_HORA_DA_LIBERACAO: DateTimeFormatter =
    DateTimeFormatter.ofPattern("HH:mm").withZone(ZoneId.of("America/Sao_Paulo"))

/** A hora da liberação como a tela mostra (fuso de São Paulo, como no iOS). */
fun horaDaLiberacao(liberaEm: Instant): String = FORMATO_HORA_DA_LIBERACAO.format(liberaEm)

/**
 * Quando a avaliação deste turno libera (o `fim` previsto), enquanto isso ainda está no futuro: presença verificada, check-out
 * feito, nada avaliado por este lado e o servidor ainda não liberou (`podeAvaliar` falso). Sem presença verificada é `null`, para
 * não prometer o que não vai abrir. Mesma regra do iOS (`MeuTurnoViewModel.liberacaoDaAvaliacao`, #672/#676); o horário não vem
 * de campo novo da API, é o `fim` que o turno já traz.
 */
fun liberacaoDaAvaliacao(turno: ItemTurno, comprovante: ComprovanteCheckin?, agora: Instant): Instant? {
    if (turno.podeAvaliar || turno.avaliacaoResposta != null || turno.checkoutEm == null) return null
    val verificada = comprovante?.tipoVerificacao.let {
        it == TipoVerificacaoCheckin.GEOLOCALIZADO || it == TipoVerificacaoCheckin.MANUAL_CONFIRMADO
    }
    if (!verificada) return null
    val fim = turno.fim ?: return null
    return fim.takeIf { it.isAfter(agora) }
}
