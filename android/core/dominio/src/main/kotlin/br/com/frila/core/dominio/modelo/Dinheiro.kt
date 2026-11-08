package br.com.frila.core.dominio.modelo

import java.math.BigDecimal
import java.math.RoundingMode
import java.text.NumberFormat
import java.util.Locale

/**
 * Valor monetário em centavos de Real (BRL). Nunca representa dinheiro em Double/Float.
 *
 * RN02 (valor por hora de uma vaga): aceita de 100 a 1000 reais (10_000 a 100_000 centavos),
 * conferido por [ehValorHoraValido] / [paraValorHora].
 */
@JvmInline
value class Dinheiro(val centavos: Long) : Comparable<Dinheiro> {

    val reais: BigDecimal
        get() = BigDecimal(centavos).divide(BigDecimal(100), 2, RoundingMode.UNNECESSARY)

    /** Formata em BRL, ex.: "R$ 160,00". */
    fun formatado(locale: Locale = Locale.forLanguageTag("pt-BR")): String {
        val formatador = NumberFormat.getCurrencyInstance(locale)
        return formatador.format(reais)
    }

    operator fun plus(outro: Dinheiro): Dinheiro = Dinheiro(centavos + outro.centavos)

    operator fun minus(outro: Dinheiro): Dinheiro = Dinheiro(centavos - outro.centavos)

    override fun compareTo(other: Dinheiro): Int = centavos.compareTo(other.centavos)

    companion object {
        /** Limite inferior de RN02 para valor por hora: R$ 100,00. */
        val VALOR_HORA_MINIMO = Dinheiro(10_000)

        /** Limite superior de RN02 para valor por hora: R$ 1.000,00. */
        val VALOR_HORA_MAXIMO = Dinheiro(100_000)

        fun deReais(reais: Int, centavos: Int = 0): Dinheiro {
            require(centavos in 0..99) { "centavos deve estar entre 0 e 99: $centavos" }
            val sinal = if (reais < 0) -1 else 1
            return Dinheiro(reais * 100L + sinal * centavos)
        }

        /**
         * Valida o valor por hora de uma vaga contra RN02 (100 a 1000 reais, inclusive).
         * Retorna o próprio [Dinheiro] em caso de sucesso.
         */
        fun paraValorHora(centavos: Long): Result<Dinheiro> {
            val valor = Dinheiro(centavos)
            return if (ehValorHoraValido(valor)) {
                Result.success(valor)
            } else {
                Result.failure(
                    IllegalArgumentException(
                        "valor por hora fora da faixa RN02 " +
                            "(${VALOR_HORA_MINIMO.formatado()} a ${VALOR_HORA_MAXIMO.formatado()}): " +
                            valor.formatado(),
                    ),
                )
            }
        }

        fun ehValorHoraValido(valor: Dinheiro): Boolean =
            valor.centavos in VALOR_HORA_MINIMO.centavos..VALOR_HORA_MAXIMO.centavos
    }
}
