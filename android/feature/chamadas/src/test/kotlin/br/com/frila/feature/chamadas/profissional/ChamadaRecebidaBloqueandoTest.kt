package br.com.frila.feature.chamadas.profissional

import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ChamadaDetalheDto
import br.com.frila.core.rede.ClienteSupabase
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** xsZd5wZO: durante o pedido de bloqueio, Aceitar e Recusar ficam desligados (antes Aceitar seguia habilitado e podia responder no meio). */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ChamadaRecebidaBloqueandoTest {

    @get:Rule
    val rule = createComposeRule()

    private fun detalhe(): ChamadaDetalheDto =
        ClienteSupabase.jsonFrila.decodeFromString(Fixtures.detalheChamadaJson(estado = "aberta", contaNova = false, recado = "Traga avental"))

    private fun montar(bloqueando: Boolean) {
        rule.setContent {
            FrilaTheme {
                ConteudoDaChamadaRecebida(
                    tela = EstadoChamadaRecebida(chamadaId = Fixtures.CHAMADA, carregando = false, detalhe = detalhe()),
                    aoTentarNovamente = {}, aoAceitar = {}, aoAbrirRecusa = {}, aoFecharRecusa = {}, aoEscolherMotivo = {},
                    aoConfirmarRecusa = {}, aoVoltar = {}, aoAbrirTurno = {},
                    bloqueando = bloqueando,
                )
            }
        }
    }

    @Test
    fun `sem pedido de bloqueio em curso, Aceitar e Recusar estao habilitados`() {
        montar(bloqueando = false)

        rule.onNodeWithTag("aceitar-chamada").assertIsEnabled()
        rule.onNodeWithTag("recusar-chamada").assertIsEnabled()
    }

    @Test
    fun `durante o pedido de bloqueio, Aceitar e Recusar ficam desligados`() {
        montar(bloqueando = true)

        rule.onNodeWithTag("aceitar-chamada").assertIsNotEnabled()
        rule.onNodeWithTag("recusar-chamada").assertIsNotEnabled()
    }
}
