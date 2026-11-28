package br.com.frila.feature.vagas.candidaturas

/** Textos das candidaturas do profissional (paridade com `TextosDaCandidatura` e `TextosMinhasCandidaturas` do iOS). */
object TextosCandidaturas {
    const val TITULO = "Candidaturas"
    const val ROTULO_VOLTAR = "Voltar"
    const val AGUARDANDO = "Aguardando resposta"
    const val ANTERIORES = "Anteriores"
    const val VAZIO_TITULO = "Nenhuma candidatura"
    const val VAZIO_MENSAGEM = "As vagas a que você se candidatar aparecem aqui."
    const val CARREGANDO = "Carregando as candidaturas."
    const val ATUALIZANDO = "Atualizando as candidaturas."
    const val LISTA = "Suas candidaturas"
    const val ERRO_TITULO = "Não foi possível carregar as candidaturas."
    const val TENTAR_DE_NOVO = "Tentar de novo"
    const val DESATUALIZADA = "Não foi possível atualizar. A lista de candidaturas pode estar desatualizada."
    const val ERRO_GENERICO = "Não foi possível carregar suas candidaturas. Tente novamente."
    const val ERRO_SEM_REDE = "Sem conexão. Tente novamente quando a internet voltar."
    const val SESSAO_EXPIRADA = "Sua sessão expirou. Entre novamente para continuar."
    const val CONTA_NAO_PODE = "Sua conta não pode realizar esta ação."
    const val VALOR = "%s pelo turno"

    // O que cada candidatura diz de si
    const val ESTADO_PENDENTE = "Aguardando a escolha do estabelecimento"
    const val ESTADO_ACEITA = "Confirmada: o turno está em Meus turnos"
    /** A aceita cujo turno foi cancelado (`meus_turnos`): não diz mais "Confirmada" (paridade com o iOS, `estadoTurnoCancelado`). */
    const val ESTADO_TURNO_CANCELADO = "Turno cancelado"
    const val ESTADO_RECUSADA = "O estabelecimento escolheu outra pessoa"
    const val ESTADO_RETIRADA = "Candidatura retirada"
    const val ESTADO_EXPIRADA = "A vaga foi encerrada ou cancelada antes de a sua candidatura ser escolhida"

    // O que o toque faz, dito a quem usa leitor de tela
    const val ABRE_A_VAGA = "Abre a vaga"
    const val ABRE_MEUS_TURNOS = "Abre Meus turnos"
    const val ABRE_O_TURNO = "Abre o detalhe do turno"

    // Retirar candidatura
    const val RETIRAR = "Retirar candidatura"
    const val RETIRAR_CANDIDATURA_DE = "Retirar a candidatura à vaga de %s"
    const val RETIRANDO = "Retirando candidatura…"
    const val PERGUNTA_DA_RETIRADA = "Retirar a candidatura?"
    const val AVISO_DA_RETIRADA = "Sua candidatura a esta vaga será retirada. Enquanto ela aceitar candidaturas, dá para se candidatar de novo."
    const val CONFIRMAR_RETIRADA = "Retirar"
    const val CANCELAR = "Cancelar"
    const val FECHAR = "Fechar"
    const val RETIRADA_TITULO = "Candidatura retirada"
    const val RETIRADA_MENSAGEM = "Sua candidatura a esta vaga foi retirada."
    const val RETIRADA_SEM_CONEXAO = "Sem conexão. A candidatura não foi retirada; tente de novo quando a internet voltar."
    const val RETIRADA_FALHA = "Não foi possível retirar a candidatura. Tente de novo."
    const val RETIRADA_NAO_ENCONTRADA = "Não encontramos esta candidatura nesta conta."
    const val JA_ESCOLHIDA = "A sua candidatura foi escolhida, e não dá mais para retirá-la. O turno está em Meus turnos."
    const val JA_RECUSADA = "O estabelecimento escolheu outra pessoa. Não há mais candidatura para retirar."
    const val JA_EXPIRADA = "A vaga foi encerrada ou cancelada. Não há mais candidatura para retirar."
    const val JA_RESPONDIDA = "Esta candidatura já teve resposta e não pode mais ser retirada. Veja a situação em Candidaturas."
}
