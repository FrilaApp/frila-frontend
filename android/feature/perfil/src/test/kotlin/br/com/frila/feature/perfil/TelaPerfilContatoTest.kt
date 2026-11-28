package br.com.frila.feature.perfil

import android.content.ClipboardManager
import android.content.Context
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.core.app.ApplicationProvider
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoConta
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoTurnos
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** wdgLuHOV: o perfil do profissional mostra o telefone e o e-mail da conta, e tocar copia para a área de transferência do sistema. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h2400dp")
class TelaPerfilContatoTest {

    @get:Rule
    val rule = createComposeRule()

    private val perfilJson = """
        {"id":"11111111-1111-1111-1111-111111111111","usuario_id":"22222222-2222-2222-2222-222222222222",
         "funcoes":[{"id":"f1","nome":"Garçom","categoria":"Salão"}],"ponto_base":{"latitude":-15.7942,"longitude":-47.8822},
         "disponibilidades":[],"reputacao":{"positivas":7,"total":7,"taxa_comparecimento":0.95,"turnos_considerados":8,"turnos_realizados":8}}
    """.trimIndent()

    private fun contaJson(telefone: String) =
        """{"id":"u1","perfil":"profissional","nome":"Ana Souza","telefone":"$telefone","email":"ana@exemplo.com","nascimento":"1990-01-01","estado":"ativa"}"""

    private fun cliente(corpo: String) = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-teste",
        engine = MockEngine { respond(corpo, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) },
    )

    private fun viewModel(telefone: String) = PerfilViewModel(
        servicoPerfil = ServicoPerfil(cliente(perfilJson)),
        servicoTurnos = ServicoTurnos(cliente("[]")),
        armazenamentoDeSessao = mockk(relaxed = true),
        escopo = CoroutineScope(Dispatchers.Default),
        comprimirFoto = { _, _ -> throw IllegalStateException("sem foto neste teste") },
        obterAvatarSalvo = { null },
        preferenciasNotificacao = br.com.frila.core.notificacoes.GerenciadorPreferenciasNotificacaoEmMemoria(),
        servicoConta = ServicoConta(cliente(contaJson(telefone))),
    )

    private fun textoDaAreaDeTransferencia(): String? {
        val contexto = ApplicationProvider.getApplicationContext<Context>()
        val gerenciador = contexto.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        return gerenciador.primaryClip?.getItemAt(0)?.text?.toString()
    }

    @Test
    fun `o perfil mostra o telefone formatado e o e-mail da conta`() {
        runBlocking {
            val vm = viewModel("+5561988887777")
            vm.carregar().join()
            rule.setContent { FrilaTheme { TelaPerfil(vm) } }
        }

        rule.onNodeWithText("(61) 98888-7777").performScrollTo().assertIsDisplayed()
        rule.onNodeWithText("ana@exemplo.com").performScrollTo().assertIsDisplayed()
    }

    @Test
    fun `tocar no telefone e no e-mail copia para a area de transferencia do sistema`() {
        runBlocking {
            val vm = viewModel("+5561988887777")
            vm.carregar().join()
            rule.setContent { FrilaTheme { TelaPerfil(vm) } }
        }

        rule.onNodeWithTag("perfil-telefone").performScrollTo().performClick()
        rule.runOnIdle { assertEquals("(61) 98888-7777", textoDaAreaDeTransferencia()) }
        rule.onNodeWithTag("perfil-email").performScrollTo().performClick()
        rule.runOnIdle { assertEquals("ana@exemplo.com", textoDaAreaDeTransferencia()) }
    }
}
