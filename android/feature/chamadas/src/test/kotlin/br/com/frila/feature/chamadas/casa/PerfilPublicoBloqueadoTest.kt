package br.com.frila.feature.chamadas.casa

import androidx.compose.material3.Text
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Q2HssEym: o perfil público visto pela casa. Bloqueada a pessoa nesta tela, "Chamar" some; as ações de segurança ficam. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1600dp")
class PerfilPublicoBloqueadoTest {

    @get:Rule
    val rule = createComposeRule()

    private val perfil = PerfilPublicoDto(
        id = "p1", tipo = "profissional", nome = "Maria S.", funcoes = listOf("Garçom"),
        reputacao = ReputacaoDto(positivas = 7, total = 8, turnosConsiderados = 8, turnosRealizados = 8),
    )

    private fun montar(bloqueado: Boolean, nomesNoSlot: MutableList<String> = mutableListOf()) {
        rule.setContent {
            FrilaTheme {
                ConteudoPerfilPublico(
                    estado = EstadoPerfilPublico.Carregado(perfil),
                    aoTentarNovamente = {},
                    aoVoltar = {},
                    aoChamar = {},
                    acoesDeSeguranca = { p ->
                        nomesNoSlot += p.nome
                        Text(text = "seguranca", modifier = androidx.compose.ui.Modifier.testTag("slot-seguranca"))
                    },
                    bloqueado = bloqueado,
                )
            }
        }
    }

    @Test
    fun `sem bloqueio, o perfil de profissional oferece Chamar`() {
        montar(bloqueado = false)

        rule.onNodeWithText(TextosChamadaCasa.TITULO_DA_FOLHA).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `bloqueada a pessoa, some o Chamar e o perfil e as acoes de seguranca continuam`() {
        val nomes = mutableListOf<String>()
        montar(bloqueado = true, nomesNoSlot = nomes)

        rule.onNodeWithText(TextosChamadaCasa.TITULO_DA_FOLHA).assertDoesNotExist()
        rule.onNodeWithText("Maria S.").assertIsDisplayed()
        rule.onNodeWithTag("slot-seguranca").performScrollTo().assertIsDisplayed()
        assertEquals(listOf("Maria S."), nomes.distinct())
    }
}
