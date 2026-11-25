package br.com.frila.feature.vagas.detalhe

import br.com.frila.core.rede.ContatoDto
import br.com.frila.core.rede.VagaAbertaDto
import br.com.frila.core.rede.VagaDto

/** Status da candidatura nesta tela. */
enum class StatusCandidatura { NENHUMA, ENVIANDO, CONFIRMADA, PENDENTE, ERRO }

/** Estado da tela de detalhe da vaga. */
data class EstadoDetalheVaga(
    val vaga: VagaAbertaDto,
    val statusCandidatura: StatusCandidatura = StatusCandidatura.NENHUMA,
    val mensagem: String? = null,
    val contato: ContatoDto? = null,
    /** O detalhe lido do servidor (`detalhe_vaga`), quando a vaga foi aberta pelo id; nulo quando veio da lista. */
    val detalhe: VagaDto? = null,
    val navegarParaConfirmada: Boolean = false,
    val ehConflitoHorario: Boolean = false,
    val ehVagaPreenchida: Boolean = false,
    val ehVagaEncerrada: Boolean = false,
    val ehContaSuspensa: Boolean = false,
) {
    /** A lista sempre traz a distância; o detalhe pode não trazer, e aí a tela não a mostra. */
    val mostraDistancia: Boolean
        get() = detalhe == null || detalhe.distanciaKm != null

    /** Modo urgência (RN19): primeiro elegível confirma na hora. Modo seleção: fica pendente. */
    val ehModoUrgencia: Boolean
        get() = vaga.modo == "urgencia"
}
