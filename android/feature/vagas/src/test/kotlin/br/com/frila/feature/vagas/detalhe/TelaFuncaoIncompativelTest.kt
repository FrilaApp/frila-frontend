package br.com.frila.feature.vagas.detalhe

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaFuncaoIncompativelTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `mostra o titulo e a mensagem do iOS, com ajustar as funcoes no primario e a lista no secundario`() {
        var ajustou = 0
        var voltou = 0
        compose.setContent {
            FrilaTheme {
                TelaFuncaoIncompativel(aoAjustarFuncoes = { ajustou++ }, aoVoltarAoFeed = { voltou++ })
            }
        }

        compose.onNodeWithTag("resultado-funcao-incompativel").assertTextEquals("Função diferente")
        compose.onNodeWithText("Esta vaga exige uma função que não está cadastrada no seu perfil profissional.").assertIsDisplayed()
        compose.onNodeWithTag("ajustar-minhas-funcoes").assertIsDisplayed()
        compose.onNodeWithText("Ajustar minhas funções").assertIsDisplayed()
        compose.onNodeWithText("Ver outras vagas perto de você").assertIsDisplayed()

        compose.onNodeWithTag("ajustar-minhas-funcoes").performClick()
        assertEquals(1, ajustou)
        assertEquals(0, voltou)

        compose.onNodeWithTag("voltar-para-lista").performClick()
        assertEquals(1, ajustou)
        assertEquals(1, voltou)
    }
}
