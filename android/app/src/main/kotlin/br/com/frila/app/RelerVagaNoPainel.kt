package br.com.frila.app

import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.VagaNoPainelDto
import br.com.frila.feature.vagas.painel.MinhasVagasViewModel
import java.time.Instant

/**
 * A vaga [vagaId] como o painel da casa [estabelecimentoId] a mostra agora, ou `null` se o painel não pôde ser lido, é de
 * outra casa ou não traz a vaga. Serve à escolha de candidato: quando a resposta de `escolher_candidato` se perde, o painel
 * diz se a pessoa já ficou confirmada (iOS: `relerVaga` / `confirmadoNoPainel`). A janela é a mesma de Minhas vagas.
 */
internal suspend fun relerVagaNoPainel(
    servico: ServicoVagas,
    estabelecimentoId: String,
    vagaId: String,
    agora: Instant = Instant.now(),
): VagaNoPainelDto? {
    val hoje = agora.atZone(MinhasVagasViewModel.FUSO_DO_PAINEL)
    val painel = servico.painelEstabelecimento(
        estabelecimentoId,
        hoje.minusDays(MinhasVagasViewModel.JANELA_EM_DIAS).toInstant(),
        hoje.plusDays(MinhasVagasViewModel.JANELA_EM_DIAS).toInstant(),
    ).getOrNull() ?: return null
    if (painel.estabelecimentoId != estabelecimentoId) return null
    return painel.vagas.firstOrNull { it.vaga.id == vagaId }
}
