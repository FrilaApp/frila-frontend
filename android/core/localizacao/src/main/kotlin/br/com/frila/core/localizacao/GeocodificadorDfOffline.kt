package br.com.frila.core.localizacao

import br.com.frila.core.dominio.modelo.Coordenada
import java.text.Normalizer

/**
 * Geocodificação reversa offline de alta fidelidade para o Distrito Federal (RN02/RF05).
 * Resolve coordenadas geográficas (WGS84) para as Regiões Administrativas oficiais e polos urbanos
 * por proximidade geográfica (Haversine) sem onerar a rede ou violar limites da API de mapas.
 */
object GeocodificadorDfOffline {

    /** Região Administrativa oficial do Distrito Federal. */
    data class RegiaoAdministrativa(
        val numero: Int,
        val nome: String,
        val centroide: Coordenada,
    )

    /** Polo urbano ou bairro representativo mapeado dentro de uma Região Administrativa. */
    data class PoloUrbano(
        val nomeExibicao: String,
        val regiaoAdministrativa: String,
        val centroide: Coordenada,
    )

    /** As 35 Regiões Administrativas oficiais do Distrito Federal (fonte oficial GDF / SEGOV). */
    val REGIOES_ADMINISTRATIVAS: List<RegiaoAdministrativa> = listOf(
        RegiaoAdministrativa(1, "Plano Piloto", Coordenada(-15.793889, -47.882778)),
        RegiaoAdministrativa(2, "Gama", Coordenada(-16.016667, -48.066667)),
        RegiaoAdministrativa(3, "Taguatinga", Coordenada(-15.833333, -48.056944)),
        RegiaoAdministrativa(4, "Brazlândia", Coordenada(-15.666667, -48.200000)),
        RegiaoAdministrativa(5, "Sobradinho", Coordenada(-15.650000, -47.783333)),
        RegiaoAdministrativa(6, "Planaltina", Coordenada(-15.616667, -47.650000)),
        RegiaoAdministrativa(7, "Paranoá", Coordenada(-15.766667, -47.783333)),
        RegiaoAdministrativa(8, "Núcleo Bandeirante", Coordenada(-15.866667, -47.966667)),
        RegiaoAdministrativa(9, "Ceilândia", Coordenada(-15.816667, -48.116667)),
        RegiaoAdministrativa(10, "Guará", Coordenada(-15.816667, -47.983333)),
        RegiaoAdministrativa(11, "Cruzeiro", Coordenada(-15.791667, -47.936111)),
        RegiaoAdministrativa(12, "Samambaia", Coordenada(-15.875000, -48.086111)),
        RegiaoAdministrativa(13, "Santa Maria", Coordenada(-16.016667, -47.983333)),
        RegiaoAdministrativa(14, "São Sebastião", Coordenada(-15.900000, -47.766667)),
        RegiaoAdministrativa(15, "Recanto das Emas", Coordenada(-15.908333, -48.066667)),
        RegiaoAdministrativa(16, "Lago Sul", Coordenada(-15.840000, -47.870000)),
        RegiaoAdministrativa(17, "Riacho Fundo", Coordenada(-15.883333, -48.016667)),
        RegiaoAdministrativa(18, "Lago Norte", Coordenada(-15.733333, -47.850000)),
        RegiaoAdministrativa(19, "Candangolândia", Coordenada(-15.850000, -47.950000)),
        RegiaoAdministrativa(20, "Águas Claras", Coordenada(-15.839722, -48.026389)),
        RegiaoAdministrativa(21, "Riacho Fundo II", Coordenada(-15.900000, -48.033333)),
        RegiaoAdministrativa(22, "Sudoeste/Octogonal", Coordenada(-15.796944, -47.925000)),
        RegiaoAdministrativa(23, "Varjão", Coordenada(-15.716667, -47.883333)),
        RegiaoAdministrativa(24, "Park Way", Coordenada(-15.890000, -47.950000)),
        RegiaoAdministrativa(25, "SCIA / Estrutural", Coordenada(-15.783333, -47.983333)),
        RegiaoAdministrativa(26, "Sobradinho II", Coordenada(-15.633333, -47.800000)),
        RegiaoAdministrativa(27, "Jardim Botânico", Coordenada(-15.883333, -47.816667)),
        RegiaoAdministrativa(28, "Itapoã", Coordenada(-15.750000, -47.766667)),
        RegiaoAdministrativa(29, "SIA", Coordenada(-15.816667, -47.950000)),
        RegiaoAdministrativa(30, "Vicente Pires", Coordenada(-15.808333, -48.033333)),
        RegiaoAdministrativa(31, "Fercal", Coordenada(-15.583333, -47.883333)),
        RegiaoAdministrativa(32, "Sol Nascente/Pôr do Sol", Coordenada(-15.825000, -48.140000)),
        RegiaoAdministrativa(33, "Arniqueira", Coordenada(-15.866667, -48.016667)),
        RegiaoAdministrativa(34, "Arapoanga", Coordenada(-15.630000, -47.690000)),
        RegiaoAdministrativa(35, "Água Quente", Coordenada(-16.000000, -48.166667)),
    )

