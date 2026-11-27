package br.com.frila.app

import android.app.Application
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import br.com.frila.core.dominio.modelo.DataCivil
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.rede.ServicoConta
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.cadastro.CadastroViewModel
import br.com.frila.feature.entrada.cadastro.PerfilDaConta
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.estabelecimento.CadastroEstabelecimentoViewModel
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.StatusPerfil
import br.com.frila.feature.vagas.feed.EstadoFeed
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.StatusFeed
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
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
 * #784: o cadastro de casa termina no cadastro do estabelecimento (com o Perfil por baixo, como na abertura de quem ainda
 * não tem casa) e o de profissional na lista de vagas. Nos dois casos o destino fica guardado, como o iOS faz.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppNavegacaoCadastroPorPapelTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste() // C0-6b: testReleaseUnitTest

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private lateinit var cadastro: CadastroViewModel
    private val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
        every { estaAutenticado() } returns false
        every { isBiometriaAtivada() } returns false
    }
    private val destinosGuardados = mutableListOf<DestinoDaConta>()
    private val guardado = object : DestinoGuardado {
        override fun obter(): DestinoDaConta? = destinosGuardados.lastOrNull()
        override fun salvar(destino: DestinoDaConta) { destinosGuardados += destino }
        override fun limpar() { destinosGuardados.clear() }
    }

    private fun montar(perfilDaResposta: String) {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine {
                respond(
                    """{"id":"u1","perfil":"$perfilDaResposta","nome":"Conta de Teste","telefone":"+5511987654321","email":"t@exemplo.com","nascimento":"2000-06-15","estado":"ativa"}""",
                    HttpStatusCode.OK,
                    headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )
        cadastro = CadastroViewModel(
            servicoConta = ServicoConta(cliente),
            escopo = CoroutineScope(Dispatchers.Default),
            hoje = { DataCivil.de(2026, 11, 27) },
        )
        val entrada = mockk<EntradaViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoEntrada())
        }
        val perfil = mockk<PerfilViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoPerfil(status = StatusPerfil.SUCESSO))
        }
        val feed = mockk<FeedVagasViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.ERRO))
        }
        val casa = CadastroEstabelecimentoViewModel(
            cadastrar = { error("não deveria cadastrar") },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single<ArmazenamentoDeSessao> { sessao }
                        single<DestinoGuardado> { guardado }
                        viewModel { entrada }
                        viewModel { perfil }
                        viewModel { feed }
                        viewModel { casa }
                        viewModel { cadastro }
                    },
                )
            }) {
                nav = rememberNavController()
                AppNavegacao(
                    armazenamentoDeSessao = sessao,
                    monitorDeConectividade = MonitorDeConectividadeFalso(),
                    navController = nav,
                    servicoMembros = null,
                )
            }
        }
        rule.runOnIdle { nav.navigate(Rotas.CADASTRO) }
    }

    private fun concluirComo(perfil: PerfilDaConta) {
        rule.runOnIdle {
            cadastro.aoEscolherPerfil(perfil)
            cadastro.aoMudarNome("Conta de Teste")
            cadastro.aoMudarCpf("52998224725")
            cadastro.aoMudarTelefone("11987654321")
            cadastro.aoMudarNascimento(DataCivil.de(2000, 6, 15))
            cadastro.aoMudarAceiteDeTermos(true)
            cadastro.concluirCadastro()
        }
        rule.waitUntil(5_000) { cadastro.estado.value.concluido || cadastro.estado.value.erro != null }
        assertEquals(null, cadastro.estado.value.erro)
        rule.waitUntil(5_000) { rule.runOnIdle { nav.currentDestination?.route != Rotas.CADASTRO } }
    }

    private fun rotasNaPilha(): List<String?> = rule.runOnIdle { nav.currentBackStack.value.map { it.destination.route } }

    @Test
    fun `cadastro de casa termina no cadastro do estabelecimento, com o Perfil por baixo`() {
        montar(perfilDaResposta = "contratante")

        concluirComo(PerfilDaConta.CONTRATANTE)

        rule.runOnIdle { assertEquals(Rotas.CADASTRO_ESTABELECIMENTO, nav.currentDestination?.route) }
        val pilha = rotasNaPilha()
        assertTrue("o Perfil fica por baixo do cadastro da casa: $pilha", Rotas.PERFIL in pilha)
        assertTrue("o cadastro concluído não fica na pilha: $pilha", Rotas.CADASTRO !in pilha)
        assertEquals(listOf<DestinoDaConta>(DestinoDaConta.Contratante(casa = null)), destinosGuardados)
    }

    @Test
    fun `cadastro de profissional termina na lista de vagas`() {
        montar(perfilDaResposta = "profissional")

        concluirComo(PerfilDaConta.PROFISSIONAL)

        rule.runOnIdle { assertEquals(Rotas.FEED, nav.currentDestination?.route) }
        assertTrue("o cadastro concluído não fica na pilha", Rotas.CADASTRO !in rotasNaPilha())
        assertEquals(listOf<DestinoDaConta>(DestinoDaConta.Profissional), destinosGuardados)
    }
}
