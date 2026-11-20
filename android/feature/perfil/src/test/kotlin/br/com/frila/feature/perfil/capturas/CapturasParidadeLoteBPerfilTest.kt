package br.com.frila.feature.perfil.capturas

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.unit.Density
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.JanelaDeDisponibilidadeDto
import br.com.frila.feature.perfil.ConteudoFuncoesEHorarios
import br.com.frila.feature.perfil.EstadoFuncoesEHorarios
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasParidadeLoteBPerfilTest {

    @get:Rule
    val compose = createComposeRule()

    private fun comFonte(escala: Float, conteudo: @Composable () -> Unit): @Composable () -> Unit = {
        val densidadeAtual = LocalDensity.current
        CompositionLocalProvider(
            LocalDensity provides Density(densidadeAtual.density, fontScale = escala),
            content = conteudo,
        )
    }

    private val estadoExemplo = EstadoFuncoesEHorarios(
        funcoesDisponiveis = listOf(
            FuncaoDto(id = "f1", nome = "Garçom", categoria = "Salão"),
            FuncaoDto(id = "f2", nome = "Bartender", categoria = "Bar"),
            FuncaoDto(id = "f3", nome = "Cozinheiro", categoria = "Cozinha"),
            FuncaoDto(id = "f4", nome = "Cumim", categoria = "Salão"),
            FuncaoDto(id = "f5", nome = "Recepcionista", categoria = "Salão"),
        ),
        funcoesSelecionadas = setOf("f1", "f2"),
        disponibilidades = listOf(
            JanelaDeDisponibilidadeDto(diaSemana = 1, inicio = "08:00", fim = "16:00"),
            JanelaDeDisponibilidadeDto(diaSemana = 5, inicio = "18:00", fim = "23:30"),
            JanelaDeDisponibilidadeDto(diaSemana = 6, inicio = "18:00", fim = "02:00"),
        ),
        diaSelecionado = 1,
    )

    @Test
    fun capturaItem17FuncoesEHorariosPadrao() {
        compose.setContent(
            comFonte(1.0f) {
                FrilaTheme(temaEscuro = false) {
                    ConteudoFuncoesEHorarios(
                        estado = estadoExemplo,
                        aoAlternarFuncao = {},
                        aoSelecionarDia = {},
                        aoAdicionarJanela = { _, _, _ -> true },
                        aoRemoverJanela = {},
                        aoSalvar = {},
                        aoTentarRecarregar = {},
                        aoVoltar = {},
                    )
                }
            },
        )
        compose.onNodeWithText("Funções e horários").assertIsDisplayed()
        compose.onNodeWithText("Funções exercidas").assertIsDisplayed()
        compose.onNodeWithText("Disponibilidade semanal").assertIsDisplayed()
        compose.capturar("01-item17-funcoes-e-horarios-padrao")
    }

    @Test
    fun capturaItem17FuncoesEHorariosFonteGrande() {
        compose.setContent(
            comFonte(1.5f) {
                FrilaTheme(temaEscuro = false) {
                    ConteudoFuncoesEHorarios(
                        estado = estadoExemplo,
                        aoAlternarFuncao = {},
                        aoSelecionarDia = {},
                        aoAdicionarJanela = { _, _, _ -> true },
                        aoRemoverJanela = {},
                        aoSalvar = {},
                        aoTentarRecarregar = {},
                        aoVoltar = {},
                    )
                }
            },
        )
        compose.onNodeWithText("Funções e horários").assertIsDisplayed()
        compose.onNodeWithText("Funções exercidas").assertIsDisplayed()
        compose.onNodeWithText("Disponibilidade semanal").assertIsDisplayed()
        compose.capturar("02-item17-funcoes-e-horarios-fonte-grande")
    }
}
