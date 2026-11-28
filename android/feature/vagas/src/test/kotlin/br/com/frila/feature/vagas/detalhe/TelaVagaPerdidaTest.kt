package br.com.frila.feature.vagas.detalhe

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.InclusosDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.VagaAbertaDto
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Cartão UR07a5pG (item 273): o botão da tela de vaga perdida volta ao feed; os dois motivos têm o seu título. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class TelaVagaPerdidaTest {

    @get:Rule
    val compose = createComposeRule()

    private val vaga = VagaAbertaDto(
        id = "vaga-123",
        funcao = FuncaoDto(id = "f1", nome = "Garçom", categoria = "salao"),
        estabelecimento = PerfilPublicoDto("est-1", "estabelecimento", "Restaurante Panelinha", null, ReputacaoDto(30, 28, null, 28, 28)),
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
    fun `o botao chama a volta ao feed, uma vez`() {
        var voltas = 0
        compose.setContent { TelaVagaPerdida(MotivoDaVagaPerdida.ENCERRADA, vaga, aoVoltarAoFeed = { voltas++ }) }

        compose.onNodeWithTag("voltar-para-lista").performClick()

        assertEquals(1, voltas)
    }

    @Test
    fun `cada motivo tem o seu titulo`() {
        compose.setContent { TelaVagaPerdida(MotivoDaVagaPerdida.PREENCHIDA, vaga, aoVoltarAoFeed = {}) }
        compose.onNodeWithText("Esta vaga já foi preenchida").assertIsDisplayed()
    }
}
