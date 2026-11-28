package br.com.frila.feature.chamadas.casa

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextClearance
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTextReplacement
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
 * Cartão 6ebYkEoy (item 262): a folha da busca, como a do iOS (`TelaBuscaDeProfissionais.swift:417,488-497`), mostra no topo "O mesmo
 * valor total e o mesmo horário vão para cada profissional selecionado." e mostra **o tempo todo** o que falta, com o botão "Enviar
 * chamadas" desligado enquanto falta algo (antes só aparecia depois do toque, a mensagem antiga ficava até o próximo toque e o botão
 * ficava ligado). Fora: a ordem das regras (`validarFolhaDaBusca`).
 *
 * JUnit: nenhum método devolve valor (um `@Test` que devolve valor é ignorado).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1200dp")
class FolhaDaBuscaOQueFaltaTest {

    @get:Rule
    val rule = createComposeRule()

    private val agora = Instant.parse("2026-11-16T15:00:00Z")
    private val garcom = FuncaoDto("f1", "Garçom", "salao")
    private val casa = MeuEstabelecimentoDto(
        id = "c1", nome = "Bistrô Ipê", tipo = "restaurante", endereco = "SCS Quadra 2",
        regiaoAdministrativa = "Plano Piloto", ponto = CoordenadaDto(-15.79, -47.88), papel = "administrador",
    )

    private var estado by mutableStateOf(EstadoBusca())
    private val enviadas = mutableListOf<Pair<TrabalhoDaChamada, String?>>()

    private fun montar(extra: (EstadoBusca) -> EstadoBusca = { it }) {
        estado = extra(
            EstadoBusca(
                funcoes = listOf(garcom), funcaoId = garcom.id, casa = casa, estado = EstadoDaBusca.Resultados,
                selecionados = listOf("p1"), filtroDaBusca = RascunhoDeVagaDaBusca("c1", garcom.id),
            ),
        )
        rule.setContent {
            FrilaTheme {
                FolhaDeChamadaDaBusca(
                    estado = estado,
                    relogio = { agora },
                    aoChamar = { trabalho, recado -> enviadas += trabalho to recado },
                    aoReenviar = {},
                    aoConfirmarJ7 = {},
                    aoFechar = {},
                )
            }
        }
    }

    private fun enviar() = rule.onNodeWithTag("folha-enviar").performScrollTo()

    private fun faltaNaTela(motivo: String) = rule.onNodeWithText(motivo).performScrollTo().assertIsDisplayed()

    private fun semMotivo(vararg motivos: String) = motivos.forEach { rule.onAllNodesWithText(it).assertCountEquals(0) }

    private val todosOsMotivos = arrayOf(
        TextosChamadaCasa.FALTA_VALOR, TextosChamadaCasa.FALTA_CONFIRMAR_TOTAL, TextosChamadaCasa.FALTA_RESPONSAVEL,
        TextosChamadaCasa.BUSCA_DATA_INVALIDA, TextosChamadaCasa.FALTA_ANTECEDENCIA, TextosChamadaCasa.FALTA_DURACAO,
        TextosChamadaCasa.RECADO_LONGO, TextosChamadaCasa.BUSCA_SEM_CASA,
    )

    /** Escolhe data e hora nos seletores do sistema que o toque abre. `mes` é de 1 a 12. */
    private fun escolherNosSeletores(ano: Int, mes: Int, dia: Int, hora: Int, minuto: Int) {
        rule.waitForIdle()
        val data = org.robolectric.shadows.ShadowDialog.getShownDialogs().filterIsInstance<android.app.DatePickerDialog>().last()
        data.updateDate(ano, mes - 1, dia)
        data.getButton(android.app.AlertDialog.BUTTON_POSITIVE).performClick()
        rule.waitForIdle()
        val horaDialogo = org.robolectric.shadows.ShadowDialog.getShownDialogs().filterIsInstance<android.app.TimePickerDialog>().last()
        horaDialogo.updateTime(hora, minuto)
        horaDialogo.getButton(android.app.AlertDialog.BUTTON_POSITIVE).performClick()
        rule.waitForIdle()
    }

    private fun preencherTudo() {
        rule.onNodeWithTag("folha-valor").performTextInput("180")
        rule.onNodeWithTag("folha-confirmar-total").performClick()
    }

    // ---- a explicação no topo ----

    @Test
    fun `a explicacao do iOS aparece no topo da folha`() {
        montar()

        rule.onNodeWithText("O mesmo valor total e o mesmo horário vão para cada profissional selecionado.").assertIsDisplayed()
        assertEquals(
            "O mesmo valor total e o mesmo horário vão para cada profissional selecionado.",
            TextosChamadaCasa.BUSCA_FOLHA_EXPLICACAO,
        )
    }

    // ---- o que falta, o tempo todo, com o botão desligado ----

    @Test
    fun `antes de qualquer toque a folha ja diz o que falta e o botao esta desligado`() {
        montar()

        faltaNaTela(TextosChamadaCasa.FALTA_VALOR)
        enviar().assertIsNotEnabled()
    }

    @Test
    fun `o motivo acompanha a pessoa preenchendo, um de cada vez, e some quando nada falta`() {
        montar()
        faltaNaTela(TextosChamadaCasa.FALTA_VALOR)

        rule.onNodeWithTag("folha-valor").performTextInput("180")
        faltaNaTela(TextosChamadaCasa.FALTA_CONFIRMAR_TOTAL)
        semMotivo(TextosChamadaCasa.FALTA_VALOR)
        enviar().assertIsNotEnabled()

        rule.onNodeWithTag("folha-confirmar-total").performClick()
        semMotivo(*todosOsMotivos)
        enviar().assertIsEnabled()
    }

