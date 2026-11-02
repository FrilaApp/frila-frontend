package br.com.frila.app

import android.app.Application
import androidx.compose.material3.Text
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.componentes.TextosAtualizacaoObrigatoria
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class PortaoDeAtualizacaoTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun `quando versao for menor que versaoMinima portao exibe tela de atualizacao e oculta conteudo`() {
        rule.setContent {
            PortaoDeAtualizacao(
                versaoAtual = "1.0.0",
                versaoMinima = "1.2.0",
                conteudo = { Text("Conteudo Protegido do App") },
            )
        }

        rule.onNodeWithText(TextosAtualizacaoObrigatoria.TITULO).assertIsDisplayed()
        rule.onNodeWithText(TextosAtualizacaoObrigatoria.MENSAGEM_PADRAO).assertIsDisplayed()
        rule.onNodeWithText(TextosAtualizacaoObrigatoria.BOTAO_ATUALIZAR).assertIsDisplayed()
        rule.onNodeWithText("Conteudo Protegido do App").assertDoesNotExist()
    }

    @Test
    fun `quando versao for igual ou superior a versaoMinima portao renderiza conteudo`() {
        rule.setContent {
            PortaoDeAtualizacao(
                versaoAtual = "1.2.0",
                versaoMinima = "1.2.0",
                conteudo = { Text("Conteudo Protegido do App") },
            )
        }

        rule.onNodeWithText("Conteudo Protegido do App").assertIsDisplayed()
        rule.onNodeWithText(TextosAtualizacaoObrigatoria.TITULO).assertDoesNotExist()
    }

    @Test
    fun `quando versaoMinima for nula portao renderiza conteudo normalmente`() {
        rule.setContent {
            PortaoDeAtualizacao(
                versaoAtual = "1.1.0",
                versaoMinima = null,
                conteudo = { Text("Conteudo Liberado") },
            )
        }

        rule.onNodeWithText("Conteudo Liberado").assertIsDisplayed()
        rule.onNodeWithText(TextosAtualizacaoObrigatoria.TITULO).assertDoesNotExist()
    }

    @Test
    fun `quando usuario toca em atualizar botao aciona callback aoAtualizar`() {
        var atualizacaoDisparada = false

        rule.setContent {
            PortaoDeAtualizacao(
                versaoAtual = "0.9.0",
                versaoMinima = "1.0.0",
                aoAtualizar = { atualizacaoDisparada = true },
                conteudo = { Text("Conteudo") },
            )
        }

        rule.onNodeWithText(TextosAtualizacaoObrigatoria.BOTAO_ATUALIZAR).performClick()
        rule.waitForIdle()

        assertTrue(atualizacaoDisparada)
    }
}
