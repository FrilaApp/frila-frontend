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
class TelaConflitoHorarioTest {

    @get:Rule
    val compose = createComposeRule()

    private val vagaDeExemplo = VagaAbertaDto(
        id = "vaga-456",
        funcao = FuncaoDto(id = "f2", nome = "Cozinheiro", categoria = "cozinha"),
        estabelecimento = PerfilPublicoDto(
            id = "est-2",
            tipo = "estabelecimento",
            nome = "Bar Beirute",
            reputacao = ReputacaoDto(45, 43, null, 43, 43),
        ),
        inicioEm = "2026-11-21T19:00:00Z",
        fimEm = "2026-11-22T01:00:00Z",
        local = "CLS 109 Bloco A",
        regiaoAdministrativa = "Asa Sul",
        distanciaKm = 4.0,
        valorCentavos = 22000,
        posicoesAbertas = 1,
        inclusos = InclusosDto(incluiRefeicao = true, incluiTransporte = true, exigeMaterialProprio = false),
        modo = "urgencia",
    )

    @Test
    fun aoCarregarExibeExplicacaoDeConflitoResumoDaVagaEBotaDeRetorno() {
        var voltouAoFeed = false

        compose.setContent {
            FrilaTheme {
                TelaConflitoHorario(
                    vaga = vagaDeExemplo,
                    aoVoltarAoFeed = { voltouAoFeed = true },
                )
            }
        }

        compose.onNodeWithTag("resultado-turno-sobreposto").assertIsDisplayed()
        compose.onNodeWithText("Conflito de horário").assertIsDisplayed()
        compose.onNodeWithText(
            "Você já tem um turno confirmado que coincide com o horário desta vaga. Não é possível assumir dois turnos ao mesmo tempo.",
        ).assertIsDisplayed()
        compose.onNodeWithText("Vaga original").assertIsDisplayed()
        compose.onNodeWithText("Cozinheiro, Bar Beirute").assertIsDisplayed()
        compose.onNodeWithText("CLS 109 Bloco A, Asa Sul").assertIsDisplayed()
        compose.onNodeWithText(Dinheiro(22000).formatado()).assertExists()

        compose.onNodeWithTag("voltar-para-lista").assertIsDisplayed().performClick()
        assertTrue(voltouAoFeed)
    }
}
