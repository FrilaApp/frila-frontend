package br.com.frila.app.datas

import android.os.Build
import androidx.test.ext.junit.runners.AndroidJUnit4
import br.com.frila.core.dominio.regra.instanteDoServidor
import java.time.Instant
import java.time.format.DateTimeParseException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Prova em aparelho do leitor único de datas. O servidor devolve instantes com `+00:00` (Postgres).
 * Até o Android 11 (API 30) o `Instant.parse` do sistema só aceita `Z` e lança exceção; os testes de JVM
 * rodam no Java 17, onde ele já lê, e por isso não mostram o defeito. Rodar num emulador API 28 a 30:
 * `./gradlew :app:connectedDebugAndroidTest -Pandroid.testInstrumentationRunnerArguments.class=br.com.frila.app.datas.LeituraDeDatasDoServidorInstrumentedTest`
 */
@RunWith(AndroidJUnit4::class)
class LeituraDeDatasDoServidorInstrumentedTest {

    private val comoOServidorManda = "2026-11-25T12:31:00+00:00"
    private val esperado: Instant = Instant.parse("2026-11-25T12:31:00Z")

    @Test
    fun leitorUnicoLeDataComMaisZeroZeroNesteAparelho() {
        assertEquals(esperado, instanteDoServidor(comoOServidorManda))
        assertEquals(esperado, instanteDoServidor("2026-11-25T12:31:00Z"))
        assertEquals(
            Instant.parse("2026-11-25T12:31:00.123456Z"),
            instanteDoServidor("2026-11-25T12:31:00.123456+00:00"),
        )
    }

    /** O defeito que o leitor único conserta: só existe até a API 30, por isso o teste se pula nas mais novas. */
    @Test
    fun instantParseDoSistemaRecusaMaisZeroZeroAteOAndroid11() {
        assumeTrue("só vale até a API 30; este aparelho é API ${Build.VERSION.SDK_INT}", Build.VERSION.SDK_INT <= 30)

        assertThrows(DateTimeParseException::class.java) { Instant.parse(comoOServidorManda) }
    }
}
