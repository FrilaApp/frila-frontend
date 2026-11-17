package br.com.frila.feature.perfil

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/** L1-3a: a caixa do rosto estimada pela distância entre os olhos (o detector do sistema não dá a caixa). */
class EstimativaDoRostoTest {

    @Test
    fun `a caixa e proporcional a distancia entre os olhos`() {
        assertEquals(RostoDetectado(250, 300), EstimativaDoRosto.caixaPelosOlhos(100f))
    }

    @Test
    fun `distancia invalida vira caixa vazia e nunca libera a foto (so avisa)`() {
        listOf(0f, -5f, Float.NaN, Float.POSITIVE_INFINITY).forEach { invalida ->
            assertEquals(RostoDetectado(0, 0), EstimativaDoRosto.caixaPelosOlhos(invalida), "distância $invalida")
        }
        assertEquals(
            ResultadoDaVerificacaoLocal.AvisoSemRosto,
            RegraDoRostoNaFoto.decidir(listOf(EstimativaDoRosto.caixaPelosOlhos(Float.NaN)), 1000, 1000),
        )
    }

    @Test
    fun `olhos afastados o bastante liberam e olhos muito juntos so avisam na foto de 1000 por 1000`() {
        // 100 px entre os olhos: caixa de 250x300 = 7,5% da foto; 10 px: 25x30 = 0,075%.
        assertEquals(ResultadoDaVerificacaoLocal.Liberada, RegraDoRostoNaFoto.decidir(listOf(EstimativaDoRosto.caixaPelosOlhos(100f)), 1000, 1000))
        assertEquals(
            ResultadoDaVerificacaoLocal.AvisoSemRosto,
            RegraDoRostoNaFoto.decidir(listOf(EstimativaDoRosto.caixaPelosOlhos(10f)), 1000, 1000),
        )
    }

    @Test
    fun `o limite de 1 por cento da foto e exato`() {
        // Na foto 1000x1000 (1.000.000 px²), 1% = 10.000 px²: com 40 px entre os olhos a caixa é 100x120 = 12.000 (libera); com 35 px, 88x105 = 9.240 (so avisa).
        assertEquals(ResultadoDaVerificacaoLocal.Liberada, RegraDoRostoNaFoto.decidir(listOf(EstimativaDoRosto.caixaPelosOlhos(40f)), 1000, 1000))
        assertEquals(
            ResultadoDaVerificacaoLocal.AvisoSemRosto,
            RegraDoRostoNaFoto.decidir(listOf(EstimativaDoRosto.caixaPelosOlhos(35f)), 1000, 1000),
        )
    }
}
