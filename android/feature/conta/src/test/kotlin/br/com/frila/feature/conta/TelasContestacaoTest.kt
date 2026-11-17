package br.com.frila.feature.conta

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.designsystem.componentes.AuditoriaSemanticaAcessibilidade
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.SituacaoDaContaDto
import br.com.frila.core.rede.SuspensaoDaContaDto
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** As telas provisórias do L2-5: a contestação dentro de "Conta suspensa" e o pedido de revisão do despacho. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1600dp")
class TelasContestacaoTest {

    @get:Rule
    val rule = createComposeRule()

    private val email = "suporte@frilabr.com"
    private val protocolo = ProtocoloExibido("6F1C2A4E", "17/11/2026", "24/11/2026", prazo = null)

    private fun contar(texto: String) = rule.onAllNodesWithText(texto).fetchSemanticsNodes().size

    private fun secao(estado: EstadoContaSuspensa, acoes: AcoesContestacaoDaSuspensao = AcoesContestacaoDaSuspensao()) = rule.setContent {
        FrilaTheme {
            TelaContaSuspensa(emailSuporte = email, aoContatarSuporte = {}, aoSair = {}, motivo = estado.motivo, desde = estado.desde) {
                SecaoContestacaoDaSuspensao(estado, email, acoes)
            }
        }
    }

    @Test
    fun `conta suspensa mostra motivo e data e oferece contestar entre as informacoes e o suporte`() {
        var abriu = 0
        secao(EstadoContaSuspensa(motivo = "Faltas sem aviso", desde = "10/11/2026"), AcoesContestacaoDaSuspensao(aoAbrirFormulario = { abriu++ }))

        rule.onNodeWithText("Faltas sem aviso").assertIsDisplayed()
        rule.onNodeWithText("10/11/2026").assertIsDisplayed()
        val contestacao = rule.onNodeWithText(TextosContaSuspensa.SECAO_CONTESTACAO).assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        val suporte = rule.onNodeWithText(TextosContaSuspensa.SECAO_SUPORTE)
        assertTrue(contestacao.getUnclippedBoundsInRoot().top < suporte.getUnclippedBoundsInRoot().top)
        rule.onNodeWithText(TextosContaSuspensa.PRAZO_ANALISE).assertIsDisplayed()
        rule.onNodeWithText(TextosContaSuspensa.BOTAO_CONTESTAR).performScrollTo().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()

        assertEquals(1, abriu)
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(rule.onRoot().fetchSemanticsNode())
    }

    @Test
    fun `o formulario tem o campo do relato com a dica, envia, cancela e mostra o erro em texto`() {
        var enviou = 0
        var cancelou = 0
        val digitado = mutableListOf<String>()
        secao(
            EstadoContaSuspensa(formularioAberto = true, mensagemErro = TextosContaSuspensa.RELATO_MINIMO),
            AcoesContestacaoDaSuspensao(aoMudarRelato = { digitado += it }, aoEnviar = { enviou++ }, aoCancelar = { cancelou++ }),
        )

        rule.onNodeWithText(TextosContaSuspensa.ROTULO_RELATO).performScrollTo().performTextInput("abc")
        rule.onNodeWithText(TextosContaSuspensa.DICA_RELATO).assertIsDisplayed()
        rule.onNodeWithText(TextosContaSuspensa.RELATO_MINIMO).assertIsDisplayed()
        rule.onNodeWithText(TextosContaSuspensa.BOTAO_ENVIAR).performScrollTo().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()
        rule.onNodeWithText(TextosContaSuspensa.CANCELAR).performScrollTo().performClick()

        assertEquals(listOf("abc"), digitado)
        assertEquals(1, enviou)
        assertEquals(1, cancelou)
        assertEquals(0, contar(TextosContaSuspensa.BOTAO_CONTESTAR))
    }

    @Test
    fun `enquanto envia, os botoes ficam desligados e a tela diz que esta enviando`() {
        secao(EstadoContaSuspensa(formularioAberto = true, relato = "Não reconheço a falta.", enviando = true))

        rule.onNodeWithText(TextosContaSuspensa.ENVIANDO).assertIsDisplayed()
        rule.onNodeWithText(TextosContaSuspensa.BOTAO_ENVIAR).assertIsNotEnabled()
        rule.onNodeWithText(TextosContaSuspensa.CANCELAR).assertIsNotEnabled()
    }

    @Test
    fun `contestacao em analise mostra o protocolo e nao oferece outra`() {
        secao(EstadoContaSuspensa(protocolo = protocolo, emAnalise = true))

        rule.onNodeWithText("6F1C2A4E").assertIsDisplayed()
        rule.onNodeWithText("17/11/2026").assertIsDisplayed()
        rule.onNodeWithText("24/11/2026").assertIsDisplayed()
        rule.onNodeWithText(TextosContaSuspensa.EM_ANALISE).assertIsDisplayed()
        rule.onNodeWithText(TextosContaSuspensa.MENSAGEM_EM_ANALISE).assertIsDisplayed()
        assertEquals(0, contar(TextosContaSuspensa.BOTAO_CONTESTAR))
    }

