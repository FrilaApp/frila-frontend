package br.com.frila.feature.turnos

import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/** Um check-in ou check-out guardado no aparelho à espera da rede: o instante do toque e se foi sem localização (manual). */
data class RegistroNaFila(val instante: Instant, val manual: Boolean)

/** Textos da fila de presença (tela provisória), com o mesmo sentido do iOS (`PresencaDoTurnoViewModel`). */
object TextosDaFilaDePresenca {
    const val CHECKIN_NA_FILA =
        "Sem conexão. O check-in das %s está guardado neste aparelho e será enviado quando a internet voltar, com esse horário."
    const val CHECKIN_MANUAL_NA_FILA =
        "Sem conexão. O check-in manual das %s está guardado neste aparelho e será enviado quando a internet voltar, com esse horário. " +
            "Depois ele aguarda a confirmação do contratante."
    const val CHECKOUT_NA_FILA =
        "Sem conexão. O check-out das %s está guardado neste aparelho e será enviado quando a internet voltar, com esse horário."
    const val CHECKIN_RECUSADO = "O check-in guardado neste aparelho não foi registrado. Esse envio não será repetido."
    const val CHECKOUT_RECUSADO = "O check-out guardado neste aparelho não foi registrado. Esse envio não será repetido."

    private val FORMATO_HORA = DateTimeFormatter.ofPattern("HH:mm").withZone(ZoneId.of("America/Sao_Paulo"))

    fun checkinNaFila(registro: RegistroNaFila): String =
        (if (registro.manual) CHECKIN_MANUAL_NA_FILA else CHECKIN_NA_FILA).format(FORMATO_HORA.format(registro.instante))

    fun checkoutNaFila(registro: RegistroNaFila): String = CHECKOUT_NA_FILA.format(FORMATO_HORA.format(registro.instante))
}
