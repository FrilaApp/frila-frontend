package br.com.frila.app

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.performClick
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.LeituraDeLocalizacao
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoAutenticacao
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.StatusConectividade
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.turnos.CheckinViewModel
import br.com.frila.feature.turnos.EstadoMeusTurnos
import br.com.frila.feature.turnos.ItemTurno
import br.com.frila.feature.turnos.MeusTurnosViewModel
import br.com.frila.feature.turnos.StatusMeusTurnos
import br.com.frila.feature.vagas.feed.EstadoFeed
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.StatusFeed
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import io.mockk.every
import io.mockk.mockk
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.Collections
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * C0-7: na rota de Meus turnos, cada turno tem o seu [CheckinViewModel], com o ponto da vaga dele. Antes,
 * todos os cartões dividiam um só (e sem ponto), e o toque no 2º registrava no 1º.
 */
@RunWith(RobolectricTestRunner::class)
// Tela alta: os dois cartões cabem nela e o toque chega ao 2º.
@Config(sdk = [35], application = android.app.Application::class, qualifiers = "w411dp-h2400dp")
class AppNavegacaoCheckinPorTurnoTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private val pontoT1 = Coordenada(latitude = -15.7942, longitude = -47.8822)
    private val pontoT2 = Coordenada(latitude = -15.8350, longitude = -48.0560)

    private fun turno(id: String, ponto: Coordenada, inicio: Instant) = ItemTurno(
        turnoId = id,
        posicaoId = "posicao-$id",
        inicio = inicio,
        fim = inicio.plus(4, ChronoUnit.HOURS),
        funcaoNome = "Faxina residencial",
        estabelecimentoNome = "Casa $id",
        dataHorarioFormatado = "hoje",
        valorFormatado = "R$ 150,00",
        estado = "confirmada",
        pontoDaVaga = ponto,
    )

    /** O aparelho está no ponto da vaga de quem receber a leitura, com precisão boa. */
    private fun provedorNoPonto(ponto: Coordenada?) = object : ProvedorDeLocalizacao {
        override suspend fun obterCoordenadaAtual(): Coordenada? = ponto
        override suspend fun lerParaCheckin(): LeituraDeLocalizacao? =
            ponto?.let { LeituraDeLocalizacao(coordenada = it, precisaoMetros = 10f, simulada = false) }
        override fun temPermissaoDeLocalizacao(): Boolean = true
        override fun isGpsAtivado(): Boolean = true
    }

    @Test
    fun `dois turnos na mesma tela tem controladores diferentes, cada um com o seu ponto, e o toque registra no turno certo`() {
        val armazenamento = mockk<ArmazenamentoDeSessao>(relaxed = true)
        every { armazenamento.estaAutenticado() } returns true
        every { armazenamento.isBiometriaAtivada() } returns false
        val inicio = Instant.now().plus(20, ChronoUnit.MINUTES) // dentro da janela do check-in
        val turnosViewModel = mockk<MeusTurnosViewModel>(relaxed = true)
        every { turnosViewModel.estado } returns MutableStateFlow(
            EstadoMeusTurnos(
                status = StatusMeusTurnos.SUCESSO,
                agendados = listOf(turno("t1", pontoT1, inicio), turno("t2", pontoT2, inicio.plus(5, ChronoUnit.MINUTES))),
            ),
        )
        // A rota inicial com sessão é o feed: ele só precisa existir.
        val feedViewModel = mockk<FeedVagasViewModel>(relaxed = true)
        every { feedViewModel.estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.SUCESSO))
        val criados = Collections.synchronizedList(mutableListOf<Pair<String, Coordenada?>>())
        val corpos = Collections.synchronizedList(mutableListOf<String>())
        val engine = MockEngine { pedido ->
            corpos += (pedido.body as TextContent).text
            respond(
                content = """{"turno_id":"t2","tipo":"geolocalizado","verificacao":"verificado","registrado_em":"2026-11-17T01:30:00Z","distancia_m":0}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servicoTurnos = ServicoTurnos(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))
        lateinit var navController: NavHostController

        rule.setContent {
            navController = rememberNavController()
            KoinApplication(application = {
                modules(
                    module {
                        single { mockk<ServicoAutenticacao>(relaxed = true) }
                        single { armazenamento }
                        viewModel { EntradaViewModel(get()) }
                        viewModel { feedViewModel }
                        viewModel { turnosViewModel }
                        viewModel { (turnoId: String, ponto: Coordenada?) ->
                            criados += turnoId to ponto
                            CheckinViewModel(turnoId, ponto, servicoTurnos, provedorNoPonto(ponto))
                        }
                    },
                )
            }) {
                AppNavegacao(
                    armazenamentoDeSessao = armazenamento,
                    monitorDeConectividade = MonitorDeConectividadeFalso(StatusConectividade.CONECTADO),
                    navController = navController,
                    servicoMembros = null,
                )
            }
        }
        rule.waitForIdle()
        rule.runOnUiThread { navController.navigate(Rotas.MEUS_TURNOS) }
        rule.waitForIdle()

        val botoes = rule.onAllNodesWithText("Fazer check-in")
        botoes[1].performClick()
        rule.waitUntil(timeoutMillis = 5_000) { corpos.isNotEmpty() }

        // Um controlador por turno, cada um com o ponto da vaga dele.
        assertEquals(setOf("t1" to pontoT1, "t2" to pontoT2), criados.toSet())
        // O toque no 2º cartão registra no t2, com a distância medida até o ponto dele.
        val corpo = corpos.single()
        assertTrue(corpo, corpo.contains("\"turno_id\":\"t2\""))
        assertTrue(corpo, Regex("\"distancia_m\":\\d+").containsMatchIn(corpo))
    }
}
