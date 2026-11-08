package br.com.frila.core.seguranca

/**
 * Resultado da verificação de integridade de execução (RN15, cartão Cdv0sS5w) — só para
 * telemetria/auditoria. Nunca usado para bloquear, travar ou encerrar o app: ver
 * [VerificadorDeIntegridade].
 */
data class RelatorioIntegridade(
    val rootDetectado: Boolean,
    val emuladorDetectado: Boolean,
    val assinaturaAdulterada: Boolean,
) {
    val integro: Boolean
        get() = !rootDetectado && !emuladorDetectado && !assinaturaAdulterada
}
