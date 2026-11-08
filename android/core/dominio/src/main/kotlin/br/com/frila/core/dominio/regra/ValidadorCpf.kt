package br.com.frila.core.dominio.regra

/**
 * Validação oficial de Cadastro de Pessoas Físicas (CPF).
 * Implementa a verificação dos dois dígitos verificadores segundo o algoritmo módulo 11
 * da Receita Federal do Brasil.
 */
object ValidadorCpf {

    private val CPFS_INVALIDOS_CONHECIDOS = (0..9).map { digito ->
        digito.toString().repeat(11)
    }.toSet()

    /**
     * Valida se a string representa um CPF matematicamente válido.
     * Aceita strings formatadas ("000.000.000-00") ou apenas dígitos numéricos ("00000000000").
     */
    fun ehValido(cpfRaw: String): Boolean {
        val digitos = cpfRaw.filter { it.isDigit() }
        if (digitos.length != 11) return false
        if (digitos in CPFS_INVALIDOS_CONHECIDOS) return false

        val numeros = digitos.map { it.digitToInt() }

        // Primeiro dígito verificador
        val soma1 = (0..8).sumOf { i -> numeros[i] * (10 - i) }
        val resto1 = (soma1 * 10) % 11
        val dv1 = if (resto1 == 10) 0 else resto1
        if (dv1 != numeros[9]) return false

        // Segundo dígito verificador
        val soma2 = (0..9).sumOf { i -> numeros[i] * (11 - i) }
        val resto2 = (soma2 * 10) % 11
        val dv2 = if (resto2 == 10) 0 else resto2
        if (dv2 != numeros[10]) return false

        return true
    }

    /**
     * Formata uma cadeia de 11 dígitos no padrão visual brasileiro "000.000.000-00".
     */
    fun formatar(cpfRaw: String): String {
        val digitos = cpfRaw.filter { it.isDigit() }
        if (digitos.length != 11) return cpfRaw
        return "%s.%s.%s-%s".format(
            digitos.substring(0, 3),
            digitos.substring(3, 6),
            digitos.substring(6, 9),
            digitos.substring(9, 11),
        )
    }

    /**
     * Remove qualquer caractere não numérico, retornando apenas dígitos.
     */
    fun desformatar(cpfRaw: String): String = cpfRaw.filter { it.isDigit() }
}