    /** Polos urbanos e bairros de alta densidade no DF para granularidade amigável. */
    val POLOS_URBANOS: List<PoloUrbano> = listOf(
        PoloUrbano("Asa Sul", "Plano Piloto", Coordenada(-15.8150, -47.9150)),
        PoloUrbano("Asa Norte", "Plano Piloto", Coordenada(-15.7600, -47.8850)),
        PoloUrbano("Noroeste", "Plano Piloto", Coordenada(-15.7500, -47.9100)),
        PoloUrbano("Sudoeste", "Sudoeste/Octogonal", Coordenada(-15.7970, -47.9250)),
        PoloUrbano("Octogonal", "Sudoeste/Octogonal", Coordenada(-15.8030, -47.9350)),
        PoloUrbano("Águas Claras", "Águas Claras", Coordenada(-15.8397, -48.0264)),
        PoloUrbano("Taguatinga Centro", "Taguatinga", Coordenada(-15.8333, -48.0569)),
        PoloUrbano("Taguatinga Sul", "Taguatinga", Coordenada(-15.8450, -48.0480)),
        PoloUrbano("Taguatinga Norte", "Taguatinga", Coordenada(-15.8150, -48.0650)),
        PoloUrbano("Ceilândia Centro", "Ceilândia", Coordenada(-15.8167, -48.1167)),
        PoloUrbano("Ceilândia Norte", "Ceilândia", Coordenada(-15.8000, -48.1100)),
        PoloUrbano("Ceilândia Sul", "Ceilândia", Coordenada(-15.8300, -48.1250)),
        PoloUrbano("Guará I", "Guará", Coordenada(-15.8167, -47.9833)),
        PoloUrbano("Guará II", "Guará", Coordenada(-15.8280, -47.9780)),
        PoloUrbano("Samambaia Norte", "Samambaia", Coordenada(-15.8650, -48.0850)),
        PoloUrbano("Samambaia Sul", "Samambaia", Coordenada(-15.8850, -48.0900)),
        PoloUrbano("Gama", "Gama", Coordenada(-16.0167, -48.0667)),
        PoloUrbano("Sobradinho", "Sobradinho", Coordenada(-15.6500, -47.7833)),
        PoloUrbano("Planaltina", "Planaltina", Coordenada(-15.6167, -47.6500)),
        PoloUrbano("Vicente Pires", "Vicente Pires", Coordenada(-15.8083, -48.0333)),
        PoloUrbano("Lago Sul", "Lago Sul", Coordenada(-15.8400, -47.8700)),
        PoloUrbano("Lago Norte", "Lago Norte", Coordenada(-15.7333, -47.8500)),
    )

