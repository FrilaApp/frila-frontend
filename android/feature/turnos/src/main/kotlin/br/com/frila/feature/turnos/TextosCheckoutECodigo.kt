package br.com.frila.feature.turnos

/** Textos do check-out e da confirmação por código do profissional (tela provisória; o iOS ainda espera o desenho). */
object TextosCheckoutECodigo {
    const val BOTAO_CHECKOUT = "Fazer check-out"
    const val CHECKOUT_REGISTRANDO = "Registrando o check-out…"
    const val CHECKOUT_FEITO = "Check-out registrado"
    const val BOTAO_CHECKOUT_TENTAR_DE_NOVO = "Tentar o check-out de novo"
    const val CHECKOUT_ERRO_PADRAO = "Não foi possível registrar o check-out. Tente de novo."
    const val CHECKOUT_FORA_DA_JANELA = "Fora do horário permitido para o check-out deste turno."
    const val CHECKOUT_SEM_CHECKIN = "Faça o check-in antes do check-out."
    const val CHECKOUT_HORARIO_ERRADO = "O horário do aparelho está incorreto. Ajuste e tente de novo."
    const val CHECKOUT_SEM_REDE = "Sem conexão. Verifique sua internet e tente de novo."
    const val CHECKOUT_NAO_ENCONTRADO = "Não encontramos este turno."

    const val CODIGO_ROTULO = "Código de 6 números"
    const val CODIGO_EXPLICACAO = "A casa mostra um código de 6 números. Digite aqui para confirmar sua presença."
    const val BOTAO_CONFIRMAR_CODIGO = "Confirmar código"
    const val CODIGO_ENVIANDO = "Confirmando…"
    const val CODIGO_VERIFICADO = "Presença confirmada pelo código."
    const val CODIGO_JA_VERIFICADO = "A presença já estava confirmada."
    const val CODIGO_INVALIDO = "Código incorreto. Confira os 6 números e tente de novo."
    const val CODIGO_BLOQUEADO_TEMPORARIO = "Muitas tentativas. Espere alguns minutos e tente de novo."
    const val CODIGO_BLOQUEADO_ENCERRADO = "O código não vale mais neste turno. Peça à casa para confirmar sua presença."
    const val CODIGO_FORA_DO_RAIO = "Você está longe do local. Chegue mais perto e tente de novo."
    const val CODIGO_CHEGUE_MAIS_PERTO = "Você está a %d m do local. Chegue mais perto (até 50 m) e tente de novo."
    const val CODIGO_SEM_LOCALIZACAO = "Não conseguimos ler sua localização. Peça à casa para confirmar sua presença."
    const val CODIGO_FORMATO_INVALIDO = "O código tem 6 números."
    const val CODIGO_RECURSO_DESLIGADO = "Confirmar por código não está disponível agora. Peça à casa para confirmar sua presença."
    const val CODIGO_RESPOSTA_PERDIDA =
        "Não recebemos a resposta. Veja se a presença já foi confirmada e, se não, digite o código de novo."
    const val CODIGO_FALHOU = "Não foi possível confirmar o código. Tente de novo."
}
