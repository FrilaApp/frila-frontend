package br.com.frila.feature.vagas.detalhe

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.Dinheiro
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.InclusosDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.VagaAbertaDto
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaTurnoConfirmadoTest {

    @get:Rule
    val compose = createComposeRule()

    private val vagaDeExemplo = VagaAbertaDto(
        id = "vaga-123",
        funcao = FuncaoDto(id = "f1", nome = "Garçom", categoria = "salao"),
        estabelecimento = PerfilPublicoDto(
            id = "est-1",
            tipo = "estabelecimento",
            nome = "Restaurante Panelinha",
            reputacao = ReputacaoDto(30, 28, null, 28, 28),
        ),
        inicioEm = "2026-11-21T18:00:00Z",
        fimEm = "2026-11-22T00:00:00Z",
        local = "CLN 402 Bloco B",
        regiaoAdministrativa = "Asa Norte",
        distanciaKm = 2.5,
        valorCentavos = 18000,
        posicoesAbertas = 1,
        inclusos = InclusosDto(incluiRefeicao = true, incluiTransporte = false, exigeMaterialProprio = false),
        modo = "urgencia",
    )

    @Test
    fun aoCarregarExibeCabecalhoResumoEBotoes() {
        var foiParaMeusTurnos = false
        var voltouAoFeed = false

        compose.setContent {
            FrilaTheme {
                TelaTurnoConfirmado(
                    vaga = vagaDeExemplo,
                    quemRecebe = "Carlos Silva",
                    aoVerMeusTurnos = { foiParaMeusTurnos = true },
                    aoVoltarAoFeed = { voltouAoFeed = true },
                )
            }
        }

        compose.onNodeWithTag("resultado-confirmada").assertIsDisplayed()
        compose.onNodeWithText("Turno confirmado!").assertIsDisplayed()
        compose.onNodeWithText("Garçom, Restaurante Panelinha").assertIsDisplayed()
        compose.onNodeWithText("CLN 402 Bloco B, Asa Norte").assertIsDisplayed()
        compose.onNodeWithText("Quem recebe: Carlos Silva").assertIsDisplayed()
        compose.onNodeWithText(Dinheiro(18000).formatado()).assertIsDisplayed()

        compose.onNodeWithTag("botao-ver-meus-turnos").assertIsDisplayed().performClick()
        assertTrue(foiParaMeusTurnos)

        compose.onNodeWithTag("voltar-para-lista").assertIsDisplayed().performClick()
        assertTrue(voltouAoFeed)
    }

    @Test
    fun fallbackDeQuemRecebeUsaNomeDoEstabelecimento() {
        compose.setContent {
            FrilaTheme {
                TelaTurnoConfirmado(
                    vaga = vagaDeExemplo,
                    quemRecebe = null,
                    aoVerMeusTurnos = {},
                    aoVoltarAoFeed = {},
                )
            }
        }

        compose.onNodeWithText("Quem recebe: Restaurante Panelinha").assertIsDisplayed()
    }
}
