package br.com.frila.feature.turnos

import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class SecaoACaminhoTest {

    @get:Rule
    val compose = createComposeRule()

    private val inicio = Instant.parse("2026-11-01T21:00:00Z")
    private val naJanela = inicio.minusSeconds(1800)

    private fun turno(aCaminhoEm: Instant? = null) = ItemTurno(
        turnoId = "t1", posicaoId = "p1", inicio = inicio, funcaoNome = "garçom", estabelecimentoNome = "Bar do Zé",
        dataHorarioFormatado = "01/11 18:00", valorFormatado = "R$ 160,00", estado = "confirmada", aCaminhoEm = aCaminhoEm,
    )

    private fun montar(turno: ItemTurno, agora: Instant = naJanela, avisando: Boolean = false, erro: String? = null, aoAvisar: () -> Unit = {}) {
        compose.setContent {
            FrilaTheme { SecaoACaminho(turno = turno, avisando = avisando, mensagemErro = erro, aoAvisar = aoAvisar, agora = agora) }
        }
    }

    @Test
    fun `na janela mostra o botao Estou a caminho, com alvo minimo, e um toque avisa`() {
        var toques = 0
        montar(turno()) { toques++ }

        compose.onNodeWithText(TextosACaminho.BOTAO).assertIsDisplayed().assertHeightIsAtLeast(FrilaMetricas.alvoMinimo).performClick()

        assertEquals(1, toques)
    }

    @Test
    fun `fora da janela nao mostra o botao`() {
        montar(turno(), agora = inicio.minusSeconds(4 * 3600))

        compose.onAllNodesWithText(TextosACaminho.BOTAO).assertCountEquals(0)
    }

    @Test
    fun `quem ja avisou ve a hora de Brasilia e nao ve o botao`() {
        // 20:30Z = 17:30 em Brasília (UTC-3).
        montar(turno(aCaminhoEm = Instant.parse("2026-11-01T20:30:00Z")))

        compose.onNodeWithText(TextosACaminho.avisou("17:30")).assertIsDisplayed()
        compose.onAllNodesWithText(TextosACaminho.BOTAO).assertCountEquals(0)
    }

    @Test
    fun `avisando desliga o botao e mostra o andamento`() {
        montar(turno(), avisando = true)

        compose.onNodeWithText(TextosACaminho.AVISANDO).assertIsDisplayed().assertIsNotEnabled()
    }

    @Test
    fun `a recusa aparece em texto do Frila e o botao continua`() {
        montar(turno(), erro = TextosACaminho.ERRO_SEM_REDE)

        compose.onNodeWithText(TextosACaminho.ERRO_SEM_REDE).assertIsDisplayed()
        compose.onNodeWithText(TextosACaminho.BOTAO).assertIsDisplayed()
    }

    // ---- na tela de Meus turnos: o botão só existe quando alguém passa o callback (a fiação é o L2-8) ----

    private val turnoJson = """
        {"id":"t1","posicao_id":"p1",
         "vaga":{"id":"v1","funcao":"garçom","local":"CLS 405","regiao_administrativa":"Plano Piloto","inicio_em":"2026-11-01T21:00:00Z","fim_em":"2026-11-02T03:00:00Z","valor_centavos":16000},
         "contraparte":{"id":"e1","tipo":"estabelecimento","nome":"Bar do Zé","reputacao":{"positivas":1,"total":1,"turnos_considerados":1,"turnos_realizados":1}},
         "a_caminho_em":null,"checkin_em":null,"checkin_tipo":null,"checkin_distancia_m":null,"checkin_confirmado_em":null,
         "checkout_em":null,"checkout_distancia_m":null,"verificacao":"pendente","valor_acordado_centavos":16000,"pode_avaliar":false,
         "estado":"confirmada","avaliacao":null,"cancelamento":null}
    """.trimIndent()

    private fun viewModel(): MeusTurnosViewModel {
        val cliente = ClienteSupabase(
            "https://frila.supabase.co", "chave-teste",
            engine = MockEngine { respond("[$turnoJson]", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) },
        )
        return MeusTurnosViewModel(
            ServicoTurnos(cliente),
            java.time.Clock.fixed(naJanela, java.time.ZoneOffset.UTC),
            CoroutineScope(Dispatchers.Default),
        )
    }

    private fun montarTela(vm: MeusTurnosViewModel, aoAvisarACaminho: ((ItemTurno) -> Unit)?) {
        compose.setContent {
            FrilaTheme {
                TelaMeusTurnos(
                    viewModel = vm,
                    criarCheckinViewModel = { t ->
                        CheckinViewModel(
                            turnoId = t.turnoId,
                            coordenadaDaVaga = null,
                            servicoTurnos = ServicoTurnos(
                                ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = MockEngine { respond("") }),
                            ),
                            provedorDeLocalizacao = object : ProvedorDeLocalizacao {
                                override suspend fun obterCoordenadaAtual(): Coordenada? = null
                                override fun temPermissaoDeLocalizacao(): Boolean = false
                                override fun isGpsAtivado(): Boolean = false
                            },
                        )
                    },
                    relogio = { naJanela },
                    aoAvisarACaminho = aoAvisarACaminho,
                )
            }
        }
    }

    @Test
    fun `na tela de turnos o botao so aparece com o callback e leva o turno ao tocar`() {
        runBlocking {
            val vm = viewModel()
            vm.carregar().join()
            val avisados = mutableListOf<String>()

            montarTela(vm) { avisados += it.turnoId }

            compose.onNodeWithText(TextosACaminho.BOTAO).performScrollTo().performClick()
            assertEquals(listOf("t1"), avisados)
        }
    }

    @Test
    fun `na tela de turnos sem o callback o botao nao aparece`() {
        runBlocking {
            val vm = viewModel()
            vm.carregar().join()

            montarTela(vm, aoAvisarACaminho = null)

            compose.onAllNodesWithText(TextosACaminho.BOTAO).assertCountEquals(0)
        }
    }
}
