package br.com.frila.core.dominio.regra

/**
 * Classificação do valor da diária em relação à faixa de referência não bloqueante (B-124).
 */
enum class AvisoValorDiaria {
    MUITO_BAIXO,
    MUITO_ALTO,
}

/**
 * Faixa de referência fixa para o valor da diária nas telas da casa (B-124).
 * Valores fora da faixa geram apenas aviso na tela; apenas valor <= 0 é recusado.
 */
object ReferenciaValorDiaria {
    /** Limite inferior de referência em centavos: R$ 50,00 (B-124). */
    const val PISO_AVISO_CENTAVOS = 5_000L

    /** Limite superior de referência em centavos: R$ 2.000,00 (B-124). */
    const val TETO_AVISO_CENTAVOS = 200_000L

    /**
     * Avalia [centavos] contra a faixa de referência (B-124).
     * Retorna `null` para valor nulo, não positivo (<= 0) ou dentro de [5000, 200000].
     */
    fun avaliar(centavos: Long?): AvisoValorDiaria? = when {
        centavos == null || centavos <= 0L -> null
        centavos < PISO_AVISO_CENTAVOS -> AvisoValorDiaria.MUITO_BAIXO
        centavos > TETO_AVISO_CENTAVOS -> AvisoValorDiaria.MUITO_ALTO
        else -> null
    }
}
