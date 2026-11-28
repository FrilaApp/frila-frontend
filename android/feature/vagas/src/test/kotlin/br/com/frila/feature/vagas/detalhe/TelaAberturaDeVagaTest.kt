package br.com.frila.feature.vagas.detalhe

import androidx.compose.material3.Text
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.componentes.AuditoriaSemanticaAcessibilidade
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.core.rede.VagaDto
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Abrir a vaga pelo id: os quatro momentos da tela provisória e o detalhe completo na tela de detalhe. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1600dp")
class TelaAberturaDeVagaTest {

    @get:Rule
    val rule = createComposeRule()

    private class Toques {
        var tentou = 0
        var voltou = 0
    }

    private fun contar(texto: String) = rule.onAllNodesWithText(texto).fetchSemanticsNodes().size

    private fun montar(estado: EstadoAberturaDeVaga, toques: Toques = Toques()): Toques {
        rule.setContent {
            FrilaTheme {
                ConteudoAberturaDeVaga(estado, aoTentarDeNovo = { toques.tentou++ }, aoVoltarParaFeed = { toques.voltou++ }) { vaga ->
                    Text("vaga aberta ${vaga.id}")
                }
            }
        }
        return toques
    }

    @Test
    fun `enquanto le, a tela diz que esta carregando a vaga`() {
        montar(EstadoAberturaDeVaga.Carregando)

        rule.onNodeWithContentDescription(TextosAberturaDeVaga.CARREGANDO).assertIsDisplayed()
    }

    @Test
    fun `falha passageira mostra o texto e o Tentar de novo com alvo de 48 dp`() {
        val toques = montar(EstadoAberturaDeVaga.Falha(TextosAberturaDeVaga.SEM_REDE, podeTentarDeNovo = true))

        rule.onNodeWithText(TextosAberturaDeVaga.ERRO_TITULO).assertIsDisplayed()
        rule.onNodeWithText(TextosAberturaDeVaga.SEM_REDE).assertIsDisplayed()
        rule.onNodeWithText(TextosAberturaDeVaga.TENTAR_DE_NOVO).assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()

        assertEquals(1, toques.tentou)
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(rule.onRoot().fetchSemanticsNode())
    }

    @Test
    fun `falha que repetir nao resolve nao oferece Tentar de novo`() {
        montar(EstadoAberturaDeVaga.Falha(TextosAberturaDeVaga.SESSAO_EXPIRADA, podeTentarDeNovo = false))

        rule.onNodeWithText(TextosAberturaDeVaga.SESSAO_EXPIRADA).assertIsDisplayed()
        assertEquals(0, contar(TextosAberturaDeVaga.TENTAR_DE_NOVO))
    }

    @Test
    fun `vaga indisponivel explica o motivo e leva de volta para a lista`() {
        val toques = montar(EstadoAberturaDeVaga.Indisponivel(MotivoIndisponibilidadeVaga.PREENCHIDA, ModoPreenchimentoVaga.SELECAO))

        rule.onNodeWithText(TextosVagaIndisponivel.PREENCHIDA_TITULO).assertIsDisplayed()
        rule.onNodeWithText(TextosVagaIndisponivel.PREENCHIDA_MENSAGEM_SELECAO).assertIsDisplayed()
        rule.onNodeWithText(TextosVagaIndisponivel.BOTAO_VOLTAR_PADRAO).performClick()

        assertEquals(1, toques.voltou)
    }

    // ---- xdvUylw7 (item 271) ----

    @Test
    fun `candidatura recusada diz que o estabelecimento escolheu outra pessoa, nao vaga preenchida`() {
        montar(
            EstadoAberturaDeVaga.Indisponivel(
                MotivoIndisponibilidadeVaga.PREENCHIDA, ModoPreenchimentoVaga.SELECAO,
                candidatura = br.com.frila.core.dominio.modelo.EstadoCandidatura.RECUSADA,
            ),
        )

        rule.onNodeWithText(TextosVagaIndisponivel.RECUSADA_TITULO).assertExists()
        rule.onAllNodesWithText(TextosVagaIndisponivel.PREENCHIDA_TITULO).assertCountEquals(0)
    }

    @Test
    fun `candidatura expirada diz que a selecao foi encerrada`() {
        montar(
            EstadoAberturaDeVaga.Indisponivel(MotivoIndisponibilidadeVaga.ENCERRADA, ModoPreenchimentoVaga.SELECAO, candidaturaExpirada = true),
        )
        rule.onNodeWithText(TextosVagaIndisponivel.EXPIRADA_TITULO).assertExists()
    }

    @Test
    fun `candidatura expirada com a vaga cancelada diz que a casa cancelou`() {
        montar(
            EstadoAberturaDeVaga.Indisponivel(
                MotivoIndisponibilidadeVaga.ENCERRADA, ModoPreenchimentoVaga.SELECAO, vagaCancelada = true, candidaturaExpirada = true,
            ),
        )
        rule.onNodeWithText(TextosVagaIndisponivel.CANCELADA_TITULO).assertExists()
    }

    @Test
    fun `vaga que aceita candidatura e entregue a quem desenha o detalhe`() {
        montar(EstadoAberturaDeVaga.Aberta(vagaDoServidor()))

        rule.onNodeWithText("vaga aberta v1").assertIsDisplayed()
    }

    private fun detalhe(vaga: VagaDto) {
        val servico = ServicoVagas(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = MockEngine { respond("", HttpStatusCode.OK) }))
        val viewModel = DetalheVagaViewModel(vaga.paraVagaAberta(), servico, detalhe = vaga, escopo = CoroutineScope(Dispatchers.Default))
        rule.setContent { FrilaTheme { TelaDetalheVaga(viewModel = viewModel) } }
    }

    @Test
    fun `aberta pelo id, a tela de detalhe mostra o que so o servidor sabe - posicoes, responsavel, traje e observacoes`() {
        detalhe(vagaDoServidor())

        rule.onNodeWithText("Garçom").assertIsDisplayed()
        rule.onNodeWithText("Posições abertas: 2 de 3").assertIsDisplayed()
        rule.onNodeWithText("Responsável no local: Procure a gerente no balcão").assertIsDisplayed()
        rule.onNodeWithText("Traje: Camisa preta").assertIsDisplayed()
        rule.onNodeWithText("Observações: Chegar 15 minutos antes").assertIsDisplayed()
        rule.onNode(hasText("de distância", substring = true)).assertIsDisplayed()
    }

    @Test
    fun `sem distancia, traje nem observacoes no detalhe, a tela nao inventa as linhas`() {
        detalhe(vagaDoServidor(distanciaKm = null, traje = null, observacoes = " "))

        rule.onNodeWithText("Responsável no local: Procure a gerente no balcão").assertIsDisplayed()
        assertEquals(0, rule.onAllNodes(hasText("de distância", substring = true)).fetchSemanticsNodes().size)
        assertEquals(0, rule.onAllNodes(hasText("Traje:", substring = true)).fetchSemanticsNodes().size)
        assertEquals(0, rule.onAllNodes(hasText("Observações:", substring = true)).fetchSemanticsNodes().size)
    }
}
