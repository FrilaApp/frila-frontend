package br.com.frila.core.dominio.regra

import br.com.frila.core.dominio.modelo.Coordenada
import java.text.Normalizer
import java.util.Locale

/**
 * Cobertura atual do Frila: o Distrito Federal. Endereço fora dele pode ser cadastrado, mas a pessoa é avisada de que o foco e
 * a cobertura do Frila, por ora, são só do DF (decisão da PO sobre o relatório de testes da 0.5.5, item A6). Porte de
 * `iOS/Sources/Dominio/CoberturaDoDF.swift`, com os mesmos limites e a mesma ordem de decisão.
 *
 * A conferência é uma heurística local, sem rede: usa a unidade federativa que o geocodificador devolve quando existe e, sem
 * ela, um retângulo que envolve o DF. O retângulo é folgado de propósito e inclui um pedaço do Entorno em Goiás, então um ponto
 * de fora pode passar por dentro. O aviso é informativo: nunca impede o cadastro nem decide quem recebe vaga (isso é do servidor).
 */
object CoberturaDoDF {
    /** Retângulo que envolve o Distrito Federal (limites do GDF, com folga de cerca de 1 km). */
    internal val LATITUDES = -16.06..-15.49
    internal val LONGITUDES = -48.30..-47.29

    /**
     * `true` quando o ponto está fora do Distrito Federal. [area] é a unidade federativa como o geocodificador a devolveu
     * ("DF", "Distrito Federal", "Federal District", "GO"…) e, quando vem, vale mais que o retângulo; [codigoDoPais] é o código
     * ISO do país ("BR"…), quando o geocodificador o traz.
     */
    fun estaForaDoDF(latitude: Double, longitude: Double, area: String? = null, codigoDoPais: String? = null): Boolean {
        val pais = codigoDoPais?.trim()?.uppercase(Locale.ROOT)
        if (!pais.isNullOrEmpty() && pais != "BR") return true
        val uf = normalizar(area)
        if (!uf.isNullOrEmpty()) return uf !in NOMES_DO_DF
        return !(latitude in LATITUDES && longitude in LONGITUDES)
    }

    fun estaForaDoDF(coordenada: Coordenada, area: String? = null, codigoDoPais: String? = null): Boolean =
        estaForaDoDF(coordenada.latitude, coordenada.longitude, area, codigoDoPais)

    private val NOMES_DO_DF = setOf("df", "distrito federal", "federal district")

    /** Sem acento e em minúsculas, como o `folding(.diacriticInsensitive, .caseInsensitive)` do iOS. */
    private fun normalizar(texto: String?): String? = texto?.trim()?.let {
        Normalizer.normalize(it, Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "").lowercase(Locale.ROOT)
    }
}
