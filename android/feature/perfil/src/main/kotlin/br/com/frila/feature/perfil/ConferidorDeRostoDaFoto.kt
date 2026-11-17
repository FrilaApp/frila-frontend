package br.com.frila.feature.perfil

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
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
 * Limites conhecidos: acha só rosto de frente com os dois olhos visíveis (rosto de perfil, de óculos escuros ou muito inclinado não é achado)
 * e devolve só a distância entre os olhos, de onde sai a caixa de [EstimativaDoRosto]. Por isso "não achei rosto" **não bloqueia**: antes do aviso
 * ele tenta de novo com a foto reduzida e girada (90° e 270°), e a pessoa pode enviar mesmo assim; a moderação do servidor decide.
 * Espera a foto já na posição certa (o preparo do JPEG, no L1-3b, aplica a orientação antes). O prazo só corta nos pontos de espera: a
 * chamada do sistema em si não é interrompível, mas roda em foto reduzida (no máximo [LADO_MAXIMO_PX] px) e leva milissegundos.
 * Não roda em teste de JVM: a regra é testada em [RegraDoRostoNaFoto] e [EstimativaDoRosto], e o conferidor, no aparelho.
 */
class ConferidorDeRostoDoAndroid(private val prazoMs: Long = RegraDoRostoNaFoto.PRAZO_MS) : ConferidorDeRostoDaFoto {

    override suspend fun conferir(jpeg: ByteArray): ResultadoDaVerificacaoLocal =
        RegraDoRostoNaFoto.comFalhaFechada(prazoMs) {
            withContext(Dispatchers.Default) {
                RegraDoRostoNaFoto.comRetentativas(
                    primeira = { analisar(jpeg, LADO_MAXIMO_PX, graus = 0) },
                    retentativas = listOf(
                        { analisar(jpeg, LADO_REDUZIDO_PX, graus = 0) },
                        { analisar(jpeg, LADO_REDUZIDO_PX, graus = 90) },
                        { analisar(jpeg, LADO_REDUZIDO_PX, graus = 270) },
                    ),
                )
            }
        }

    /** Uma passada do detector na foto reduzida a [ladoMaximoPx] e girada [graus]. */
    private fun analisar(jpeg: ByteArray, ladoMaximoPx: Int, graus: Int): ResultadoDaVerificacaoLocal {
        val bitmap = prepararParaDeteccao(jpeg, ladoMaximoPx, graus) ?: error("imagem ilegível")
        try {
            val achados = arrayOfNulls<FaceDetector.Face>(MAXIMO_DE_ROSTOS)
            val quantos = FaceDetector(bitmap.width, bitmap.height, MAXIMO_DE_ROSTOS).findFaces(bitmap, achados)
            return RegraDoRostoNaFoto.decidir(
                rostos = achados.take(quantos).filterNotNull().map { EstimativaDoRosto.caixaPelosOlhos(it.eyesDistance()) },
                larguraDaImagem = bitmap.width,
                alturaDaImagem = bitmap.height,
            )
        } finally {
            bitmap.recycle()
        }
    }

    /** O `FaceDetector` exige `RGB_565` e largura par; reduz foto grande (a regra é proporcional, o tamanho absoluto não importa) e gira se pedido. */
    private fun prepararParaDeteccao(jpeg: ByteArray, ladoMaximoPx: Int, graus: Int): Bitmap? {
        val medidas = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size, medidas)
        var reducao = 1
        while (maxOf(medidas.outWidth, medidas.outHeight) / reducao > ladoMaximoPx) reducao *= 2
        val opcoes = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.RGB_565
            inSampleSize = reducao
        }
        var atual = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size, opcoes) ?: return null
        if (graus != 0) {
            val girada = Bitmap.createBitmap(atual, 0, 0, atual.width, atual.height, Matrix().apply { postRotate(graus.toFloat()) }, true)
            atual.recycle()
            atual = girada
        }
        if (atual.config != Bitmap.Config.RGB_565) {
            val convertida = atual.copy(Bitmap.Config.RGB_565, false) ?: return null
            atual.recycle()
            atual = convertida
        }
        if (atual.width % 2 != 0) {
            val par = Bitmap.createBitmap(atual, 0, 0, atual.width - 1, atual.height)
            atual.recycle()
            atual = par
        }
        return atual
    }

    private companion object {
        /** Dois bastam: com mais de um rosto a regra já bloqueia. */
        const val MAXIMO_DE_ROSTOS = 2
        const val LADO_MAXIMO_PX = 1280

        /** O detector do sistema costuma achar melhor em foto menor. */
        const val LADO_REDUZIDO_PX = 640
    }
}
