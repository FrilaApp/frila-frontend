package br.com.frila.feature.vagas.feed

import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoVagas
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class FiltrosAvancadosVagasTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `botao do feed abre o bottom sheet e tem alvo minimo`() {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { respond("[]") },
        )
        val viewModel = FeedVagasViewModel(
            ServicoVagas(cliente),
            escopo = CoroutineScope(Dispatchers.Default),
        )
        compose.setContent {
            FrilaTheme {
                TelaFeedVagas(viewModel = viewModel, aoAbrirDetalhe = {})
            }
        }

        compose.onNodeWithContentDescription("Abrir filtros avançados")
            .assertHasClickAction()
            .assertHeightIsAtLeast(48.dp)
            .performClick()

        compose.onNodeWithText("Filtros avançados").assertIsDisplayed()
    }

    @Test
    fun `bottom sheet exibe titulo chips e acoes acessiveis`() {
        compose.setContent {
            FrilaTheme {
                FiltrosAvancadosVagas(
                    filtroRemuneracao = FiltroRemuneracao.CEM,
                    filtroPeriodo = FiltroPeriodo.MANHA,
                    aoSelecionarRemuneracao = {},
                    aoSelecionarPeriodo = {},
                    aoAplicar = {},
                    aoLimpar = {},
                    aoFechar = {},
                )
            }
        }

        compose.onNodeWithText("Filtros avançados")
            .assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        compose.onNodeWithText("R$ 100+")
            .assertHasClickAction()
            .assertHeightIsAtLeast(48.dp)
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.RadioButton))
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "selecionado"))
        compose.onNodeWithText("Manhã")
            .assertHasClickAction()
            .assertHeightIsAtLeast(48.dp)
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.RadioButton))
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "selecionado"))
        compose.onNodeWithText("Aplicar filtros")
            .assertHasClickAction()
            .assertHeightIsAtLeast(48.dp)
        compose.onNodeWithText("Limpar")
            .assertHasClickAction()
            .assertHeightIsAtLeast(48.dp)
    }

    @Test
    fun `chips nao selecionados anunciam estado ao TalkBack`() {
        compose.setContent {
            FrilaTheme {
                FiltrosAvancadosVagas(
                    filtroRemuneracao = FiltroRemuneracao.QUALQUER,
                    filtroPeriodo = FiltroPeriodo.QUALQUER,
                    aoSelecionarRemuneracao = {},
                    aoSelecionarPeriodo = {},
                    aoAplicar = {},
                    aoLimpar = {},
                    aoFechar = {},
                )
            }
        }

        compose.onNodeWithText("R$ 150+")
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "não selecionado"))
        compose.onNodeWithText("Noite")
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, "não selecionado"))
    }

    @Test
    fun `bottom sheet exibe secao e slider de remuneracao por hora`() {
        compose.setContent {
            FrilaTheme {
                FiltrosAvancadosVagas(
                    filtroRemuneracao = FiltroRemuneracao.QUALQUER,
                    filtroPeriodo = FiltroPeriodo.QUALQUER,
                    faixaRemuneracaoHora = FaixaRemuneracaoHora(minima = 25f, maxima = 100f, ativa = true),
                    aoSelecionarRemuneracao = {},
                    aoSelecionarPeriodo = {},
                    aoAlterarFaixaRemuneracaoHora = {},
                    aoAplicar = {},
                    aoLimpar = {},
                    aoFechar = {},
                )
            }
        }

        compose.onNodeWithText("Remuneração por hora (líquida)").assertIsDisplayed()
        compose.onNodeWithText("R$ 25/h a R$ 100/h").assertIsDisplayed()
        compose.onNodeWithContentDescription("Faixa de remuneração de R$ 25 por hora até R$ 100 por hora")
            .assertIsDisplayed()
    }
}
