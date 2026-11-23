package br.com.frila.app

import android.app.Application
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.junit4.createComposeRule
import br.com.frila.core.designsystem.tema.FrilaCores
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "night")
class TemaDoAparelhoTest {
    @get:Rule(order = 0) val registraActivity = RegistraActivityDeTeste()
    @get:Rule(order = 1) val rule = createComposeRule()

    @Test fun `raiz usa claro mesmo no sistema escuro e troca sem recriar conteudo`() {
        val escolha = MutableStateFlow(false)
        var fundo = Color.Unspecified
        var identidade: Any? = null
        rule.setContent {
            TemaDoAparelho(escolha) {
                fundo = MaterialTheme.colorScheme.background
                identidade = remember { Any() }
            }
        }
        rule.runOnIdle { assertEquals(FrilaCores.fundoClaro, fundo) }
        val original = identidade
        rule.runOnIdle { escolha.value = true }
        rule.waitUntil { fundo == FrilaCores.fundoEscuro }
        rule.runOnIdle { assertSame(original, identidade); escolha.value = false }
        rule.waitUntil { fundo == FrilaCores.fundoClaro }
        rule.runOnIdle { assertSame(original, identidade) }
    }
}
