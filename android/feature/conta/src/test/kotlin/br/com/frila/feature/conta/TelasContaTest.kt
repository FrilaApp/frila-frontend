package br.com.frila.feature.conta

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ExclusaoDeContaDto
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelasContaTest {

    @get:Rule
    val rule = createComposeRule()

    /** Estado vive no teste, como o `StateFlow` do ViewModel vive na tela. */
    private fun montarExclusao(
        inicial: EstadoExclusaoDeConta = EstadoExclusaoDeConta(),
        aoExcluir: () -> Unit = {},
        aoVoltar: () -> Unit = {},
    ) {
        rule.setContent {
            var estado by mutableStateOf(inicial)
            FrilaTheme {
                ConteudoExclusaoDeConta(
                    estado = estado,
                    aoAlterarConfirmacao = { estado = estado.copy(confirmouConsequencias = it) },
                    aoExcluir = aoExcluir,
                    aoVoltar = aoVoltar,
                )
            }
        }
    }

    @Test
    fun exclusaoTemTituloComoCabecalhoEExplicaOPrazoDe15DiasDaLgpd() {
        montarExclusao()

        rule.onNodeWithText(TextosExclusaoDeConta.TITULO)
            .assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithText(TextosExclusaoDeConta.CONSEQUENCIA_PRAZO, substring = true).assertIsDisplayed()
        rule.onNodeWithText("15 dias", substring = true).assertIsDisplayed()
        rule.onNodeWithText("30 dias", substring = true).assertDoesNotExist()
    }

    @Test
    fun botaoDeExcluirSoHabilitaDepoisDaCaixaDeConfirmacao() {
        montarExclusao()

        rule.onNodeWithText(TextosExclusaoDeConta.BOTAO_EXCLUIR)
            .performScrollTo()
            .assertIsNotEnabled()

        rule.onNodeWithText(TextosExclusaoDeConta.CONFIRMACAO_CHECK).performClick()

        rule.onNodeWithText(TextosExclusaoDeConta.BOTAO_EXCLUIR)
            .assertIsEnabled()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
    }

    @Test
    fun caixaDeConfirmacaoExpoeSemanticaDeCheckbox() {
        montarExclusao()

        rule.onNodeWithText(TextosExclusaoDeConta.CONFIRMACAO_CHECK)
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, androidx.compose.ui.semantics.Role.Checkbox))
    }

    @Test
    fun excluirPedeConfirmacaoFinalEOCancelarNaoDisparaOPedido() {
        var pedidos = 0
        montarExclusao(inicial = EstadoExclusaoDeConta(confirmouConsequencias = true), aoExcluir = { pedidos++ })

        rule.onNodeWithText(TextosExclusaoDeConta.BOTAO_EXCLUIR).performScrollTo().performClick()
        rule.onNodeWithText(TextosExclusaoDeConta.DIALOGO_TITULO).assertIsDisplayed()
        assertEquals("clicar em excluir só abre o diálogo", 0, pedidos)

        rule.onNodeWithText(TextosExclusaoDeConta.CANCELAR).performClick()
        rule.onNodeWithText(TextosExclusaoDeConta.DIALOGO_TITULO).assertDoesNotExist()
        assertEquals(0, pedidos)
    }

    @Test
    fun confirmarNoDialogoDisparaOPedidoUmaVez() {
        var pedidos = 0
        montarExclusao(inicial = EstadoExclusaoDeConta(confirmouConsequencias = true), aoExcluir = { pedidos++ })

        rule.onNodeWithText(TextosExclusaoDeConta.BOTAO_EXCLUIR).performScrollTo().performClick()
        rule.onNodeWithText(TextosExclusaoDeConta.DIALOGO_CONFIRMAR).performClick()

        assertEquals(1, pedidos)
        rule.onNodeWithText(TextosExclusaoDeConta.DIALOGO_TITULO).assertDoesNotExist()
    }

    @Test
    fun excluindoDesabilitaBotaoEVoltarEMostraProgresso() {
        montarExclusao(inicial = EstadoExclusaoDeConta(confirmouConsequencias = true, excluindo = true))

        rule.onNodeWithText(TextosExclusaoDeConta.EXCLUINDO).performScrollTo().assertIsNotEnabled()
        rule.onNodeWithContentDescription(TextosExclusaoDeConta.ROTULO_VOLTAR).assertIsNotEnabled()
    }

    @Test
    fun erroAparecePertoDoBotaoEPermiteTentarDeNovo() {
        montarExclusao(
            inicial = EstadoExclusaoDeConta(
                confirmouConsequencias = true,
                mensagemErro = TextosExclusaoDeConta.ERRO_ADMIN_UNICO,
            ),
        )

        rule.onNodeWithText(TextosExclusaoDeConta.ERRO_ADMIN_UNICO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosExclusaoDeConta.BOTAO_EXCLUIR).assertIsEnabled()
    }

    @Test
    fun exclusaoConcluidaMostraOResumoESomeComOBotao() {
        montarExclusao(
            inicial = EstadoExclusaoDeConta(
                confirmouConsequencias = true,
                resultado = ExclusaoDeContaDto("2026-11-10T12:00:00Z", "2026-11-25", 2),
            ),
        )

        rule.onNodeWithText(TextosExclusaoDeConta.CONCLUIDA_TITULO).assertIsDisplayed()
        rule.onNodeWithText("Turnos cancelados: 2", substring = true).assertIsDisplayed()
        rule.onNodeWithText("2026-11-25", substring = true).assertIsDisplayed()
        rule.onNodeWithText(TextosExclusaoDeConta.BOTAO_EXCLUIR).assertDoesNotExist()
    }

    @Test
    fun voltarNaExclusaoChamaOCallback() {
        var voltou = false
        montarExclusao(aoVoltar = { voltou = true })

        rule.onNodeWithContentDescription(TextosExclusaoDeConta.ROTULO_VOLTAR)
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()

        assertTrue(voltou)
    }

    @Test
    fun contaSuspensaTemCabecalhoAvisoESaidasComAlvoMinimo() {
        var emailPedido: String? = null
        var saiu = false
        rule.setContent {
            FrilaTheme {
                TelaContaSuspensa(
                    emailSuporte = "suporte@frilabr.com",
                    aoContatarSuporte = { emailPedido = it },
                    aoSair = { saiu = true },
                )
            }
        }

        rule.onNodeWithText(TextosContaSuspensa.TITULO)
            .assertIsDisplayed()
            .assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.Heading))
        rule.onNodeWithText(TextosContaSuspensa.AVISO_PRINCIPAL).assertIsDisplayed()
        rule.onNodeWithText("suporte@frilabr.com").assertIsDisplayed()

        rule.onNodeWithText(TextosContaSuspensa.BOTAO_SUPORTE)
            .performScrollTo()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()
        assertEquals("suporte@frilabr.com", emailPedido)

        rule.onNodeWithText(TextosContaSuspensa.BOTAO_SAIR)
            .performScrollTo()
            .assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
            .performClick()
        assertTrue(saiu)
    }

    @Test
    fun contaSuspensaSoMostraMotivoEDataQuandoVierem() {
        rule.setContent {
            FrilaTheme {
                TelaContaSuspensa(
                    emailSuporte = "suporte@frilabr.com",
                    aoContatarSuporte = {},
                    aoSair = {},
                )
            }
        }
        rule.onNodeWithText(TextosContaSuspensa.SECAO_MOTIVO).assertDoesNotExist()
    }

    @Test
    fun contaSuspensaMostraMotivoEDataInformados() {
        rule.setContent {
            FrilaTheme {
                TelaContaSuspensa(
                    emailSuporte = "suporte@frilabr.com",
                    aoContatarSuporte = {},
                    aoSair = {},
                    motivo = "Denúncia de assédio confirmada",
                    desde = "09/11/2026",
                )
            }
        }

        rule.onNodeWithText(TextosContaSuspensa.SECAO_MOTIVO).assertIsDisplayed()
        rule.onNodeWithText("Denúncia de assédio confirmada").assertIsDisplayed()
        rule.onNodeWithText("09/11/2026").assertIsDisplayed()
    }
}
