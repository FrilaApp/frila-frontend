package br.com.frila.feature.perfil.capturas

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.unit.Density
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.CriteriosDeNotificacaoDto
import br.com.frila.core.rede.EquipeDeConfiancaCriterioDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.JanelaDeDisponibilidadeDto
import br.com.frila.feature.perfil.ConteudoPorQueReceboVagas
import br.com.frila.feature.perfil.EstadoPorQueReceboVagas
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h914dp-xxhdpi")
class CapturasParidadeLoteCPerfilTest {

    @get:Rule
    val compose = createComposeRule()

    private fun comFonte(escala: Float, conteudo: @Composable () -> Unit): @Composable () -> Unit = {
        val densidadeAtual = LocalDensity.current
        CompositionLocalProvider(
            LocalDensity provides Density(densidadeAtual.density, fontScale = escala),
            content = conteudo,
        )
    }

    private val estadoExemplo = EstadoPorQueReceboVagas.Conteudo(
        criterios = CriteriosDeNotificacaoDto(
            funcoes = listOf(
                FuncaoDto(id = "f1", nome = "Garçom", categoria = "Salão"),
                FuncaoDto(id = "f2", nome = "Bartender", categoria = "Bar"),
            ),
            disponibilidades = listOf(
                JanelaDeDisponibilidadeDto(diaSemana = 1, inicio = "08:00", fim = "16:00"),
                JanelaDeDisponibilidadeDto(diaSemana = 5, inicio = "18:00", fim = "02:00"),
            ),
            distanciaMaximaKm = 15.0,
            equipesDeConfianca = listOf(
                EquipeDeConfiancaCriterioDto(estabelecimentoId = "est-1", nome = "Restaurante Central"),
            ),
            notificacoesNoMaximoACadaMin = 30,
        ),
    )

    @Test
    fun capturaItem34PorQueReceboVagasPadrao() {
        compose.setContent(
            comFonte(1.0f) {
                FrilaTheme(temaEscuro = false) {
                    ConteudoPorQueReceboVagas(
                        estado = estadoExemplo,
                        aoTentarRecarregar = {},
                        aoContestar = {},
                        aoVoltar = {},
                    )
                }
            },
        )
        compose.onNodeWithText("Por que recebo vagas").assertIsDisplayed()
        compose.onNodeWithTag("perfil-explicacao-vagas").assertIsDisplayed()
        compose.onNodeWithTag("criterios-funcoes").assertIsDisplayed()
        compose.capturar("01-item34-por-que-recebo-vagas-padrao")
    }

    @Test
    fun capturaItem34PorQueReceboVagasFonteGrande() {
        compose.setContent(
            comFonte(1.5f) {
                FrilaTheme(temaEscuro = false) {
                    ConteudoPorQueReceboVagas(
                        estado = estadoExemplo,
                        aoTentarRecarregar = {},
                        aoContestar = {},
                        aoVoltar = {},
                    )
                }
            },
        )
        compose.onNodeWithText("Por que recebo vagas").assertIsDisplayed()
        compose.onNodeWithTag("perfil-explicacao-vagas").assertIsDisplayed()
        compose.onNodeWithTag("criterios-funcoes").assertIsDisplayed()
        compose.capturar("02-item34-por-que-recebo-vagas-fonte-grande")
    }
}
