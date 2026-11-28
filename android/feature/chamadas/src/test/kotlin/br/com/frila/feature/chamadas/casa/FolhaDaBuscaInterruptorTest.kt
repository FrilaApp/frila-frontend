package br.com.frila.feature.chamadas.casa

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.state.ToggleableState
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.MeuEstabelecimentoDto
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão m3W8Ahuj (item 263): na folha da busca, "Confirmo que este é o valor total" é um interruptor (`Role.Switch`, estado ligado ou
 * desligado), como o `Toggle` do iOS (`TelaBuscaDeProfissionais.swift:436`) e como a `TelaChamadaDireta`. Antes usava a linha de escolha
 * única (`Role.RadioButton`), e o TalkBack falava de uma escolha que não se desmarca. Fora: os outros usos da linha de opção.
 *
 * JUnit: nenhum método devolve valor (um `@Test` que devolve valor é ignorado).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1200dp")
class FolhaDaBuscaInterruptorTest {

    @get:Rule
    val rule = createComposeRule()

    private val agora = Instant.parse("2026-11-16T15:00:00Z")
    private val garcom = FuncaoDto("f1", "Garçom", "salao")
    private val casa = MeuEstabelecimentoDto(
        id = "c1", nome = "Bistrô Ipê", tipo = "restaurante", endereco = "SCS Quadra 2",
        regiaoAdministrativa = "Plano Piloto", ponto = CoordenadaDto(-15.79, -47.88), papel = "administrador",
    )
    private var estado by mutableStateOf(EstadoBusca())

    private fun montar(extra: (EstadoBusca) -> EstadoBusca = { it }) {
        estado = extra(
            EstadoBusca(
                funcoes = listOf(garcom), funcaoId = garcom.id, casa = casa, estado = EstadoDaBusca.Resultados,
                selecionados = listOf("p1"), filtroDaBusca = RascunhoDeVagaDaBusca("c1", garcom.id),
            ),
        )
        rule.setContent {
            FrilaTheme {
                FolhaDeChamadaDaBusca(estado = estado, relogio = { agora }, aoChamar = { _, _ -> }, aoReenviar = {}, aoConfirmarJ7 = {}, aoFechar = {})
            }
        }
    }

    private fun total() = rule.onNodeWithTag("folha-confirmar-total").performScrollTo()

    private fun estadoDoInterruptor(): ToggleableState? =
        rule.onNodeWithTag("folha-confirmar-total").fetchSemanticsNode().config.getOrNull(SemanticsProperties.ToggleableState)

    @Test
    fun `a confirmacao do total se anuncia como interruptor, nao como botao de opcao`() {
        montar()

        total().assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Switch))
        total().assert(SemanticsMatcher.keyNotDefined(SemanticsProperties.Selected))
        total().assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.ToggleableState))
    }

    @Test
    fun `nasce desligado, liga ao tocar e desliga ao tocar de novo`() {
        montar()
        total()
        assertEquals(ToggleableState.Off, estadoDoInterruptor())

        total().performClick()
        assertEquals(ToggleableState.On, estadoDoInterruptor())

        total().performClick()
        assertEquals(ToggleableState.Off, estadoDoInterruptor())
    }

    @Test
    fun `mudar o valor desliga a confirmacao, e o interruptor acompanha`() {
        montar()
        rule.onNodeWithTag("folha-valor").performTextInput("180")
        total().performClick()
        assertEquals(ToggleableState.On, estadoDoInterruptor())

        rule.onNodeWithTag("folha-valor").performTextInput("5")

        total()
        assertEquals(ToggleableState.Off, estadoDoInterruptor())
    }

    @Test
    fun `a linha inteira e o alvo, com 48 dp no minimo`() {
        montar()

        total().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo)
    }

    @Test
    fun `enviando, o interruptor fica desabilitado, e com a folha livre fica habilitado`() {
        montar()
        total().assertIsEnabled()

        estado = estado.copy(enviando = true)

        total().assertIsNotEnabled()
        estado = estado.copy(enviando = false)
        total().assertIsEnabled()
    }

    @Test
    fun `depois do envio, com o resultado de cada pessoa, o interruptor fica travado`() {
        montar { it.copy(resultadosDaChamada = mapOf("p1" to ResultadoDaChamadaDaBusca.NaoEnviada)) }

        total().assertIsNotEnabled()
    }
}