    private val REGRAS_CASAMENTO: List<Pair<Regex, String>> = listOf(
        Regex("""\b(riacho\s+fundo\s+(ii|2))\b""", RegexOption.IGNORE_CASE) to "Riacho Fundo II",
        Regex("""\b(sobradinho\s+(ii|2))\b""", RegexOption.IGNORE_CASE) to "Sobradinho II",
        Regex("""\b(sol\s+nascente|por\s+do\s+sol)\b""", RegexOption.IGNORE_CASE) to "Sol Nascente/Pôr do Sol",
        Regex("""\b(sudoeste|octogonal)\b""", RegexOption.IGNORE_CASE) to "Sudoeste/Octogonal",
        Regex("""\b(scia|estrutural|cidade\s+estrutural)\b""", RegexOption.IGNORE_CASE) to "SCIA / Estrutural",
        Regex("""\b(sia|setor\s+de\s+industria\s+e\s+abastecimento)\b""", RegexOption.IGNORE_CASE) to "SIA",
        Regex("""\b(plano\s+piloto|asa\s+sul|asa\s+norte|noroeste|vila\s+planalto)\b""", RegexOption.IGNORE_CASE) to "Plano Piloto",
        Regex("""\briacho\s+fundo\b""", RegexOption.IGNORE_CASE) to "Riacho Fundo",
        Regex("""\bsobradinho\b""", RegexOption.IGNORE_CASE) to "Sobradinho",
        Regex("""\bagua\s+quente\b""", RegexOption.IGNORE_CASE) to "Água Quente",
        Regex("""\baguas\s+claras\b""", RegexOption.IGNORE_CASE) to "Águas Claras",
        Regex("""\barapoanga\b""", RegexOption.IGNORE_CASE) to "Arapoanga",
        Regex("""\barniqueira(s)?\b""", RegexOption.IGNORE_CASE) to "Arniqueira",
        Regex("""\bbrazlandia\b""", RegexOption.IGNORE_CASE) to "Brazlândia",
        Regex("""\bcandangolandia\b""", RegexOption.IGNORE_CASE) to "Candangolândia",
        Regex("""\bceilandia\b""", RegexOption.IGNORE_CASE) to "Ceilândia",
        Regex("""\bcruzeiro\b""", RegexOption.IGNORE_CASE) to "Cruzeiro",
        Regex("""\bfercal\b""", RegexOption.IGNORE_CASE) to "Fercal",
        Regex("""\bgama\b""", RegexOption.IGNORE_CASE) to "Gama",
        Regex("""\bguara\b""", RegexOption.IGNORE_CASE) to "Guará",
        Regex("""\bitapoa\b""", RegexOption.IGNORE_CASE) to "Itapoã",
        Regex("""\bjardim\s+botanico\b""", RegexOption.IGNORE_CASE) to "Jardim Botânico",
        Regex("""\blago\s+norte\b""", RegexOption.IGNORE_CASE) to "Lago Norte",
        Regex("""\blago\s+sul\b""", RegexOption.IGNORE_CASE) to "Lago Sul",
        Regex("""\bnucleo\s+bandeirante\b""", RegexOption.IGNORE_CASE) to "Núcleo Bandeirante",
        Regex("""\bparanoa\b""", RegexOption.IGNORE_CASE) to "Paranoá",
        Regex("""\bpark\s+way\b""", RegexOption.IGNORE_CASE) to "Park Way",
        Regex("""\bplanaltina\b""", RegexOption.IGNORE_CASE) to "Planaltina",
        Regex("""\brecanto\s+das\s+emas\b""", RegexOption.IGNORE_CASE) to "Recanto das Emas",
        Regex("""\bsamambaia\b""", RegexOption.IGNORE_CASE) to "Samambaia",
        Regex("""\bsanta\s+maria\b""", RegexOption.IGNORE_CASE) to "Santa Maria",
        Regex("""\bsao\s+sebastiao\b""", RegexOption.IGNORE_CASE) to "São Sebastião",
        Regex("""\btaguatinga\b""", RegexOption.IGNORE_CASE) to "Taguatinga",
        Regex("""\bvarjao\b""", RegexOption.IGNORE_CASE) to "Varjão",
        Regex("""\bvicente\s+pires\b""", RegexOption.IGNORE_CASE) to "Vicente Pires",
    )

