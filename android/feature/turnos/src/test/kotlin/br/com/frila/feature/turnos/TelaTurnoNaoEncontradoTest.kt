package br.com.frila.feature.turnos

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
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaTurnoNaoEncontradoTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun renderizaTextosNormativosECabecalhoComSemantica() {
        var voltou = false

        rule.setContent {
            FrilaTheme {
                TelaTurnoNaoEncontrado(
                    aoVoltar = { voltou = true },
                    aoVerMeusTurnos = {},
                )
            }
        }

        // Título da barra superior
        rule.onNodeWithText("Meu turno").assertIsDisplayed()

        // Cabeçalho de estado com trait de heading
        rule.onNodeWithText("Não encontramos este turno")
            .assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))

        // Mensagem explicativa
        rule.onNodeWithText("Ele não está entre os turnos desta conta.")
            .assertIsDisplayed()

        // Botão voltar com alvo mínimo >= 48dp
        val botaoVoltar = rule.onNodeWithContentDescription("Voltar")
        botaoVoltar
            .assertIsDisplayed()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .assertWidthIsAtLeast(FrilaMetricas.alvoMinimo)

        botaoVoltar.performClick()
        assertTrue("Callback aoVoltar deve ser disparado", voltou)
    }

    @Test
    fun botaoVerMeusTurnosPossuiAlvoMinimoEAcionaCallback() {
        var clicouVerTurnos = false

        rule.setContent {
            FrilaTheme {
                TelaTurnoNaoEncontrado(
                    aoVoltar = {},
                    aoVerMeusTurnos = { clicouVerTurnos = true },
                )
            }
        }

        val botao = rule.onNodeWithText("Ver meus turnos")
        botao.assertIsDisplayed()
        botao.assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)

        botao.performClick()
        assertTrue("Callback aoVerMeusTurnos deve ser disparado", clicouVerTurnos)
    }

    @Test
    fun permiteCustomizarRotuloDoBotaoDeAcao() {
        var clicou = false

        rule.setContent {
            FrilaTheme {
                TelaTurnoNaoEncontrado(
                    aoVoltar = {},
                    aoVerMeusTurnos = { clicou = true },
                    rotuloBotao = "Ir para agenda de turnos",
                )
            }
        }

        val botao = rule.onNodeWithText("Ir para agenda de turnos")
        botao.assertIsDisplayed()
        botao.performClick()
        assertTrue("Callback deve responder ao botão customizado", clicou)
    }
}
