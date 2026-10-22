package br.com.frila.core.dominio.modelo

/** Estado do ciclo de vida de uma vaga. */
enum class EstadoVaga {
    ABERTA,
    EM_SELECAO,
    PREENCHIDA,
    ENCERRADA,
    CANCELADA,
}
