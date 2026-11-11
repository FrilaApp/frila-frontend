package br.com.frila.feature.turnos.contratante

/** Textos do acompanhamento do turno pela casa (paridade com `TelaTurnoDoContratante.swift`). */
object TextosTurnoDoContratante {
    const val TITULO = "Turno"
    const val ROTULO_VOLTAR = "Voltar"
    const val PROFISSIONAL = "Profissional"
    const val SEM_PROFISSIONAL = "Posição sem profissional confirmado."
    const val FUNCOES = "Funções: %s"
    const val CHEGADA = "Chegada"
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

    const val ERRO_CHECKIN_PENDENTE = "O profissional ainda não fez o check-in. Não há presença para confirmar."
    const val ERRO_NAO_ENCONTRADO = "Não encontramos este turno."
    const val ERRO_SEM_PERMISSAO = "Você não tem permissão para confirmar a presença neste turno."
    const val ERRO_SESSAO = "Sua sessão expirou. Entre de novo."
    const val ERRO_SEM_REDE = "Sem conexão. A confirmação não foi enviada. Tente de novo quando a internet voltar."
    const val ERRO_GENERICO = "Não foi possível confirmar a presença. Tente novamente."
}
