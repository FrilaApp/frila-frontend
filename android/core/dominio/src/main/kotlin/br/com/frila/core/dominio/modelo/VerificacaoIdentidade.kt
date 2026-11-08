package br.com.frila.core.dominio.modelo

/**
 * Estado da verificação progressiva de identidade do profissional (RN14, contrato 0.2.50).
 */
enum class StatusVerificacaoIdentidade {
    NAO_EXIGIDA,
    PENDENTE,
    EM_ANALISE,
    APROVADA,
    REJEITADA,
}

/**
 * Documentos aceitos na verificação de identidade (RN14).
 */
enum class TipoDocumentoIdentidade {
    RG,
    CNH,
}

/**
 * Partes das evidências fotográficas exigidas para verificação (RN14).
 */
enum class TipoParteEvidencia {
    FRENTE,
    VERSO,
    SELFIE,
}

/**
 * Modelo de domínio para o status da verificação de identidade do profissional (RN14).
 */
data class VerificacaoIdentidade(
    val status: StatusVerificacaoIdentidade,
    val motivo: String? = null,
    val prazoEnvioAte: String? = null,
    val identidadeVerificada: Boolean = false,
)

/**
 * Registro de consentimento para coleta e processamento de biometria facial sob a LGPD (RN14/RN15).
 */
data class ConsentimentoBiometriaLGPD(
    val consentido: Boolean,
    val versaoTermo: String,
    val dataHoraIso: String,
)
