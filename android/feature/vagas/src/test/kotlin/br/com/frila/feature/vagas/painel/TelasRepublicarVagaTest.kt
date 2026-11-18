package br.com.frila.feature.vagas.painel

import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.componentes.AuditoriaSemanticaAcessibilidade
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** As telas provisórias de republicar (vaga e posições restantes) e as entradas delas em Minhas vagas. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1600dp")
class TelasRepublicarVagaTest {

    @get:Rule
    val rule = createComposeRule()

    private val inicio = Instant.parse("2026-11-12T21:00:00Z")
    private val fim = Instant.parse("2026-11-13T03:00:00Z")

    private fun contar(texto: String) = rule.onAllNodesWithText(texto).fetchSemanticsNodes().size

    private fun item(podeRepublicar: Boolean = false, republicavel: Int = 0) = ItemMinhaVaga(
        id = "v1", funcao = "Garçom", local = "SQN 108", inicio = inicio, fim = fim, valorCentavos = 16_000, selecao = true,
        oculta = false, alertaVagaVazia = false, candidatosPendentes = 0, totalPosicoes = 3, confirmadas = 1, posicoesAbertas = 2,
        emAtraso = 0, secao = SecaoMinhasVagas.ENCERRADAS, recemPublicada = false, podeVerCandidatos = false, comecaEm = null,
        podeRepublicar = podeRepublicar, republicavelEmUrgencia = republicavel,
    )

    private fun minhasVagas(item: ItemMinhaVaga, acoes: AcoesMinhasVagas) = rule.setContent {
        FrilaTheme {
            ConteudoMinhasVagas(EstadoMinhasVagas(ListaMinhasVagas.Sucesso(listOf(item))), nomeEstabelecimento = null, acoes = acoes)
        }
    }

    @Test
    fun `Minhas vagas oferece republicar e republicar posicoes na vaga que permite e entrega a vaga tocada`() {
        val tocadas = mutableListOf<String>()
        minhasVagas(
            item(podeRepublicar = true, republicavel = 2),
            AcoesMinhasVagas(aoRepublicarVaga = { tocadas += "vaga ${it.id}" }, aoRepublicarPosicoesRestantes = { tocadas += "restantes ${it.id}" }),
        )

        rule.onNodeWithContentDescription("Republicar a vaga de Garçom").assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()
        rule.onNodeWithText("Republicar 2 posições em urgência").assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()

        assertEquals(listOf("vaga v1", "restantes v1"), tocadas)
    }

    @Test
    fun `Minhas vagas nao mostra os botoes de republicar sem quem atenda, nem na vaga que nao permite`() {
        minhasVagas(item(podeRepublicar = true, republicavel = 1), AcoesMinhasVagas())
        assertEquals(0, contar(TextosRepublicarVaga.TITULO))
        assertEquals(0, contar(TextosRepublicarPosicoesRestantes.BOTAO_UMA))
    }

    @Test
    fun `Minhas vagas nao mostra os botoes de republicar na vaga que nao permite`() {
        minhasVagas(item(), AcoesMinhasVagas(aoRepublicarVaga = {}, aoRepublicarPosicoesRestantes = {}))

        assertEquals(0, contar(TextosRepublicarVaga.TITULO))
        assertEquals(0, contar(TextosRepublicarPosicoesRestantes.BOTAO_UMA))
    }

    private fun republicar(estado: EstadoRepublicarVaga, aoConfirmar: () -> Unit = {}, aoFechar: () -> Unit = {}) = rule.setContent {
        FrilaTheme { ConteudoRepublicarVaga(estado, {}, {}, aoConfirmar, aoFechar) }
    }

    @Test
    fun `republicar mostra o horario com rotulo falado, o erro do campo e confirma`() {
        var confirmou = 0
        republicar(EstadoRepublicarVaga(inicio, fim, erroFim = TextosRepublicarVaga.TURNO_CURTO), aoConfirmar = { confirmou++ })

        rule.onNodeWithContentDescription("Data de início: 12/11/2026").assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).assertIsEnabled()
        rule.onNodeWithContentDescription("Hora de término: 00:00").assertIsEnabled()
        rule.onNodeWithText(TextosRepublicarVaga.TURNO_CURTO).assertIsDisplayed()
        rule.onNodeWithText(TextosRepublicarVaga.CONFIRMAR).assertIsEnabled().performClick()

        assertEquals(1, confirmou)
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(rule.onRoot().fetchSemanticsNode())
    }

    @Test
    fun `depois de falha passageira o horario trava e o botao vira Tentar novamente`() {
        republicar(EstadoRepublicarVaga(inicio, fim, camposBloqueados = true, mensagemErro = TextosRepublicarVaga.SEM_REDE))

        rule.onNodeWithContentDescription("Data de início: 12/11/2026").assertIsNotEnabled()
        rule.onNodeWithText(TextosRepublicarVaga.SEM_REDE).assertIsDisplayed()
        rule.onNodeWithText(TextosRepublicarVaga.TENTAR_NOVAMENTE).assertIsEnabled()
        assertEquals(0, contar(TextosRepublicarVaga.CONFIRMAR))
    }

    @Test
    fun `republicada mostra o desfecho e fecha`() {
        var fechou = 0
        republicar(EstadoRepublicarVaga(inicio, fim, vagaPublicadaId = "nova"), aoFechar = { fechou++ })

        rule.onNodeWithText(TextosRepublicarVaga.SUCESSO).assertIsDisplayed()
        rule.onNodeWithText(TextosRepublicarVaga.OK).performClick()

        assertEquals(1, fechou)
    }

    private fun dialogo(estado: EstadoRepublicarPosicoesRestantes, aoConfirmar: () -> Unit = {}) = rule.setContent {
        FrilaTheme { DialogoRepublicarPosicoesRestantes(estado, aoConfirmar = aoConfirmar, aoFechar = {}) }
    }

    @Test
    fun `posicoes restantes - o dialogo avisa da urgencia, confirma e mostra a recusa`() {
        var confirmou = 0
        dialogo(EstadoRepublicarPosicoesRestantes(posicoesRestantes = 2, erro = TextosRepublicarPosicoesRestantes.JA_COMECOU)) { confirmou++ }

        rule.onNodeWithText(TextosRepublicarPosicoesRestantes.CONFIRMACAO_TITULO).assertIsDisplayed()
        rule.onNodeWithText("Republicar 2 posições em urgência").assertIsDisplayed()
        rule.onNodeWithText(TextosRepublicarPosicoesRestantes.CONFIRMACAO_MENSAGEM).assertIsDisplayed()
        rule.onNodeWithText(TextosRepublicarPosicoesRestantes.JA_COMECOU).assertIsDisplayed()
        rule.onNodeWithText(TextosRepublicarPosicoesRestantes.CONFIRMAR).performClick()

        assertEquals(1, confirmou)
    }

    @Test
    fun `posicoes restantes - enquanto republica o Confirmar fica desligado`() {
        dialogo(EstadoRepublicarPosicoesRestantes(posicoesRestantes = 1, carregando = true))

        rule.onNodeWithText(TextosRepublicarPosicoesRestantes.REPUBLICANDO).assertIsDisplayed()
        rule.onNodeWithText(TextosRepublicarPosicoesRestantes.CONFIRMAR).assertIsNotEnabled()
    }
}
