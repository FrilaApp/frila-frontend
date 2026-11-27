package br.com.frila.app

import android.app.Application
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import androidx.navigation.NavDestination
import androidx.navigation.navDeepLink
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import br.com.frila.core.notificacoes.EntradaDoAvisoActivity
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

    @Test
    fun `intent de turno do aviso resolve MainActivity e corresponde ao destino do turno com id`() {
        val intent = intentPara("frila://meus_turnos/turno-999")

        assertEquals(
            ComponentName(contexto, MainActivity::class.java),
            intent.resolveActivity(contexto.packageManager),
        )
        assertTrue(destino(Rotas.TURNO_AVISO, DeepLinks.TURNO_AVISO).hasDeepLink(intent.data!!))
    }

    /** C0-10 (achado L do F-036): sem o host `chamadas` no manifesto, o link do aviso da chamada não chegava ao app. */
    @Test
    fun `intent de chamada recebida resolve MainActivity e corresponde ao destino da chamada`() {
        val intent = intentPara("frila://chamadas/chamada-9")

        assertEquals(
            ComponentName(contexto, MainActivity::class.java),
            intent.resolveActivity(contexto.packageManager),
        )
        assertTrue(
            destino(RotasChamadaProfissional.RECEBIDA, RotasChamadaProfissional.DEEP_LINK_RECEBIDA)
                .hasDeepLink(intent.data!!),
        )
    }

    /** O toque num push entra pela `EntradaDoAvisoActivity`, não exportada: `frila://aviso` não tem filtro no app. */
    @Test
    fun `frila aviso nao abre o app por filtro, e a entrada do aviso nao e exportada`() {
        val implicito = Intent(Intent.ACTION_VIEW, Uri.parse("frila://aviso?tipo=vaga")).setPackage(contexto.packageName)

        assertNull(implicito.resolveActivity(contexto.packageManager))
        val entrada = contexto.packageManager.getActivityInfo(ComponentName(contexto, EntradaDoAvisoActivity::class.java), 0)
        assertFalse(entrada.exported)
    }

    @Test
    fun `o link do aviso leva o tipo e os ids, e so ele com tipo vira aviso`() {
        assertEquals(
            AvisoDoToque("cancelamento", vagaId = "v1", posicaoId = "p1"),
            avisoDoLink("frila://aviso?tipo=cancelamento&vaga_id=v1&posicao_id=p1"),
        )
        assertNull(avisoDoLink("frila://vagas/v1"))
        assertNull(avisoDoLink("frila://aviso?vaga_id=v1"))
        assertNull(avisoDoLink(null))
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
