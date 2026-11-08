package br.com.frila.feature.perfil

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertWidthIsAtLeast
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaAjudaPerfilTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun tituloPossuiSemanticaDeCabecalhoEAlvoMinimoNoBotaoVoltar() {
        var voltou = false

        rule.setContent {
            FrilaTheme {
                TelaAjudaPerfil(
                    aoVoltar = { voltou = true },
                )
            }
        }

        rule.onNodeWithText("Ajuda")
            .assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))

        val botaoVoltar = rule.onNodeWithContentDescription("Voltar")
        botaoVoltar
            .assertIsDisplayed()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .assertWidthIsAtLeast(FrilaMetricas.alvoMinimo)

        botaoVoltar.performClick()
        assertTrue("Callback aoVoltar deve ser acionado", voltou)
    }

    @Test
    fun exibeCanaisDeSuporteETermosComAlvoMinimo() {
        rule.setContent {
            FrilaTheme {
                TelaAjudaPerfil(
                    aoVoltar = {},
                )
            }
        }

        rule.onNodeWithText("Fale com o suporte")
            .assertIsDisplayed()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)

        rule.onNodeWithContentDescription("E-mail de suporte: suporte@frilabr.com")
            .assertIsDisplayed()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)

        rule.onNodeWithText("Respondemos o mais breve possível, com triagem em até 5 dias úteis.")
            .assertIsDisplayed()

        rule.onNodeWithText("Termos de uso")
            .assertIsDisplayed()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)

        rule.onNodeWithText("Política de privacidade")
            .assertIsDisplayed()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)

        rule.onNodeWithText("Licenças de código aberto")
            .assertIsDisplayed()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
    }

    @Test
    fun acionaCallbacksDeNavegacaoAoClicarNosItens() {
        var emailDestino: String? = null
        var urlTermos: String? = null
        var urlPrivacidade: String? = null
        var abriuLicencas = false

        rule.setContent {
            FrilaTheme {
                TelaAjudaPerfil(
                    aoVoltar = {},
                    aoAbrirEmailSuporte = { emailDestino = it },
                    aoNavegarParaTermos = { urlTermos = it },
                    aoNavegarParaPrivacidade = { urlPrivacidade = it },
                    aoNavegarParaLicencas = { abriuLicencas = true },
                )
            }
        }

        rule.onNodeWithText("Fale com o suporte").performClick()
        assertEquals("suporte@frilabr.com", emailDestino)

        rule.onNodeWithText("Termos de uso").performClick()
        assertEquals("https://frila.netlify.app/termos", urlTermos)

        rule.onNodeWithText("Política de privacidade").performClick()
        assertEquals("https://frila.netlify.app/privacidade", urlPrivacidade)

        rule.onNodeWithText("Licenças de código aberto").performClick()
        assertTrue("Callback de licenças deve ser chamado", abriuLicencas)
    }

    @Test
    fun enderecosPersonalizadosSaoExibidosERepassadosAosCallbacks() {
        val enderecosCustomizados = EnderecosOficiais(
            termosDeUso = "https://exemplo.org/termos",
            politicaDePrivacidade = "https://exemplo.org/privacidade",
            emailSuporte = "ajuda-teste@exemplo.org",
        )
        var emailEnviado: String? = null
        var urlTermos: String? = null

        rule.setContent {
            FrilaTheme {
                TelaAjudaPerfil(
                    aoVoltar = {},
                    enderecos = enderecosCustomizados,
                    aoAbrirEmailSuporte = { emailEnviado = it },
                    aoNavegarParaTermos = { urlTermos = it },
                )
            }
        }

        rule.onNodeWithContentDescription("E-mail de suporte: ajuda-teste@exemplo.org")
            .assertIsDisplayed()

        rule.onNodeWithText("Fale com o suporte").performClick()
        assertEquals("ajuda-teste@exemplo.org", emailEnviado)

        rule.onNodeWithText("Termos de uso").performClick()
        assertEquals("https://exemplo.org/termos", urlTermos)
    }
}
