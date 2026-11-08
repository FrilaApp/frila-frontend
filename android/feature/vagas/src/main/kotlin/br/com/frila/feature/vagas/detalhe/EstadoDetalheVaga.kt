package br.com.frila.feature.vagas.detalhe

import br.com.frila.core.rede.ContatoDto
import br.com.frila.core.rede.VagaAbertaDto

/** Status da candidatura nesta tela. */
enum class StatusCandidatura { NENHUMA, ENVIANDO, CONFIRMADA, PENDENTE, ERRO }

/** Estado da tela de detalhe da vaga. */
data class EstadoDetalheVaga(
    val vaga: VagaAbertaDto,
    val statusCandidatura: StatusCandidatura = StatusCandidatura.NENHUMA,
    val mensagem: String? = null,
    val contato: ContatoDto? = null,
) {
    /** Modo urgência (RN19): primeiro elegível confirma na hora. Modo seleção: fica pendente. */
    val ehModoUrgencia: Boolean
        get() = vaga.modo == "urgencia"
}
