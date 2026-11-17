package br.com.frila.feature.turnos.contratante

import androidx.compose.material3.Text
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** L1-5: o cartão do código de chegada na tela do turno da casa (TELA PROVISÓRIA, sem estilo novo). */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1200dp")
class CartaoDoCodigoDaCasaTest {

    @get:Rule
    val rule = createComposeRule()

    private fun montarCartao(estado: EstadoCartaoDoCodigo, aoTentarDeNovo: () -> Unit = {}) {
        rule.setContent { FrilaTheme { ConteudoDoCartaoDoCodigo(estado = estado, aoTentarDeNovo = aoTentarDeNovo) } }
    }

    private fun contar(texto: String) = rule.onAllNodesWithText(texto).fetchSemanticsNodes().size

    @Test
    fun `mostrando exibe o titulo, a explicacao, os seis digitos e a validade`() {
        montarCartao(EstadoCartaoDoCodigo(EstadoDoCodigoDaCasa.Mostrando("049215"), segundosRestantes = 272))

        rule.onNodeWithText(TextosCodigoDaCasa.TITULO).assertIsDisplayed()
        rule.onNodeWithText(TextosCodigoDaCasa.EXPLICACAO).assertIsDisplayed()
        rule.onNodeWithText("049215").assertIsDisplayed()
        rule.onNodeWithText("Vale por mais 4:32").assertIsDisplayed()
    }

    @Test
    fun `o leitor de tela le o codigo digito a digito`() {
        montarCartao(EstadoCartaoDoCodigo(EstadoDoCodigoDaCasa.Mostrando("049215"), segundosRestantes = 272))

        rule.onNodeWithContentDescription("Código de chegada: 0 4 9 2 1 5").assertIsDisplayed()
    }

    @Test
    fun `renovando troca a validade pelo aviso de que gera outro codigo`() {
        montarCartao(EstadoCartaoDoCodigo(EstadoDoCodigoDaCasa.Mostrando("049215"), segundosRestantes = 0, renovando = true))

        rule.onNodeWithText(TextosCodigoDaCasa.GERANDO_OUTRO).assertIsDisplayed()
        assertEquals(0, contar("Vale por mais 0:00"))
    }

    @Test
    fun `carregando mostra o aviso de que gera o codigo`() {
        montarCartao(EstadoCartaoDoCodigo(EstadoDoCodigoDaCasa.Carregando))

        rule.onNodeWithText(TextosCodigoDaCasa.CARREGANDO).assertIsDisplayed()
    }

    /** Um `setContent` por teste: o Compose não aceita dois na mesma regra. */
    private fun verInformativo(estado: EstadoDoCodigoDaCasa, texto: String) {
        montarCartao(EstadoCartaoDoCodigo(estado))

        rule.onNodeWithText(texto).assertIsDisplayed()
        assertEquals(0, contar(TextosCodigoDaCasa.TENTAR_DE_NOVO))
    }

    @Test
    fun `sem codigo para este check-in diz para confirmar pelo botao, sem tentar de novo`() =
        verInformativo(EstadoDoCodigoDaCasa.SemCodigoParaEsteCheckin, TextosCodigoDaCasa.SEM_CODIGO_PARA_ESTE_CHECKIN)

    @Test
    fun `fora da janela diz isso, sem tentar de novo`() =
        verInformativo(EstadoDoCodigoDaCasa.ForaDaJanela, TextosCodigoDaCasa.FORA_DA_JANELA)

    @Test
    fun `encerrado manda para a confirmacao manual, sem tentar de novo`() =
        verInformativo(EstadoDoCodigoDaCasa.Encerrado, TextosCodigoDaCasa.ENCERRADO)

    @Test
    fun `falha mostra o erro e o botao tentar de novo com alvo minimo, que chama o callback`() {
        var tentou = 0
        montarCartao(EstadoCartaoDoCodigo(EstadoDoCodigoDaCasa.Falhou)) { tentou++ }

        rule.onNodeWithText(TextosCodigoDaCasa.FALHOU).assertIsDisplayed()
        rule.onNodeWithText(TextosCodigoDaCasa.TENTAR_DE_NOVO)
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()

        assertEquals(1, tentou)
    }

    @Test
    fun `indisponivel nao mostra cartao nenhum`() {
        montarCartao(EstadoCartaoDoCodigo(EstadoDoCodigoDaCasa.Indisponivel))

        assertEquals(0, contar(TextosCodigoDaCasa.TITULO))
    }

    @Test
    fun `ja verificado nao mostra cartao nenhum`() {
        montarCartao(EstadoCartaoDoCodigo(EstadoDoCodigoDaCasa.JaVerificado))

        assertEquals(0, contar(TextosCodigoDaCasa.TITULO))
    }

    // ---- Encaixe na tela do turno ----

    private val ana = PerfilPublicoDto("p1", "profissional", "Ana", listOf("garçom"), ReputacaoDto(1, 1, null, 1, 1))

    private fun turno(verificacao: String?, checkinTipo: String?, checkinEm: Instant?) = EstadoTurnoDoContratante(
        contexto = ContextoDoTurnoContratante(
            turnoId = "t1", funcao = "Garçom", local = "SQN 108", inicio = Instant.parse("2026-11-12T21:00:00Z"),
            fim = Instant.parse("2026-11-13T03:00:00Z"), profissional = ana, aCaminhoEm = null, checkinEm = checkinEm,
            checkinTipo = checkinTipo, verificacao = verificacao, emAtraso = false,
        ),
    )

    private fun montarTurno(estado: EstadoTurnoDoContratante, comCartao: Boolean = true) {
        rule.setContent {
            FrilaTheme {
                ConteudoTurnoDoContratante(
                    estado = estado,
                    acoes = AcoesTurnoDoContratante(),
                    cartaoDoCodigo = if (comCartao) ({ Text("CARTAO-DO-CODIGO") }) else null,
                )
            }
        }
    }

    @Test
    fun `com check-in manual pendente o cartao aparece junto da confirmacao`() {
        montarTurno(turno("pendente", "manual", Instant.parse("2026-11-12T21:02:00Z")))

        rule.onNodeWithText("CARTAO-DO-CODIGO").assertIsDisplayed()
        rule.onNodeWithText(TextosTurnoDoContratante.CONFIRMAR_PRESENCA).assertIsDisplayed()
    }

    @Test
    fun `aguardando o profissional o cartao nao aparece`() {
        montarTurno(turno(null, null, null))

        assertEquals(0, contar("CARTAO-DO-CODIGO"))
    }

    @Test
    fun `com a presenca verificada o cartao nao aparece`() {
        montarTurno(turno("verificado", "codigo", Instant.parse("2026-11-12T21:02:00Z")))

        assertEquals(0, contar("CARTAO-DO-CODIGO"))
    }

    @Test
    fun `com a presenca nao verificada o cartao nao aparece`() {
        montarTurno(turno("nao_verificado", "manual", Instant.parse("2026-11-12T21:02:00Z")))

        assertEquals(0, contar("CARTAO-DO-CODIGO"))
    }

    @Test
    fun `sem o cartao a tela do turno e a de antes`() {
        montarTurno(turno("pendente", "manual", Instant.parse("2026-11-12T21:02:00Z")), comCartao = false)

        rule.onNodeWithText(TextosTurnoDoContratante.CONFIRMAR_PRESENCA).assertIsDisplayed()
        assertEquals(0, contar("CARTAO-DO-CODIGO"))
    }
}
