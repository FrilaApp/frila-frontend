package br.com.frila.app

import br.com.frila.core.dominio.regra.instanteDoServidor
import br.com.frila.core.rede.ServicoConta
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.TurnoDto
import br.com.frila.feature.conta.ConsultaDeTurnosDaExclusao
import br.com.frila.feature.conta.TurnoFuturoDaExclusao
import br.com.frila.feature.vagas.painel.MinhasVagasViewModel
import java.time.Instant

private const val CONTRAPARTE_SEM_NOME = "Profissional"

/**
 * Os turnos que a exclusão da conta cancelaria, como o iOS os consulta (`ExclusaoDeContaViewModel.swift`): para
 * **contratante**, as posições `confirmada` do painel de cada casa dela (do dia anterior até 12 meses à frente: a consulta é
 * **limitada** e a tela avisa); para o resto (profissional), `meus_turnos`, sem os já `cancelada`. Qualquer falha propaga: quem
 * chama a mostra como "lista indisponível" e **nunca** bloqueia a exclusão. Só lê.
 */
internal suspend fun consultarTurnosDaConta(
    conta: ServicoConta,
    turnos: ServicoTurnos,
    membros: ServicoMembros,
    vagas: ServicoVagas,
    agora: Instant = Instant.now(),
): ConsultaDeTurnosDaExclusao {
    if (conta.minhaConta().perfil != "contratante") {
        return ConsultaDeTurnosDaExclusao(
            turnos = turnos.listarMeusTurnos().filter { it.estado != "cancelada" }.map { it.paraTurnoFuturoDaExclusao() },
            limitada = false,
        )
    }
    val casas = membros.listarMeusEstabelecimentos()
    if (casas.isEmpty()) return ConsultaDeTurnosDaExclusao(emptyList(), limitada = false)
    val hoje = agora.atZone(MinhasVagasViewModel.FUSO_DO_PAINEL)
    val de = agora.minusSeconds(24 * 60 * 60L)
    val ate = hoje.plusYears(1).toInstant()
    val lista = casas.flatMap { casa ->
        val painel = vagas.painelEstabelecimento(casa.id, de, ate).getOrThrow()
        if (painel.estabelecimentoId != casa.id) return@flatMap emptyList()
        painel.vagas.flatMap { vagaNoPainel ->
            vagaNoPainel.posicoes.filter { it.estado == "confirmada" }.map { posicao ->
                TurnoFuturoDaExclusao(
                    id = posicao.turnoId ?: posicao.id,
                    funcao = vagaNoPainel.vaga.funcao,
                    contraparte = posicao.profissional?.nome ?: CONTRAPARTE_SEM_NOME,
                    inicio = instanteDoServidor(vagaNoPainel.vaga.inicioEm),
                    fim = instanteDoServidor(vagaNoPainel.vaga.fimEm),
                    local = vagaNoPainel.vaga.local,
                )
            }
        }
    }
    return ConsultaDeTurnosDaExclusao(lista, limitada = true)
}

internal fun TurnoDto.paraTurnoFuturoDaExclusao() = TurnoFuturoDaExclusao(
    id = id,
    funcao = vaga.funcao,
    contraparte = contraparte.nome,
    inicio = instanteDoServidor(vaga.inicioEm),
    fim = instanteDoServidor(vaga.fimEm),
    local = vaga.local,
)
