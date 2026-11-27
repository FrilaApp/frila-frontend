package br.com.frila.core.dominio.regra

import br.com.frila.core.dominio.modelo.Coordenada
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.CsvSource

/** Os mesmos casos de `iOS/Tests/Unitarios/CoberturaDoDFTests.swift` (decisão A6 da PO). */
class CoberturaDoDFTest {

    @ParameterizedTest(name = "dentro do DF: {0}, {1}")
    @CsvSource(
        "-15.7942, -47.8822", // Plano Piloto
        "-15.8267, -47.9218", // Guará
        "-15.8330, -48.0500", // Taguatinga
        "-16.0000, -47.9500", // Santa Maria, sul do DF
        "-15.6000, -47.6500", // Planaltina, norte do DF
    )
    fun `pontos dentro do DF, sem unidade federativa, nao sao fora`(latitude: Double, longitude: Double) {
        assertFalse(CoberturaDoDF.estaForaDoDF(latitude, longitude))
    }

    @ParameterizedTest(name = "fora do DF: {0}, {1}")
    @CsvSource(
        "-16.6869, -49.2648", // Goiânia
        "-23.5505, -46.6333", // São Paulo
        "-12.9714, -38.5014", // Salvador
        "-15.4000, -47.9000", // ao norte do DF
        "-15.8000, -48.5000", // a oeste do DF
    )
    fun `pontos longe do DF, sem unidade federativa, sao fora`(latitude: Double, longitude: Double) {
        assertTrue(CoberturaDoDF.estaForaDoDF(latitude, longitude))
    }

    @ParameterizedTest(name = "área \"{0}\" fora = {1}")
    @CsvSource(
        "DF, false", "Distrito Federal, false", "distrito federal, false", "' Federal District ', false",
        "GO, true", "Goiás, true", "MG, true",
    )
    fun `a unidade federativa do geocodificador vale mais que o retangulo`(area: String, fora: Boolean) {
        // Ponto dentro do retângulo, no Entorno: só a unidade federativa separa os dois lados.
        assertEquals(fora, CoberturaDoDF.estaForaDoDF(-15.9000, -48.2800, area = area))
    }

    @Test
    fun `area vazia cai no retangulo`() {
        assertFalse(CoberturaDoDF.estaForaDoDF(-15.7942, -47.8822, area = "  "))
        assertTrue(CoberturaDoDF.estaForaDoDF(-16.6869, -49.2648, area = ""))
    }

    @Test
    fun `pais diferente de BR e fora, mesmo com as coordenadas do DF`() {
        assertTrue(CoberturaDoDF.estaForaDoDF(-15.7942, -47.8822, area = "DF", codigoDoPais = "AR"))
        assertFalse(CoberturaDoDF.estaForaDoDF(-15.7942, -47.8822, area = "DF", codigoDoPais = "br"))
    }

    @Test
    fun `a sobrecarga com Coordenada da a mesma resposta`() {
        assertTrue(CoberturaDoDF.estaForaDoDF(Coordenada(-16.6869, -49.2648)))
        assertFalse(CoberturaDoDF.estaForaDoDF(Coordenada(-15.8200, -47.9000)))
    }
}
