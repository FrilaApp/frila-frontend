package br.com.frila.feature.perfil.capturas

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.unit.Density
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.feature.perfil.AtalhoHistorico
import br.com.frila.feature.perfil.ConteudoHistoricoDeTurnos
import br.com.frila.feature.perfil.EstadoTelaHistorico
import br.com.frila.feature.perfil.FormatoExportacao
import br.com.frila.feature.perfil.TextosHistoricoDeTurnos
import java.time.LocalDate
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasParidadeLoteCHistoricoTest {

    @get:Rule
    val compose = createComposeRule()

    private fun comFonte(escala: Float, conteudo: @Composable () -> Unit): @Composable () -> Unit = {
        val densidadeAtual = LocalDensity.current
        CompositionLocalProvider(
            LocalDensity provides Density(densidadeAtual.density, fontScale = escala),
            content = conteudo,
        )
    }

    private val hoje = LocalDate.of(2026, 10, 3)
    private val estadoExemplo = EstadoTelaHistorico(
        atalho = AtalhoHistorico.ESTE_MES,
        formato = FormatoExportacao.CSV,
        inicioEscolhido = LocalDate.of(2026, 10, 1),
        fimEscolhido = hoje,
        hoje = hoje,
    )

    @Test
    fun capturaItem32HistoricoTurnosPadrao() {
        compose.setContent(
            comFonte(1.0f) {
                FrilaTheme(temaEscuro = false) {
                    ConteudoHistoricoDeTurnos(
                        estado = estadoExemplo,
                        aoEscolherAtalho = {},
                        aoEscolherFormato = {},
                        aoEscolherInicio = {},
                        aoEscolherFim = {},
                        aoExportar = {},
                        aoVoltar = {},
                    )
                }
            },
        )
        compose.onNodeWithText(TextosHistoricoDeTurnos.TITULO).assertIsDisplayed()
        compose.onNodeWithText(TextosHistoricoDeTurnos.PERIODO).assertIsDisplayed()
        compose.onNodeWithText(TextosHistoricoDeTurnos.FORMATO).assertIsDisplayed()
        compose.capturar("01-item32-historico-turnos-padrao")
    }

    @Test
    fun capturaItem32HistoricoTurnosFonteGrande() {
        compose.setContent(
            comFonte(1.5f) {
                FrilaTheme(temaEscuro = false) {
                    ConteudoHistoricoDeTurnos(
                        estado = estadoExemplo,
                        aoEscolherAtalho = {},
                        aoEscolherFormato = {},
                        aoEscolherInicio = {},
                        aoEscolherFim = {},
                        aoExportar = {},
                        aoVoltar = {},
                    )
                }
            },
        )
        compose.onNodeWithText(TextosHistoricoDeTurnos.TITULO).assertIsDisplayed()
        compose.onNodeWithText(TextosHistoricoDeTurnos.PERIODO).assertIsDisplayed()
        compose.onNodeWithText(TextosHistoricoDeTurnos.FORMATO).assertIsDisplayed()
        compose.capturar("02-item32-historico-turnos-fonte-grande")
    }
}
