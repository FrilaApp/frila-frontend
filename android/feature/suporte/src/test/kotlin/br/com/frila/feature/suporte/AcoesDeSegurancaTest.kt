package br.com.frila.feature.suporte

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.BloqueioDto
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** GpINsbhj: as ações de segurança reutilizáveis (chamada recebida do profissional; perfil público visto pela casa, item 187). */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class AcoesDeSegurancaTest {

    @get:Rule
    val rule = createComposeRule()

    private class Eventos {
        var denunciar = 0
        var abrirBloqueio = 0
        var confirmarBloqueio = 0
        var cancelarBloqueio = 0
    }

    private fun montar(estado: EstadoBloqueioDeAlvo = EstadoBloqueioDeAlvo(), rotulo: String = TextosSuporte.BLOQUEADO): Eventos {
        val eventos = Eventos()
        rule.setContent {
            FrilaTheme {
                AcoesDeSeguranca(
                    nome = "Bar do Zé",
                    estado = estado,
                    aoDenunciar = { eventos.denunciar++ },
                    aoAbrirBloqueio = { eventos.abrirBloqueio++ },
                    aoConfirmarBloqueio = { eventos.confirmarBloqueio++ },
                    aoCancelarBloqueio = { eventos.cancelarBloqueio++ },
                    rotuloBloqueado = rotulo,
                )
            }
        }
        return eventos
    }

    @Test
    fun `mostra Denunciar e Bloquear, e o nome vai na descricao de acessibilidade`() {
        montar()

        rule.onNodeWithText("Denunciar").assertIsDisplayed()
        rule.onNodeWithText("Bloquear").assertIsDisplayed()
        rule.onNodeWithContentDescription("Denunciar Bar do Zé").assertExists()
        rule.onNodeWithContentDescription("Bloquear Bar do Zé").assertExists()
    }

    @Test
    fun `tocar em Denunciar e em Bloquear dispara cada evento uma vez`() {
        val eventos = montar()

        rule.onNodeWithTag("seguranca-denunciar").performClick()
        rule.onNodeWithTag("seguranca-bloquear").performClick()

        assertEquals(1, eventos.denunciar)
        assertEquals(1, eventos.abrirBloqueio)
        assertEquals(0, eventos.confirmarBloqueio)
    }

    @Test
    fun `com o dialogo aberto, mostra o titulo e o efeito do bloqueio e confirma ou cancela`() {
        val eventos = montar(EstadoBloqueioDeAlvo(dialogoAberto = true))

        rule.onNodeWithText(TextosSuporte.BLOQUEIO_TITULO).assertIsDisplayed()
        rule.onNodeWithText(TextosSuporte.BLOQUEIO_EFEITO).assertIsDisplayed()
        rule.onNodeWithText(TextosSuporte.CANCELAR).performClick()
        rule.onNodeWithText(TextosSuporte.BLOQUEIO_CONFIRMAR).performClick()

        assertEquals(1, eventos.cancelarBloqueio)
        assertEquals(1, eventos.confirmarBloqueio)
    }

    @Test
    fun `sem o dialogo aberto, nenhum dialogo aparece`() {
        montar()

        rule.onAllNodesWithTag("seguranca-bloqueado").assertCountEquals(0)
        rule.onAllNodesWithText(TextosSuporte.BLOQUEIO_TITULO).assertCountEquals(0)
    }

    @Test
    fun `depois de bloquear mostra o rotulo e tira o Bloquear, e o Denunciar continua`() {
        montar(EstadoBloqueioDeAlvo(bloqueado = true), rotulo = TextosSuporte.BLOQUEOU_ESTABELECIMENTO)

        rule.onNodeWithText("Você bloqueou este estabelecimento").assertIsDisplayed()
        rule.onAllNodesWithTag("seguranca-bloquear").assertCountEquals(0)
        rule.onNodeWithTag("seguranca-denunciar").assertIsEnabled()
    }

    @Test
    fun `bloqueando, o botao diz Bloqueando e fica desabilitado`() {
        montar(EstadoBloqueioDeAlvo(bloqueando = true))

        rule.onNodeWithText(TextosSuporte.BLOQUEANDO).assertIsDisplayed()
        rule.onNodeWithTag("seguranca-bloquear").assertIsNotEnabled()
    }

    @Test
    fun `um erro de bloqueio aparece junto das acoes`() {
        montar(EstadoBloqueioDeAlvo(erro = TextosSuporte.ERRO_SEM_REDE))

        rule.onNodeWithText(TextosSuporte.ERRO_SEM_REDE).assertIsDisplayed()
    }

    @Test
    fun `com o view model real, bloquear e confirmar chama o servico com o alvo e troca o botao pelo rotulo`() {
        val pedidos = mutableListOf<Pair<String, String>>()
        val vm = BloqueioDeAlvoViewModel(
            alvoTipo = TipoDeAlvo.ESTABELECIMENTO,
            alvoId = "casa-9",
            bloquear = { t, id -> pedidos += t to id; BloqueioDto(t, id, "2026-11-10T12:00:00Z") },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        rule.setContent {
            FrilaTheme {
                AcoesDeSeguranca(
                    nome = "Bar do Zé", viewModel = vm, aoDenunciar = {}, rotuloBloqueado = TextosSuporte.BLOQUEOU_ESTABELECIMENTO,
                )
            }
        }

        rule.onNodeWithTag("seguranca-bloquear").performClick()
        rule.onNodeWithText(TextosSuporte.BLOQUEIO_CONFIRMAR).performClick()

        assertEquals(listOf("estabelecimento" to "casa-9"), pedidos)
        rule.onNodeWithText("Você bloqueou este estabelecimento").assertIsDisplayed()
    }
}
