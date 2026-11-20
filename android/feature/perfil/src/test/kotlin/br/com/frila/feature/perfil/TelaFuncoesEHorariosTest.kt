package br.com.frila.feature.perfil

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.JanelaDeDisponibilidadeDto
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h2400dp")
class TelaFuncoesEHorariosTest {

    @get:Rule
    val rule = createComposeRule()

    private val garcom = FuncaoDto(id = "f-garcom", nome = "Garçom", categoria = "Salão")
    private val cozinheiro = FuncaoDto(id = "f-cozinheiro", nome = "Cozinheiro", categoria = "Cozinha")
    private val janelaSegunda = JanelaDeDisponibilidadeDto(diaSemana = 1, inicio = "08:00", fim = "16:00")

    private val estadoPadrao = EstadoFuncoesEHorarios(
        funcoesDisponiveis = listOf(garcom, cozinheiro),
        funcoesSelecionadas = setOf("f-garcom"),
        disponibilidades = listOf(janelaSegunda),
        diaSelecionado = 1,
    )

    private class Eventos {
        val funcoesAlternadas = mutableListOf<String>()
        val diasSelecionados = mutableListOf<Int>()
        val janelasAdicionadas = mutableListOf<Triple<Int, String, String>>()
        val janelasRemovidas = mutableListOf<JanelaDeDisponibilidadeDto>()
        var salvou = 0
        var tentouRecarregar = 0
        var voltou = 0
    }

    private fun montar(estado: EstadoFuncoesEHorarios = estadoPadrao, eventos: Eventos = Eventos()): Eventos {
        rule.setContent {
            FrilaTheme {
                ConteudoFuncoesEHorarios(
                    estado = estado,
                    aoAlternarFuncao = { eventos.funcoesAlternadas += it },
                    aoSelecionarDia = { eventos.diasSelecionados += it },
                    aoAdicionarJanela = { dia, ini, fim ->
                        eventos.janelasAdicionadas += Triple(dia, ini, fim)
                        true
                    },
                    aoRemoverJanela = { eventos.janelasRemovidas += it },
                    aoSalvar = { eventos.salvou++ },
                    aoTentarRecarregar = { eventos.tentouRecarregar++ },
                    aoVoltar = { eventos.voltou++ },
                )
            }
        }
        return eventos
    }

    @Test
    fun `renderiza titulo funcoes do catalogo e seletor de dias`() {
        montar()

        rule.onNodeWithText("Funções e horários").assertIsDisplayed()
        rule.onNodeWithText("Funções exercidas").assertIsDisplayed()
        rule.onNodeWithText("Garçom").assertIsDisplayed()
        rule.onNodeWithText("Cozinheiro").assertIsDisplayed()
        rule.onNodeWithText("Disponibilidade semanal").assertIsDisplayed()
        rule.onNodeWithTag("dia-1").assertIsSelected()
    }

    @Test
    fun `tocar em funcao avisa callback para alternar`() {
        val eventos = montar()

        rule.onNodeWithTag("chip-funcao-f-cozinheiro").performClick()
        assertEquals(listOf("f-cozinheiro"), eventos.funcoesAlternadas)
    }

    @Test
    fun `tocar em dia avisa callback para selecionar dia`() {
        val eventos = montar()

        rule.onNodeWithTag("dia-2").performClick()
        assertEquals(listOf(2), eventos.diasSelecionados)
    }

    @Test
    fun `tocar em adicionar horario avisa callback com valores dos campos`() {
        val eventos = montar()

        rule.onNodeWithTag("botao-adicionar-horario").performScrollTo().performClick()
        assertEquals(1, eventos.janelasAdicionadas.size)
        val adicionada = eventos.janelasAdicionadas.first()
        assertEquals(1, adicionada.first)
        assertEquals("08:00", adicionada.second)
        assertEquals("16:00", adicionada.third)
    }

    @Test
    fun `tocar em remover janela avisa callback com a janela`() {
        val eventos = montar()

        rule.onNodeWithTag("remover-janela-08:00-16:00").performScrollTo().performClick()
        assertEquals(listOf(janelaSegunda), eventos.janelasRemovidas)
    }

    @Test
    fun `exibe erro de validacao quando presente no estado`() {
        montar(estadoPadrao.copy(erroValidacaoHorario = "O horário de início deve ser anterior ao de término."))

        rule.onNodeWithTag("erro-validacao-horario").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("O horário de início deve ser anterior ao de término.").assertIsDisplayed()
    }

    @Test
    fun `quando precisa definir ponto base desabilita botao salvar e exibe mensagem`() {
        montar(
            estadoPadrao.copy(
                semPerfil = true,
                pontoBaseExistente = null,
                erro = "Defina seu ponto base no perfil antes de salvar funções e horários.",
            ),
        )

        rule.onNodeWithTag("botao-salvar-funcoes-horarios").assertIsNotEnabled()
        rule.onNodeWithText("Defina seu ponto base no perfil antes de salvar funções e horários.").assertIsDisplayed()
    }

    @Test
    fun `tocar em salvar alteracoes avisa callback de salvar`() {
        val eventos = montar()

        rule.onNodeWithTag("botao-salvar-funcoes-horarios").performClick()
        assertEquals(1, eventos.salvou)
    }
}
