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
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão jJ6AxB4c (item 248): a gravação da aparência que passa de 2 s (`withTimeout(2_000)`) vira o aviso de falha e devolve as opções
 * (o `TimeoutCancellationException` de `AparenciaDoAparelho`). Apagar o `falhou = true` desse ramo sobrevivia. O relógio é o virtual do
 * teste de Compose (`mainClock`): nenhum teste espera 2 s de verdade.
 *
 * JUnit: nenhum método devolve valor (um `@Test` que devolve valor é ignorado).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AparenciaDoAparelhoTempoEsgotadoTest {

    @get:Rule(order = 0) val registraActivity = RegistraActivityDeTeste()
    @get:Rule(order = 1) val rule = createComposeRule()

    private val claro = "Claro"
    private val escuro = "Escuro"
    private val aviso = "Não foi possível guardar a aparência. Tente novamente."

    /** DataStore em memória cuja gravação só termina quando [segurar] é liberado: o disco que "pendurou". */
    private class DataStorePendurado : DataStore<Preferences> {
        private val estado = MutableStateFlow(emptyPreferences())
        override val data: Flow<Preferences> = estado
        var segurar: CompletableDeferred<Unit>? = CompletableDeferred()
        var tentativas = 0

        override suspend fun updateData(transform: suspend (t: Preferences) -> Preferences): Preferences {
            tentativas++
            segurar?.await()
            return transform(estado.value).also { estado.value = it }
        }
    }

    private fun montar(dados: DataStorePendurado) {
        rule.mainClock.autoAdvance = false
        rule.setContent { FrilaTheme(temaEscuro = false) { AparenciaDoAparelho(PreferenciasAparencia(dados), aoVoltar = {}) } }
    }

    @Test
    fun `gravacao que passa de 2 segundos mostra o aviso e devolve as opcoes`() {
        val dados = DataStorePendurado()
        montar(dados)

        rule.onNodeWithText(escuro).performClick()
        rule.mainClock.advanceTimeBy(500)
        rule.onNodeWithText(escuro).assertIsNotEnabled()
        rule.onAllNodesWithText(aviso).assertCountEquals(0)

        // Aos 1,9 s ainda grava; aos 2,1 s o prazo de 2 s já esgotou.
        rule.mainClock.advanceTimeBy(1_400)
        rule.onNodeWithText(escuro).assertIsNotEnabled()
        rule.onAllNodesWithText(aviso).assertCountEquals(0)
        rule.mainClock.advanceTimeBy(200)

        rule.onNodeWithText(aviso).assertExists()
        rule.onNodeWithText(escuro).assertIsEnabled()
        rule.onNodeWithText(claro).assertIsEnabled()
        rule.onNodeWithText(claro).assertIsSelected()
        assertEquals(1, dados.tentativas)
    }

    @Test
    fun `gravacao que termina antes de 2 segundos nao mostra aviso`() {
        val dados = DataStorePendurado()
        montar(dados)

        rule.onNodeWithText(escuro).performClick()
        rule.mainClock.advanceTimeBy(1_900)
        dados.segurar!!.complete(Unit)
        rule.mainClock.advanceTimeBy(1_500)

        rule.onAllNodesWithText(aviso).assertCountEquals(0)
        rule.onNodeWithText(escuro).assertIsEnabled()
        rule.onNodeWithText(escuro).assertIsSelected()
    }

    @Test
    fun `depois do tempo esgotado uma nova tentativa que grava na hora apaga o aviso`() {
        val dados = DataStorePendurado()
        montar(dados)
        rule.onNodeWithText(escuro).performClick()
        rule.mainClock.advanceTimeBy(2_500)
        rule.onNodeWithText(aviso).assertExists()

        dados.segurar = null
        rule.onNodeWithText(escuro).performClick()
        rule.mainClock.advanceTimeBy(500)

        rule.onAllNodesWithText(aviso).assertCountEquals(0)
        rule.onNodeWithText(escuro).assertIsSelected()
        assertEquals(2, dados.tentativas)
    }
}
