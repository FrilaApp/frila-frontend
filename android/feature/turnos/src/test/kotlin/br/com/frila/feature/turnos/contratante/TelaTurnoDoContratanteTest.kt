package br.com.frila.feature.turnos.contratante

import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
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

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1200dp")
class TelaTurnoDoContratanteTest {

    @get:Rule
    val rule = createComposeRule()

    private val ana = PerfilPublicoDto("p1", "profissional", "Ana", listOf("garçom", "barman"), ReputacaoDto(1, 1, null, 1, 1))

    private fun estado(
        verificacao: String? = null,
        checkinTipo: String? = null,
        checkinEm: Instant? = null,
        aCaminhoEm: Instant? = null,
        emAtraso: Boolean = false,
        profissional: PerfilPublicoDto? = ana,
        enviando: Boolean = false,
        aviso: AvisoDaConfirmacao? = null,
        fim: String = "2026-11-13T03:00:00Z",
    ) = EstadoTurnoDoContratante(
        contexto = ContextoDoTurnoContratante(
            turnoId = "t1", funcao = "Garçom", local = "SQN 108", inicio = Instant.parse("2026-11-12T21:00:00Z"),
            fim = Instant.parse(fim), profissional = profissional, aCaminhoEm = aCaminhoEm, checkinEm = checkinEm,
            checkinTipo = checkinTipo, verificacao = verificacao, emAtraso = emAtraso,
        ),
        enviando = enviando,
        aviso = aviso,
    )

    private class Chamadas {
        var confirmou = 0
        var voltou = 0
    }

    private fun montar(estado: EstadoTurnoDoContratante, chamadas: Chamadas = Chamadas()): Chamadas {
        rule.setContent {
            FrilaTheme {
                ConteudoTurnoDoContratante(
                    estado = estado,
                    acoes = AcoesTurnoDoContratante(aoConfirmarPresenca = { chamadas.confirmou++ }, aoVoltar = { chamadas.voltou++ }),
                )
            }
        }
        return chamadas
    }

    private fun contar(texto: String) = rule.onAllNodesWithText(texto).fetchSemanticsNodes().size

    @Test
    fun `mostra funcao, horario no fuso de Brasilia, local e o cartao do profissional`() {
        montar(estado())

        rule.onNodeWithText("Garçom").assertIsDisplayed()
        rule.onNodeWithText("12/11/2026 18:00 – 13/11/2026 00:00").assertIsDisplayed()
        rule.onNodeWithText("SQN 108").assertIsDisplayed()
        rule.onNodeWithText("Ana").assertIsDisplayed()
        rule.onNodeWithText("Funções: garçom, barman").assertIsDisplayed()
    }

    @Test
    fun `horario de um dia so fica numa linha`() {
        montar(estado(fim = "2026-11-13T00:00:00Z"))

        rule.onNodeWithText("12/11/2026, 18:00 – 21:00").assertIsDisplayed()
    }

    @Test
    fun `sem profissional confirmado a posicao diz isso`() {
        montar(estado(profissional = null))

        rule.onNodeWithText(TextosTurnoDoContratante.SEM_PROFISSIONAL).assertIsDisplayed()
    }

    @Test
    fun `aguardando mostra so o texto, sem botao`() {
        montar(estado())

        rule.onNodeWithText(TextosTurnoDoContratante.AGUARDANDO).assertIsDisplayed()
        assertEquals(0, contar(TextosTurnoDoContratante.CONFIRMAR_PRESENCA))
    }

    @Test
    fun `a caminho mostra o horario do aviso`() {
        montar(estado(aCaminhoEm = Instant.parse("2026-11-12T20:40:00Z")))

        rule.onNodeWithText("Ana está a caminho desde as 17:40.").assertIsDisplayed()
        assertEquals(0, contar(TextosTurnoDoContratante.CONFIRMAR_PRESENCA))
    }

    @Test
    fun `atraso mostra o alerta e nao oferece confirmar`() {
        montar(estado(emAtraso = true))

        rule.onNodeWithText(TextosTurnoDoContratante.EM_ATRASO).assertIsDisplayed()
        assertEquals(0, contar(TextosTurnoDoContratante.CONFIRMAR_PRESENCA))
    }

