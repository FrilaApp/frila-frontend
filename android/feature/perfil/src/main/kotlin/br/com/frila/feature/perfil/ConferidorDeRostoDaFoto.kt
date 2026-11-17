package br.com.frila.feature.perfil

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.FaceDetector
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Confere, no aparelho e antes do envio, que a foto do profissional tem um rosto só. A foto nunca sai do aparelho por causa disto. */
fun interface ConferidorDeRostoDaFoto {
    suspend fun conferir(jpeg: ByteArray): ResultadoDaVerificacaoLocal
}

/**
 * Detector do próprio Android (`android.media.FaceDetector`): roda dentro do sistema, sem biblioteca nem modelo de terceiros, e **não fala com
 * a rede** (decisão do O2, #876: o ML Kit manda métrica de uso ao Google, sem base legal, e quebra sem o backend dela; o iOS usa o Vision,
 * que não manda nada). Falha fechada e com prazo, por [RegraDoRostoNaFoto.comFalhaFechada].
 *
 * Limites conhecidos: acha só rosto de frente com os dois olhos visíveis (rosto de perfil, de óculos escuros ou muito inclinado pode ser
 * barrado aqui; o servidor continua decidindo no fim) e devolve só a distância entre os olhos, de onde sai a caixa de [EstimativaDoRosto].
 * Espera a foto já na posição certa (o preparo do JPEG, no L1-3b, aplica a orientação antes). O prazo só corta nos pontos de espera: a
 * chamada do sistema em si não é interrompível, mas roda em foto reduzida (no máximo [LADO_MAXIMO_PX] px) e leva milissegundos.
 * Não roda em teste de JVM: a regra é testada em [RegraDoRostoNaFoto] e [EstimativaDoRosto], e o conferidor, no aparelho.
 */
class ConferidorDeRostoDoAndroid(private val prazoMs: Long = RegraDoRostoNaFoto.PRAZO_MS) : ConferidorDeRostoDaFoto {

    override suspend fun conferir(jpeg: ByteArray): ResultadoDaVerificacaoLocal =
        RegraDoRostoNaFoto.comFalhaFechada(prazoMs) {
            withContext(Dispatchers.Default) {
                val bitmap = decodificarParaDeteccao(jpeg) ?: error("imagem ilegível")
                try {
                    val achados = arrayOfNulls<FaceDetector.Face>(MAXIMO_DE_ROSTOS)
                    val quantos = FaceDetector(bitmap.width, bitmap.height, MAXIMO_DE_ROSTOS).findFaces(bitmap, achados)
                    RegraDoRostoNaFoto.decidir(
                        rostos = achados.take(quantos).filterNotNull().map { EstimativaDoRosto.caixaPelosOlhos(it.eyesDistance()) },
                        larguraDaImagem = bitmap.width,
                        alturaDaImagem = bitmap.height,
                    )
                } finally {
                    bitmap.recycle()
                }
            }
        }

    /** O `FaceDetector` exige `RGB_565` e largura par; reduz foto grande (a regra é proporcional, o tamanho absoluto não importa). */
    private fun decodificarParaDeteccao(jpeg: ByteArray): Bitmap? {
        val medidas = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size, medidas)
        var reducao = 1
        while (maxOf(medidas.outWidth, medidas.outHeight) / reducao > LADO_MAXIMO_PX) reducao *= 2
        val opcoes = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.RGB_565
            inSampleSize = reducao
        }
        val lida = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size, opcoes) ?: return null
        if (lida.width % 2 == 0) return lida
        return Bitmap.createBitmap(lida, 0, 0, lida.width - 1, lida.height).also { lida.recycle() }
    }

    private companion object {
        /** Dois bastam: com mais de um rosto a regra já bloqueia. */
        const val MAXIMO_DE_ROSTOS = 2
        const val LADO_MAXIMO_PX = 1280
    }
}
