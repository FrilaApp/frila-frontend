package br.com.frila.feature.perfil

import android.content.Context
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import java.io.ByteArrayOutputStream
import kotlin.math.roundToInt
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** As regras do JPEG que sobe (contrato 0.2.54): sem EXIF, lado maior até 1600 px e até 5 MB. A parte pura; a do Android vem no [PreparadorDeJpegDoAparelho]. */
object PreparadorDeJpegDaFoto {
    const val LADO_MAXIMO_PX = 1600
    const val TAMANHO_MAXIMO_BYTES = 5 * 1024 * 1024
    val QUALIDADES = listOf(90, 80, 70, 60, 50, 40)

    data class Medidas(val largura: Int, val altura: Int)

    /** Reduz mantendo a proporção até o lado maior caber em [ladoMaximo]; nunca amplia e nunca devolve zero. */
    fun medidasFinais(largura: Int, altura: Int, ladoMaximo: Int = LADO_MAXIMO_PX): Medidas {
        val maior = maxOf(largura, altura)
        if (maior <= ladoMaximo) return Medidas(largura, altura)
        val escala = ladoMaximo.toDouble() / maior
        return Medidas((largura * escala).roundToInt().coerceAtLeast(1), (altura * escala).roundToInt().coerceAtLeast(1))
    }

    /** A primeira qualidade (da maior para a menor) em que [comprimir] cabe em [limite] bytes, ou `null` se nenhuma couber. */
    fun comprimirAteCaber(limite: Int = TAMANHO_MAXIMO_BYTES, comprimir: (qualidade: Int) -> ByteArray): ByteArray? {
        for (qualidade in QUALIDADES) {
            val bytes = comprimir(qualidade)
            if (bytes.size <= limite) return bytes
        }
        return null
    }
}

/**
 * Lê a foto escolhida (uma referência do seletor de fotos do sistema) e devolve o JPEG que sobe: o `ImageDecoder` já aplica a orientação do EXIF,
 * e o `Bitmap.compress` não grava EXIF, então o resultado sai upright e sem metadados (localização, aparelho, data). Lado maior até 1600 px e até 5 MB.
 * Lança se a foto não abrir ou não couber nos 5 MB (o ViewModel mostra "não conseguimos abrir essa foto"). Não roda em teste de JVM: provado no aparelho.
 */
class PreparadorDeJpegDoAparelho(private val contexto: Context) {
    suspend fun preparar(referencia: String): ByteArray = withContext(Dispatchers.IO) {
        val origem = ImageDecoder.createSource(contexto.contentResolver, Uri.parse(referencia))
        val lida = ImageDecoder.decodeBitmap(origem) { decoder, info, _ ->
            val medidas = PreparadorDeJpegDaFoto.medidasFinais(info.size.width, info.size.height)
            decoder.setTargetSize(medidas.largura, medidas.altura)
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
        }
        // Rede de segurança: se o tamanho-alvo foi dado antes de girar, a foto de lado ainda pode passar de 1600 px depois de girada.
        val medidas = PreparadorDeJpegDaFoto.medidasFinais(lida.width, lida.height)
        val bitmap = if (medidas.largura != lida.width || medidas.altura != lida.height) {
            Bitmap.createScaledBitmap(lida, medidas.largura, medidas.altura, true).also { if (it !== lida) lida.recycle() }
        } else {
            lida
        }
        try {
            PreparadorDeJpegDaFoto.comprimirAteCaber { qualidade ->
                ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.JPEG, qualidade, it) }.toByteArray()
            } ?: error("foto grande demais")
        } finally {
            bitmap.recycle()
        }
    }
}
