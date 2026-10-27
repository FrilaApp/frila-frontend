package br.com.frila.core.dominio.regra

/**
 * Validação e formatação de números telefônicos no padrão brasileiro (Anatel) e E.164.
 *
 * Suporta:
 * - Telefonia móvel nacional: 11 dígitos com DDD (ex: "11987654321"). O primeiro dígito após DDD é sempre 9.
 * - Telefonia fixa nacional: 10 dígitos com DDD (ex: "1134567890"). O primeiro dígito após DDD varia entre 2 e 5.
 * - Formato internacional E.164 com código do país Brasil (+55): ex "+5511987654321".
 */
object ValidadorTelefone {

    private val DDDS_VALIDOS = setOf(
        11, 12, 13, 14, 15, 16, 17, 18, 19,
        21, 22, 24, 27, 28,
        31, 32, 33, 34, 35, 37, 38,
        41, 42, 43, 44, 45, 46, 47, 48, 49,
        51, 53, 54, 55,
        61, 62, 63, 64, 65, 66, 67, 68, 69,
        71, 73, 74, 75, 77, 79,
        81, 82, 83, 84, 85, 86, 87, 88, 89,
        91, 92, 93, 94, 95, 96, 97, 98, 99,
    )

    /**
     * Extrai os dígitos nacionais (10 ou 11 dígitos sem código de país +55).
     */
    fun extrairDigitosNacionais(telefoneRaw: String): String {
        val digitos = telefoneRaw.filter { it.isDigit() }
        return if (digitos.length in 12..13 && digitos.startsWith("55")) {
            digitos.substring(2)
        } else {
            digitos
        }
    }

    /**
     * Valida se a sequência numérica representa um telefone brasileiro válido com DDD.
     */
    fun ehValido(telefoneRaw: String): Boolean {
        val nacionais = extrairDigitosNacionais(telefoneRaw)
        if (nacionais.length !in 10..11) return false

        val ddd = nacionais.substring(0, 2).toIntOrNull() ?: return false
        if (ddd !in DDDS_VALIDOS) return false

        val primeiroDigitoNumero = nacionais[2]

        return if (nacionais.length == 11) {
            // Celular: deve começar com dígito 9 após o DDD
            primeiroDigitoNumero == '9'
        } else {
            // Fixo: primeiro dígito após DDD deve ser entre 2 e 5
            primeiroDigitoNumero in '2'..'5'
        }
    }

    /**
     * Converte o número de telefone para a representação canônica E.164 (+55...).
     * Retorna null se o telefone for inválido.
     */
    fun paraE164(telefoneRaw: String): String? {
        if (!ehValido(telefoneRaw)) return null
        val nacionais = extrairDigitosNacionais(telefoneRaw)
        return "+55$nacionais"
    }

    /**
     * Formata visualmente como "(XX) XXXXX-XXXX" para móvel ou "(XX) XXXX-XXXX" para fixo.
     */
    fun formatar(telefoneRaw: String): String {
        val nacionais = extrairDigitosNacionais(telefoneRaw)
        return when (nacionais.length) {
            11 -> "(%s) %s-%s".format(
                nacionais.substring(0, 2),
                nacionais.substring(2, 7),
                nacionais.substring(7, 11),
            )
            10 -> "(%s) %s-%s".format(
                nacionais.substring(0, 2),
                nacionais.substring(2, 6),
                nacionais.substring(6, 10),
            )
            else -> telefoneRaw
        }
    }
}