    @Test
    fun `mudar o valor depois de confirmar o total volta a pedir a confirmacao, ao vivo`() {
        montar()
        preencherTudo()
        enviar().assertIsEnabled()

        rule.onNodeWithTag("folha-valor").performTextInput("5")

        faltaNaTela(TextosChamadaCasa.FALTA_CONFIRMAR_TOTAL)
        enviar().assertIsNotEnabled()
    }

    @Test
    fun `esvaziar o valor, o responsavel, o horario ou estourar o recado traz o motivo na hora`() {
        montar()
        preencherTudo()

        rule.onNodeWithTag("folha-responsavel").performScrollTo().performTextClearance()
        faltaNaTela(TextosChamadaCasa.FALTA_RESPONSAVEL)
        enviar().assertIsNotEnabled()
        rule.onNodeWithTag("folha-responsavel").performScrollTo().performTextInput("Lia")
        semMotivo(*todosOsMotivos)
        enviar().assertIsEnabled()

        // Início, pelos seletores: 16/11 às 13:00 (Brasília) fica a menos de 2 h do relógio da folha (16/11 12:00 em Brasília).
        rule.onNodeWithTag("folha-inicio").performScrollTo().performClick()
        escolherNosSeletores(2026, 11, 16, 13, 0)
        faltaNaTela(TextosChamadaCasa.FALTA_ANTECEDENCIA)
        enviar().assertIsNotEnabled()
        rule.onNodeWithTag("folha-inicio").performScrollTo().performClick()
        escolherNosSeletores(2026, 11, 17, 12, 0)
        // Término a 1 h do início: turno curto demais.
        rule.onNodeWithTag("folha-fim").performScrollTo().performClick()
        escolherNosSeletores(2026, 11, 17, 13, 0)
        faltaNaTela(TextosChamadaCasa.FALTA_DURACAO)
        enviar().assertIsNotEnabled()
        rule.onNodeWithTag("folha-fim").performScrollTo().performClick()
        escolherNosSeletores(2026, 11, 17, 16, 0)
        semMotivo(*todosOsMotivos)

        rule.onNodeWithTag("folha-recado").performScrollTo().performTextInput("x".repeat(301))
        faltaNaTela(TextosChamadaCasa.RECADO_LONGO)
        enviar().assertIsNotEnabled()
        rule.onNodeWithTag("folha-recado").performScrollTo().performTextClearance()
        enviar().assertIsEnabled()
    }

    @Test
    fun `a mensagem antiga nao fica, corrigido o campo o motivo troca sem precisar tocar no botao`() {
        montar()
        rule.onNodeWithTag("folha-valor").performTextInput("180")
        faltaNaTela(TextosChamadaCasa.FALTA_CONFIRMAR_TOTAL)

        rule.onNodeWithTag("folha-confirmar-total").performClick()

        semMotivo(TextosChamadaCasa.FALTA_CONFIRMAR_TOTAL)
        assertEquals(0, enviadas.size)
    }

    // ---- o botão ----

    @Test
    fun `o botao desligado nao envia e o ligado envia uma vez, com o trabalho e o recado`() {
        montar()
        enviar().performClick()
        assertEquals(0, enviadas.size)

        preencherTudo()
        rule.onNodeWithTag("folha-recado").performScrollTo().performTextInput("Traga avental")
        enviar().assertIsEnabled().performClick()

        assertEquals(1, enviadas.size)
        val (trabalho, recado) = enviadas.single()
        assertEquals(18000L, trabalho.valorCentavos)
        assertEquals("Traga avental", recado)
    }

    @Test
    fun `sem casa o aviso de sem casa vale e o botao fica desligado`() {
        montar { it.copy(casa = null) }
        preencherTudo()

        // O aviso do alto da folha vale; a mesma frase não se repete junto do botão.
        rule.onAllNodesWithText(TextosChamadaCasa.BUSCA_SEM_CASA).assertCountEquals(1)
        enviar().assertIsNotEnabled()
    }

    @Test
    fun `enviando, o botao fica desligado e o motivo some, mesmo faltando algo`() {
        montar { it.copy(enviando = true) }

        enviar().assertIsNotEnabled()
        semMotivo(*todosOsMotivos)
    }

    @Test
    fun `com tudo certo, enviando o botao desliga e volta a ligar quando o envio termina`() {
        montar()
        preencherTudo()
        enviar().assertIsEnabled()

        estado = estado.copy(enviando = true)
        enviar().assertIsNotEnabled()
        semMotivo(*todosOsMotivos)

        estado = estado.copy(enviando = false)
        enviar().assertIsEnabled()
    }

    @Test
    fun `depois do envio, com o resultado de cada pessoa, nao ha mais motivo nem botao de enviar`() {
        montar { it.copy(resultadosDaChamada = mapOf("p1" to ResultadoDaChamadaDaBusca.NaoEnviada)) }

        semMotivo(*todosOsMotivos)
        rule.onAllNodesWithText(TextosChamadaCasa.BUSCA_FOLHA_ENVIAR).assertCountEquals(0)
    }
}
