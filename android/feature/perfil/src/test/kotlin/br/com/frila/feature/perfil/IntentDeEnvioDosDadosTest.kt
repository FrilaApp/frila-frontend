package br.com.frila.feature.perfil

import android.content.Intent
import android.net.Uri
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class IntentDeEnvioDosDadosTest {
    @Test
    fun `envia JSON pela URI com permissao somente de leitura`() {
        val uri = Uri.parse("content://br.com.frila.teste.fileprovider/meus_dados/dados.json")

        val envio = intentDeEnvioDosDados(uri)

        assertEquals(Intent.ACTION_SEND, envio.action)
        assertEquals("application/json", envio.type)
        @Suppress("DEPRECATION")
        val arquivo = envio.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        assertEquals(uri, arquivo)
        assertEquals(uri, envio.clipData!!.getItemAt(0).uri)
        assertEquals(Intent.FLAG_GRANT_READ_URI_PERMISSION, envio.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION)
        assertEquals(0, envio.flags and Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
    }
}
