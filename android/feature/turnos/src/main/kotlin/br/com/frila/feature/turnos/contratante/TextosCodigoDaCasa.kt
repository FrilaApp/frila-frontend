package br.com.frila.feature.turnos.contratante

/** Textos do código de chegada na tela do turno da casa (paridade com `TextosDoCheckinPorCodigoCasa.swift`). */
object TextosCodigoDaCasa {
    const val TITULO = "Código de chegada"
    const val EXPLICACAO =
        "Mostre este código de 6 números ao profissional que chegou. Ele digitará no aplicativo para confirmar a presença."
    const val SEM_CODIGO_PARA_ESTE_CHECKIN =
        "O check-in foi feito longe do local ou há mais de 15 min. Confirme a presença pelo botão abaixo."
    const val VALIDADE = "Vale por mais %s"
    const val GERANDO_OUTRO = "O código venceu. Gerando outro…"
    const val CARREGANDO = "Gerando o código…"
    const val FALHOU = "Não foi possível gerar o código. Confira a conexão e tente novamente."
    const val TENTAR_DE_NOVO = "Tentar de novo"
    const val FORA_DA_JANELA = "Fora da janela de check-in deste turno."
    const val ENCERRADO = "O código não vale mais neste turno. Confirme a presença pelo botão de confirmação manual abaixo."
    private const val CODIGO_POR_EXTENSO = "Código de chegada: %s"

    /** Lido dígito a dígito pelo leitor de tela: "Código de chegada: 0 4 9 2 1 5". */
    fun codigoPorExtenso(digitos: String): String = CODIGO_POR_EXTENSO.format(digitos.toList().joinToString(" "))
}
