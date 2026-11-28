package br.com.frila.feature.chamadas.profissional

import androidx.compose.material3.Text
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ChamadaDetalheDto
import br.com.frila.core.rede.ClienteSupabase
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** GpINsbhj: bloqueada a casa que chamou, a chamada não se responde mais; as ações de segurança continuam na tela. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ChamadaRecebidaBloqueadaTest {

    @get:Rule
    val rule = createComposeRule()

    private fun detalhe(): ChamadaDetalheDto =
        ClienteSupabase.jsonFrila.decodeFromString(Fixtures.detalheChamadaJson(estado = "aberta", contaNova = false, recado = "Traga avental"))

    private fun montar(bloqueado: Boolean, nomesDaSeguranca: MutableList<String> = mutableListOf()) {
        rule.setContent {
            FrilaTheme {
                ConteudoDaChamadaRecebida(
                    tela = EstadoChamadaRecebida(chamadaId = Fixtures.CHAMADA, carregando = false, detalhe = detalhe()),
                    aoTentarNovamente = {},
                    aoAceitar = {},
                    aoAbrirRecusa = {},
                    aoFecharRecusa = {},
                    aoEscolherMotivo = {},
                    aoConfirmarRecusa = {},
                    aoVoltar = {},
                    aoAbrirTurno = {},
                    acoesDeSeguranca = { perfil ->
                        nomesDaSeguranca += perfil.nome
                        Text(text = "seguranca-de-${perfil.nome}", modifier = androidx.compose.ui.Modifier.testTag("slot-seguranca"))
                    },
                    bloqueado = bloqueado,
                )
            }
        }
    }

    @Test
    fun `sem bloqueio, a chamada aberta oferece aceitar e recusar`() {
        montar(bloqueado = false)

        rule.onNodeWithTag("aceitar-chamada").assertIsDisplayed()
        rule.onNodeWithTag("recusar-chamada").assertIsDisplayed()
    }

    @Test
    fun `com a casa bloqueada, some o rodape de aceitar e recusar e as acoes de seguranca continuam`() {
        val nomes = mutableListOf<String>()
        montar(bloqueado = true, nomesDaSeguranca = nomes)

        rule.onAllNodesWithTag("aceitar-chamada").assertCountEquals(0)
        rule.onAllNodesWithTag("recusar-chamada").assertCountEquals(0)
        rule.onNodeWithTag("slot-seguranca").performScrollTo().assertIsDisplayed()
        assertEquals(listOf("Bistrô Aurora"), nomes.distinct())
    }
}
