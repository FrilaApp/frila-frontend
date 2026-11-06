package br.com.frila.feature.perfil

import android.content.Context
import android.net.Uri
import io.mockk.every
import io.mockk.mockk
import java.io.ByteArrayInputStream
import org.junit.jupiter.api.Assertions.assertArrayEquals
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

class LerImagemComLimiteTest {

    private val uri = mockk<Uri>(relaxed = true)

    private fun contextoCom(bytes: ByteArray?): Context = mockk {
        every { contentResolver.openInputStream(uri) } returns bytes?.let { ByteArrayInputStream(it) }
    }

    @Test
    fun `imagem pequena volta inteira`() {
        val bytes = ByteArray(1_000) { (it % 251).toByte() }

        assertArrayEquals(bytes, lerImagemComLimite(contextoCom(bytes), uri))
    }

    @Test
    fun `imagem com exatamente 5 MB e aceita`() {
        val bytes = ByteArray(VerificacaoIdentidadeViewModel.LIMITE_BYTES) { 7 }

        assertEquals(VerificacaoIdentidadeViewModel.LIMITE_BYTES, lerImagemComLimite(contextoCom(bytes), uri)?.size)
    }

    @Test
    fun `imagem com 1 byte acima de 5 MB e recusada`() {
        val bytes = ByteArray(VerificacaoIdentidadeViewModel.LIMITE_BYTES + 1) { 7 }

        assertNull(lerImagemComLimite(contextoCom(bytes), uri))
    }

    @Test
    fun `uri que nao abre devolve nulo`() {
        assertNull(lerImagemComLimite(contextoCom(null), uri))
    }
}
