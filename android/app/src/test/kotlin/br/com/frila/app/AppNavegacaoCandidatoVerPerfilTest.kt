package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.BloqueioDto
import br.com.frila.core.rede.CandidatoDto
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ProtocoloDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ResultadoConfirmacaoDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.chamadas.casa.PerfilPublicoViewModel
import br.com.frila.feature.chamadas.casa.TextosChamadaCasa
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.suporte.BloqueioDeAlvoViewModel
import br.com.frila.feature.suporte.DenunciaViewModel
import br.com.frila.feature.vagas.candidatos.CandidatosDaVagaViewModel
import io.mockk.every
import io.mockk.mockk
import java.time.Instant
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
 * Cartão R2fbierN (item 184): na lista de candidatos da vaga, "Ver perfil público" abre o perfil do candidato SEM "Chamar"
 * (como o iOS, `MinhasVagas.swift:1041-1043`) e COM Denunciar e Bloquear (#1235). A busca segue abrindo o mesmo perfil com
 * "Chamar" (o teste do #1235, `AppNavegacaoPerfilPublicoSegurancaTest`).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h1600dp")
class AppNavegacaoCandidatoVerPerfilTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val perfisLidos = mutableListOf<String>()
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    private val ana = PerfilPublicoDto(
        id = "p-c1", tipo = "profissional", nome = "Ana Souza", funcoes = listOf("Garçom"), fotoId = "foto-c1",
        reputacao = ReputacaoDto(positivas = 1, total = 1, turnosConsiderados = 1, turnosRealizados = 1),
    )

    private fun montar(estabelecimentoId: String?) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        val escopo = CoroutineScope(Dispatchers.Unconfined)
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single<ArmazenamentoDeSessao> { sessao }
                        viewModel { entrada }
                        viewModel { parametros ->
                            CandidatosDaVagaViewModel(
                                vagaId = parametros[0],
                                buscar = { listOf(CandidatoDto(candidaturaId = "c1", profissional = ana, criadaEm = "2026-11-10T12:00:00Z")) },
                                escolher = { ResultadoConfirmacaoDto("confirmada", "pos-1", "t1") },
                                posicoesAbertas = parametros[1],
                                inicioDaVaga = parametros[2],
                                escopo = escopo,
                                relogio = { Instant.parse("2026-11-10T15:00:00Z") },
                            )
                        }
                        viewModel { (id: String) ->
                            PerfilPublicoViewModel(id = id, buscar = { perfisLidos += it; ana }, escopo = escopo)
                        }
                        viewModel { (alvoTipo: TipoDeAlvo, alvoId: String, turnoId: String?, chamadaId: String?, fotoId: String?) ->
                            DenunciaViewModel(
                                alvoTipo = alvoTipo,
                                alvoId = alvoId,
                                denunciar = { ProtocoloDto("6f1c2a4e-1111-2222-3333-444455556666", "denuncia", "2026-11-10T12:00:00Z", "2026-11-17") },
                                bloquear = { tipo, alvo -> BloqueioDto(tipo, alvo, "2026-11-10T12:00:00Z") },
                                turnoId = turnoId,
                                chamadaId = chamadaId,
                                fotoId = fotoId,
                                escopo = escopo,
                            )
                        }
                        viewModel { (alvoTipo: TipoDeAlvo, alvoId: String) ->
                            BloqueioDeAlvoViewModel(
                                alvoTipo = alvoTipo,
                                alvoId = alvoId,
                                bloquear = { tipo, alvo -> BloqueioDto(tipo, alvo, "2026-11-10T12:00:00Z") },
                                escopo = escopo,
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
                )
            }
        }
        rule.runOnIdle { nav.navigate(Rotas.candidatosDaVaga("v1", 2, null, estabelecimentoId)) }
        rule.waitUntil(5_000) { rule.onAllNodesWithTag("perfil-do-candidato-c1").fetchSemanticsNodes().isNotEmpty() }
    }

    private fun abrirPerfilDaAna() {
        rule.onNodeWithTag("perfil-do-candidato-c1").performScrollTo().performClick()
        rule.waitUntil(5_000) { rule.onAllNodesWithTag("perfil-publico-denunciar").fetchSemanticsNodes().isNotEmpty() }
    }

    @Test
    fun `Ver perfil publico do candidato abre o perfil sem Chamar e com Denunciar e Bloquear`() {
        montar(estabelecimentoId = "casa-1")

        abrirPerfilDaAna()

        rule.runOnIdle {
            assertEquals(RotasChamadaCasa.PERFIL_PUBLICO, nav.currentDestination?.route)
            assertEquals(false, nav.currentBackStackEntry?.arguments?.getBoolean("comChamar", true))
        }
        assertEquals(listOf("p-c1"), perfisLidos)
        rule.onNodeWithTag("perfil-publico-denunciar").performScrollTo()
        rule.onNodeWithTag("perfil-publico-bloquear").performScrollTo()
        rule.onAllNodesWithText(TextosChamadaCasa.TITULO_DA_FOLHA).assertCountEquals(0)
    }

    @Test
    fun `sem a casa na rota (aviso push) o perfil do candidato abre do mesmo jeito`() {
        montar(estabelecimentoId = null)

        abrirPerfilDaAna()

        assertEquals(listOf("p-c1"), perfisLidos)
        rule.onAllNodesWithText(TextosChamadaCasa.TITULO_DA_FOLHA).assertCountEquals(0)
    }
}