    @Test
    fun `depois do prazo a tela diz que a resposta vai por e-mail e para onde escrever`() {
        secao(EstadoContaSuspensa(protocolo = protocolo, emAnalise = false))

        rule.onNodeWithText("A resposta da Equipe Frila é enviada por e-mail. Para qualquer recurso adicional, escreva para $email.").assertIsDisplayed()
        assertEquals(0, contar(TextosContaSuspensa.EM_ANALISE))
    }

    @Test
    fun `contestacao que ja existe, ainda sem protocolo, mostra o aviso e nao oferece outra`() {
        secao(EstadoContaSuspensa(contestacaoJaExiste = true))

        rule.onNodeWithText(TextosContaSuspensa.CONTESTACAO_JA_EXISTE).assertIsDisplayed()
        assertEquals(0, contar(TextosContaSuspensa.BOTAO_CONTESTAR))
    }

    @Test
    fun `a tela ligada le a situacao ao abrir e mostra o que o servidor disse`() {
        val viewModel = ContaSuspensaViewModel(
            buscarSituacao = { SituacaoDaContaDto("suspensa", SuspensaoDaContaDto("Faltas sem aviso", "2026-11-10T12:00:00Z", null)) },
            contestar = { protocoloDoServidor() },
            relogio = { Instant.parse("2026-11-17T15:00:00Z") },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        rule.setContent { FrilaTheme { TelaContaSuspensaComContestacao(viewModel, email, aoContatarSuporte = {}, aoSair = {}) } }

        rule.onNodeWithText("Faltas sem aviso").assertIsDisplayed()
        rule.onNodeWithText("10/11/2026").assertIsDisplayed()
        rule.onNodeWithText(TextosContaSuspensa.BOTAO_CONTESTAR).performScrollTo().performClick()
        rule.onNodeWithText(TextosContaSuspensa.BOTAO_ENVIAR).performScrollTo().assertIsEnabled()
    }

    private fun despacho(estado: EstadoContestarDespacho, aoEnviar: () -> Unit = {}, aoVoltar: () -> Unit = {}) = rule.setContent {
        FrilaTheme { ConteudoContestarDespacho(estado, aoMudarRelato = {}, aoEnviar = aoEnviar, aoVoltar = aoVoltar) }
    }

    @Test
    fun `contestar despacho explica o pedido, tem o campo do relato e envia`() {
        var enviou = 0
        despacho(EstadoContestarDespacho(mensagemErro = TextosContestarDespacho.RELATO_OBRIGATORIO), aoEnviar = { enviou++ })

        rule.onNodeWithText(TextosContestarDespacho.TITULO).assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithText(TextosContestarDespacho.EXPLICACAO).assertIsDisplayed()
        rule.onNodeWithText(TextosContestarDespacho.ROTULO_RELATO).assertIsDisplayed()
        rule.onNodeWithText(TextosContestarDespacho.RELATO_OBRIGATORIO).assertIsDisplayed()
        rule.onNodeWithText(TextosContestarDespacho.BOTAO_ENVIAR).assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()

        assertEquals(1, enviou)
        AuditoriaSemanticaAcessibilidade.assertSemanticaValida(rule.onRoot().fetchSemanticsNode())
    }

    @Test
    fun `pedido enviado mostra o protocolo e so resta voltar`() {
        var voltou = 0
        despacho(EstadoContestarDespacho(protocolo = protocolo), aoVoltar = { voltou++ })

        rule.onNodeWithText(TextosContestarDespacho.PEDIDO_ENVIADO).assertIsDisplayed()
        rule.onNodeWithText("6F1C2A4E").assertIsDisplayed()
        rule.onNodeWithText(TextosContestarDespacho.MENSAGEM_ENVIADO).assertIsDisplayed()
        assertEquals(0, contar(TextosContestarDespacho.BOTAO_ENVIAR))
        rule.onNodeWithText(TextosContestarDespacho.VOLTAR).performClick()

        assertEquals(1, voltou)
    }

    @Test
    fun `contestacao de despacho que ja existe mostra o aviso e nao oferece enviar`() {
        despacho(EstadoContestarDespacho(contestacaoJaAberta = true))

        rule.onNodeWithText(TextosContestarDespacho.CONTESTACAO_JA_ABERTA).assertIsDisplayed()
        assertEquals(0, contar(TextosContestarDespacho.BOTAO_ENVIAR))
    }
}
