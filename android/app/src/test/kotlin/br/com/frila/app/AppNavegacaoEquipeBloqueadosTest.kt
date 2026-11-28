package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.AlvoBloqueado
import br.com.frila.core.dominio.modelo.BloqueiosDaSessao
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.equipe.EquipeDeConfiancaViewModel
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
import org.koin.core.module.Module
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** I1PonzKJ, fatia 2: a equipe de confiança lê o conjunto da sessão, e some quem a pessoa acabou de bloquear, sem recarregar. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h1600dp")
class AppNavegacaoEquipeBloqueadosTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val bloqueios = BloqueiosDaSessao()
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }

    private val reputacao = ReputacaoDto(positivas = 7, total = 8, turnosConsiderados = 8, turnosRealizados = 8)
    private val ana = PerfilPublicoDto(id = "prof-ana", tipo = "profissional", nome = "Ana Souza", reputacao = reputacao)
    private val beto = PerfilPublicoDto(id = "prof-beto", tipo = "profissional", nome = "Beto Lima", reputacao = reputacao)

    private fun montar(registrarOConjunto: Boolean = true) {
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        val modulo: Module = module {
            viewModel { entrada }
            if (registrarOConjunto) single { bloqueios }
            viewModel { (estabelecimentoId: String) ->
                EquipeDeConfiancaViewModel(
                    estabelecimentoId = estabelecimentoId,
                    listar = { listOf(ana, beto) },
                    removerMembro = { _, _ -> error("o teste nao remove") },
                    sair = { },
                    escopo = CoroutineScope(Dispatchers.Unconfined),
                )
            }
        }
        rule.setContent {
            KoinApplication(application = { modules(modulo) }) {
                nav = rememberNavController()
                AppNavegacao(armazenamentoDeSessao = sessao, monitorDeConectividade = MonitorDeConectividadeFalso(), navController = nav)
            }
        }
        rule.runOnIdle { nav.navigate(Rotas.equipe("casa-1")) }
        rule.waitUntil(5_000) { rule.onAllNodesWithText("Beto Lima").fetchSemanticsNodes().isNotEmpty() }
    }

    @Test
    fun `sem ninguem bloqueado, a equipe mostra os dois`() {
        montar()

        rule.onNodeWithText("Ana Souza").assertIsDisplayed()
        rule.onNodeWithText("Beto Lima").assertIsDisplayed()
    }

    @Test
    fun `quem a sessao ja bloqueou nao aparece na equipe`() {
        bloqueios.registrar(AlvoBloqueado(TipoDeAlvo.PROFISSIONAL, "prof-ana"))
        montar()

        assertEquals(0, rule.onAllNodesWithText("Ana Souza").fetchSemanticsNodes().size)
        rule.onNodeWithText("Beto Lima").assertIsDisplayed()
    }

    @Test
    fun `bloquear com a equipe aberta tira o membro na hora, sem recarregar`() {
        montar()
        rule.onNodeWithText("Ana Souza").assertIsDisplayed()

        rule.runOnIdle { bloqueios.registrar(AlvoBloqueado(TipoDeAlvo.PROFISSIONAL, "prof-ana")) }

        rule.waitUntil(5_000) { rule.onAllNodesWithText("Ana Souza").fetchSemanticsNodes().isEmpty() }
        rule.onNodeWithText("Beto Lima").assertIsDisplayed()
    }

    @Test
    fun `o mesmo id com outro tipo nao esconde o membro`() {
        bloqueios.registrar(AlvoBloqueado(TipoDeAlvo.ESTABELECIMENTO, "prof-ana"))
        montar()

        rule.onNodeWithText("Ana Souza").assertIsDisplayed()
    }

    @Test
    fun `um grafo sem o conjunto registrado segue funcionando, como os testes e as rotas antigas`() {
        montar(registrarOConjunto = false)

        rule.onNodeWithText("Ana Souza").assertIsDisplayed()
        rule.onNodeWithText("Beto Lima").assertIsDisplayed()
    }
}
