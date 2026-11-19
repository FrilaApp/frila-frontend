package br.com.frila.app.falhas

import android.app.Application
import android.graphics.Bitmap
import android.graphics.Canvas
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.test.junit4.ComposeContentTestRule
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import br.com.frila.app.RegistraActivityDeTeste
import br.com.frila.core.designsystem.tema.FrilaTheme
import java.io.File
import org.junit.After
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.core.context.stopKoin
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Capturas de tela da tela provisória de consentimento do Crashlytics (sistema do Fabrício).
 * Gera as imagens exigidas no despacho: modo padrão e fonte grande (acessibilidade).
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", application = Application::class)
class CapturasConsentimentoCrashlyticsTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val compose = createComposeRule()

    @After
    fun tearDown() {
        stopKoin()
    }

    private fun capturarParaRetornos(nome: String): File? {
        compose.waitForIdle()
        val vista = (compose.onRoot().fetchSemanticsNode().root as ViewRootForTest).view
        val imagem = Bitmap.createBitmap(vista.width, vista.height, Bitmap.Config.ARGB_8888)
        vista.draw(Canvas(imagem))

        val pastaDestino = System.getenv("FRILA_CAPTURAS_DIR")?.takeIf { it.isNotBlank() }
            ?: "/Users/cauecarneiro/Documents/Projetos/Frila/orquestracao/retornos/ANDROID-CRASHLYTICS-provas"
        val pasta = File(pastaDestino)
        if (!pasta.exists()) {
            pasta.mkdirs()
        }
        val arquivo = File(pasta, "$nome.png")
        arquivo.outputStream().use { imagem.compress(Bitmap.CompressFormat.PNG, 100, it) }
        return arquivo
    }

    @Test
    fun `captura consentimento crashlytics - padrao`() {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                TelaConsentimentoCrashlytics(
                    aoPermitir = {},
                    aoRecusar = {},
                )
            }
        }
        capturarParaRetornos("consentimento-crashlytics-padrao")
    }

    @Test
    @Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", fontScale = 1.5f, application = Application::class)
    fun `captura consentimento crashlytics - fonte grande`() {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                TelaConsentimentoCrashlytics(
                    aoPermitir = {},
                    aoRecusar = {},
                )
            }
        }
        capturarParaRetornos("consentimento-crashlytics-fonte-grande")
    }
}
