package br.com.frila.feature.perfil

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import java.io.File
import java.io.FileOutputStream

/**
 * Compressão defensiva do avatar de perfil (RF03/RNF04). Mesmo algoritmo de subamostragem já
 * medido em `br.com.frila.feature.turnos.CompressorDeFoto`, copiado em vez de reutilizado por
 * cruzar módulo (`feature:perfil` não depende de `feature:turnos`) — teto reduzido para
 * [LADO_MAXIMO_PX] porque um avatar não precisa do tamanho de um anexo de ocorrência.
 *
 * Diferença do compressor de ocorrências: aqui o resultado é sempre recortado 1:1
 * ([calcularRecorteQuadrado]) antes da compressão, porque o avatar é exibido num círculo/quadrado.
 * O arquivo final grava no `filesDir` do app (armazenamento privado, persistente entre sessões) —
 * não há endpoint remoto de avatar no contrato atual (openapi.yaml / Dtos.kt: nenhum campo
 * `foto_url`/`avatar_url`), então o avatar é só local por ora.
 */
object CompressorDeFotoPerfil {
    const val LADO_MAXIMO_PX = 512
    const val QUALIDADE_JPEG = 80
    const val PREFIXO_ARQUIVO_AVATAR = "avatar_perfil_"
    const val NOME_ARQUIVO_TEMPORARIO = "avatar_perfil.tmp"

    data class RecorteQuadrado(val origemX: Int, val origemY: Int, val lado: Int)

    /**
     * Avatar persistido mais recente em `filesDir`, ou `null` sem nenhum salvo. MEDIDO (Shisui,
     * PR #590): sem isto, [PerfilViewModel.carregar] nunca repunha `fotoLocalPath` e o avatar
     * desaparecia ao reabrir o app/tela.
     */
    fun avatarExistente(contexto: Context): File? =
        contexto.filesDir
            .listFiles { arquivo -> arquivo.isFile && arquivo.name.startsWith(PREFIXO_ARQUIVO_AVATAR) }
            ?.maxByOrNull { it.lastModified() }

    /** Ver doc idêntica em `CompressorDeFoto.calcularInSampleSize`. */
    fun calcularInSampleSize(largura: Int, altura: Int, ladoMaximo: Int = LADO_MAXIMO_PX): Int {
        if (largura <= 0 || altura <= 0) return 1
        var inSampleSize = 1
        var maiorLado = maxOf(largura, altura)
        while (maiorLado / 2 >= ladoMaximo) {
            inSampleSize *= 2
            maiorLado /= 2
        }
        return inSampleSize
    }

    /**
     * Retângulo quadrado centralizado que corta o excesso do lado maior. Dimensões inválidas
     * (zero ou negativas) devolvem [RecorteQuadrado] vazio em vez de lançar erro — quem chama
     * decide o que fazer com um recorte de lado zero.
     */
    fun calcularRecorteQuadrado(largura: Int, altura: Int): RecorteQuadrado {
        if (largura <= 0 || altura <= 0) return RecorteQuadrado(0, 0, 0)
        val lado = minOf(largura, altura)
        val origemX = (largura - lado) / 2
        val origemY = (altura - lado) / 2
        return RecorteQuadrado(origemX, origemY, lado)
    }

    /**
     * Decodifica [uriOrigem] já subamostrada, recorta 1:1 centralizado, garante o teto exato de
     * [LADO_MAXIMO_PX] (MEDIDO, Shisui PR #590: a subamostragem por potência de 2 sozinha deixava
     * o lado final entre 512 e 1023px — `Bitmap.createScaledBitmap` fecha essa lacuna) e
     * recomprime em JPEG a [QUALIDADE_JPEG]%.
     *
     * Grava primeiro em [NOME_ARQUIVO_TEMPORARIO] e só promove ao nome final
     * (`${PREFIXO_ARQUIVO_AVATAR}<timestamp>.jpg`) depois que a gravação termina sem erro —
     * se a gravação falhar no meio, o avatar anterior continua intacto (gravação atômica, item
     * não-bloqueante do Shisui). O nome final leva timestamp para que `fotoLocalPath` mude a cada
     * troca de foto — MEDIDO (Shisui): com nome fixo, duas trocas seguidas geravam o mesmo
     * caminho e a UI nunca recompunha a imagem. Avatares antigos são apagados após a promoção.
     *
     * Lança [IllegalStateException] se a imagem não puder ser decodificada; quem chama decide
     * como tratar (rollback no ViewModel).
     */
    fun comprimir(contexto: Context, uriOrigem: Uri): File {
        val limites = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        contexto.contentResolver.openInputStream(uriOrigem)?.use { fluxo ->
            BitmapFactory.decodeStream(fluxo, null, limites)
        }

        val opcoesDeDecodificacao = BitmapFactory.Options().apply {
            inSampleSize = calcularInSampleSize(limites.outWidth, limites.outHeight)
        }
        val bitmapOriginal = contexto.contentResolver.openInputStream(uriOrigem)?.use { fluxo ->
            BitmapFactory.decodeStream(fluxo, null, opcoesDeDecodificacao)
        } ?: throw IllegalStateException("Não foi possível decodificar a imagem selecionada.")

        val recorte = calcularRecorteQuadrado(bitmapOriginal.width, bitmapOriginal.height)
        val bitmapRecortado = if (recorte.lado <= 0) {
            bitmapOriginal
        } else {
            Bitmap.createBitmap(bitmapOriginal, recorte.origemX, recorte.origemY, recorte.lado, recorte.lado)
        }

        val bitmapFinal = if (bitmapRecortado.width > LADO_MAXIMO_PX || bitmapRecortado.height > LADO_MAXIMO_PX) {
            Bitmap.createScaledBitmap(bitmapRecortado, LADO_MAXIMO_PX, LADO_MAXIMO_PX, true)
        } else {
            bitmapRecortado
        }

        val arquivoTemporario = File(contexto.filesDir, NOME_ARQUIVO_TEMPORARIO)
        try {
            FileOutputStream(arquivoTemporario).use { saida ->
                bitmapFinal.compress(Bitmap.CompressFormat.JPEG, QUALIDADE_JPEG, saida)
            }
        } finally {
            if (bitmapFinal !== bitmapRecortado) bitmapFinal.recycle()
            if (bitmapRecortado !== bitmapOriginal) bitmapRecortado.recycle()
            bitmapOriginal.recycle()
        }

        val arquivoFinal = File(contexto.filesDir, "$PREFIXO_ARQUIVO_AVATAR${System.currentTimeMillis()}.jpg")
        if (!arquivoTemporario.renameTo(arquivoFinal)) {
            throw IllegalStateException("Não foi possível salvar a foto de perfil comprimida.")
        }
        contexto.filesDir
            .listFiles { arquivo -> arquivo.isFile && arquivo.name.startsWith(PREFIXO_ARQUIVO_AVATAR) && arquivo != arquivoFinal }
            ?.forEach { it.delete() }

        return arquivoFinal
    }
}
