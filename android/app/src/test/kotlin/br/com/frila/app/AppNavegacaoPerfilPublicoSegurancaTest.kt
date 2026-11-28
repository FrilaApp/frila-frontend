package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.BloqueioDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ProtocoloDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.chamadas.casa.PerfilPublicoViewModel
import br.com.frila.feature.chamadas.casa.TextosChamadaCasa
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
 * Q2HssEym (CD-RF12): a casa denuncia e bloqueia o profissional a partir do perfil público dele. "Denunciar" abre a denúncia do
 * perfil (sem turno nem chamada); bloquear tira o "Chamar" da tela. Esconder o perfil bloqueado na sessão fica de fora: sem
 * `BloqueiosDaSessao` no Android.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h1600dp")
class AppNavegacaoPerfilPublicoSegurancaTest {

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

    private val perfil = PerfilPublicoDto(
        id = "prof-7", tipo = "profissional", nome = "Maria S.", funcoes = listOf("Garçom"), fotoId = "foto-7",
        reputacao = ReputacaoDto(positivas = 7, total = 8, turnosConsiderados = 8, turnosRealizados = 8),
    )

    private fun montar() {
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single<ArmazenamentoDeSessao> { sessao }
                        viewModel { entrada }
                        viewModel { (id: String) ->
                            PerfilPublicoViewModel(id = id, buscar = { perfil }, escopo = CoroutineScope(Dispatchers.Unconfined))
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
        rule.runOnIdle { nav.navigate(RotasChamadaCasa.perfilPublico("casa-1", "prof-7")) }
        rule.waitUntil(5_000) { rule.onAllNodesWithText("Maria S.").fetchSemanticsNodes().isNotEmpty() }
    }

    @Test
    fun `o perfil publico oferece Denunciar e Bloquear, e o Chamar continua`() {
        montar()

        rule.onNodeWithTag("perfil-publico-denunciar").performScrollTo().assertIsDisplayed()
        rule.onNodeWithTag("perfil-publico-bloquear").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaCasa.TITULO_DA_FOLHA).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `Denunciar abre a denuncia do profissional com a foto, sem turno nem chamada`() {
        montar()

        rule.onNodeWithTag("perfil-publico-denunciar").performScrollTo().performClick()

        rule.runOnIdle {
            assertEquals(Rotas.DENUNCIA, nav.currentDestination?.route)
            val argumentos = nav.currentBackStackEntry?.arguments
            assertEquals("profissional", argumentos?.getString("alvoTipo"))
            assertEquals("prof-7", argumentos?.getString("alvoId"))
            assertEquals("foto-7", argumentos?.getString("fotoId"))
            assertNull(argumentos?.getString("turnoId"))
            assertNull(argumentos?.getString("chamadaId"))
        }
    }

    @Test
    fun `Bloquear e confirmar bloqueia o profissional, mostra o aviso e tira o Chamar`() {
        montar()

        rule.onNodeWithTag("perfil-publico-bloquear").performScrollTo().performClick()
        rule.onNodeWithText(TextosSuporte.BLOQUEIO_CONFIRMAR).performClick()

        rule.waitUntil(5_000) { rule.onAllNodesWithTag("perfil-publico-bloqueado").fetchSemanticsNodes().isNotEmpty() }
        assertEquals(listOf("profissional" to "prof-7"), bloqueios)
        rule.onNodeWithText(TextosSuporte.BLOQUEADO).assertIsDisplayed()
        rule.onAllNodesWithText(TextosChamadaCasa.TITULO_DA_FOLHA).assertCountEquals(0)
    }

    @Test
    fun `cancelar a confirmacao nao bloqueia e o Chamar continua`() {
        montar()

        rule.onNodeWithTag("perfil-publico-bloquear").performScrollTo().performClick()
        rule.onNodeWithText(TextosSuporte.CANCELAR).performClick()

        assertEquals(emptyList<Pair<String, String>>(), bloqueios)
        rule.onNodeWithText(TextosChamadaCasa.TITULO_DA_FOLHA).performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `se o bloqueio falha, mostra o erro e o Chamar continua`() {
        falhaDoBloqueio = ErroDaApi(CodigoErroAPI.SEM_REDE, "sem_rede", null, "x")
        montar()

        rule.onNodeWithTag("perfil-publico-bloquear").performScrollTo().performClick()
        rule.onNodeWithText(TextosSuporte.BLOQUEIO_CONFIRMAR).performClick()

        rule.waitUntil(5_000) { rule.onAllNodesWithTag("perfil-publico-erro-bloqueio").fetchSemanticsNodes().isNotEmpty() }
        rule.onNodeWithText(TextosSuporte.ERRO_SEM_REDE).assertIsDisplayed()
        rule.onNodeWithText(TextosChamadaCasa.TITULO_DA_FOLHA).performScrollTo().assertIsDisplayed()
        rule.onAllNodesWithTag("perfil-publico-bloqueado").assertCountEquals(0)
    }
}
