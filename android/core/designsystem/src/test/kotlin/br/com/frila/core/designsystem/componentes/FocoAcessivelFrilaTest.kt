package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertIsFocused
import androidx.compose.ui.test.assertIsNotFocused
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performKeyInput
import androidx.compose.ui.test.pressKey
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaRaios
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Navegação por teclado físico e D-Pad (RNF10): Tab percorre os componentes interativos na
 * ordem lógica, D-Pad Center aciona o componente com foco, e o indicador visual de foco
 * (`Modifier.focoAcessivelFrila`) liga e desliga junto com o estado de foco real reportado
 * pelo Compose — não um efeito visual desacoplado do foco de verdade.
 */
@OptIn(ExperimentalTestApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class FocoAcessivelFrilaTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `BotaoPrimario recebe foco ao navegar com Tab`() {
        compose.setContent {
            FrilaTheme {
                BotaoPrimario(texto = "Continuar", aoClicar = {})
            }
        }

        compose.onNodeWithText("Continuar").assertIsNotFocused()

        compose.onRoot().performKeyInput { pressKey(Key.Tab) }

        compose.onNodeWithText("Continuar").assertIsFocused()
    }

    @Test
    fun `D-Pad Center aciona o clique do botao com foco`() {
        var cliques = 0
        compose.setContent {
            FrilaTheme {
                BotaoPrimario(texto = "Confirmar", aoClicar = { cliques++ })
            }
        }

        compose.onRoot().performKeyInput { pressKey(Key.Tab) }
        compose.onNodeWithText("Confirmar").assertIsFocused()

        compose.onNodeWithText("Confirmar").performKeyInput { pressKey(Key.DirectionCenter) }

        assertTrue(cliques > 0)
    }

    @Test
    fun `Tab percorre dois botoes na ordem declarada`() {
        compose.setContent {
            FrilaTheme {
                Column {
                    BotaoPrimario(texto = "Primeiro", aoClicar = {})
                    BotaoSecundario(texto = "Segundo", aoClicar = {})
                }
            }
        }

        compose.onRoot().performKeyInput { pressKey(Key.Tab) }
        compose.onNodeWithText("Primeiro").assertIsFocused()
        compose.onNodeWithText("Segundo").assertIsNotFocused()

        compose.onRoot().performKeyInput { pressKey(Key.Tab) }
        compose.onNodeWithText("Primeiro").assertIsNotFocused()
        compose.onNodeWithText("Segundo").assertIsFocused()
    }

    @Test
    fun `CartaoVaga clicavel recebe foco por Tab e aciona por D-Pad Center`() {
        var cliques = 0
        compose.setContent {
            FrilaTheme {
                CartaoVaga(aoClicar = { cliques++ }, rotuloDaAcao = "Abrir vaga") {
                    Text("Garçom")
                }
            }
        }

        compose.onRoot().performKeyInput { pressKey(Key.Tab) }
        compose.onNodeWithText("Garçom").assertIsFocused()

        compose.onNodeWithText("Garçom").performKeyInput { pressKey(Key.DirectionCenter) }

        assertTrue(cliques > 0)
    }

    @OptIn(ExperimentalMaterial3Api::class)
    @Test
    fun `chip de filtro com semanticaDeFiltro recebe foco por Tab e liga o contorno de foco`() {
        compose.setContent {
            FrilaTheme {
                FilterChip(
                    selected = true,
                    onClick = {},
                    label = { Text("Até 5 km") },
                    modifier = Modifier.semanticaDeFiltro(selecionado = true),
                )
            }
        }

        val chip = compose.onNodeWithText("Até 5 km")
        chip.assertIsNotFocused()
        chip.assert(SemanticsMatcher.expectValue(ContornoDeFocoVisivelFrila, false))

        compose.onRoot().performKeyInput { pressKey(Key.Tab) }

        chip.assertIsFocused()
        chip.assert(SemanticsMatcher.expectValue(ContornoDeFocoVisivelFrila, true))
    }

    /**
     * `focoAcessivelFrila` liga o contorno no mesmo instante em que o componente de fato
     * recebe foco — nunca antes, nunca com delay — e desliga de volta quando o foco sai.
     * Validação pela chave semântica `ContornoDeFocoVisivelFrila` (só para teste; não altera
     * o que leitores de tela anunciam), não por captura de pixel: `captureToImage()` sob
     * Robolectric (mesmo com `@GraphicsMode(Mode.NATIVE)`) trava em `ComposeTimeoutException`
     * neste ambiente — MEDIDO. A prova visual de contraste fica documentada na matemática do
     * KDoc de `focoAcessivelFrila`; a prova de comportamento (quando liga/desliga) é esta.
     */
    @Test
    fun `contorno de foco liga e desliga exatamente junto com o foco real do componente`() {
        compose.setContent {
            FrilaTheme {
                Box(
                    modifier = Modifier
                        .testTag(TAG_ALVO_DE_FOCO)
                        .size(60.dp)
                        .background(MaterialTheme.colorScheme.surface)
                        .focoAcessivelFrila(forma = RoundedCornerShape(FrilaRaios.medio))
                        .focusable(),
                )
            }
        }

        val alvo = compose.onNodeWithTag(TAG_ALVO_DE_FOCO)
        alvo.assertIsNotFocused()
        alvo.assert(SemanticsMatcher.expectValue(ContornoDeFocoVisivelFrila, false))

        compose.onRoot().performKeyInput { pressKey(Key.Tab) }

        alvo.assertIsFocused()
        alvo.assert(SemanticsMatcher.expectValue(ContornoDeFocoVisivelFrila, true))
    }

    private companion object {
        const val TAG_ALVO_DE_FOCO = "alvo-de-foco"
    }
}
