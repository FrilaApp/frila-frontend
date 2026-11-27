package br.com.frila.feature.perfil

import androidx.test.core.app.ApplicationProvider
import java.io.File
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * `CompressorDeFotoPerfil.descartar`: tira a foto da conta que saiu do aparelho mesmo quando `File.delete()` falha (cartão
 * TGQEI6xN). A falha de `delete()` é provocada tirando a permissão de escrita da pasta; a do esvaziamento, a do arquivo.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class DescartarAvatarTest {

    @get:Rule
    val pasta = TemporaryFolder()

    private val bloqueados = mutableListOf<File>()

    @After
    fun restaurar() {
        bloqueados.forEach { it.setWritable(true) }
        ApplicationProvider.getApplicationContext<android.content.Context>().filesDir.listFiles()?.forEach { it.deleteRecursively() }
    }

    private fun bloquear(alvo: File) {
        alvo.setWritable(false)
        bloqueados += alvo
        assertFalse("o ambiente de teste não impede a escrita (executando como administrador?)", alvo.canWrite())
    }

    @Test
    fun `apaga o arquivo quando da`() {
        val arquivo = File(pasta.root, "avatar_perfil_1.jpg").also { it.writeText("foto") }

        assertTrue(CompressorDeFotoPerfil.descartar(arquivo))

        assertFalse(arquivo.exists())
    }

    @Test
    fun `arquivo que ja nao existe conta como descartado`() {
        assertTrue(CompressorDeFotoPerfil.descartar(File(pasta.root, "avatar_perfil_2.jpg")))
    }

    @Test
    fun `sem poder apagar esvazia o arquivo`() {
        val arquivo = File(pasta.root, "avatar_perfil_3.jpg").also { it.writeText("foto") }
        bloquear(pasta.root)

        assertTrue(CompressorDeFotoPerfil.descartar(arquivo))

        assertTrue(arquivo.exists())
        assertEquals(0L, arquivo.length())
    }

    @Test
    fun `sem poder apagar nem esvaziar devolve false e o arquivo segue como estava`() {
        val arquivo = File(pasta.root, "avatar_perfil_4.jpg").also { it.writeText("foto") }
        bloquear(arquivo)
        bloquear(pasta.root)

        assertFalse(CompressorDeFotoPerfil.descartar(arquivo))

        assertEquals("foto", arquivo.readText())
    }

    @Test
    fun `avatarExistente ignora o arquivo esvaziado`() {
        val contexto = ApplicationProvider.getApplicationContext<android.content.Context>()
        File(contexto.filesDir, "${CompressorDeFotoPerfil.PREFIXO_ARQUIVO_AVATAR}5.jpg").writeBytes(ByteArray(0))

        assertNull(CompressorDeFotoPerfil.avatarExistente(contexto))
    }
}
