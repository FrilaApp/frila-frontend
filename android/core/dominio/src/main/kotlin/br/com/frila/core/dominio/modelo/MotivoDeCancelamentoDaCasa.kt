package br.com.frila.core.dominio.modelo

/**
 * Os motivos que a casa escolhe ao cancelar, a vaga inteira (`cancelar_vaga`) ou uma posição (`cancelar_posicao`): paridade com
 * `MotivoDeCancelamento.opcoes(para: .contratante)` do iOS. O contrato recebe texto, não código: [texto] é o `motivo` que vai ao servidor
 * (mínimo de [MINIMO_DO_MOTIVO] caracteres, e passa pelo filtro da diretriz 1.2). [OUTRO] não diz nada sozinho: o campo livre é obrigatório.
 */
enum class MotivoDeCancelamentoDaCasa(val texto: String, val exigeDetalhes: Boolean = false) {
    MOVIMENTO_MENOR(Textos.MOVIMENTO_MENOR),
    PREENCHIDA_FORA(Textos.PREENCHIDA_FORA),
    MUDANCA_DE_PLANOS(Textos.MUDANCA_DE_PLANOS),
    PROBLEMA_NO_LOCAL(Textos.PROBLEMA_NO_LOCAL),
    OUTRO(Textos.OUTRO, exigeDetalhes = true),
    ;

    /**
     * O que vai ao servidor: o motivo e, se houver detalhe, o detalhe depois de dois pontos; em [OUTRO], só o detalhe. `null` enquanto não dá
     * para enviar (o detalhe obrigatório com menos de [MINIMO_DO_MOTIVO] caracteres).
     */
    fun textoParaOServidor(detalhes: String): String? {
        val detalhe = detalhes.trim()
        if (exigeDetalhes) return detalhe.takeIf { it.length >= MINIMO_DO_MOTIVO }
        return if (detalhe.isEmpty()) texto else "$texto: $detalhe"
    }

    /** Os textos dos motivos, num só lugar: as telas da casa e o servidor leem a mesma coisa. */
    object Textos {
        const val MOVIMENTO_MENOR = "Movimento menor que o esperado"
        const val PREENCHIDA_FORA = "A posição foi preenchida de outra forma"
        const val MUDANCA_DE_PLANOS = "O evento ou o turno mudou"
        const val PROBLEMA_NO_LOCAL = "Problema no estabelecimento"
        const val OUTRO = "Outro motivo"
    }

    companion object {
        const val MINIMO_DO_MOTIVO = 3
    }
}
