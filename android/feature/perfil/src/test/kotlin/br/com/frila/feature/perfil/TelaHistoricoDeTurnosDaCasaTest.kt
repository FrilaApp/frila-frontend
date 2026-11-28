package br.com.frila.feature.perfil

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.onNodeWithTag
import br.com.frila.core.designsystem.tema.FrilaTheme
import java.time.LocalDate
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** rUFapFEL: a casa exporta só CSV (o PDF local é do profissional), então a tela não oferece o PDF; o padrão segue com os dois. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h2400dp")
class TelaHistoricoDeTurnosDaCasaTest {

    @get:Rule
    val rule = createComposeRule()

    private val hoje = LocalDate.of(2026, 10, 3)
    private val estado = EstadoTelaHistorico(
        formato = FormatoExportacao.CSV, inicioEscolhido = LocalDate.of(2026, 10, 1), fimEscolhido = hoje, hoje = hoje,
    )

    private fun montar(formatos: List<FormatoExportacao>? = null) {
        rule.setContent {
            FrilaTheme {
                if (formatos == null) {
                    ConteudoHistoricoDeTurnos(estado, {}, {}, {}, {}, {}, {})
                } else {
                    ConteudoHistoricoDeTurnos(estado, {}, {}, {}, {}, {}, {}, formatosDisponiveis = formatos)
                }
            }
        }
    }

    @Test
    fun `com so o CSV disponivel, a tela mostra o CSV e nao oferece o PDF`() {
        montar(listOf(FormatoExportacao.CSV))

        rule.onNodeWithTag("historico-formato-csv").assertIsDisplayed()
        rule.onAllNodesWithTag("historico-formato-pdf").assertCountEquals(0)
    }

    @Test
    fun `sem restringir, a tela segue oferecendo CSV e PDF`() {
        montar()

        rule.onNodeWithTag("historico-formato-csv").assertIsDisplayed()
        rule.onNodeWithTag("historico-formato-pdf").assertIsDisplayed()
    }
}
