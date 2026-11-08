package br.com.frila.core.dominio.modelo

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Test
import kotlin.math.abs

class CoordenadaTest {

    @Test
    fun `distancia ate si mesma e zero`() {
        val brasilia = Coordenada(-15.7801, -47.9292)
        assertEquals(0.0, brasilia.distanciaKmAte(brasilia), 0.001)
    }

    @Test
    fun `distancia entre Brasilia e Goiania e proxima dos 170km conhecidos`() {
        // Distância em linha reta medida de referência (fontes geográficas públicas): ~170km.
        val brasilia = Coordenada(-15.7801, -47.9292)
        val goiania = Coordenada(-16.6869, -49.2648)

        val distancia = brasilia.distanciaKmAte(goiania)

        assertEquals(170.0, distancia, 10.0)
    }

    @Test
    fun `distancia e simetrica`() {
        val a = Coordenada(-15.80, -47.90)
        val b = Coordenada(-15.90, -48.00)

        assertEquals(a.distanciaKmAte(b), b.distanciaKmAte(a), 0.0001)
    }

    @Test
    fun `rejeita latitude fora do intervalo`() {
        assertThrows(IllegalArgumentException::class.java) {
            Coordenada(91.0, 0.0)
        }
    }

    @Test
    fun `rejeita longitude fora do intervalo`() {
        assertThrows(IllegalArgumentException::class.java) {
            Coordenada(0.0, 181.0)
        }
    }

    @Test
    fun `distancia nunca e negativa`() {
        val a = Coordenada(10.0, 10.0)
        val b = Coordenada(-10.0, -10.0)

        assertEquals(true, abs(a.distanciaKmAte(b)) == a.distanciaKmAte(b))
    }
}
