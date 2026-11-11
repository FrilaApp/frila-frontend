package br.com.frila.core.dominio.modelo

/**
 * Motivo normativo de `/rpc/denunciar` (schema `MotivoDenuncia` do contrato, RF26, UC17).
 * Fraude e documento falso chegam por [OUTRO], com o relato.
 */
enum class MotivoDenuncia(val chave: String) {
    ASSEDIO("assedio"),
    DISCRIMINACAO("discriminacao"),
    RISCO_SEGURANCA("risco_seguranca"),
    OUTRO("outro"),
}

/** Alvo de denúncia ou bloqueio (schema `TipoDeAlvo`): os mesmos valores de `PerfilPublico.tipo`. */
enum class TipoDeAlvo(val chave: String) {
    PROFISSIONAL("profissional"),
    ESTABELECIMENTO("estabelecimento"),
}
