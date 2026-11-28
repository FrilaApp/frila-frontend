package br.com.frila.feature.vagas.detalhe

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.FuncaoDto
import br.com.frila.core.rede.InclusosDto
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.VagaAbertaDto
import java.util.TimeZone
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão Gw2AupEb (item 282): com o início (ou o fim) ilegível, ou com o fim igual ou anterior ao início, as telas do resultado da candidatura NÃO inventam o
 * período: escondem a linha da data, do horário e da duração, e nunca mostram duração negativa. Antes, o início ilegível virava `Instant.now()` (a data de hoje
 * e a hora do relógio) e a duração saía negativa ("das 07:58 às 21:00 (-154 h -58 min de turno)"); o fim ilegível virava início mais 6 h.
 *
 * O iOS não trata isso nessas telas: a vaga nem é decodificada com a data ilegível (`DTOsContrato.swift:863-864`) nem com o fim que não é posterior ao início
 * (`ObjetosDeValor.swift:107-111`, `try Periodo(inicio:fim:)` em `DTOsContrato.swift:899-902`). No Android as telas recebem texto, então o que sobra é esconder a linha.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h2400dp")
class ResultadoDaCandidaturaPeriodoIlegivelTest {

    @get:Rule
    val compose = createComposeRule()

    private lateinit var fusoOriginal: TimeZone

    @Before
    fun guardarOFusoDoAparelho() {
        fusoOriginal = TimeZone.getDefault()
        TimeZone.setDefault(TimeZone.getTimeZone("UTC"))
    }

    @After
    fun restaurarOFusoDoAparelho() {
        TimeZone.setDefault(fusoOriginal)
    }

    private fun vaga(inicioEm: String, fimEm: String) = VagaAbertaDto(
        id = "vaga-1",
        funcao = FuncaoDto(id = "f1", nome = "Garçom", categoria = "salao"),
        estabelecimento = PerfilPublicoDto(
            id = "est-1",
            tipo = "estabelecimento",
            nome = "Restaurante Panelinha",
            reputacao = ReputacaoDto(30, 28, null, 28, 28),
        ),
        inicioEm = inicioEm,
        fimEm = fimEm,
        local = "CLN 402 Bloco B",
        regiaoAdministrativa = "Asa Norte",
        distanciaKm = 2.5,
        valorCentavos = 18000,
        posicoesAbertas = 1,
        inclusos = InclusosDto(incluiRefeicao = true, incluiTransporte = false, exigeMaterialProprio = false),
        modo = "urgencia",
    )

    private enum class Tela { CONFIRMADO, CONFLITO }

    private fun montar(tela: Tela, vaga: VagaAbertaDto) {
        compose.setContent {
            FrilaTheme {
                when (tela) {
                    Tela.CONFIRMADO -> TelaTurnoConfirmado(vaga = vaga, aoVerMeusTurnos = {}, aoVoltarAoFeed = {})
                    Tela.CONFLITO -> TelaConflitoHorario(vaga = vaga, aoVoltarAoFeed = {})
                }
            }
        }
    }

    private fun semLinhaDoPeriodo(tela: Tela, vaga: VagaAbertaDto) {
        montar(tela, vaga)
        // Nem o horário, nem a duração, nem a data inventada: a linha inteira some.
        compose.onAllNodes(hasText("de turno", substring = true)).assertCountEquals(0)
        compose.onAllNodes(hasText("das ", substring = true)).assertCountEquals(0)
        compose.onAllNodes(hasText("de 20", substring = true)).assertCountEquals(0)
        compose.onAllNodes(SemanticsMatcher("texto com duração negativa") { no ->
            no.config.getOrNull(SemanticsProperties.Text)?.any { it.text.contains("-") && it.text.contains("min") } == true
        }).assertCountEquals(0)
        // O resto do resumo segue na tela.
        compose.onNodeWithText("Garçom, Restaurante Panelinha").assertExists()
        compose.onNodeWithText("CLN 402 Bloco B, Asa Norte").assertExists()
    }

    private val fimValido = "2026-11-22T00:00:00Z"

    @Test
    fun confirmado_inicioIlegivelEscondeALinhaDoPeriodo() = semLinhaDoPeriodo(Tela.CONFIRMADO, vaga("isto-nao-e-uma-data", fimValido))

    @Test
    fun conflito_inicioIlegivelEscondeALinhaDoPeriodo() = semLinhaDoPeriodo(Tela.CONFLITO, vaga("isto-nao-e-uma-data", fimValido))

    @Test
    fun confirmado_inicioVazioEscondeALinhaDoPeriodo() = semLinhaDoPeriodo(Tela.CONFIRMADO, vaga("", fimValido))

    @Test
    fun conflito_inicioVazioEscondeALinhaDoPeriodo() = semLinhaDoPeriodo(Tela.CONFLITO, vaga("", fimValido))

    @Test
    fun confirmado_fimIlegivelNaoInventaUmFimDeSeisHoras() = semLinhaDoPeriodo(Tela.CONFIRMADO, vaga("2026-11-21T18:00:00Z", "isto-nao-e-uma-data"))

    @Test
    fun conflito_fimIlegivelNaoInventaUmFimDeSeisHoras() = semLinhaDoPeriodo(Tela.CONFLITO, vaga("2026-11-21T18:00:00Z", "isto-nao-e-uma-data"))

    @Test
    fun confirmado_fimAnteriorAoInicioNuncaMostraDuracaoNegativa() = semLinhaDoPeriodo(Tela.CONFIRMADO, vaga("2026-11-22T00:00:00Z", "2026-11-21T18:00:00Z"))

    @Test
    fun conflito_fimAnteriorAoInicioNuncaMostraDuracaoNegativa() = semLinhaDoPeriodo(Tela.CONFLITO, vaga("2026-11-22T00:00:00Z", "2026-11-21T18:00:00Z"))

    @Test
    fun confirmado_fimIgualAoInicioNaoMostraTurnoDeZeroHoras() = semLinhaDoPeriodo(Tela.CONFIRMADO, vaga("2026-11-21T18:00:00Z", "2026-11-21T18:00:00Z"))

    @Test
    fun conflito_fimIgualAoInicioNaoMostraTurnoDeZeroHoras() = semLinhaDoPeriodo(Tela.CONFLITO, vaga("2026-11-21T18:00:00Z", "2026-11-21T18:00:00Z"))

    @Test
    fun confirmado_comOPeriodoLegivelALinhaContinuaNaTela() {
        montar(Tela.CONFIRMADO, vaga("2026-11-21T18:00:00Z", fimValido))
        compose.onNodeWithText("Sábado, 21 de novembro de 2026\ndas 15:00 às 21:00 (6 h de turno)").assertExists()
    }

    @Test
    fun conflito_comOPeriodoLegivelALinhaContinuaNaTela() {
        montar(Tela.CONFLITO, vaga("2026-11-21T18:00:00Z", fimValido))
        compose.onNodeWithText("Sábado, 21 de novembro de 2026\ndas 15:00 às 21:00 (6 h de turno)").assertExists()
    }
}
