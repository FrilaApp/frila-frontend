package br.com.frila.core.designsystem.componentes

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão upuh2Fmn (item 284): o `BotaoPrimario` anuncia "Carregando" enquanto a ação roda, como o iOS (`BotaoPrimario(carregando:)`, `Componentes.swift:161-167`:
 * `.disabled(carregando)` e `.accessibilityValue("Carregando")`). Antes o leitor de tela ouvia só "desativado". Só o parâmetro: nenhuma tela o liga neste PR, e
 * sem ele nenhum botão muda.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class BotaoPrimarioCarregandoTest {

    @get:Rule
    val compose = createComposeRule()

    private var cliques = 0

    private fun montar(carregando: Boolean? = null, habilitado: Boolean? = null) {
        compose.setContent {
            FrilaTheme {
                when {
                    carregando == null && habilitado == null -> BotaoPrimario(texto = "Confirmar", aoClicar = { cliques++ })
                    carregando == null -> BotaoPrimario(texto = "Confirmar", aoClicar = { cliques++ }, habilitado = habilitado!!)
                    habilitado == null -> BotaoPrimario(texto = "Confirmar", aoClicar = { cliques++ }, carregando = carregando)
                    else -> BotaoPrimario(texto = "Confirmar", aoClicar = { cliques++ }, habilitado = habilitado, carregando = carregando)
                }
            }
        }
    }

    private fun estado() = compose.onNodeWithText("Confirmar").fetchSemanticsNode().config.getOrNull(SemanticsProperties.StateDescription)

    @Test
    fun `carregando, o leitor de tela diz Carregando`() {
        montar(carregando = true)

        assertEquals("Carregando", estado())
    }

    @Test
    fun `carregando, o botao fica desligado e nao clica`() {
        montar(carregando = true)

        compose.onNodeWithText("Confirmar").assertIsNotEnabled().performClick()

        assertEquals(0, cliques)
    }

    @Test
    fun `carregando, o rotulo do botao segue sendo o texto dele`() {
        montar(carregando = true)

        compose.onNodeWithText("Confirmar").assertExists()
    }

    @Test
    fun `carregando mesmo habilitado, desliga`() {
        montar(carregando = true, habilitado = true)

        compose.onNodeWithText("Confirmar").assertIsNotEnabled()
    }

    @Test
    fun `sem o parametro, o botao e o de sempre, ligado, clica e sem estado`() {
        montar()

        compose.onNodeWithText("Confirmar").assertIsEnabled().performClick()

        assertEquals(1, cliques)
        assertNull(estado())
    }

    @Test
    fun `carregando falso nao muda nada`() {
        montar(carregando = false)

        compose.onNodeWithText("Confirmar").assertIsEnabled().performClick()

        assertEquals(1, cliques)
        assertNull(estado())
    }

    @Test
    fun `desligado sem carregar continua so desligado, sem dizer Carregando`() {
        montar(habilitado = false)

        compose.onNodeWithText("Confirmar").assertIsNotEnabled()
        assertNull(estado())
    }

    @Test
    fun `o botao carregando e o desligado nao sao o mesmo para o leitor`() {
        montar(carregando = true)
        val carregando = estado()

        assertEquals("Carregando", carregando)
        compose.onNodeWithText("Confirmar").assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Disabled))
    }
}
