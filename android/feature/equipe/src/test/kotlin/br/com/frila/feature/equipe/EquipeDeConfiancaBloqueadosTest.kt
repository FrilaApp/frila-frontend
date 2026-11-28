package br.com.frila.feature.equipe

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onAllNodesWithText
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * I1PonzKJ, fatia 2: quem a pessoa bloqueou nesta sessão some da equipe de confiança. O servidor tira o par bloqueado da equipe (B-022);
 * a lista já carregada, ainda na pilha, ficaria mostrando o bloqueado até recarregar. O iOS esconde o "Chamar de novo" e limpa o cache;
 * o Android não tem cache, então a linha inteira sai.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1200dp")
class EquipeDeConfiancaBloqueadosTest {

    @get:Rule
    val rule = createComposeRule()

    private val reputacao = ReputacaoDto(positivas = 7, total = 8, turnosConsiderados = 8, turnosRealizados = 8)
    private val ana = PerfilPublicoDto(id = "a1", tipo = "profissional", nome = "Ana Souza", reputacao = reputacao)
    private val beto = PerfilPublicoDto(id = "b1", tipo = "profissional", nome = "Beto Lima", reputacao = reputacao)

    private fun montar(vararg membros: PerfilPublicoDto, bloqueados: () -> Set<String> = { emptySet() }) {
        rule.setContent {
            FrilaTheme {
                ConteudoEquipeDeConfianca(
                    tela = EstadoTelaEquipe(estado = EstadoEquipe.Conteudo(membros.toList())),
                    aoTentarNovamente = {},
                    aoRemover = {},
                    aoVoltar = {},
                    estaBloqueado = { it.id in bloqueados() },
                )
            }
        }
    }

    @Test
    fun `sem ninguem bloqueado, a equipe mostra todos`() {
        montar(ana, beto)

        rule.onNodeWithText("Ana Souza").assertIsDisplayed()
        rule.onNodeWithText("Beto Lima").assertIsDisplayed()
    }

    @Test
    fun `um membro bloqueado na sessao nao aparece, e os outros continuam`() {
        montar(ana, beto, bloqueados = { setOf("a1") })

        assertEquals(0, rule.onAllNodesWithText("Ana Souza").fetchSemanticsNodes().size)
        rule.onNodeWithText("Beto Lima").assertIsDisplayed()
    }

    @Test
    fun `se todos estao bloqueados, a tela mostra o estado vazio e nao uma lista em branco`() {
        montar(ana, beto, bloqueados = { setOf("a1", "b1") })

        rule.onNodeWithText(TextosEquipe.VAZIO_TITULO).assertIsDisplayed()
    }

    @Test
    fun `bloquear com a tela aberta tira o membro sem recarregar`() {
        var bloqueados by mutableStateOf(emptySet<String>())
        montar(ana, beto, bloqueados = { bloqueados })
        rule.onNodeWithText("Ana Souza").assertIsDisplayed()

        rule.runOnIdle { bloqueados = setOf("a1") }

        rule.waitForIdle()
        assertEquals(0, rule.onAllNodesWithText("Ana Souza").fetchSemanticsNodes().size)
        rule.onNodeWithText("Beto Lima").assertIsDisplayed()
    }
}
