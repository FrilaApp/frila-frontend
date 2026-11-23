package br.com.frila.feature.perfil

import android.content.Intent
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import br.com.frila.core.dominio.modelo.CodigoErroAPI
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ItemExportarDadosTest {
    @get:Rule(order = 0) val registrar = RegistraActivityDeTeste()
    @get:Rule(order = 1) val compose = createComposeRule()

    @Test
    fun `item exporta mostra carregamento e erro sem permitir clique duplo`() {
        val estado = mutableStateOf(EstadoExportarDados())
        var cliques = 0
        compose.setContent {
            ConteudoItemExportarDados(estado.value) {
                cliques++
                estado.value = EstadoExportarDados(carregando = true)
            }
        }
        compose.onNodeWithText("Exportar meus dados").assertIsDisplayed()
        compose.onNodeWithTag("perfil-exportar-dados").performClick()
        compose.onNodeWithTag("perfil-exportar-dados").assertIsNotEnabled()
        compose.onNodeWithText("Gerando o arquivo…").assertIsDisplayed()
        assertEquals(1, cliques)
        compose.runOnIdle { estado.value = EstadoExportarDados(erro = CodigoErroAPI.NAO_AUTENTICADO) }
        compose.onNodeWithText("Sua sessão expirou. Entre de novo.").assertIsDisplayed()
    }

    @Test
    fun `clique chama abertura do chooser uma vez e libera o item`() {
        val app = RuntimeEnvironment.getApplication()
        // A biblioteca não resolve ${applicationId}; o app resolve ao mesclar seu manifesto.
        val info = android.content.pm.ProviderInfo().apply {
            authority = "${app.packageName}.fileprovider"
            packageName = app.packageName
            name = androidx.core.content.FileProvider::class.java.name
            exported = false
            grantUriPermissions = true
            metaData = android.os.Bundle().apply {
                putInt("android.support.FILE_PROVIDER_PATHS", R.xml.file_paths_perfil)
            }
        }
        shadowOf(app.packageManager).addOrUpdateProvider(info)
        val dados = """{ "sintetico": true }""".toByteArray()
        val vm = ExportarDadosViewModel({ dados }, dispatcherIo = Dispatchers.Main.immediate)
        val aberturas = mutableListOf<Intent>()
        compose.setContent { ItemExportarDados(vm, abrir = aberturas::add) }
        compose.onNodeWithTag("perfil-exportar-dados").performClick()
        compose.runOnIdle {
            assertEquals(1, aberturas.size)
            assertEquals(Intent.ACTION_CHOOSER, aberturas.single().action)
            assertEquals(EstadoExportarDados(), vm.estado.value)
        }
    }
}
