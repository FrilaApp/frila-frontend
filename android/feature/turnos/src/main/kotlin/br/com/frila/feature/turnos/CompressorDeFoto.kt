package br.com.frila.feature.turnos

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import java.io.File
import java.io.FileOutputStream

/**
 * Compressão defensiva do anexo fotográfico de uma ocorrência (RF12, RNF04): o maior lado não
 * passa de [LADO_MAXIMO_PX] e o resultado é um JPEG de qualidade [QUALIDADE_JPEG] gravado no
 * `cacheDir` do app — nunca no armazenamento externo, nunca pedindo permissão de storage
 * (a seleção em si usa `ActivityResultContracts.PickVisualMedia`, fora deste arquivo).
 *
 * O cálculo do fator de subamostragem ([calcularInSampleSize]) é puro e testável em JVM; a
 * decodificação/gravação real do bitmap precisa de `Context`/`BitmapFactory` do Android.
 */
object CompressorDeFoto {
    const val LADO_MAXIMO_PX = 1280
    const val QUALIDADE_JPEG = 80

    /**
     * Potência de 2 que, aplicada como `inSampleSize`, deixa o maior lado da imagem decodificada
     * **no máximo** em [ladoMaximo]px — aparelhos de 2GB de RAM não decodificam a imagem
     * original inteira antes de reduzir (RNF04). `1` (sem subamostragem) quando a imagem já é
     * pequena. Dobra enquanto `maiorLado / inSampleSize` ainda ultrapassa o limite — não só
     * enquanto a metade ainda caberia em outra rodada, que deixava o resultado final entre
     * [ladoMaximo] e `2 * ladoMaximo - 1`, acima do teto (achado do portão de revisão).
     */
    fun calcularInSampleSize(largura: Int, altura: Int, ladoMaximo: Int = LADO_MAXIMO_PX): Int {
        if (largura <= 0 || altura <= 0) return 1
        var inSampleSize = 1
        val maiorLado = maxOf(largura, altura)
        while (maiorLado / inSampleSize > ladoMaximo) {
            inSampleSize *= 2
        }
        return inSampleSize
    }

    /**
     * Decodifica [uriOrigem] já subamostrada, recomprime em JPEG a [QUALIDADE_JPEG]% e grava em
     * um arquivo novo no `cacheDir`. Lança [IllegalStateException] se a imagem não puder ser
     * decodificada (origem inválida, arquivo corrompido) — quem chama decide como tratar.
     */
    fun comprimir(contexto: Context, uriOrigem: Uri): File {
        val limites = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        contexto.contentResolver.openInputStream(uriOrigem)?.use { fluxo ->
            BitmapFactory.decodeStream(fluxo, null, limites)
        }

        val opcoesDeDecodificacao = BitmapFactory.Options().apply {
            inSampleSize = calcularInSampleSize(limites.outWidth, limites.outHeight)
        }
        val bitmap = contexto.contentResolver.openInputStream(uriOrigem)?.use { fluxo ->
            BitmapFactory.decodeStream(fluxo, null, opcoesDeDecodificacao)
        } ?: throw IllegalStateException("Não foi possível decodificar a imagem anexada.")

        val arquivo = File(contexto.cacheDir, "ocorrencia_${System.currentTimeMillis()}.jpg")
        FileOutputStream(arquivo).use { saida ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, QUALIDADE_JPEG, saida)
        }
        bitmap.recycle()
        return arquivo
    }
}
