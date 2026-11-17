package br.com.frila.feature.perfil

import android.graphics.BitmapFactory
import com.google.android.gms.tasks.Task
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext

/** Confere, no aparelho e antes do envio, que a foto do profissional tem um rosto só. A foto nunca sai do aparelho por causa disto. */
fun interface ConferidorDeRostoDaFoto {
    suspend fun conferir(jpeg: ByteArray): ResultadoDaVerificacaoLocal
}

/**
 * ML Kit na versão **embutida** (`com.google.mlkit:face-detection`, modelo dentro do app): a foto não vai ao Google nem baixa modelo.
 * Só a caixa do rosto: sem pontos, sem contorno, sem classificação (nada biométrico). Falha fechada e com prazo, por [RegraDoRostoNaFoto.comFalhaFechada].
 * Não roda em teste de JVM (precisa da biblioteca nativa): a regra é testada em [RegraDoRostoNaFoto] e o conferidor, no aparelho.
 */
class ConferidorDeRostoMlKit(private val prazoMs: Long = RegraDoRostoNaFoto.PRAZO_MS) : ConferidorDeRostoDaFoto {

    override suspend fun conferir(jpeg: ByteArray): ResultadoDaVerificacaoLocal =
        RegraDoRostoNaFoto.comFalhaFechada(prazoMs) {
            withContext(Dispatchers.Default) {
                val bitmap = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size) ?: error("imagem ilegível")
                val detector = FaceDetection.getClient(
                    FaceDetectorOptions.Builder()
                        .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
                        .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_NONE)
                        .setContourMode(FaceDetectorOptions.CONTOUR_MODE_NONE)
                        .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_NONE)
                        .build(),
                )
                try {
                    val rostos = detector.process(InputImage.fromBitmap(bitmap, 0)).aguardar()
                    RegraDoRostoNaFoto.decidir(
                        rostos = rostos.map { RostoDetectado(it.boundingBox.width(), it.boundingBox.height()) },
                        larguraDaImagem = bitmap.width,
                        alturaDaImagem = bitmap.height,
                    )
                } finally {
                    detector.close()
                    bitmap.recycle()
                }
            }
        }
}

private suspend fun <T> Task<T>.aguardar(): T = suspendCancellableCoroutine { continuacao ->
    addOnSuccessListener { continuacao.resume(it) }
    addOnFailureListener { continuacao.resumeWithException(it) }
    addOnCanceledListener { continuacao.cancel() }
}
