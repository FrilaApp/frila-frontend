package br.com.frila.feature.vagas.feed

import android.Manifest
import android.app.Application
import android.app.NotificationManager
import android.content.Context
import androidx.activity.ComponentActivity
import androidx.activity.compose.LocalActivityResultRegistryOwner
import androidx.activity.result.ActivityResultRegistry
import androidx.activity.result.ActivityResultRegistryOwner
import androidx.activity.result.contract.ActivityResultContract
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import io.ktor.client.engine.mock.respond
import androidx.core.app.ActivityOptionsCompat
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ApplicationProvider
import br.com.frila.core.designsystem.tema.FrilaTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/** Cartão W8MrGF1E: o aviso de notificações desligadas no alto de Vagas, como o `AvisoDePermissaoDePush` do iOS. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class AvisoDeNotificacoesTest {

    @get:Rule
    val compose = createAndroidComposeRule<ComponentActivity>()

    private val aplicacao: Application get() = ApplicationProvider.getApplicationContext()

    // ---- o estado lido do aparelho ----

    @Test
    fun `notificacoes ligadas contam como concedida`() {
        shadowOf(aplicacao.getSystemService(NotificationManager::class.java)).setNotificationsEnabled(true)

        assertEquals(PermissaoDeNotificacao.CONCEDIDA, lerPermissaoDeNotificacao(aplicacao))
    }

    @Test
    fun `desligadas sem a permissao do Android 13 contam como nao pedida`() {
        shadowOf(aplicacao.getSystemService(NotificationManager::class.java)).setNotificationsEnabled(false)
        shadowOf(aplicacao).denyPermissions(Manifest.permission.POST_NOTIFICATIONS)

        assertEquals(PermissaoDeNotificacao.NAO_PEDIDA, lerPermissaoDeNotificacao(aplicacao))
    }

    @Test
    fun `desligadas com a permissao dada so voltam pelos Ajustes`() {
        shadowOf(aplicacao.getSystemService(NotificationManager::class.java)).setNotificationsEnabled(false)
        shadowOf(aplicacao).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)

        assertEquals(PermissaoDeNotificacao.NEGADA, lerPermissaoDeNotificacao(aplicacao))
    }

    // ---- o aviso ----

    /** O pedido do sistema, falso: guarda os pedidos e responde [concedida]. */
    private class Pedidos(var concedida: Boolean) {
        val permissoes = mutableListOf<Any?>()
        val dono = object : ActivityResultRegistryOwner {
            override val activityResultRegistry = object : ActivityResultRegistry() {
                override fun <I, O> onLaunch(requestCode: Int, contract: ActivityResultContract<I, O>, input: I, options: ActivityOptionsCompat?) {
                    assertTrue(contract is ActivityResultContracts.RequestPermission)
                    permissoes += input
                    dispatchResult(requestCode, concedida)
                }
            }
        }
    }

    private fun montar(estado: () -> PermissaoDeNotificacao, pedidos: Pedidos = Pedidos(false), aoAbrirAjustes: () -> Unit = {}) {
        compose.setContent {
            CompositionLocalProvider(LocalActivityResultRegistryOwner provides pedidos.dono) {
                FrilaTheme { AvisoDeNotificacoesDesligadas(aoAbrirAjustes = aoAbrirAjustes, lerPermissao = { _: Context -> estado() }) }
            }
        }
        compose.waitForIdle()
    }

    private fun contar(tag: String) = compose.onAllNodesWithTag(tag).fetchSemanticsNodes().size

    @Test
    fun `negada mostra o texto do iOS e Abrir Ajustes abre os ajustes`() {
        var abriu = 0
        montar({ PermissaoDeNotificacao.NEGADA }, aoAbrirAjustes = { abriu++ })

        compose.onNodeWithText(TextosAvisoDeNotificacoes.NEGADA).assertExists()
        compose.onNodeWithText(TextosAvisoDeNotificacoes.ABRIR_AJUSTES).performClick()

        assertEquals(1, abriu)
        assertEquals(1, contar(TextosAvisoDeNotificacoes.TAG_NEGADA))
    }

    @Test
    fun `concedida nao ocupa espaco`() {
        montar({ PermissaoDeNotificacao.CONCEDIDA })

        assertEquals(0, contar(TextosAvisoDeNotificacoes.TAG_NEGADA))
        assertEquals(0, contar(TextosAvisoDeNotificacoes.TAG_NAO_PEDIDA))
    }

    @Test
    fun `nao pedida pede a permissao do sistema e, recusada, passa o aviso para os Ajustes`() {
        val pedidos = Pedidos(concedida = false)
        montar({ PermissaoDeNotificacao.NAO_PEDIDA }, pedidos)
        compose.onNodeWithText(TextosAvisoDeNotificacoes.NAO_PEDIDA).assertExists()

        compose.onNodeWithText(TextosAvisoDeNotificacoes.ATIVAR).performClick()
        compose.waitForIdle()

        assertEquals(listOf<Any?>(Manifest.permission.POST_NOTIFICATIONS), pedidos.permissoes)
        assertEquals(0, contar(TextosAvisoDeNotificacoes.TAG_NAO_PEDIDA))
        assertEquals(1, contar(TextosAvisoDeNotificacoes.TAG_NEGADA))
    }

    @Test
    fun `nao pedida e concedida no pedido some`() {
        var estado = PermissaoDeNotificacao.NAO_PEDIDA
        val pedidos = Pedidos(concedida = true)
        montar({ estado }, pedidos)

        // O sistema concede: as notificações passam a ligadas, e a tela relê.
        estado = PermissaoDeNotificacao.CONCEDIDA
        compose.onNodeWithText(TextosAvisoDeNotificacoes.ATIVAR).performClick()
        compose.waitForIdle()

        assertEquals(0, contar(TextosAvisoDeNotificacoes.TAG_NAO_PEDIDA))
        assertEquals(0, contar(TextosAvisoDeNotificacoes.TAG_NEGADA))
    }

    @Test
    fun `voltar dos Ajustes com as notificacoes ligadas tira o aviso`() {
        var estado = PermissaoDeNotificacao.NEGADA
        montar({ estado })
        assertEquals(1, contar(TextosAvisoDeNotificacoes.TAG_NEGADA))

        // A pessoa vai aos Ajustes (a tela pausa), liga as notificações e volta.
        compose.activityRule.scenario.moveToState(Lifecycle.State.STARTED)
        estado = PermissaoDeNotificacao.CONCEDIDA
        compose.activityRule.scenario.moveToState(Lifecycle.State.RESUMED)
        compose.waitForIdle()

        assertEquals(0, contar(TextosAvisoDeNotificacoes.TAG_NEGADA))
    }

    // ---- na tela de Vagas ----

    private fun telaDeVagas(aoAbrirAjustes: (() -> Unit)?) {
        shadowOf(aplicacao.getSystemService(NotificationManager::class.java)).setNotificationsEnabled(false)
        shadowOf(aplicacao).grantPermissions(Manifest.permission.POST_NOTIFICATIONS)
        val vm = FeedVagasViewModel(
            servicoVagas = br.com.frila.core.rede.ServicoVagas(
                br.com.frila.core.rede.ClienteSupabase(
                    "https://frila.supabase.co",
                    "chave-teste",
                    engine = io.ktor.client.engine.mock.MockEngine {
                        respond("[]", io.ktor.http.HttpStatusCode.OK, io.ktor.http.headersOf(io.ktor.http.HttpHeaders.ContentType, "application/json"))
                    },
                ),
            ),
            escopo = kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Unconfined),
        )
        compose.setContent {
            FrilaTheme { TelaFeedVagas(viewModel = vm, aoAbrirDetalhe = {}, aoAbrirAjustesDeNotificacao = aoAbrirAjustes) }
        }
        compose.waitForIdle()
    }

    @Test
    fun `Vagas mostra o aviso no alto com as notificacoes desligadas`() {
        var abriu = 0
        telaDeVagas { abriu++ }

        compose.onNodeWithTag(TextosAvisoDeNotificacoes.TAG_NEGADA).assertExists()
        compose.onNodeWithText(TextosAvisoDeNotificacoes.ABRIR_AJUSTES).performClick()
        assertEquals(1, abriu)
    }

    @Test
    fun `Vagas sem o caminho dos Ajustes nao mostra o aviso`() {
        telaDeVagas(null)

        assertEquals(0, contar(TextosAvisoDeNotificacoes.TAG_NEGADA))
        assertEquals(0, contar(TextosAvisoDeNotificacoes.TAG_NAO_PEDIDA))
    }
}
