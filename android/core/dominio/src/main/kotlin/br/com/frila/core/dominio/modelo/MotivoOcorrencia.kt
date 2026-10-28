package br.com.frila.core.dominio.modelo

/**
 * Motivo normativo do chamado de suporte aberto a partir de um turno (RF12/RF23, UC14).
 * `categoria` é a chave de fio do schema `CategoriaSuporte` do contrato (MEDIDO em
 * `iOS/Contrato/openapi.yaml:3882` — `enum: [endereco, atraso, conduta, seguranca, outro]`),
 * a mesma usada por `MotivoSuporteTurno` no iOS (`SuporteTurnoViewModel.swift`).
 *
 * RN15/privacidade por desenho: só a categoria vai ao backend. O relato de texto livre e o
 * anexo fotográfico nunca são enviados a uma RPC — seguem só pelo e-mail que o app abre
 * depois, para `suporte@frila.app`, referenciando o protocolo da ocorrência.
 */
enum class MotivoOcorrencia(val categoria: String, val descricao: String) {
    RISCO_SEGURANCA("seguranca", "Risco de segurança"),
    ATRASO_OU_IMPREVISTO("atraso", "Atraso ou imprevisto"),
    PROBLEMA_NO_LOCAL("endereco", "Problema no local"),
    DIFICULDADE_DE_PRESENCA("conduta", "Dificuldade de presença"),
    OUTRO("outro", "Outro motivo"),
}
