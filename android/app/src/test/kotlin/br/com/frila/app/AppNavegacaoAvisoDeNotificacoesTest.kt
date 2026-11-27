package br.com.frila.app

import android.Manifest
import android.app.Application
import android.app.NotificationManager
import android.provider.Settings
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import androidx.test.core.app.ApplicationProvider
import br.com.frila.core.rede.MonitorDeConectividadeFalso
import br.com.frila.core.seguranca.ArmazenamentoDeSessao
import br.com.frila.feature.entrada.entrada.EntradaViewModel
import br.com.frila.feature.entrada.entrada.EstadoEntrada
import br.com.frila.feature.perfil.EstadoPerfil
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.StatusPerfil
import br.com.frila.feature.vagas.feed.EstadoFeed
import br.com.frila.feature.vagas.feed.FeedVagasViewModel
import br.com.frila.feature.vagas.feed.StatusFeed
import br.com.frila.feature.vagas.feed.TextosAvisoDeNotificacoes
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.androidx.viewmodel.dsl.viewModel
import org.koin.compose.KoinApplication
import org.koin.dsl.module
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/** Cartão W8MrGF1E: no Feed de verdade, "Abrir Ajustes" do aviso de notificações abre os ajustes de notificação do Frila. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class, qualifiers = "w411dp-h2400dp")
class AppNavegacaoAvisoDeNotificacoesTest {

    @get:Rule(order = 0)
    val registraActivity = RegistraActivityDeTeste()

    @get:Rule(order = 1)
    val rule = createComposeRule()

    private lateinit var nav: NavHostController
    private val aplicacao: Application get() = ApplicationProvider.getApplicationContext()

    @Test
    fun `Abrir Ajustes no aviso do Feed abre os ajustes de notificacao do Frila`() {
        shadowOf(aplicacao.getSystemService(NotificationManager::class.java)).setNotificationsEnabled(false)
        shadowOf(aplicacao).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        val sessao = mockk<ArmazenamentoDeSessao>(relaxed = true) {
            every { estaAutenticado() } returns false
            every { isBiometriaAtivada() } returns false
        }
        val entrada = mockk<EntradaViewModel>(relaxed = true) { every { estado } returns MutableStateFlow(EstadoEntrada()) }
        val perfil = mockk<PerfilViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoPerfil(status = StatusPerfil.SUCESSO))
        }
        val feed = mockk<FeedVagasViewModel>(relaxed = true) {
            every { estado } returns MutableStateFlow(EstadoFeed(status = StatusFeed.VAZIO))
        }
        rule.setContent {
            KoinApplication(application = {
                modules(
                    module {
                        single<ArmazenamentoDeSessao> { sessao }
                        viewModel { entrada }
                        viewModel { perfil }
                        viewModel { feed }
                    },
                )
            }) {
                nav = rememberNavController()
                AppNavegacao(armazenamentoDeSessao = sessao, monitorDeConectividade = MonitorDeConectividadeFalso(), navController = nav)
            }
        }
        rule.runOnIdle { nav.navigate(Rotas.FEED) }
        rule.waitUntil(5_000) { rule.onAllNodesWithText(TextosAvisoDeNotificacoes.ABRIR_AJUSTES).fetchSemanticsNodes().isNotEmpty() }

        rule.onNodeWithText(TextosAvisoDeNotificacoes.ABRIR_AJUSTES).performClick()
        rule.waitForIdle()

        val aberto = shadowOf(aplicacao).nextStartedActivity
        assertEquals(Settings.ACTION_APP_NOTIFICATION_SETTINGS, aberto?.action)
        assertEquals(aplicacao.packageName, aberto?.getStringExtra(Settings.EXTRA_APP_PACKAGE))
    }
}
