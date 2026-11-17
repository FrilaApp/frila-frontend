package br.com.frila.app.falhas

import java.io.File
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** L1-6: o Crashlytics do Android sai DESLIGADO, como o iOS 1.1 (C1, 08/11/2026: falta base legal para dados de falha irem ao Google nos EUA). */
class ColetaDeFalhasTest {

    @Test
    fun `so o booleano true liga a coleta`() {
        assertTrue(ColetaDeFalhas.ligada(true))
    }

    @Test
    fun `sem a chave, falso ou de outro tipo a coleta fica desligada`() {
        listOf<Any?>(null, false, "true", 1, "", Any()).forEach { valor ->
            assertFalse(ColetaDeFalhas.ligada(valor), "valor $valor")
        }
    }

    @Test
    fun `o manifesto do app manda a coleta do Crashlytics desligada`() {
        val manifesto = File("src/main/AndroidManifest.xml").readText()
        val linha = Regex("""<meta-data\s+android:name="${ColetaDeFalhas.CHAVE_NO_MANIFESTO}"\s+android:value="(\w+)"\s*/>""")
            .find(manifesto)
        assertEquals("false", linha?.groupValues?.get(1), "firebase_crashlytics_collection_enabled tem de estar no manifesto, com false")
    }

    @Test
    fun `o manifesto do app tambem desliga as sessoes do Firebase`() {
        val manifesto = File("src/main/AndroidManifest.xml").readText()
        val linha = Regex("""<meta-data\s+android:name="firebase_sessions_enabled"\s+android:value="(\w+)"\s*/>""").find(manifesto)
        assertEquals("false", linha?.groupValues?.get(1), "firebase_sessions_enabled tem de estar no manifesto, com false")
    }
}
