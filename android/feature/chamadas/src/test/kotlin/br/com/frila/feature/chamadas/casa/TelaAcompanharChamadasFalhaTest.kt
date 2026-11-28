package br.com.frila.feature.chamadas.casa

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ChamadaResumoDto
import br.com.frila.core.rede.PaginaDeChamadasDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * rsojCnB5: em Acompanhar chamadas, a falha ao carregar não é "Nenhuma chamada encontrada". Com a lista vazia, a tela mostra o erro e
 * "Tentar novamente"; com a lista já na tela, a mantém e avisa a falha. O erro de uma ação (cancelar, publicar) segue como aviso.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1200dp")
class TelaAcompanharChamadasFalhaTest {

    @get:Rule
    val rule = createComposeRule()

    private val chamada = ChamadaResumoDto(
        id = "a", vagaId = "v1", profissionalId = "p1", estabelecimentoId = "e1", estado = "aberta",
        expiraEm = "2026-11-17T12:00:00Z", criadaEm = "2026-11-16T15:00:00Z", funcao = FuncaoDto("f1", "Garçom", "salao"),
        inicioEm = "2026-11-20T22:00:00Z", fimEm = "2026-11-21T02:00:00Z", valorCentavos = 18000,
        outraParte = PerfilPublicoDto(
            id = "p1", tipo = "profissional", nome = "Maria S.",
            reputacao = ReputacaoDto(positivas = 7, total = 8, turnosConsiderados = 8, turnosRealizados = 8),
        ),
    )

    private var tentativas = 0

    private fun montar(tela: EstadoAcompanharChamadas) {
        rule.setContent {
            FrilaTheme {
                ConteudoAcompanharChamadas(
                    tela = tela, aoCancelar = {}, aoPublicarParaTodos = {}, aoVoltar = {}, aoTentarNovamente = { tentativas++ },
                )
            }
        }
    }

    private fun contar(texto: String) = rule.onAllNodesWithText(texto).fetchSemanticsNodes().size

    @Test
    fun `falha ao carregar com a lista vazia mostra o erro e Tentar novamente, e nao Nenhuma chamada encontrada`() {
        montar(EstadoAcompanharChamadas(falhaAoCarregar = TextosChamadaCasa.ERRO))

        rule.onNodeWithText(TextosChamadaCasa.ERRO).assertIsDisplayed()
        assertEquals(0, contar(TextosChamadaCasa.NENHUMA_CHAMADA))
        rule.onNodeWithText(TextosChamadaCasa.TENTAR_NOVAMENTE).performClick()

        assertEquals(1, tentativas)
    }

    @Test
    fun `lista vazia sem falha diz que nao ha chamada e nao oferece Tentar novamente`() {
        montar(EstadoAcompanharChamadas())

        rule.onNodeWithText(TextosChamadaCasa.NENHUMA_CHAMADA).assertIsDisplayed()
        assertEquals(0, contar(TextosChamadaCasa.TENTAR_NOVAMENTE))
    }

    @Test
    fun `falha ao reler com a lista na tela mantem as chamadas e avisa a falha`() {
        montar(EstadoAcompanharChamadas(chamadas = listOf(chamada), falhaAoCarregar = TextosChamadaCasa.ERRO))

        rule.onNodeWithText("Maria S.").assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaCasa.ERRO).assertIsDisplayed()
        assertEquals(0, contar(TextosChamadaCasa.TENTAR_NOVAMENTE))
    }

    @Test
    fun `erro de uma acao com a lista vazia segue como aviso e nao vira falha da carga`() {
        montar(EstadoAcompanharChamadas(erro = TextosChamadaCasa.CHAMADA_JA_RESPONDIDA))

        rule.onNodeWithText(TextosChamadaCasa.CHAMADA_JA_RESPONDIDA).assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaCasa.NENHUMA_CHAMADA).assertIsDisplayed()
        assertEquals(0, contar(TextosChamadaCasa.TENTAR_NOVAMENTE))
    }

    @Test
    fun `na tela de verdade, Tentar novamente rele a lista com o view model`() {
        var leituras = 0
        val viewModel = AcompanharChamadasViewModel(
            vagaId = "v1",
            listar = { _, _, _ ->
                leituras++
                if (leituras == 1) error("sem rede")
                PaginaDeChamadasDto(itens = listOf(chamada), proximoCursor = null)
            },
            cancelarChamada = { error("nao cancela") },
            publicarAPartirDaChamada = { _, _, _ -> error("nao publica") },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        rule.setContent { FrilaTheme { TelaAcompanharChamadas(viewModel = viewModel, aoVoltar = {}) } }

        rule.onNodeWithText(TextosChamadaCasa.TENTAR_NOVAMENTE).performClick()

        rule.waitUntil(5_000) { rule.onAllNodesWithText("Maria S.").fetchSemanticsNodes().isNotEmpty() }
        assertEquals(2, leituras)
        assertEquals(0, contar(TextosChamadaCasa.TENTAR_NOVAMENTE))
    }
}
