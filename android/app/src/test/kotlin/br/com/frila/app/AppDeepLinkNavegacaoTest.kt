package br.com.frila.app

import android.app.Application
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import androidx.navigation.NavDestination
import androidx.navigation.navDeepLink
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class AppDeepLinkNavegacaoTest {

    private val contexto: Application
        get() = RuntimeEnvironment.getApplication()

    @Test
    fun `intent de vaga resolve MainActivity e corresponde ao destino de detalhe`() {
        val intent = intentPara("frila://vagas/v1")

        assertEquals(
            ComponentName(contexto, MainActivity::class.java),
            intent.resolveActivity(contexto.packageManager),
        )
        assertTrue(destino(Rotas.DETALHE, DeepLinks.DETALHE_VAGA).hasDeepLink(intent.data!!))
    }

    @Test
    fun `intent de meus turnos resolve MainActivity e corresponde ao destino de turnos`() {
        val intent = intentPara("frila://meus_turnos")

        assertEquals(
            ComponentName(contexto, MainActivity::class.java),
            intent.resolveActivity(contexto.packageManager),
        )
        assertTrue(destino(Rotas.MEUS_TURNOS, DeepLinks.MEUS_TURNOS).hasDeepLink(intent.data!!))
    }

    private fun intentPara(uri: String): Intent =
        Intent(Intent.ACTION_VIEW, Uri.parse(uri)).setPackage(contexto.packageName).also {
            assertNotNull(it.resolveActivity(contexto.packageManager))
        }

    private fun destino(rota: String, padrao: String) = NavDestination("composable").apply {
        route = rota
        addDeepLink(navDeepLink { uriPattern = padrao })
    }
}
