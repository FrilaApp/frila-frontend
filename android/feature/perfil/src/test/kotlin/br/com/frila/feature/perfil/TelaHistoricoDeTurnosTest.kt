package br.com.frila.feature.perfil

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h2400dp")
class TelaHistoricoDeTurnosTest {

    @get:Rule
    val rule = createComposeRule()

    private val hojePadrao = LocalDate.of(2026, 10, 3)

    private val estadoPadrao = EstadoTelaHistorico(
        atalho = AtalhoHistorico.ESTE_MES,
        formato = FormatoExportacao.CSV,
        inicioEscolhido = LocalDate.of(2026, 10, 1),
        fimEscolhido = hojePadrao,
        hoje = hojePadrao,
    )

    private class Eventos {
        var atalhoEscolhido: AtalhoHistorico? = null
        var formatoEscolhido: FormatoExportacao? = null
        var inicioEscolhido: LocalDate? = null
        var fimEscolhido: LocalDate? = null
        var exportacoes = 0
        var voltas = 0
    }

    private fun montar(
        estado: EstadoTelaHistorico = estadoPadrao,
        eventos: Eventos = Eventos(),
    ): Eventos {
        rule.setContent {
            FrilaTheme {
                ConteudoHistoricoDeTurnos(
                    estado = estado,
                    aoEscolherAtalho = { eventos.atalhoEscolhido = it },
                    aoEscolherFormato = { eventos.formatoEscolhido = it },
                    aoEscolherInicio = { eventos.inicioEscolhido = it },
                    aoEscolherFim = { eventos.fimEscolhido = it },
                    aoExportar = { eventos.exportacoes++ },
                    aoVoltar = { eventos.voltas++ },
                )
            }
        }
        return eventos
    }

    @Test
    fun renderizaElementosBasicosCorretamente() {
        val eventos = montar()

        rule.onNodeWithText(TextosHistoricoDeTurnos.TITULO).assertIsDisplayed()
        rule.onNodeWithText(TextosHistoricoDeTurnos.EXPLICACAO).assertIsDisplayed()
        rule.onNodeWithTag("historico-este-mes").assertIsDisplayed()
        rule.onNodeWithTag("historico-mes-passado").assertIsDisplayed()
        rule.onNodeWithTag("historico-intervalo").assertIsDisplayed()
        rule.onNodeWithTag("historico-formato-csv").assertIsDisplayed()
        rule.onNodeWithTag("historico-formato-pdf").assertIsDisplayed()

        val botaoExportar = rule.onNodeWithTag("historico-exportar")
        botaoExportar.assertIsDisplayed()
        botaoExportar.assertIsEnabled()

        botaoExportar.performClick()
        assertEquals(1, eventos.exportacoes)

        rule.onNodeWithTag("historico-mes-passado").performClick()
        assertEquals(AtalhoHistorico.MES_PASSADO, eventos.atalhoEscolhido)

        rule.onNodeWithTag("historico-formato-pdf").performClick()
        assertEquals(FormatoExportacao.PDF, eventos.formatoEscolhido)
    }

    @Test
    fun atalhoIntervaloExibeSeletoresDeDataEResumo() {
        val estado = estadoPadrao.copy(
            atalho = AtalhoHistorico.INTERVALO,
            inicioEscolhido = LocalDate.of(2026, 9, 20),
            fimEscolhido = LocalDate.of(2026, 10, 3),
        )
        montar(estado)

        rule.onNodeWithTag("historico-de").assertIsDisplayed()
        rule.onNodeWithTag("historico-ate").assertIsDisplayed()
        rule.onNodeWithTag("historico-resumo-periodo").assertIsDisplayed()
        rule.onNodeWithText("De 20/09/2026 a 03/10/2026").assertIsDisplayed()
        rule.onNodeWithTag("historico-exportar").assertIsEnabled()
    }

    @Test
    fun periodoAcimaDeTrintaDiasExibeAvisoEDesabilitaExportar() {
        val estado = estadoPadrao.copy(
            atalho = AtalhoHistorico.INTERVALO,
            inicioEscolhido = LocalDate.of(2026, 9, 1),
            fimEscolhido = LocalDate.of(2026, 10, 3), // 33 dias
        )
        montar(estado)

        rule.onNodeWithTag("historico-periodo-invalido").assertIsDisplayed()
        rule.onNodeWithText(TextosHistoricoDeTurnos.INTERVALO_MAXIMO_EXCEDIDO).assertIsDisplayed()
        rule.onNodeWithTag("historico-exportar").assertIsNotEnabled()
    }

    @Test
    fun estadoSemTurnosExibeMensagemJuntoAoBotao() {
        val estado = estadoPadrao.copy(estado = EstadoHistorico.SemTurnos)
        montar(estado)

        rule.onNodeWithTag("historico-sem-turnos").assertIsDisplayed()
        rule.onNodeWithText(TextosHistoricoDeTurnos.SEM_TURNOS).assertIsDisplayed()
    }

    @Test
    fun estadoErroRepetivelExibeMensagemEBotaoTentarNovamente() {
        val eventos = Eventos()
        val estado = estadoPadrao.copy(estado = EstadoHistorico.Erro("Falha temporária", repetivel = true))
        montar(estado, eventos)

        rule.onNodeWithTag("historico-erro").assertIsDisplayed()
        rule.onNodeWithText("Falha temporária").assertIsDisplayed()

        val botaoTentar = rule.onNodeWithTag("historico-tentar-novamente")
        botaoTentar.assertIsDisplayed()
        botaoTentar.performClick()
        assertEquals(1, eventos.exportacoes)
    }

    @Test
    fun estadoErroNaoRepetivelNaoExibeBotaoTentarNovamente() {
        val estado = estadoPadrao.copy(estado = EstadoHistorico.Erro("Sessão expirada", repetivel = false))
        montar(estado)

        rule.onNodeWithTag("historico-erro").assertIsDisplayed()
        rule.onNodeWithText("Sessão expirada").assertIsDisplayed()
        rule.onNodeWithTag("historico-tentar-novamente").assertDoesNotExist()
    }
}
