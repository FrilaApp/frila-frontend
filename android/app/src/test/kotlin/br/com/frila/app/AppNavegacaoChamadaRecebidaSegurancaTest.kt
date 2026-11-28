package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.BloqueioDto
import br.com.frila.core.rede.ChamadaDetalheDto
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ProtocoloDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.chamadas.profissional.ChamadaRecebidaViewModel
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.suporte.BloqueioDeAlvoViewModel
import br.com.frila.feature.suporte.DenunciaViewModel
import br.com.frila.feature.suporte.TextosSuporte
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * GpINsbhj (CD-RF12): na chamada recebida o profissional denuncia e bloqueia quem chamou. "Denunciar" leva o id da chamada à
 * rota de denúncia (0.2.71); bloquear a casa tira o rodapé de aceitar e recusar, como no iOS.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h1600dp")
class AppNavegacaoChamadaRecebidaSegurancaTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val bloqueios = mutableListOf<Pair<String, String>>()
    private var falhaDoBloqueio: Exception? = null
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    private fun detalhe(id: String): ChamadaDetalheDto = ClienteSupabase.jsonFrila.decodeFromString(
        """{"id":"$id","vaga_id":"v","profissional_id":"p","estabelecimento_id":"c","estado":"aberta","expira_em":"2099-01-01T12:00:00Z","criada_em":"2026-11-16T20:00:00Z","funcao":{"id":"f","nome":"Garçom","categoria":"salao"},"inicio_em":"2099-01-02T22:00:00Z","fim_em":"2099-01-03T02:00:00Z","valor_centavos":18000,"outra_parte":{"id":"casa-7","tipo":"estabelecimento","nome":"Bistrô Aurora","reputacao":{"positivas":1,"total":1,"turnos_considerados":1,"turnos_realizados":1}},"regiao_administrativa":"Plano Piloto","inclui_refeicao":false,"inclui_transporte":false,"exige_material_proprio":false}""",
    )

    private fun montar() {
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single<ArmazenamentoDeSessao> { sessao }
                        viewModel { entrada }
                        viewModel { (chamadaId: String) ->
                            ChamadaRecebidaViewModel(
                                chamadaId = chamadaId,
                                detalhar = { id -> detalhe(id) },
                                responder = { _, _, _ -> error("não deveria responder") },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        viewModel { (alvoTipo: TipoDeAlvo, alvoId: String, turnoId: String?, chamadaId: String?, fotoId: String?) ->
                            DenunciaViewModel(
                                alvoTipo = alvoTipo,
                                alvoId = alvoId,
                                denunciar = { ProtocoloDto("6f1c2a4e-1111-2222-3333-444455556666", "denuncia", "2026-11-10T12:00:00Z", "2026-11-17") },
                                bloquear = { tipo, id -> BloqueioDto(tipo, id, "2026-11-10T12:00:00Z") },
                                turnoId = turnoId,
                                chamadaId = chamadaId,
                                fotoId = fotoId,
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        viewModel { (alvoTipo: TipoDeAlvo, alvoId: String) ->
                            BloqueioDeAlvoViewModel(
                                alvoTipo = alvoTipo,
                                alvoId = alvoId,
                                bloquear = { tipo, id ->
                                    bloqueios += tipo to id
                                    falhaDoBloqueio?.let { throw it }
                                    BloqueioDto(tipo, id, "2026-11-10T12:00:00Z")
                                },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                    },
                )
            }) {
                nav = rememberNavController()
                AppNavegacao(
                    armazenamentoDeSessao = sessao,
                    monitorDeConectividade = MonitorDeConectividadeFalso(),
                    navController = nav,
                    chamadaDiretaHabilitada = true,
                    buscaProfissionaisHabilitada = true,
                )
            }
        }
        rule.runOnIdle { nav.navigate(RotasChamadaProfissional.recebida("chamada-7")) }
        rule.waitUntil(5_000) { rule.onAllNodesWithTag("aceitar-chamada").fetchSemanticsNodes().isNotEmpty() }
    }

    @Test
    fun `a chamada recebida oferece Denunciar e Bloquear quem chamou`() {
        montar()

        rule.onNodeWithTag("chamada-denunciar").performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag("chamada-bloquear").performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `Denunciar abre a denuncia da casa com o id da chamada, sem turno`() {
        montar()

        rule.onNodeWithTag("chamada-denunciar").performScrollTo().performClick()

        rule.runOnIdle {
            assertEquals(Rotas.DENUNCIA, nav.currentDestination?.route)
            val argumentos = nav.currentBackStackEntry?.arguments
            assertEquals("estabelecimento", argumentos?.getString("alvoTipo"))
            assertEquals("casa-7", argumentos?.getString("alvoId"))
            assertEquals("chamada-7", argumentos?.getString("chamadaId"))
            assertNull(argumentos?.getString("turnoId"))
        }
    }

    @Test
    fun `Bloquear e confirmar bloqueia a casa, mostra o aviso e tira aceitar e recusar`() {
        montar()

        rule.onNodeWithTag("chamada-bloquear").performScrollTo().performClick()
        rule.onNodeWithText(TextosSuporte.BLOQUEIO_CONFIRMAR).performClick()

        rule.waitUntil(5_000) { rule.onAllNodesWithTag("chamada-bloqueado").fetchSemanticsNodes().isNotEmpty() }
        assertEquals(listOf("estabelecimento" to "casa-7"), bloqueios)
        rule.onNodeWithText(TextosSuporte.BLOQUEOU_ESTABELECIMENTO).assertIsDisplayed()
        rule.onAllNodesWithTag("aceitar-chamada").assertCountEquals(0)
        rule.onAllNodesWithTag("recusar-chamada").assertCountEquals(0)
    }

    @Test
    fun `cancelar a confirmacao nao bloqueia e o rodape continua`() {
        montar()

        rule.onNodeWithTag("chamada-bloquear").performScrollTo().performClick()
        rule.onNodeWithText(TextosSuporte.CANCELAR).performClick()

        assertEquals(emptyList<Pair<String, String>>(), bloqueios)
        rule.onNodeWithTag("aceitar-chamada").assertIsDisplayed()
    }

    @Test
    fun `se o bloqueio falha, mostra o erro e mantem a chamada respondivel`() {
        falhaDoBloqueio = ErroDaApi(CodigoErroAPI.SEM_REDE, "sem_rede", null, "x")
        montar()

        rule.onNodeWithTag("chamada-bloquear").performScrollTo().performClick()
        rule.onNodeWithText(TextosSuporte.BLOQUEIO_CONFIRMAR).performClick()

        rule.waitUntil(5_000) { rule.onAllNodesWithTag("chamada-erro-bloqueio").fetchSemanticsNodes().isNotEmpty() }
        rule.onNodeWithText(TextosSuporte.ERRO_SEM_REDE).assertIsDisplayed()
        rule.onNodeWithTag("aceitar-chamada").assertIsDisplayed()
        rule.onAllNodesWithTag("chamada-bloqueado").assertCountEquals(0)
    }
}
