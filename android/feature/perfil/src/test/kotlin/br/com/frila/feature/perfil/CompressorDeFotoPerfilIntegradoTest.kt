package br.com.frila.feature.perfil

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.test.core.app.ApplicationProvider
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Pipeline completo de [CompressorDeFotoPerfil.comprimir] com Bitmap real via Robolectric
 * (mesmo mecanismo já usado em `TelaPerfilTest` para gerar JPEGs de teste) — a lacuna que deixou
 * passar o bug medido pelo Shisui no PR #590: `calcularInSampleSize` isolado nunca prova o teto
 * final de [CompressorDeFotoPerfil.LADO_MAXIMO_PX], só o `comprimir()` completo prova.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class CompressorDeFotoPerfilIntegradoTest {

    private val contexto get() = ApplicationProvider.getApplicationContext<android.content.Context>()

    private fun criarUriDeImagem(largura: Int, altura: Int, cor: Int = android.graphics.Color.RED): Uri {
        val bitmap = Bitmap.createBitmap(largura, altura, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(cor)
        val arquivo = File.createTempFile("origem", ".jpg", contexto.cacheDir)
        arquivo.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 100, it) }
        bitmap.recycle()
        return Uri.fromFile(arquivo)
    }

    private fun decodificarDimensoes(arquivo: File): Pair<Int, Int> {
        val opcoes = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(arquivo.absolutePath, opcoes)
        return opcoes.outWidth to opcoes.outHeight
    }

    @Test
    fun `imagem grande e retalho quadrado nao passa de 512px MEDIDO`() {
        val uri = criarUriDeImagem(largura = 4000, altura = 3000)

        val resultado = CompressorDeFotoPerfil.comprimir(contexto, uri)

        val (largura, altura) = decodificarDimensoes(resultado)
        assertEquals(CompressorDeFotoPerfil.LADO_MAXIMO_PX, largura)
        assertEquals(CompressorDeFotoPerfil.LADO_MAXIMO_PX, altura)
    }

    @Test
    fun `imagem ja pequena nao e esticada para 512px`() {
        val uri = criarUriDeImagem(largura = 100, altura = 100)

        val resultado = CompressorDeFotoPerfil.comprimir(contexto, uri)

        val (largura, altura) = decodificarDimensoes(resultado)
        assertTrue("largura $largura não deveria passar de 100", largura <= 100)
        assertTrue("altura $altura não deveria passar de 100", altura <= 100)
    }

    @Test
    fun `duas compressoes seguidas geram arquivos com caminhos diferentes e apagam o anterior`() {
        val primeiroArquivo = CompressorDeFotoPerfil.comprimir(contexto, criarUriDeImagem(500, 500))
        val caminhoAntigo = primeiroArquivo.absolutePath

        val segundoArquivo = CompressorDeFotoPerfil.comprimir(contexto, criarUriDeImagem(600, 600))

        assertNotEquals(caminhoAntigo, segundoArquivo.absolutePath)
        assertFalse("avatar anterior deveria ter sido apagado", File(caminhoAntigo).exists())
        assertTrue(segundoArquivo.exists())
    }

    @Test
    fun `avatarExistente sem nenhum avatar salvo devolve null`() {
        assertNull(CompressorDeFotoPerfil.avatarExistente(contexto))
    }

    @Test
    fun `avatarExistente apos comprimir devolve o arquivo recem-criado`() {
        val arquivo = CompressorDeFotoPerfil.comprimir(contexto, criarUriDeImagem(300, 300))

        val encontrado = CompressorDeFotoPerfil.avatarExistente(contexto)

        assertEquals(arquivo.absolutePath, encontrado?.absolutePath)
    }
}
