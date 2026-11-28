package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.rede.ErroDaApi
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.CopyOnWriteArrayList
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * BqUv3cVD: a abertura que não consegue decidir a tela inicial mostra o motivo certo e "Tentar novamente", que avalia de novo, como o
 * iOS (`FrilaApp.swift`, abertura com erro). Sem isto, sem rede a pessoa ficava presa na tela de erro.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class RotaDeAberturaTest {

    // Sem ele, o build release não tem a ComponentActivity do createComposeRule no manifesto.
    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val rule = createComposeRule()

    /** O que cada avaliação devolve, na ordem: uma exceção (a abertura falha) ou o destino da conta. */
    private val respostas = ConcurrentLinkedQueue<() -> DestinoDaConta>()
    private val decididos = CopyOnWriteArrayList<DestinoDaConta>()
    private var avaliacoes = 0

    private val nadaGuardado = object : DestinoGuardado {
        override fun obter(): DestinoDaConta? = null
        override fun salvar(destino: DestinoDaConta) = Unit
        override fun limpar() = Unit
    }

    private val semRede: () -> DestinoDaConta = { throw ErroDaApi(CodigoErroAPI.SEM_REDE, "sem_rede", null, "sintetico") }
    private val respostaIlegivel: () -> DestinoDaConta = { throw IllegalStateException("resposta ilegivel") }

    private fun montar() {
        val avaliador = AvaliadorDeDestino(
            descobrir = {
                avaliacoes++
                respostas.remove()()
            },
            guardado = nadaGuardado,
            sessaoGuardada = { true },
        )
        rule.setContent { RotaDeAbertura(avaliador = avaliador, aoDecidir = { destino, _ -> decididos += destino }) }
    }

    private fun contar(texto: String) = rule.onAllNodesWithText(texto).fetchSemanticsNodes().size

    private fun esperarTexto(texto: String) = rule.waitUntil(5_000) { contar(texto) > 0 }

    @Test
    fun `sem conexao mostra o aviso de sem conexao, e Tentar novamente avalia de novo e segue para a tela da conta`() {
        respostas += semRede
        respostas += { DestinoDaConta.Profissional }
        montar()

        esperarTexto(TextosAbertura.TITULO_SEM_CONEXAO)
        rule.onNodeWithText(TextosAbertura.SEM_CONEXAO).assertIsDisplayed()
        assertEquals(0, contar(TextosAbertura.TITULO_FALHA))
        assertEquals(0, contar(TextosAbertura.FALHA))
        assertEquals(emptyList<DestinoDaConta>(), decididos.toList())

        rule.onNodeWithText("Tentar novamente").performClick()

        rule.waitUntil(5_000) { decididos.isNotEmpty() }
        assertEquals(listOf<DestinoDaConta>(DestinoDaConta.Profissional), decididos.toList())
        assertEquals(2, avaliacoes)
    }

    @Test
    fun `falha do servidor mostra o aviso de falha, e Tentar novamente avalia de novo e segue para a tela da conta`() {
        respostas += respostaIlegivel
        respostas += { DestinoDaConta.Profissional }
        montar()

        esperarTexto(TextosAbertura.TITULO_FALHA)
        rule.onNodeWithText(TextosAbertura.FALHA).assertIsDisplayed()
        assertEquals(0, contar(TextosAbertura.TITULO_SEM_CONEXAO))
        assertEquals(0, contar(TextosAbertura.SEM_CONEXAO))

        rule.onNodeWithText("Tentar novamente").performClick()

        rule.waitUntil(5_000) { decididos.isNotEmpty() }
        assertEquals(listOf<DestinoDaConta>(DestinoDaConta.Profissional), decididos.toList())
        assertEquals(2, avaliacoes)
    }

    @Test
    fun `sem conexao de novo depois de tentar novamente continua oferecendo a nova tentativa`() {
        respostas += semRede
        respostas += semRede
        respostas += { DestinoDaConta.Profissional }
        montar()

        esperarTexto(TextosAbertura.TITULO_SEM_CONEXAO)
        rule.onNodeWithText("Tentar novamente").performClick()
        rule.waitUntil(5_000) { avaliacoes == 2 }
        esperarTexto(TextosAbertura.TITULO_SEM_CONEXAO)
        rule.onNodeWithText("Tentar novamente").performClick()

        rule.waitUntil(5_000) { decididos.isNotEmpty() }
        assertEquals(3, avaliacoes)
    }
}
