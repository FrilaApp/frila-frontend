package br.com.frila.app.push

import java.io.File
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Test

/**
 * Decisão do O2 (17/11): o push do Android não manda métrica ao Google além do indispensável. A entrega não é exportada para o BigQuery, o token só nasce
 * quando o app o pede (depois da sessão) e não há Firebase Analytics. O que sobra (Firebase Installations e o registro do token) está no corpo do PR.
 */
class FcmSemMetricaTest {

    private val manifesto get() = File("src/main/AndroidManifest.xml").readText()

    private fun valorDoMetaData(nome: String): String? =
        Regex("""<meta-data\s+android:name="$nome"\s+android:value="(\w+)"\s*/>""").find(manifesto)?.groupValues?.get(1)

    @Test
    fun `a entrega do push nao e exportada para o BigQuery`() {
        assertEquals("false", valorDoMetaData("delivery_metrics_exported_to_big_query_enabled"))
    }

    @Test
    fun `o token do FCM so nasce quando o app pede, nao na primeira abertura`() {
        assertEquals("false", valorDoMetaData("firebase_messaging_auto_init_enabled"))
    }

    @Test
    fun `o app nao traz Firebase Analytics nem Google Analytics no catalogo de dependencias`() {
        val catalogo = File("../gradle/libs.versions.toml").readLines()
            .filterNot { it.trim().startsWith("#") }
            .joinToString("\n")
        assertFalse(Regex("""firebase-analytics|play-services-measurement|play-services-analytics|google-analytics""", RegexOption.IGNORE_CASE).containsMatchIn(catalogo))
    }
}
