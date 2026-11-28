package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.emptyPreferences
import br.com.frila.core.designsystem.tema.FrilaTheme
import java.io.IOException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão tYBZt2yK (item 243): `AparenciaDoAparelho` mostra "salvando" enquanto grava, "falhou" quando a gravação lança `IOException`
 * e volta a habilitar as opções no fim (`finally`). O teste do tema só cobria o caminho feliz. Aqui, com um DataStore falso que lança
 * `IOException` no `edit`: sem `falhou = true` não há aviso; sem `salvando = false` no `finally` as opções ficam desabilitadas para
 * sempre; sem `falhou = false` o aviso da tentativa anterior não some. Fora: o tempo esgotado de 2 s e o visual da `TelaAparencia`.
 *
 * JUnit: nenhum método devolve valor (um `@Test` que devolve valor é ignorado).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AparenciaDoAparelhoFalhaTest {

    @get:Rule(order = 0) val registraActivity = RegistraActivityDeTeste()
    @get:Rule(order = 1) val rule = createComposeRule()

    private val claro = "Claro"
    private val escuro = "Escuro"
    private val aviso = "Não foi possível guardar a aparência. Tente novamente."

    /** DataStore em memória; `edit` passa por `updateData`, onde a falha, ou a espera, é injetada. */
    private class DataStoreFalso : DataStore<Preferences> {
        private val estado = MutableStateFlow(emptyPreferences())
        override val data: Flow<Preferences> = estado
        var falhar: Throwable? = null
        var segurar: CompletableDeferred<Unit>? = null
        var tentativas = 0

        override suspend fun updateData(transform: suspend (t: Preferences) -> Preferences): Preferences {
            tentativas++
            segurar?.await()
            falhar?.let { throw it }
            return transform(estado.value).also { estado.value = it }
        }
    }

    private fun montar(dados: DataStoreFalso) {
        rule.setContent {
            FrilaTheme(temaEscuro = false) { AparenciaDoAparelho(PreferenciasAparencia(dados), aoVoltar = {}) }
        }
    }

    @Test
    fun `gravacao que lanca IOException mostra o aviso e as opcoes voltam a ficar habilitadas`() {
        val dados = DataStoreFalso().apply { falhar = IOException("disco cheio") }
        montar(dados)

        rule.onNodeWithText(escuro).performClick()
        rule.waitUntil { dados.tentativas == 1 }
        rule.waitForIdle()

        rule.onNodeWithText(aviso).assertExists()
        rule.onNodeWithText(escuro).assertIsEnabled()
        rule.onNodeWithText(claro).assertIsEnabled()
        // A escolha que não gravou não vira a selecionada.
        rule.onNodeWithText(claro).assertIsSelected()
    }

    @Test
    fun `depois da falha uma nova tentativa que da certo apaga o aviso`() {
        val dados = DataStoreFalso().apply { falhar = IOException("disco cheio") }
        montar(dados)
        rule.onNodeWithText(escuro).performClick()
        rule.waitUntil { dados.tentativas == 1 }
        rule.waitForIdle()
        rule.onNodeWithText(aviso).assertExists()

        dados.falhar = null
        rule.onNodeWithText(escuro).performClick()
        rule.waitUntil { dados.tentativas == 2 }
        rule.waitForIdle()

        rule.onAllNodesWithText(aviso).assertCountEquals(0)
        rule.onNodeWithText(escuro).assertIsSelected()
        rule.onNodeWithText(escuro).assertIsEnabled()
    }

    @Test
    fun `enquanto grava as opcoes ficam desabilitadas e sem aviso, e voltam ao terminar`() {
        val segurar = CompletableDeferred<Unit>()
        val dados = DataStoreFalso().apply { this.segurar = segurar }
        montar(dados)

        rule.onNodeWithText(escuro).performClick()
        rule.waitUntil { dados.tentativas == 1 }
        rule.waitForIdle()
        rule.onNodeWithText(escuro).assertIsNotEnabled()
        rule.onNodeWithText(claro).assertIsNotEnabled()
        rule.onAllNodesWithText(aviso).assertCountEquals(0)

        segurar.complete(Unit)
        rule.waitForIdle()

        rule.onNodeWithText(escuro).assertIsEnabled()
        rule.onNodeWithText(escuro).assertIsSelected()
        rule.onAllNodesWithText(aviso).assertCountEquals(0)
    }
}
