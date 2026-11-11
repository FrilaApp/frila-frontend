package br.com.frila.feature.suporte

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.MotivoDenuncia
import br.com.frila.core.rede.ProtocoloDto
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaDenunciaTest {

    @get:Rule
    val rule = createComposeRule()

    private class Chamadas {
        val ligacoes = mutableListOf<String>()
        var envios = 0
        var abriuBloqueio = 0
        var cancelouBloqueio = 0
        var confirmouBloqueio = 0
        var fechou = 0
    }

    /** O estado vive no teste, como o `StateFlow` do ViewModel vive na tela; o bloqueio abre o diálogo como o ViewModel abriria. */
    private fun montar(
        inicial: EstadoDenuncia = EstadoDenuncia(),
        chamadas: Chamadas = Chamadas(),
        turno: Boolean = false,
        chamada: Boolean = false,
    ): Chamadas {
        rule.setContent {
            var estado by mutableStateOf(inicial)
            FrilaTheme {
                ConteudoDenuncia(
                    estado = estado,
                    associadaAoTurno = turno,
                    associadaAChamada = chamada,
                    aoEscolherMotivo = { estado = estado.copy(motivo = it) },
                    aoEditarRelato = { estado = estado.copy(relato = it) },
                    aoEnviar = { chamadas.envios++ },
                    aoAbrirBloqueio = { chamadas.abriuBloqueio++; estado = estado.copy(dialogoBloqueioAberto = true) },
                    aoCancelarBloqueio = { chamadas.cancelouBloqueio++; estado = estado.copy(dialogoBloqueioAberto = false) },
                    aoConfirmarBloqueio = { chamadas.confirmouBloqueio++; estado = estado.copy(dialogoBloqueioAberto = false) },
                    aoFechar = { chamadas.fechou++ },
                    aoLigar = { chamadas.ligacoes += it },
                )
            }
        }
        return chamadas
    }

    @Test
    fun tituloEhCabecalhoEVoltarTemAlvoMinimo() {
        val c = montar()

        rule.onNodeWithText(TextosSuporte.TITULO)
            .assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithContentDescription(TextosSuporte.ROTULO_VOLTAR)
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()

        assertEquals(1, c.fechou)
    }

    @Test
    fun atalhosDeEmergenciaFicamSempreAVistaEChamamOsNumeros() {
        val c = montar()

        rule.onNodeWithText(TextosSuporte.EMERGENCIA).assertIsDisplayed()
        rule.onNodeWithText(TextosSuporte.LIGAR_190).assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()
        rule.onNodeWithText(TextosSuporte.LIGAR_180).assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()

        assertEquals(listOf("190", "180"), c.ligacoes)
    }

    @Test
    fun motivosSaoUmGrupoDeRadioComAssedioSelecionadoEAlvoMinimo() {
        montar()

        MotivoDenuncia.entries.forEach { motivo ->
            rule.onNodeWithText(TextosSuporte.nome(motivo))
                .performScrollTo()
                .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
                .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.RadioButton))
        }
        rule.onNodeWithText(TextosSuporte.nome(MotivoDenuncia.ASSEDIO)).assertIsSelected()

        rule.onNodeWithText(TextosSuporte.nome(MotivoDenuncia.DISCRIMINACAO)).performClick()

        rule.onNodeWithText(TextosSuporte.nome(MotivoDenuncia.DISCRIMINACAO)).assertIsSelected()
    }

    @Test
    fun enviarSoHabilitaComRelatoDeDezCaracteresOuMais() {
        val c = montar()

        rule.onNodeWithText(TextosSuporte.ENVIAR).performScrollTo().assertIsNotEnabled()
        rule.onNodeWithText(TextosSuporte.RELATO_DICA).assertIsDisplayed()

        rule.onNode(SemanticsMatcher.keyIsDefined(SemanticsProperties.EditableText)).performTextInput("123456789")
        rule.onNodeWithText(TextosSuporte.ENVIAR).assertIsNotEnabled()

        rule.onNode(SemanticsMatcher.keyIsDefined(SemanticsProperties.EditableText)).performTextInput("0")
        rule.onNodeWithText(TextosSuporte.RELATO_VALIDO).assertIsDisplayed()
        rule.onNodeWithText(TextosSuporte.ENVIAR).assertIsEnabled().performClick()

        assertEquals(1, c.envios)
    }

    @Test
    fun mostraAAssociacaoComOTurnoEComAChamadaQuandoExistem() {
        montar(turno = true, chamada = true)

        rule.onNodeWithText(TextosSuporte.ASSOCIADA_AO_TURNO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosSuporte.ASSOCIADA_A_CHAMADA).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun semAssociacaoNaoMostraAvisoDeAssociacao() {
        montar()

        rule.onNodeWithText(TextosSuporte.ASSOCIADA_AO_TURNO).assertDoesNotExist()
        rule.onNodeWithText(TextosSuporte.ASSOCIADA_A_CHAMADA).assertDoesNotExist()
    }

    @Test
    fun enviandoDesabilitaOBotaoEMostraProgresso() {
        montar(EstadoDenuncia(relato = "relato bem comprido", enviando = true))

        rule.onNodeWithText(TextosSuporte.ENVIANDO).performScrollTo().assertIsNotEnabled()
    }

    @Test
    fun erroDeEnvioApareceEOBotaoContinuaDisponivelParaNovaTentativa() {
        montar(EstadoDenuncia(relato = "relato bem comprido", erroDenuncia = TextosSuporte.ERRO_SEM_REDE))

        rule.onNodeWithText(TextosSuporte.ERRO_SEM_REDE).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosSuporte.ENVIAR).assertIsEnabled()
    }

    @Test
    fun denunciaEnviadaMostraProtocoloCurtoEPrazoEEscondeOFormulario() {
        val c = montar(
            EstadoDenuncia(
                relato = "relato bem comprido",
                protocolo = ProtocoloDto("6f1c2a4e-1111-2222-3333-444455556666", "denuncia", "2026-11-10T12:00:00Z", "2026-11-17"),
            ),
        )

        rule.onNodeWithText(TextosSuporte.ENVIADA).assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithText("#6F1C2A4E", substring = true).assertIsDisplayed()
        rule.onNodeWithText("17/11/2026", substring = true).assertIsDisplayed()
        rule.onNodeWithText(TextosSuporte.ENVIAR).assertDoesNotExist()
        rule.onNodeWithText(TextosSuporte.CONCLUIR).performClick()

        assertEquals(1, c.fechou)
    }

    @Test
    fun bloquearAbreODialogoEOEfeitoEstaEscritoAntesDeConfirmar() {
        val c = montar()

        rule.onNodeWithText(TextosSuporte.BLOQUEAR).performScrollTo().performClick()

        rule.onNodeWithText(TextosSuporte.BLOQUEIO_TITULO).assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithText(TextosSuporte.BLOQUEIO_EFEITO).assertIsDisplayed()
        assertEquals("só abrir o diálogo não bloqueia", 0, c.confirmouBloqueio)
    }

    @Test
    fun cancelarOBloqueioFechaODialogoSemConfirmar() {
        val c = montar()

        rule.onNodeWithText(TextosSuporte.BLOQUEAR).performScrollTo().performClick()
        rule.onNodeWithText(TextosSuporte.CANCELAR).performClick()

        rule.onNodeWithText(TextosSuporte.BLOQUEIO_TITULO).assertDoesNotExist()
        assertEquals(1, c.cancelouBloqueio)
        assertEquals(0, c.confirmouBloqueio)
    }

    @Test
    fun confirmarOBloqueioChamaOCallbackUmaVez() {
        val c = montar(EstadoDenuncia(dialogoBloqueioAberto = true))

        rule.onNodeWithText(TextosSuporte.BLOQUEIO_CONFIRMAR).performClick()

        assertEquals(1, c.confirmouBloqueio)
    }

    @Test
    fun bloqueadoTrocaOBotaoPeloAviso() {
        montar(EstadoDenuncia(bloqueado = true))

        rule.onNodeWithText(TextosSuporte.BLOQUEADO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosSuporte.BLOQUEAR).assertDoesNotExist()
    }

    @Test
    fun erroDeBloqueioAparece() {
        montar(EstadoDenuncia(erroBloqueio = TextosSuporte.ERRO_GENERICO))

        rule.onNodeWithText(TextosSuporte.ERRO_GENERICO).performScrollTo().assertIsDisplayed()
    }
}
