package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.ComprovanteCheckin

/** Status do check-in presencial de um turno (RF13/RN06/RN22). */
/** `NA_FILA`: sem rede, o toque ficou guardado no aparelho e sai quando a rede voltar (A6.2). */
enum class StatusCheckin { OCIOSO, REGISTRANDO, VERIFICADO, MANUAL_PENDENTE, ERRO, NA_FILA }

/**
 * Diálogo defensivo exibido antes de tentar o check-in geolocalizado (RN06/RN22): o profissional
 * decide entre resolver a pendência (abrir configurações) ou seguir direto no modo manual.
 */
enum class DialogoDefensivoLocalizacao {
    PERMISSAO_NEGADA,
    GPS_DESLIGADO,
    /** A leitura veio com erro acima de 100 m: não prova presença (como o `.semGPS(.imprecisa)` do iOS). */
    LEITURA_IMPRECISA,
}

/** Status do check-out de um turno (RF13/RN11/RN22): sem localização ele segue com `distancia_m` nulo, nunca trava. */
enum class StatusCheckout { OCIOSO, REGISTRANDO, FEITO, ERRO, NA_FILA }

/** Estado da ação de check-in de um turno específico. */
data class EstadoCheckin(
    val status: StatusCheckin = StatusCheckin.OCIOSO,
    /** L1-4: o check-out feito neste aparelho; o que o servidor já tinha vem em `ItemTurno.checkoutEm`. */
    val checkout: StatusCheckout = StatusCheckout.OCIOSO,
    val mensagemErroCheckout: String? = null,
    val mensagemErro: String? = null,
    val comprovante: ComprovanteCheckin? = null,
    val dialogoDefensivo: DialogoDefensivoLocalizacao? = null,
    /** C0-7: a tela abre o pedido de permissão do sistema (o diálogo das Configurações só vem depois da recusa). */
    val pedirPermissao: Boolean = false,
    /** A6.2: o que ficou na fila, para a tela dizer o horário do toque (`status`/`checkout` valem `NA_FILA`). */
    val checkinNaFila: RegistroNaFila? = null,
    val checkoutNaFila: RegistroNaFila? = null,
    /** A6.2: o servidor recusou de vez o que estava na fila; o envio não se repete até um novo toque. */
    val avisoCheckin: String? = null,
    val avisoCheckout: String? = null,
)
