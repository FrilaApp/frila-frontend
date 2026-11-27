package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.PainelDto
import br.com.frila.core.rede.VagaNoPainelDto
import br.com.frila.core.rede.VagaResumoDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.chamadas.casa.AcompanharChamadasViewModel
import br.com.frila.feature.chamadas.casa.EstadoAcompanharChamadas
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.StatusPerfil
import br.com.frila.feature.vagas.painel.MinhasVagasViewModel
import br.com.frila.feature.vagas.painel.TextosMinhasVagas
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Cartão pImBabwQ: da vaga que nasceu de uma chamada direta, "Acompanhar chamadas" em Minhas vagas leva à tela de acompanhar da casa
 * (`RotasChamadaCasa.acompanhar`), e só com a chave `chamada_direta` ligada. A vaga normal não tem a entrada.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h2400dp")
class AcompanharChamadasEmMinhasVagasTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    private fun vagaNoPainel(id: String, origem: String?) = VagaNoPainelDto(
        vaga = VagaResumoDto(
            id = id, funcao = "Garçom", local = "SQN 108", regiaoAdministrativa = "Asa Norte",
            inicioEm = "2099-11-12T21:00:00Z", fimEm = "2099-11-13T03:00:00Z", valorCentavos = 16_000, origem = origem,
        ),
        modo = "urgencia", estado = "publicada", oculta = false, alertaVagaVazia = false, candidatosPendentes = 0, posicoes = emptyList(),
    )

    private fun montar(chamadaDiretaHabilitada: Boolean) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        val perfil = mockk<PerfilViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoPerfil(status = StatusPerfil.SUCESSO)) }
        val acompanhar = mockk<AcompanharChamadasViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoAcompanharChamadas()) }
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single<ArmazenamentoDeSessao> { sessao }
                        viewModel { entrada }
                        viewModel { perfil }
                        viewModel { (estabelecimentoId: String, nome: String?, recemPublicadaId: String?) ->
                            MinhasVagasViewModel(
                                estabelecimentoId = estabelecimentoId,
                                nomeEstabelecimento = nome,
                                vagaRecemPublicadaId = recemPublicadaId,
                                buscarPainel = { id, _, _ ->
                                    Result.success(
                                        PainelDto(id, listOf(vagaNoPainel("vaga-direta", "chamada_direta"), vagaNoPainel("vaga-normal", null)), emptyList()),
                                    )
                                },
                                escopo = CoroutineScope(Dispatchers.Unconfined),
                            )
                        }
                        viewModel { (_: String) -> acompanhar }
                    },
                )
            }) {
                nav = rememberNavController()
                AppNavegacao(
                    armazenamentoDeSessao = sessao,
                    monitorDeConectividade = MonitorDeConectividadeFalso(),
                    navController = nav,
                    biometriaHabilitada = true,
                    chamadaDiretaHabilitada = chamadaDiretaHabilitada,
                )
            }
        }
        rule.runOnIdle { nav.navigate(Rotas.minhasVagas("casa-1")) }
    }

    private fun esperarTexto(texto: String) {
        rule.waitUntil(5_000) { rule.onAllNodesWithText(texto).fetchSemanticsNodes().isNotEmpty() }
    }

    @Test
    fun `com a chave ligada a vaga direta leva a tela de acompanhar da casa com o id da vaga, e a normal nao tem a entrada`() {
        montar(chamadaDiretaHabilitada = true)
        esperarTexto(TextosMinhasVagas.ACOMPANHAR_CHAMADAS)

        rule.onAllNodesWithText(TextosMinhasVagas.ACOMPANHAR_CHAMADAS).assertCountEquals(1)
        rule.onNodeWithText(TextosMinhasVagas.ACOMPANHAR_CHAMADAS).performScrollTo().performClick()

        rule.runOnIdle {
            assertEquals(RotasChamadaCasa.ACOMPANHAR, nav.currentDestination?.route)
            assertEquals("vaga-direta", nav.currentBackStackEntry?.arguments?.getString("vagaId"))
        }
    }

    @Test
    fun `com a chave desligada a vaga direta nao mostra a entrada`() {
        montar(chamadaDiretaHabilitada = false)
        esperarTexto("Garçom")

        rule.onAllNodesWithText(TextosMinhasVagas.ACOMPANHAR_CHAMADAS).assertCountEquals(0)
    }
}
