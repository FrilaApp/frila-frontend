package br.com.frila.app.ui

import android.Manifest
import android.content.pm.PackageManager
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import br.com.frila.core.designsystem.tema.FrilaTheme
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoPerfil
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.feature.perfil.AutenticadorBiometrico
import br.com.frila.feature.perfil.PerfilViewModel
import br.com.frila.feature.perfil.TelaPerfil
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Em aparelho ou emulador: o app instalado não tem as permissões de biometria, e abrir o perfil sem elas não quebra.
 * Só o aparelho prova isto: o Robolectric não aplica a checagem de permissão do serviço de biometria do sistema.
 */
@RunWith(AndroidJUnit4::class)
class PerfilSemBiometriaInstrumentedTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private val contexto get() = InstrumentationRegistry.getInstrumentation().targetContext

    private val perfilJson = """
        {"id":"11111111-1111-1111-1111-111111111111","usuario_id":"22222222-2222-2222-2222-222222222222",
         "funcoes":[{"id":"f1","nome":"Garçom","categoria":"Salão"}],"ponto_base":null,"disponibilidades":[],
         "reputacao":{"positivas":7,"total":7,"turnos_considerados":8,"turnos_realizados":8}}
    """.trimIndent()

    private fun cliente(corpo: String) = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-perfil-instrumentado",
        engine = MockEngine { respond(corpo, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) },
    )

    @Test
    fun oAppInstaladoNaoPedeAsPermissoesDeBiometria() {
        val pedidas = contexto.packageManager
            .getPackageInfo(contexto.packageName, PackageManager.GET_PERMISSIONS)
            .requestedPermissions.orEmpty().toList()

        assertFalse("USE_BIOMETRIC no pacote instalado: $pedidas", Manifest.permission.USE_BIOMETRIC in pedidas)
        @Suppress("DEPRECATION")
        assertFalse("USE_FINGERPRINT no pacote instalado: $pedidas", Manifest.permission.USE_FINGERPRINT in pedidas)
    }

    /** O motivo da guarda em `TelaPerfil`: sem a permissão, perguntar ao sistema se há biometria lança. */
    @Test
    fun consultarOHardwareDeBiometriaSemAPermissaoLanca() {
        assertThrows(SecurityException::class.java) { AutenticadorBiometrico.verificarDisponibilidade(contexto) }
    }

    @Test
    fun abrirOPerfilSemAsPermissoesDeBiometriaNaoQuebra() {
        val viewModel = PerfilViewModel(
            servicoPerfil = ServicoPerfil(cliente(perfilJson)),
            servicoTurnos = ServicoTurnos(cliente("[]")),
            armazenamentoDeSessao = ArmazenamentoDeSessaoEmMemoria(),
            escopo = CoroutineScope(Dispatchers.Default),
            obterAvatarSalvo = { null },
        )
        runBlocking { viewModel.carregar().join() }

        // Sem dublê da consulta de biometria: vale o caminho real do app.
        composeTestRule.setContent {
            FrilaTheme { TelaPerfil(viewModel = viewModel, aoDeslogar = {}) }
        }

        composeTestRule.onNodeWithText("Sair da conta").performScrollTo().assertExists()
    }
}