    /**
     * Resolve a Região Administrativa oficial mais próxima para as coordenadas fornecidas.
     * Prioriza polos urbanos catalogados (ex.: Asa Sul/Asa Norte para Plano Piloto) para desambiguação
     * precisa de fronteiras, caindo para o centroide da RA em caso geral.
     * Retorna `null` se a coordenada estiver a mais de [raioMaximoKm] de qualquer RA do DF.
     */
    fun resolverRegiaoAdministrativa(coordenada: Coordenada, raioMaximoKm: Double = 35.0): String? {
        val poloProximo = POLOS_URBANOS.minByOrNull { it.centroide.distanciaKmAte(coordenada) }
            ?.takeIf { it.centroide.distanciaKmAte(coordenada) <= 6.0 }

        if (poloProximo != null) {
            return poloProximo.regiaoAdministrativa
        }

        val maisProxima = REGIOES_ADMINISTRATIVAS.minByOrNull { it.centroide.distanciaKmAte(coordenada) } ?: return null
        val distancia = maisProxima.centroide.distanciaKmAte(coordenada)
        return if (distancia <= raioMaximoKm) maisProxima.nome else null
    }

    /**
     * Resolve o polo urbano ou bairro específico mais próximo (ex: "Asa Sul", "Taguatinga Centro", "Águas Claras").
     * Permite granularidade intuitiva para exibição em cartões e cabeçalhos.
     */
    fun resolverPoloUrbano(coordenada: Coordenada, raioMaximoKm: Double = 10.0): String? {
        val maisProximo = POLOS_URBANOS.minByOrNull { it.centroide.distanciaKmAte(coordenada) } ?: return null
        val distancia = maisProximo.centroide.distanciaKmAte(coordenada)
        return if (distancia <= raioMaximoKm) maisProximo.nomeExibicao else null
    }

    /**
     * Formata um rótulo de localização amigável sem chamadas de rede.
     * Ex.: "Asa Sul, Plano Piloto", "Águas Claras", ou "Brasília / DF" em caso de limites distantes.
     */
    fun formatarExibicao(coordenada: Coordenada): String {
        val polo = POLOS_URBANOS.minByOrNull { it.centroide.distanciaKmAte(coordenada) }
            ?.takeIf { it.centroide.distanciaKmAte(coordenada) <= 6.0 }

        if (polo != null) {
            return if (polo.nomeExibicao != polo.regiaoAdministrativa) {
                "${polo.nomeExibicao}, ${polo.regiaoAdministrativa}"
            } else {
                polo.nomeExibicao
            }
        }

        val ra = resolverRegiaoAdministrativa(coordenada)
        return ra ?: "Brasília / DF"
    }

    /**
     * Encontra a Região Administrativa oficial a partir de texto livre (ex.: endereço, CEP ou resultado de geocoder).
     * Normaliza acentos e cedilhas antes da comparação.
     */
    fun casarRegiaoAdministrativa(texto: String): String? {
        val normalizado = removerAcentos(texto).lowercase()
        for ((regex, regiao) in REGRAS_CASAMENTO) {
            if (regex.containsMatchIn(normalizado)) {
                return regiao
            }
        }
        return null
    }

    private fun removerAcentos(texto: String): String {
        val semAcento = Normalizer.normalize(texto, Normalizer.Form.NFD)
        return Regex("\\p{InCombiningDiacriticalMarks}+").replace(semAcento, "")
    }
}
