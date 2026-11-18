package br.com.frila.feature.conta

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * O formulário de contestar o despacho sempre deixa sair sem contestar: o "Voltar" fica à vista com o formulário
 * parado (inclusive depois de um erro) e só desliga enquanto o envio roda. Caso achado na revisão de risco alto do R1.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h914dp")
class ContestarDespachoVoltarTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun formularioParadoDeixaVoltarSemContestar() {
        var voltou = 0
        var enviou = 0
        rule.setContent {
            FrilaTheme {
                ConteudoContestarDespacho(
                    EstadoContestarDespacho(relato = "Rascunho que não quero enviar"),
                    aoMudarRelato = {},
                    aoEnviar = { enviou++ },
                    aoVoltar = { voltou++ },
                )
            }
        }

        rule.onNodeWithText(TextosContestarDespacho.VOLTAR).assertIsDisplayed().assertIsEnabled().performClick()

        assertEquals(1, voltou)
        assertEquals(0, enviou)
    }

    @Test
    fun depoisDeUmErroOVoltarContinuaLa() {
        var voltou = 0
        rule.setContent {
            FrilaTheme {
                ConteudoContestarDespacho(
                    EstadoContestarDespacho(relato = "Rascunho", mensagemErro = "Sem conexão. Tente de novo."),
                    aoMudarRelato = {},
                    aoEnviar = {},
                    aoVoltar = { voltou++ },
                )
            }
        }

        rule.onNodeWithText(TextosContestarDespacho.VOLTAR).assertIsDisplayed().assertIsEnabled().performClick()

        assertEquals(1, voltou)
    }

    @Test
    fun duranteOEnvioOVoltarContinuaPresenteEDesligado() {
        rule.setContent {
            FrilaTheme {
                ConteudoContestarDespacho(EstadoContestarDespacho(enviando = true), {}, {}, {})
            }
        }

        rule.onNodeWithText(TextosContestarDespacho.VOLTAR).assertIsDisplayed().assertIsNotEnabled()
    }
}
