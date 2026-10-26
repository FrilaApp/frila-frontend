package br.com.frila.core.designsystem.componentes

import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertWidthIsAtLeast
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class FeedbackEmptyStateTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `EstadoVazio renderiza titulo mensagem e botao com alvo de toque minimo`() {
        var acaoClicada = false

        compose.setContent {
            FrilaTheme {
                EstadoVazio(
                    titulo = "Nenhuma vaga aberta",
                    mensagem = "Mude os filtros ou puxe para atualizar.",
                    textoAcao = "Limpar filtros",
                    aoClicarAcao = { acaoClicada = true },
                )
            }
        }

        compose.onNodeWithText("Nenhuma vaga aberta").assertExists()
        compose.onNodeWithText("Mude os filtros ou puxe para atualizar.").assertExists()

        val botao = compose.onNodeWithText("Limpar filtros")
        botao.assertExists()
            .assertHasClickAction()
            .assertWidthIsAtLeast(FrilaMetricas.alvoMinimo)
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Button))
            .performClick()

        assertTrue(acaoClicada)
    }

    @Test
    fun `EstadoErro expoe semantica de erro e botao de retentativa aciona callback`() {
        var retentativaAcionada = false

        compose.setContent {
            FrilaTheme {
                EstadoErro(
                    titulo = "Falha de conexão",
                    mensagem = "Não foi possível carregar as vagas.",
                    textoBotao = "Tentar novamente",
                    aoTentarNovamente = { retentativaAcionada = true },
                )
            }
        }

        compose.onNodeWithText("Falha de conexão").assertExists()
        compose.onNodeWithText("Não foi possível carregar as vagas.").assertExists()

        // Valida que semântica de erro está presente no container
        compose.onNode(SemanticsMatcher.expectValue(SemanticsProperties.Error, "Não foi possível carregar as vagas."))
            .assertExists()

        val botaoRetry = compose.onNodeWithText("Tentar novamente")
        botaoRetry.assertExists()
            .assertHasClickAction()
            .assertWidthIsAtLeast(FrilaMetricas.alvoMinimo)
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()

        assertTrue(retentativaAcionada)
    }

    @Test
    fun `AvisoFrila renderiza banner contextual e botao dispensar possui alvo minimo`() {
        var dispensado = false

        compose.setContent {
            FrilaTheme {
                AvisoFrila(
                    tom = TomAviso.ALERTA,
                    titulo = "Modo avião",
                    mensagem = "Mostrando os dados salvos neste aparelho.",
                    aoDispensar = { dispensado = true },
                )
            }
        }

        compose.onNodeWithText("Modo avião").assertExists()
        compose.onNodeWithText("Mostrando os dados salvos neste aparelho.").assertExists()

        val botaoFechar = compose.onNodeWithContentDescription("Fechar aviso")
        botaoFechar.assertExists()
            .assertHasClickAction()
            .assertWidthIsAtLeast(FrilaMetricas.alvoMinimo)
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()

        assertTrue(dispensado)
    }

    @Test
    fun `FrilaSkeleton e FrilaCartaoSkeleton expõem acessibilidade de carregamento`() {
        compose.setContent {
            FrilaTheme {
                FrilaCartaoSkeleton()
            }
        }

        // Cada item skeleton dentro do cartão expõe "Carregando conteúdo"
        compose.onAllNodes(SemanticsMatcher.expectValue(SemanticsProperties.ContentDescription, listOf("Carregando conteúdo")))
            .assertCountEquals(3)
    }
}
