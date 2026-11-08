package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import br.com.frila.core.rede.StatusConectividade
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

private const val MENSAGEM_OFFLINE = "Sem conexão com a internet. Verifique sua rede."

/**
 * RNF01 (cartão 9Q0sJIzW): prova isolada do [BannerDeConectividade] real extraído de
 * `AppNavegacao` — sem precisar montar o grafo Koin/`NavHost` completo (mesma estratégia de
 * isolamento de `GuardaBiometricoNavegacaoTest`).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class BannerDeConectividadeTest {

    @get:Rule
    val rule = createComposeRule()

    @Test
    fun `banner aparece quando o status e SEM_CONEXAO`() {
        rule.setContent { BannerDeConectividade(status = StatusConectividade.SEM_CONEXAO) }

        rule.onNodeWithText(MENSAGEM_OFFLINE).assertExists()
    }

    @Test
    fun `banner nao aparece quando o status e CONECTADO`() {
        rule.setContent { BannerDeConectividade(status = StatusConectividade.CONECTADO) }

        rule.onNodeWithText(MENSAGEM_OFFLINE).assertDoesNotExist()
    }
}
