package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.BloqueioDto
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ProtocoloDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.equipe.EquipeDeConfiancaViewModel
import br.com.frila.feature.equipe.TextosEquipe
import br.com.frila.feature.suporte.DenunciaViewModel
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

/** Cartão Jh3jhl21: da Equipe de confiança, tocar em "Denunciar" abre a denúncia do profissional, sem turno nem chamada. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoDenunciaEquipeTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    private val ana = PerfilPublicoDto(
        id = "prof-ana",
        tipo = "profissional",
        nome = "Ana Souza",
        funcoes = listOf("garçom"),
        reputacao = ReputacaoDto(positivas = 7, total = 8, turnosConsiderados = 8, turnosRealizados = 8),
    )

    private fun montar(inicio: String) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoEntrada())
        }
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        viewModel { entrada }
                        viewModel { (estabelecimentoId: String) ->
                            EquipeDeConfiancaViewModel(
                                estabelecimentoId = estabelecimentoId,
                                listar = { listOf(ana) },
                                removerMembro = { _, _ -> error("o teste não remove") },
                                sair = { },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        viewModel { (alvoTipo: TipoDeAlvo, alvoId: String, turnoId: String?, chamadaId: String?) ->
                            DenunciaViewModel(
                                alvoTipo = alvoTipo,
                                alvoId = alvoId,
                                denunciar = { ProtocoloDto("6f1c2a4e-1111-2222-3333-444455556666", "denuncia", "2026-11-10T12:00:00Z", "2026-11-17") },
                                bloquear = { tipo, id -> BloqueioDto(tipo, id, "2026-11-10T12:00:00Z") },
                                turnoId = turnoId,
                                chamadaId = chamadaId,
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
                )
            }
        }
        rule.runOnIdle { nav.navigate(inicio) }
    }

    @Test
    fun denunciarNaEquipeAbreADenunciaDoProfissionalSemTurnoNemChamada() {
        montar(Rotas.equipe("casa-1"))

        rule.onNodeWithContentDescription(TextosEquipe.rotuloDenunciar("Ana Souza")).performScrollTo().performClick()

        rule.runOnIdle {
            assertEquals(Rotas.DENUNCIA, nav.currentDestination?.route)
            val argumentos = nav.currentBackStackEntry?.arguments
            assertEquals("profissional", argumentos?.getString("alvoTipo"))
            assertEquals("prof-ana", argumentos?.getString("alvoId"))
            assertNull(argumentos?.getString("turnoId"))
            assertNull(argumentos?.getString("chamadaId"))
        }
    }
}
