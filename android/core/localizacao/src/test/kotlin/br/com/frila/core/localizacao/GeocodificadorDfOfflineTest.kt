package br.com.frila.core.localizacao

import br.com.frila.core.dominio.modelo.Coordenada
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.CsvSource

class GeocodificadorDfOfflineTest {

    @Test
    fun `todas as 35 RAs oficiais do DF estao cadastradas com numeros e nomes unicos`() {
        val regioes = GeocodificadorDfOffline.REGIOES_ADMINISTRATIVAS
        assertEquals(35, regioes.size)
        assertEquals(35, regioes.map { it.numero }.distinct().size)
        assertEquals(35, regioes.map { it.nome }.distinct().size)
    }

    @ParameterizedTest
    @CsvSource(
        "-15.8333, -48.0569, Taguatinga",
        "-15.8397, -48.0264, Águas Claras",
        "-15.8167, -48.1167, Ceilândia",
        "-15.8167, -47.9833, Guará",
        "-15.8750, -48.0861, Samambaia",
        "-16.0167, -48.0667, Gama",
        "-15.6500, -47.7833, Sobradinho",
        "-15.6167, -47.6500, Planaltina",
        "-15.8083, -48.0333, Vicente Pires",
        "-15.7938, -47.8827, Plano Piloto",
    )
    fun `resolve corretamente coordenadas conhecidas para a Regiao Administrativa correspondente`(
        latitude: Double,
        longitude: Double,
        raEsperada: String,
    ) {
        val coordenada = Coordenada(latitude, longitude)
        val raResolvida = GeocodificadorDfOffline.resolverRegiaoAdministrativa(coordenada)

        assertEquals(raEsperada, raResolvida)
    }

    @Test
    fun `resolve coordenadas de polos urbanos e bairros de alta densidade`() {
        val asaSul = Coordenada(-15.8150, -47.9150)
        assertEquals("Asa Sul", GeocodificadorDfOffline.resolverPoloUrbano(asaSul))
        assertEquals("Plano Piloto", GeocodificadorDfOffline.resolverRegiaoAdministrativa(asaSul))

        val asaNorte = Coordenada(-15.7600, -47.8850)
        assertEquals("Asa Norte", GeocodificadorDfOffline.resolverPoloUrbano(asaNorte))
        assertEquals("Plano Piloto", GeocodificadorDfOffline.resolverRegiaoAdministrativa(asaNorte))

        val sudoeste = Coordenada(-15.7970, -47.9250)
        assertEquals("Sudoeste", GeocodificadorDfOffline.resolverPoloUrbano(sudoeste))
    }

    @Test
    fun `coordenada muito distante fora do DF retorna nulo`() {
        val goiania = Coordenada(-16.6869, -49.2648)
        assertNull(GeocodificadorDfOffline.resolverRegiaoAdministrativa(goiania))
        assertNull(GeocodificadorDfOffline.resolverPoloUrbano(goiania))
        assertEquals("Brasília / DF", GeocodificadorDfOffline.formatarExibicao(goiania))
    }

    @Test
    fun `formatarExibicao combina polo urbano e RA de forma amigavel`() {
        val asaSul = Coordenada(-15.8150, -47.9150)
        assertEquals("Asa Sul, Plano Piloto", GeocodificadorDfOffline.formatarExibicao(asaSul))

        val aguasClaras = Coordenada(-15.8397, -48.0264)
        assertEquals("Águas Claras", GeocodificadorDfOffline.formatarExibicao(aguasClaras))
    }

    @ParameterizedTest
    @CsvSource(
        "CLS 405 Bloco B - Asa Sul, Plano Piloto",
        "CLN 108 Bloco A - Asa Norte, Plano Piloto",
        "SQNW 102 - Noroeste, Plano Piloto",
        "QNA 15 Lote 20 - Taguatinga Norte, Taguatinga",
        "Av. das Castanheiras - Águas Claras, Águas Claras",
        "QNM 18 Conjunto A - Ceilândia Centro, Ceilândia",
        "QI 15 Bloco C - Guará II, Guará",
        "QS 408 Conjunto 3 - Samambaia Norte, Samambaia",
        "Setor Sul Quadra 1 - Gama, Gama",
        "Quadra 2 - Sobradinho, Sobradinho",
        "Rua 12 Chácara 30 - Vicente Pires, Vicente Pires",
    )
    fun `casarRegiaoAdministrativa identifica RA a partir de texto de endereco`(
        endereco: String,
        raEsperada: String,
    ) {
        val raCasada = GeocodificadorDfOffline.casarRegiaoAdministrativa(endereco)
        assertEquals(raEsperada, raCasada)
    }

    @Test
    fun `casarRegiaoAdministrativa com texto sem relacao ao DF retorna nulo`() {
        assertNull(GeocodificadorDfOffline.casarRegiaoAdministrativa("Avenida Paulista, Bela Vista, São Paulo - SP"))
        assertNull(GeocodificadorDfOffline.casarRegiaoAdministrativa("Rua das Flores, 123"))
    }
}
