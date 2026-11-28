package br.com.frila.feature.conta

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão GJ4E4guN (item 297): o campo do relato da contestação (da suspensão e do despacho) tem o exemplo DENTRO do campo vazio e avisa quando o mínimo foi atendido, como o iOS
 * (`TextosContaSuspensa.swift:13,16`, `TextosPorQueReceboVagas.swift:32,34`). Antes, o campo passava só o apoio e nunca o exemplo. Os textos esperados são os do iOS, escritos aqui por
 * extenso. Fora: o contador (#1258).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h1600dp")
class ContestacaoExemploEMinimoTest {

    @get:Rule
    val rule = createComposeRule()

    private val exemploDaSuspensao = "Descreva seus argumentos para contestar a suspensão…"
    private val exemploDoDespacho = "Conte qual vaga esperava receber e por quê…"
    private val dicaDeDez = "Mínimo de 10 caracteres."
    private val atendido = "Mínimo de caracteres atendido"

    private fun contar(texto: String) = rule.onAllNodesWithText(texto).fetchSemanticsNodes().size

    private fun suspensao(relato: String) = rule.setContent {
        FrilaTheme {
            TelaContaSuspensa(emailSuporte = "suporte@frilabr.com", aoContatarSuporte = {}, aoSair = {}, motivo = "Faltas", desde = "10/11/2026") {
                SecaoContestacaoDaSuspensao(EstadoContaSuspensa(formularioAberto = true, relato = relato), "suporte@frilabr.com", AcoesContestacaoDaSuspensao())
            }
        }
    }

    private fun despacho(relato: String) = rule.setContent {
        FrilaTheme { ConteudoContestarDespacho(EstadoContestarDespacho(relato = relato), aoMudarRelato = {}, aoEnviar = {}, aoVoltar = {}) }
    }

    // --- contestação da suspensão -------------------------------------------------------------------------------------------------

    @Test
    fun suspensao_campoVazioMostraOExemploDentroDoCampo() {
        suspensao("")

        rule.onNodeWithText(exemploDaSuspensao).assertExists()
    }

    @Test
    fun suspensao_campoVazioMantemADicaDeDezCaracteres() {
        suspensao("")

        rule.onNodeWithText(dicaDeDez).assertExists()
        assertEquals(0, contar(atendido))
    }

    @Test
    fun suspensao_comRelatoValidoAvisaQueOMinimoFoiAtendido() {
        suspensao("Não reconheço a falta.")

        rule.onNodeWithText(atendido).assertExists()
        assertEquals(0, contar(dicaDeDez))
    }

    @Test
    fun suspensao_comRelatoPreenchidoOExemploSome() {
        suspensao("Não reconheço a falta.")

        assertEquals(0, contar(exemploDaSuspensao))
    }

    @Test
    fun suspensao_nove_caracteres_aindaNaoAtende() {
        suspensao("123456789")

        rule.onNodeWithText(dicaDeDez).assertExists()
        assertEquals(0, contar(atendido))
    }

    @Test
    fun suspensao_dez_caracteres_exatos_atende() {
        suspensao("1234567890")

        rule.onNodeWithText(atendido).assertExists()
        assertEquals(0, contar(dicaDeDez))
    }

    @Test
    fun suspensao_espacosNaoContam_dezEspacosNaoAtende() {
        suspensao("          ")

        assertEquals(0, contar(atendido))
        rule.onNodeWithText(dicaDeDez).assertExists()
    }

    // --- pedido de revisão do despacho ---------------------------------------------------------------------------------------------

    @Test
    fun despacho_campoVazioMostraOExemploDentroDoCampo() {
        despacho("")

        rule.onNodeWithText(exemploDoDespacho).assertExists()
    }

    @Test
    fun despacho_campoVazioMantemADicaDeDezCaracteres() {
        despacho("")

        rule.onNodeWithText(dicaDeDez).assertExists()
        assertEquals(0, contar(atendido))
    }

    @Test
    fun despacho_comRelatoValidoAvisaQueOMinimoFoiAtendido() {
        despacho("Esperava a vaga de sábado.")

        rule.onNodeWithText(atendido).assertExists()
        assertEquals(0, contar(dicaDeDez))
    }

    @Test
    fun despacho_comRelatoPreenchidoOExemploSome() {
        despacho("Esperava a vaga de sábado.")

        assertEquals(0, contar(exemploDoDespacho))
    }

    @Test
    fun despacho_nove_caracteres_aindaNaoAtende() {
        despacho("123456789")

        rule.onNodeWithText(dicaDeDez).assertExists()
        assertEquals(0, contar(atendido))
    }

    @Test
    fun despacho_dez_caracteres_exatos_atende() {
        despacho("1234567890")

        rule.onNodeWithText(atendido).assertExists()
        assertEquals(0, contar(dicaDeDez))
    }

    @Test
    fun despacho_espacosNaoContam_dezEspacosNaoAtende() {
        despacho("          ")

        assertEquals(0, contar(atendido))
        rule.onNodeWithText(dicaDeDez).assertExists()
    }

    @Test
    fun osDoisExemplosSaoDiferentes() {
        assertEquals(false, exemploDaSuspensao == exemploDoDespacho)
    }
}
