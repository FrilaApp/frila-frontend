package br.com.frila.feature.turnos.contratante

/** Textos do acompanhamento do turno pela casa (paridade com `TelaTurnoDoContratante.swift`). */
object TextosTurnoDoContratante {
    const val TITULO = "Turno"
    const val ROTULO_VOLTAR = "Voltar"
    const val PROFISSIONAL = "Profissional"
    const val SEM_PROFISSIONAL = "Posição sem profissional confirmado."
    const val FUNCOES = "Funções: %s"
    const val PEDIR_AJUDA = "Pedir ajuda com o turno"
    const val DENUNCIAR = "Denunciar"
    /** `TextosDaSeguranca.voceBloqueouProfissional` do iOS: o que a tela diz do profissional que a casa bloqueou. */
    const val VOCE_BLOQUEOU_PROFISSIONAL = "Você bloqueou este profissional"
    /** Como o iOS (`AcoesDeSeguranca.swift:46`): "Denunciar <nome>". */
    const val DENUNCIAR_ROTULO = "Denunciar %s"
    const val CHEGADA = "Chegada"
    /** Antes do fim do turno, no lugar de "Avaliar turno" (iOS `TextosDoProfissional.Avaliacao.liberaAs`). */
    const val AVALIACAO_LIBERA_AS = "A avaliação libera às %s"

    /** As quatro etapas do turno, como na tela do profissional (e o selo que repete a etapa atual). */
    const val ETAPA_CONFIRMADO = "Confirmado"
    const val ETAPA_A_CAMINHO = "A caminho"
    const val ETAPA_PRESENCA = "Presença"
    const val ETAPA_CONCLUIDO = "Concluído"
    const val SELO_PRESENCA_MARCADA = "Presença marcada"
    const val AGUARDANDO = "Aguardando o profissional chegar."
    const val A_CAMINHO = "%s está a caminho desde as %s."
    const val EM_ATRASO = "Passaram 15 minutos do início e o check-in não chegou. Você pode esperar ou reabrir a posição."
    const val CHECKIN_PENDENTE_COM_HORA = "%s fez o check-in às %s. Confirme a presença para ela contar."
    const val CHECKIN_PENDENTE = "%s fez o check-in. Confirme a presença para ela contar."
    const val CONFIRMAR_PRESENCA = "Confirmar presença"
    const val CONFIRMANDO = "Confirmando…"
    const val VERIFICADA = "Presença verificada"
    const val NAO_VERIFICADA = "Presença não verificada"
    const val CONFIRMADA_AGORA = "Presença confirmada."
    const val JA_CONFIRMADA = "Essa presença já estava confirmada."

    const val REABRIR_VAGA = "Reabrir vaga"
    const val REABRINDO = "Reabrindo…"
    const val REABRIR_PERGUNTA = "Reabrir a vaga?"
    const val REABRIR_AVISO = "Conta como falta para %s, e a vaga volta a ser oferecida a outros profissionais."
    const val REABRIR_CONFIRMAR = "Reabrir vaga"
    const val ESPERAR = "Esperar"
    const val VAGA_REABERTA = "Vaga reaberta. A falta foi registrada, e a posição voltou a ser oferecida."
    const val FALTA_SEM_REABERTURA = "Falta registrada. Falta menos de 1 hora para o fim do turno, e a vaga não foi reaberta."
    const val ERRO_ANTES_DA_TOLERANCIA = "Ainda não passaram 15 minutos do início do turno."
    const val ERRO_CHECKIN_REGISTRADO = "O profissional já fez o check-in. A vaga não pode ser reaberta."
    const val ERRO_SITUACAO_MUDOU = "A situação deste turno mudou. Atualize a tela."
    const val ERRO_REABRIR_SEM_PERMISSAO = "Você não tem permissão para reabrir a vaga deste turno."
    /** TEXTO PROVISÓRIO (o final é do Fabrício): a resposta se perdeu, e o servidor pode ter reaberto a vaga e registrado a falta. */
    const val ERRO_REABRIR_RESULTADO_INCERTO = "Não deu para confirmar se a vaga foi reaberta. Atualize a tela antes de tentar de novo."

    const val ERRO_CHECKIN_PENDENTE = "O profissional ainda não fez o check-in. Não há presença para confirmar."
    const val ERRO_NAO_ENCONTRADO = "Não encontramos este turno."
    const val ERRO_SEM_PERMISSAO = "Você não tem permissão para confirmar a presença neste turno."
    const val ERRO_SESSAO = "Sua sessão expirou. Entre de novo."
    const val ERRO_SEM_REDE = "Sem conexão. A confirmação não foi enviada. Tente de novo quando a internet voltar."
    const val ERRO_GENERICO = "Não foi possível confirmar a presença. Tente novamente."
}
