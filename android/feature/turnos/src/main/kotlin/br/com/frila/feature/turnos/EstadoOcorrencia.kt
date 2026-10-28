package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.MotivoOcorrencia
import br.com.frila.core.rede.ProtocoloDto

/** Status do envio do chamado de ocorrência do turno (RF12/RF23). */
enum class StatusOcorrencia { OCIOSO, ENVIANDO, SUCESSO, ERRO }

/**
 * Estado da tela de ocorrência. `relato` e `anexoUri` nunca saem deste estado em direção a
 * uma RPC — só a `categoria` do [motivo] é enviada (RN15); relato e foto seguem só pelo
 * e-mail que o app abre depois do sucesso.
 */
data class EstadoOcorrencia(
    val motivo: MotivoOcorrencia? = null,
    val relato: String = "",
    val anexoUri: String? = null,
    val status: StatusOcorrencia = StatusOcorrencia.OCIOSO,
    val protocolo: ProtocoloDto? = null,
    val mensagemErro: String? = null,
)
