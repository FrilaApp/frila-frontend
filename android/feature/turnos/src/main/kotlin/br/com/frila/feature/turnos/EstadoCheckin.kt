package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.ComprovanteCheckin

/** Status do check-in presencial de um turno (RF13/RN06/RN22). */
enum class StatusCheckin { OCIOSO, REGISTRANDO, VERIFICADO, MANUAL_PENDENTE, ERRO }

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

/** Estado da ação de check-in de um turno específico. */
data class EstadoCheckin(
    val status: StatusCheckin = StatusCheckin.OCIOSO,
    val mensagemErro: String? = null,
    val comprovante: ComprovanteCheckin? = null,
    val dialogoDefensivo: DialogoDefensivoLocalizacao? = null,
    /** C0-7: a tela abre o pedido de permissão do sistema (o diálogo das Configurações só vem depois da recusa). */
    val pedirPermissao: Boolean = false,
)
