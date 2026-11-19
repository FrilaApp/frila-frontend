package br.com.frila.app.falhas

import android.app.Application
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.app.RegistraActivityDeTeste
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.core.context.stopKoin
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Testes visuais e de interação da tela de consentimento do Crashlytics.
 * Garante que o texto exigido pelo Parecer P-059 está presente e os botões de peso igual funcionam.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi", application = Application::class)
class TelaConsentimentoCrashlyticsTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val compose = createComposeRule()

    @After
    fun tearDown() {
        stopKoin()
    }

    @Test
    fun `tela renderiza titulo, textos de protecao de dados e botoes de peso igual`() {
        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                TelaConsentimentoCrashlytics(
                    aoPermitir = {},
                    aoRecusar = {},
                )
            }
        }

        // Título obrigatório
        compose.onNodeWithText(TextosConsentimentoCrashlytics.TITULO).assertIsDisplayed()

        // Informação técnica e finalidade
        compose.onNodeWithText(TextosConsentimentoCrashlytics.PARAGRAFO_1).assertIsDisplayed()

        // Destaque explícito de que NÃO leva dados pessoais
        compose.onNodeWithText(
            TextosConsentimentoCrashlytics.ROTULO_NAO_LEVA + TextosConsentimentoCrashlytics.CORPO_NAO_LEVA,
        ).assertIsDisplayed()

        // Destaque explícito de transferência internacional (EUA/90 dias)
        compose.onNodeWithText(
            TextosConsentimentoCrashlytics.ROTULO_EXTERIOR + TextosConsentimentoCrashlytics.CORPO_EXTERIOR,
        ).assertIsDisplayed()

        // Aviso de que é opcional e revogável a qualquer momento
        compose.onNodeWithText(TextosConsentimentoCrashlytics.PARAGRAFO_OPCIONAL).assertIsDisplayed()

        // Dois botões de peso igual
        compose.onNodeWithTag("botao-permitir-envio").assertIsDisplayed()
        compose.onNodeWithTag("botao-recusar-envio").assertIsDisplayed()
    }

    @Test
    fun `clicar em Permitir envio aciona callback correspondente`() {
        var permitiu = false
        var recusou = false

        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                TelaConsentimentoCrashlytics(
                    aoPermitir = { permitiu = true },
                    aoRecusar = { recusou = true },
                )
            }
        }

        compose.onNodeWithTag("botao-permitir-envio").performClick()
        assertEquals(true, permitiu)
        assertEquals(false, recusou)
    }

    @Test
    fun `clicar em Agora nao aciona callback correspondente`() {
        var permitiu = false
        var recusou = false

        compose.setContent {
            FrilaTheme(temaEscuro = false) {
                TelaConsentimentoCrashlytics(
                    aoPermitir = { permitiu = true },
                    aoRecusar = { recusou = true },
                )
            }
        }

        compose.onNodeWithTag("botao-recusar-envio").performClick()
        assertEquals(false, permitiu)
        assertEquals(true, recusou)
    }
}
