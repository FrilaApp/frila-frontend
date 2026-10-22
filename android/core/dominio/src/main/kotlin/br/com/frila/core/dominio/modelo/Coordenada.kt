package br.com.frila.core.dominio.modelo

import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/** Coordenada geográfica (WGS84) em graus decimais. */
data class Coordenada(val latitude: Double, val longitude: Double) {

    init {
        require(latitude in -90.0..90.0) { "latitude fora do intervalo [-90, 90]: $latitude" }
        require(longitude in -180.0..180.0) { "longitude fora do intervalo [-180, 180]: $longitude" }
    }

    /** Distância em quilômetros até [outra], pela fórmula de Haversine (raio médio da Terra: 6371 km). */
    fun distanciaKmAte(outra: Coordenada): Double {
        val deltaLatRad = Math.toRadians(outra.latitude - latitude)
        val deltaLonRad = Math.toRadians(outra.longitude - longitude)
        val latRad1 = Math.toRadians(latitude)
        val latRad2 = Math.toRadians(outra.latitude)

        val senMeioLat = sin(deltaLatRad / 2)
        val senMeioLon = sin(deltaLonRad / 2)
        val a = senMeioLat * senMeioLat + cos(latRad1) * cos(latRad2) * senMeioLon * senMeioLon
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return RAIO_MEDIO_TERRA_KM * c
    }

    companion object {
        private const val RAIO_MEDIO_TERRA_KM = 6371.0
    }
}
