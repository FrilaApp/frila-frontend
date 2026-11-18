package br.com.frila.core.dominio.modelo

import java.security.MessageDigest
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Tipo de verificação do check-in presencial (RF13/RN06/RN22).
 */
enum class TipoVerificacaoCheckin(val descricao: String) {
    GEOLOCALIZADO("Geolocalizado na vaga"),
    MANUAL_PENDENTE("Check-in manual pendente de confirmação"),
    MANUAL_CONFIRMADO("Check-in manual confirmado pelo contratante"),
    NAO_VERIFICADO("Sem verificação"),
}

/**
 * Comprovante de check-in com carimbo temporal e hash verificador (RN06/RN22).
 * Não guarda a posição: ela só serve para medir a distância no toque e não aparece aqui nem no texto compartilhado.
 */
data class ComprovanteCheckin(
    val turnoId: String,
    val registradoEm: Instant,
    val tipoVerificacao: TipoVerificacaoCheckin,
    val codigoAutenticacao: String,
) {
    fun horarioFormatado(fuso: ZoneId = FUSO_BRASILIA): String =
        FORMATO_DATA_HORA.withZone(fuso).format(registradoEm)

    fun textoCompartilhamento(): String = buildString {
        appendLine("Comprovante de Check-in · Frila")
        appendLine("Código: $codigoAutenticacao")
        appendLine("Horário: ${horarioFormatado()}")
        appendLine("Status: ${tipoVerificacao.descricao}")
        append("Turno: $turnoId")
    }

    companion object {
        private val FUSO_BRASILIA: ZoneId = ZoneId.of("America/Sao_Paulo")
        private val FORMATO_DATA_HORA: DateTimeFormatter =
            DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm:ss")
    }
}

/**
 * Gerador de comprovante com cálculo determinístico de hash SHA-256 (RN22). Não recebe coordenada.
 */
object GeradorComprovanteCheckin {

    fun gerar(
        turnoId: String,
        registradoEm: Instant,
        tipoVerificacao: TipoVerificacaoCheckin,
    ): ComprovanteCheckin = ComprovanteCheckin(
        turnoId = turnoId,
        registradoEm = registradoEm,
        tipoVerificacao = tipoVerificacao,
        codigoAutenticacao = calcularCodigoAutenticacao(turnoId, registradoEm),
    )

    fun calcularCodigoAutenticacao(turnoId: String, registradoEm: Instant): String {
        val entrada = "$turnoId:${registradoEm.toEpochMilli()}"
        val digest = MessageDigest.getInstance("SHA-256").digest(entrada.toByteArray(Charsets.UTF_8))
        val hex = digest.take(4).joinToString("") { "%02X".format(it) }
        return "CHK-$hex"
    }
}
