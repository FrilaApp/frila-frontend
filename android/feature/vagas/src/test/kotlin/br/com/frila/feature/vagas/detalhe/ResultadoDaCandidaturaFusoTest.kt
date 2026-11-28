package br.com.frila.feature.vagas.detalhe

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
 * Cartão L0fQaRbF (item 276): a data, o período e a duração do resultado da candidatura (turno confirmado e conflito de horário) no fuso de Brasília.
 * Os testes antigos de cada tela não conferiam o período nem a duração, então trocar o fuso por UTC ou quebrar a duração com minutos passava. O fuso do
 * aparelho é forçado (UTC, depois Tóquio) e restaurado: o que vale é o fuso de São Paulo que o código fixa, e não o da máquina que roda o teste.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h2400dp")
class ResultadoDaCandidaturaFusoTest {

    @get:Rule
    val compose = createComposeRule()

    private lateinit var fusoOriginal: TimeZone

    @Before
    fun guardarOFusoDoAparelho() {
        fusoOriginal = TimeZone.getDefault()
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

    private fun confere(tela: Tela, vaga: VagaAbertaDto, periodo: String, duracao: String) {
        montar(tela, vaga)
        // A linha do dado junta o período e a duração num só texto, separados por um espaço.
        compose.onNodeWithText("$periodo $duracao").assertExists()
    }

    // 18:00Z a 00:00Z do dia seguinte são 15:00 a 21:00 em Brasília (UTC-3, sem horário de verão), sábado, 21 de novembro.
    private val sabadoTarde = vaga("2026-11-21T18:00:00Z", "2026-11-22T00:00:00Z")
    private val periodoSabadoTarde = "Sábado, 21 de novembro de 2026\ndas 15:00 às 21:00"

    private fun comAparelhoEm(id: String) = TimeZone.setDefault(TimeZone.getTimeZone(id))

    @Test
    fun confirmado_periodoEDuracaoNoFusoDeSaoPauloComOAparelhoEmUtc() {
        comAparelhoEm("UTC")
        confere(Tela.CONFIRMADO, sabadoTarde, periodoSabadoTarde, "(6 h de turno)")
    }

    @Test
    fun conflito_periodoEDuracaoNoFusoDeSaoPauloComOAparelhoEmUtc() {
        comAparelhoEm("UTC")
        confere(Tela.CONFLITO, sabadoTarde, periodoSabadoTarde, "(6 h de turno)")
    }

    @Test
    fun confirmado_omesmoTextoComOAparelhoEmOutroFuso() {
        comAparelhoEm("Asia/Tokyo")
        confere(Tela.CONFIRMADO, sabadoTarde, periodoSabadoTarde, "(6 h de turno)")
    }

    @Test
    fun conflito_omesmoTextoComOAparelhoEmOutroFuso() {
        comAparelhoEm("Asia/Tokyo")
        confere(Tela.CONFLITO, sabadoTarde, periodoSabadoTarde, "(6 h de turno)")
    }

    // 01:30Z de domingo é 22:30 de sábado em Brasília: a data é a de Brasília, e não a do UTC.
    private val viraODia = vaga("2026-11-22T01:30:00Z", "2026-11-22T05:00:00Z")
    private val periodoViraODia = "Sábado, 21 de novembro de 2026\ndas 22:30 às 02:00"

    @Test
    fun confirmado_aDataEDeBrasiliaEntrePassaDaMeiaNoiteDoUtc() {
        comAparelhoEm("UTC")
        confere(Tela.CONFIRMADO, viraODia, periodoViraODia, "(3 h 30 min de turno)")
    }

    @Test
    fun conflito_aDataEDeBrasiliaEntrePassaDaMeiaNoiteDoUtc() {
        comAparelhoEm("UTC")
        confere(Tela.CONFLITO, viraODia, periodoViraODia, "(3 h 30 min de turno)")
    }

    @Test
    fun confirmado_duracaoComMinutosMostraHorasEMinutos() {
        comAparelhoEm("UTC")
        confere(Tela.CONFIRMADO, vaga("2026-11-21T18:00:00Z", "2026-11-22T00:30:00Z"), "Sábado, 21 de novembro de 2026\ndas 15:00 às 21:30", "(6 h 30 min de turno)")
    }

    @Test
    fun conflito_duracaoComMinutosMostraHorasEMinutos() {
        comAparelhoEm("UTC")
        confere(Tela.CONFLITO, vaga("2026-11-21T18:00:00Z", "2026-11-22T00:30:00Z"), "Sábado, 21 de novembro de 2026\ndas 15:00 às 21:30", "(6 h 30 min de turno)")
    }

    @Test
    fun confirmado_duracaoSemMinutosNaoMostraMinutos() {
        comAparelhoEm("UTC")
        confere(Tela.CONFIRMADO, vaga("2026-11-21T18:00:00Z", "2026-11-22T02:00:00Z"), "Sábado, 21 de novembro de 2026\ndas 15:00 às 23:00", "(8 h de turno)")
    }

    @Test
    fun conflito_duracaoSemMinutosNaoMostraMinutos() {
        comAparelhoEm("UTC")
        confere(Tela.CONFLITO, vaga("2026-11-21T18:00:00Z", "2026-11-22T02:00:00Z"), "Sábado, 21 de novembro de 2026\ndas 15:00 às 23:00", "(8 h de turno)")
    }
}
