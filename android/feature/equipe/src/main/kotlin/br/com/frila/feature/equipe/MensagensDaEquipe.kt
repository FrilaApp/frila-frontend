package br.com.frila.feature.equipe

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi

/**
 * As recusas do contrato para listar, remover e incluir na equipe, em texto do Frila (paridade com `MensagensDaEquipe.texto`).
 * `sem_turno_cumprido` e `conta_suspensa` vêm em `details`; `403` sem `details` é "não é administrador".
 */
internal fun mensagemDeErroDaEquipe(erro: ErroDaApi): String = when {
    erro.codigo == CodigoErroAPI.SEM_PERMISSAO && erro.detalhes == "sem_turno_cumprido" -> TextosEquipe.SEM_TURNO_CUMPRIDO
    erro.codigo == CodigoErroAPI.SEM_PERMISSAO && erro.detalhes == "conta_suspensa" -> TextosEquipe.CONTA_SUSPENSA
    erro.codigo == CodigoErroAPI.CONTA_SUSPENSA -> TextosEquipe.CONTA_SUSPENSA
    erro.codigo == CodigoErroAPI.SEM_PERMISSAO -> TextosEquipe.SO_ADMINISTRADOR
    erro.codigo == CodigoErroAPI.NAO_ENCONTRADO -> TextosEquipe.INDISPONIVEL
    erro.codigo == CodigoErroAPI.SEM_REDE -> TextosEquipe.SEM_REDE
    else -> TextosEquipe.ERRO
}