    @Test
    fun `check-in manual pendente mostra a hora e o botao confirmar presenca com alvo minimo`() {
        val chamadas = montar(estado(verificacao = "pendente", checkinTipo = "manual", checkinEm = Instant.parse("2026-11-12T21:02:00Z")))

        rule.onNodeWithText("Ana fez o check-in às 18:02. Confirme a presença para ela contar.").assertIsDisplayed()
        rule.onNodeWithText(TextosTurnoDoContratante.CONFIRMAR_PRESENCA)
            .assertIsEnabled()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()

        assertEquals(1, chamadas.confirmou)
    }

    @Test
    fun `check-in pendente sem a hora usa o texto sem hora`() {
        montar(estado(verificacao = "pendente", checkinTipo = "manual"))

        rule.onNodeWithText("Ana fez o check-in. Confirme a presença para ela contar.").assertIsDisplayed()
    }

    @Test
    fun `enquanto confirma o botao mostra confirmando e fica desabilitado`() {
        montar(estado(verificacao = "pendente", checkinTipo = "manual", enviando = true))

        rule.onNodeWithText(TextosTurnoDoContratante.CONFIRMANDO).assertIsNotEnabled()
    }

    @Test
    fun `presenca verificada mostra o selo e nao oferece confirmar`() {
        montar(estado(verificacao = "verificado", checkinTipo = "manual"))

        rule.onNodeWithText(TextosTurnoDoContratante.VERIFICADA).assertIsDisplayed()
        assertEquals(0, contar(TextosTurnoDoContratante.CONFIRMAR_PRESENCA))
    }

    @Test
    fun `presenca nao verificada e dita em texto`() {
        montar(estado(verificacao = "nao_verificado", checkinTipo = "geolocalizado"))

        rule.onNodeWithText(TextosTurnoDoContratante.NAO_VERIFICADA).assertIsDisplayed()
    }

    @Test
    fun `aviso de erro e de sucesso da confirmacao sao mostrados`() {
        montar(estado(verificacao = "pendente", checkinTipo = "manual", aviso = AvisoDaConfirmacao.SEM_REDE))
        rule.onNodeWithText(TextosTurnoDoContratante.ERRO_SEM_REDE).assertIsDisplayed()
    }

    @Test
    fun `aviso de presenca confirmada aparece junto ao selo`() {
        montar(estado(verificacao = "verificado", checkinTipo = "manual", aviso = AvisoDaConfirmacao.CONFIRMADA_AGORA))

        rule.onNodeWithText(TextosTurnoDoContratante.CONFIRMADA_AGORA).assertIsDisplayed()
        rule.onNodeWithText(TextosTurnoDoContratante.VERIFICADA).assertIsDisplayed()
    }

    @Test
    fun `voltar chama o callback`() {
        val chamadas = montar(estado())

        rule.onNodeWithContentDescription(TextosTurnoDoContratante.ROTULO_VOLTAR).performClick()

        assertEquals(1, chamadas.voltou)
    }

    @Test
    fun `a tela ligada ao ViewModel confirma a presenca pelo servico e passa a mostrar o selo`() {
        val chamados = mutableListOf<String>()
        val vm = AcompanhamentoContratanteViewModel(
            contexto = estado(verificacao = "pendente", checkinTipo = "manual").contexto,
            confirmar = { id ->
                chamados += id
                Result.success(br.com.frila.core.rede.ResultadoRegistroDto(id, "manual", "verificado", "2026-11-12T21:05:00Z"))
            },
            escopo = kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Unconfined),
        )
        var voltou = 0
        rule.setContent { FrilaTheme { TelaTurnoDoContratante(viewModel = vm, aoVoltar = { voltou++ }) } }

        rule.onNodeWithText(TextosTurnoDoContratante.CONFIRMAR_PRESENCA).performClick()
        rule.onNodeWithContentDescription(TextosTurnoDoContratante.ROTULO_VOLTAR).performClick()

        assertEquals(listOf("t1"), chamados)
        rule.onNodeWithText(TextosTurnoDoContratante.VERIFICADA).assertIsDisplayed()
        assertEquals(0, contar(TextosTurnoDoContratante.CONFIRMAR_PRESENCA))
        assertEquals(1, voltou)
    }
}
