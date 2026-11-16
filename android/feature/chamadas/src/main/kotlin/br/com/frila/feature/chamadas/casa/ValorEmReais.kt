package br.com.frila.feature.chamadas.casa

/**
 * O valor como a pessoa digita, em reais ("180" ou "180,50"), e o caminho até os centavos do contrato.
 * Paridade com `ChamadaDiretaViewModel.valorDigitado` e `textoEmReais` do iOS.
 */
internal object ValorEmReais {
    private const val MAXIMO_DE_ALGARISMOS_EM_REAIS = 5

    /**
     * Limpa o que a pessoa digita ou cola: só algarismos e uma vírgula, até 5 algarismos em reais e 2 em
     * centavos. Com vírgula, o ponto é separador de milhar ("R$ 1.500,00" vale 1.500). Sem vírgula, o ponto
     * só é milhar quando separa grupos de três ("1.500"); senão é a vírgula decimal de um teclado em outro
     * idioma ("1.50"). Com mais de 5 algarismos em reais devolve [anterior]: cortar "1.500.000,00" em
     * 15000,00 daria um valor 100 vezes menor e plausível.
     */
    fun digitado(texto: String, anterior: String = ""): String {
        val permitido = texto.filter { it in '0'..'9' || it == ',' || it == '.' }
        val virgula = permitido.indexOf(',')
        val separador = when {
            virgula >= 0 -> virgula
            pontoDeMilhar(permitido) -> -1
            else -> permitido.lastIndexOf('.')
        }
        val reais = (if (separador >= 0) permitido.substring(0, separador) else permitido).filter(Char::isDigit)
        if (reais.length > MAXIMO_DE_ALGARISMOS_EM_REAIS) return anterior
        if (separador < 0) return reais
        val centavos = permitido.substring(separador + 1).filter(Char::isDigit).take(2)
        return reais.ifEmpty { "0" } + "," + centavos
    }

    /** "1.500" e "12.345": cada ponto separa um grupo de três algarismos. */
    private fun pontoDeMilhar(texto: String): Boolean {
        val grupos = texto.split('.')
        return grupos.size > 1 && grupos.first().length in 1..3 && grupos.drop(1).all { it.length == 3 }
    }

    /** Os centavos de "180", "180,5" ou "180,50"; `null` para texto vazio, zero ou ilegível. "180," ainda vale 180. */
    fun centavos(texto: String): Long? {
        val completo = texto.trim().removeSuffix(",")
        val normalizado = if (',' in completo) completo.replace(".", "").replace(',', '.') else completo
        val partes = normalizado.split('.')
        if (partes.size > 2) return null
        val inteiro = partes[0]
        val fracao = partes.getOrNull(1) ?: ""
        if (inteiro.isEmpty() || inteiro.length > 9 || !inteiro.all(Char::isDigit)) return null
        if (fracao.length > 2 || !fracao.all(Char::isDigit)) return null
        return (inteiro.toLong() * 100 + fracao.padEnd(2, '0').toLong()).takeIf { it > 0 }
    }

    /** "R$ 180" fica "180"; "R$ 180,50" fica "180,50". */
    fun texto(centavos: Long): String =
        if (centavos % 100 == 0L) "${centavos / 100}" else "${centavos / 100},${(centavos % 100).toString().padStart(2, '0')}"
}
