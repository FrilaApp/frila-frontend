package br.com.frila.feature.perfil

import kotlin.math.roundToInt

/**
 * O `android.media.FaceDetector` não devolve a caixa do rosto, só a distância entre os olhos. Daqui sai uma caixa aproximada
 * (um rosto tem ~2,5 vezes a distância entre os olhos de largura e ~3 vezes de altura) para a [RegraDoRostoNaFoto] medir o 1% da foto.
 */
object EstimativaDoRosto {
    const val LARGURA_EM_DISTANCIAS_ENTRE_OS_OLHOS = 2.5f
    const val ALTURA_EM_DISTANCIAS_ENTRE_OS_OLHOS = 3.0f

    /** Distância inválida (zero, negativa, NaN ou infinita) vira caixa vazia: a foto nunca é liberada por causa dela. */
    fun caixaPelosOlhos(distanciaEntreOsOlhosPx: Float): RostoDetectado {
        if (!distanciaEntreOsOlhosPx.isFinite() || distanciaEntreOsOlhosPx <= 0f) return RostoDetectado(0, 0)
        return RostoDetectado(
            largura = (distanciaEntreOsOlhosPx * LARGURA_EM_DISTANCIAS_ENTRE_OS_OLHOS).roundToInt(),
            altura = (distanciaEntreOsOlhosPx * ALTURA_EM_DISTANCIAS_ENTRE_OS_OLHOS).roundToInt(),
        )
    }
}
