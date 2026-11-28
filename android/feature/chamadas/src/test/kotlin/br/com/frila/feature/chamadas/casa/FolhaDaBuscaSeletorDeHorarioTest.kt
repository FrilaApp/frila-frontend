package br.com.frila.feature.chamadas.casa

import android.app.AlertDialog
import android.app.DatePickerDialog
import android.app.TimePickerDialog
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.assertIsDisplayed
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.MeuEstabelecimentoDto
import java.time.Instant
import java.util.TimeZone
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowDialog

/**
 * Cartão XI2du401 (item 261): na folha da busca, início e término são escolhidos pelos seletores de data e de hora do sistema, como o
 * iOS (`TelaBuscaDeProfissionais.swift:443-446`), e não digitados em "dd/mm/aaaa hh:mm". O horário é o de Brasília em qualquer fuso do
 * aparelho (aqui forçado a UTC e restaurado). A faixa do seletor fica livre, como no iOS: antecedência e duração são avisadas, não
 * impedidas.
 *
 * JUnit: nenhum método devolve valor (um `@Test` que devolve valor é ignorado).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1200dp")
class FolhaDaBuscaSeletorDeHorarioTest {

    @get:Rule
    val rule = createComposeRule()

    private val fusoDoAparelho = TimeZone.getDefault()

    @Before fun aparelhoEmUtc() = TimeZone.setDefault(TimeZone.getTimeZone("UTC"))

    @After fun devolveOFuso() = TimeZone.setDefault(fusoDoAparelho)

    private val agora = Instant.parse("2026-11-16T15:00:00Z")
    private val garcom = FuncaoDto("f1", "Garçom", "salao")
    private val casa = MeuEstabelecimentoDto(
        id = "c1", nome = "Bistrô Ipê", tipo = "restaurante", endereco = "SCS Quadra 2",
        regiaoAdministrativa = "Plano Piloto", ponto = CoordenadaDto(-15.79, -47.88), papel = "administrador",
    )
    private var estado by mutableStateOf(EstadoBusca())
    private val enviadas = mutableListOf<TrabalhoDaChamada>()

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
                    estado = estado, relogio = { agora }, aoChamar = { trabalho, _ -> enviadas += trabalho },
                    aoReenviar = {}, aoConfirmarJ7 = {}, aoFechar = {},
                )
            }
        }
    }

    private fun inicio() = rule.onNodeWithTag("folha-inicio").performScrollTo()
    private fun fim() = rule.onNodeWithTag("folha-fim").performScrollTo()

    /** O último seletor de [tipo] aberto: a própria folha também é um diálogo, então `getLatestDialog()` não serve. */
    private inline fun <reified T : android.app.Dialog> ultimo(): T = ShadowDialog.getShownDialogs().filterIsInstance<T>().last()

    /** Escolhe data e hora nos dois seletores que o toque abre (data primeiro, hora depois). `mes` é de 1 a 12. */
    private fun escolher(ano: Int, mes: Int, dia: Int, hora: Int, minuto: Int) {
        rule.waitForIdle()
        val data = ultimo<DatePickerDialog>()
        data.updateDate(ano, mes - 1, dia)
        data.getButton(AlertDialog.BUTTON_POSITIVE).performClick()
        rule.waitForIdle()
        val horaDialogo = ultimo<TimePickerDialog>()
        horaDialogo.updateTime(hora, minuto)
        horaDialogo.getButton(AlertDialog.BUTTON_POSITIVE).performClick()
        rule.waitForIdle()
    }

    private fun preencherOResto() {
        rule.onNodeWithTag("folha-valor").performScrollTo().performTextInput("180")
        rule.onNodeWithTag("folha-confirmar-total").performScrollTo().performClick()
    }

    // ---- o campo ----

    @Test
    fun `inicio e termino sao botoes com a data e a hora de Brasilia, sem a dica de formato digitado`() {
        montar()

        inicio().assert(hasText("17/11/2026 12:00"))
        fim().assert(hasText("17/11/2026 16:00"))
        rule.onNodeWithText(TextosChamadaCasa.INICIO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaCasa.TERMINO).performScrollTo().assertIsDisplayed()
        rule.onAllNodesWithText("dd/mm/aaaa", substring = true).assertCountEquals(0)
    }

    @Test
    fun `com horario no filtro da busca, a folha ja abre com ele`() {
        montar { it.copy(horario = HorarioDaBusca(Instant.parse("2026-11-20T22:00:00Z"), Instant.parse("2026-11-21T02:00:00Z"))) }

        inicio().assert(hasText("20/11/2026 19:00"))
        fim().assert(hasText("20/11/2026 23:00"))
    }

    // ---- os seletores ----

    @Test
    fun `tocar no inicio abre o seletor de data na data atual e depois o de hora, e o botao mostra o escolhido`() {
        montar()

        inicio().performClick()
        rule.waitForIdle()
        val data = ultimo<DatePickerDialog>()
        assertEquals(2026, data.datePicker.year)
        assertEquals(10, data.datePicker.month)
        assertEquals(17, data.datePicker.dayOfMonth)
        escolher(2026, 11, 18, 10, 30)

        inicio().assert(hasText("18/11/2026 10:30"))
    }

    @Test
    fun `o horario escolhido e o de Brasilia, qualquer que seja o fuso do aparelho, e vai no trabalho enviado`() {
        montar()
        preencherOResto()

        inicio().performClick()
        escolher(2026, 11, 18, 10, 30)
        fim().performClick()
        escolher(2026, 11, 18, 14, 30)
        rule.onNodeWithTag("folha-enviar").performScrollTo().assertIsEnabled().performClick()

        val trabalho = enviadas.single()
        // 10:30 em Brasília (UTC-3) é 13:30Z, mesmo com o aparelho em UTC.
        assertEquals(Instant.parse("2026-11-18T13:30:00Z"), trabalho.inicio)
        assertEquals(Instant.parse("2026-11-18T17:30:00Z"), trabalho.fim)
    }

    @Test
    fun `a faixa do seletor e livre, como no iOS, e o que falta avisa na hora`() {
        montar()
        preencherOResto()

        inicio().performClick()
        // O relógio da folha é 16/11 às 12:00 em Brasília: 13:00 do mesmo dia fica a 1 h, abaixo das 2 h de antecedência.
        escolher(2026, 11, 16, 13, 0)

        inicio().assert(hasText("16/11/2026 13:00"))
        rule.onNodeWithText(TextosChamadaCasa.FALTA_ANTECEDENCIA).performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag("folha-enviar").performScrollTo().assertIsNotEnabled()
    }

    @Test
    fun `termino antes do inicio ou turno fora de 2 a 16 horas avisa a duracao e desliga o botao`() {
        montar()
        preencherOResto()

        fim().performClick()
        escolher(2026, 11, 17, 13, 0)
        rule.onNodeWithText(TextosChamadaCasa.FALTA_DURACAO).performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag("folha-enviar").performScrollTo().assertIsNotEnabled()

        fim().performClick()
        escolher(2026, 11, 17, 16, 0)
        rule.onAllNodesWithText(TextosChamadaCasa.FALTA_DURACAO).assertCountEquals(0)
        rule.onNodeWithTag("folha-enviar").performScrollTo().assertIsEnabled()
    }

    @Test
    fun `nao ha mais mensagem de data invalida na folha, porque o seletor nao deixa digitar`() {
        montar()

        rule.onAllNodesWithText(TextosChamadaCasa.BUSCA_DATA_INVALIDA).assertCountEquals(0)
        inicio().performClick()
        escolher(2026, 12, 31, 23, 59)
        rule.onAllNodesWithText(TextosChamadaCasa.BUSCA_DATA_INVALIDA).assertCountEquals(0)
    }

    // ---- travas ----

    @Test
    fun `enviando, os dois botoes de horario ficam desabilitados`() {
        montar { it.copy(enviando = true) }

        inicio().assertIsNotEnabled()
        fim().assertIsNotEnabled()
    }

    @Test
    fun `depois do envio, com o resultado de cada pessoa, os horarios ficam travados`() {
        montar { it.copy(resultadosDaChamada = mapOf("p1" to ResultadoDaChamadaDaBusca.NaoEnviada)) }

        inicio().assertIsNotEnabled()
        fim().assertIsNotEnabled()
    }

    @Test
    fun `livre, os dois botoes de horario ficam habilitados`() {
        montar()

        inicio().assertIsEnabled()
        fim().assertIsEnabled()
    }
}
