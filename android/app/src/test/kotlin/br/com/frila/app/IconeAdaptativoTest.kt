package br.com.frila.app

import android.app.Application
import android.content.Context
import android.content.pm.ApplicationInfo
import android.graphics.drawable.AdaptiveIconDrawable
import androidx.core.content.ContextCompat
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.core.context.stopKoin
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Validação do ícone adaptativo e camada monocromática (RNF10, Cartão 63).
 * Testa a integridade do asset para Android 8.0+ (API 28+) e a camada monocromática no Android 13+ (API 33+).
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = Application::class)
class IconeAdaptativoTest {

    private val context: Context = ApplicationProvider.getApplicationContext()

    @After
    fun tearDown() {
        stopKoin()
    }

    @Test
    @Config(sdk = [35])
    fun `icone adaptativo principal contem background foreground e camada monocromatica na API 35`() {
        val drawable = ContextCompat.getDrawable(context, R.mipmap.ic_launcher)
        assertNotNull("ic_launcher deve ser encontrado", drawable)
        assertTrue("ic_launcher deve ser AdaptiveIconDrawable", drawable is AdaptiveIconDrawable)

        val adaptive = drawable as AdaptiveIconDrawable
        assertNotNull("background não pode ser nulo", adaptive.background)
        assertNotNull("foreground não pode ser nulo", adaptive.foreground)
        assertNotNull("monochrome layer não pode ser nula no Android 13+", adaptive.monochrome)
    }

    @Test
    @Config(sdk = [35])
    fun `icone adaptativo redondo contem background foreground e camada monocromatica na API 35`() {
        val drawable = ContextCompat.getDrawable(context, R.mipmap.ic_launcher_round)
        assertNotNull("ic_launcher_round deve ser encontrado", drawable)
        assertTrue("ic_launcher_round deve ser AdaptiveIconDrawable", drawable is AdaptiveIconDrawable)

        val adaptive = drawable as AdaptiveIconDrawable
        assertNotNull("background não pode ser nulo", adaptive.background)
        assertNotNull("foreground não pode ser nulo", adaptive.foreground)
        assertNotNull("monochrome layer não pode ser nula no Android 13+", adaptive.monochrome)
    }

    @Test
    @Config(sdk = [28])
    fun `icone adaptativo e suportado no Android 9 API 28 com fallback seguro`() {
        val drawable = ContextCompat.getDrawable(context, R.mipmap.ic_launcher)
        assertNotNull("ic_launcher deve ser encontrado", drawable)
        assertTrue("ic_launcher deve ser AdaptiveIconDrawable", drawable is AdaptiveIconDrawable)

        val adaptive = drawable as AdaptiveIconDrawable
        assertNotNull("background não pode ser nulo", adaptive.background)
        assertNotNull("foreground não pode ser nulo", adaptive.foreground)
    }

    @Test
    @Config(sdk = [35])
    fun `manifesto declara icon e roundIcon apontando para mipmap ic_launcher`() {
        val appInfo = context.packageManager.getApplicationInfo(context.packageName, 0)
        assertEquals(R.mipmap.ic_launcher, appInfo.icon)
        assertEquals(R.mipmap.ic_launcher_round, roundIconRes(appInfo))
    }

    @Test
    @Config(sdk = [35])
    fun `roundIcon do manifesto resolve para AdaptiveIconDrawable`() {
        val appInfo = context.packageManager.getApplicationInfo(context.packageName, 0)
        val recurso = roundIconRes(appInfo)
        assertEquals(R.mipmap.ic_launcher_round, recurso)
        assertTrue(
            "roundIcon deve resolver para AdaptiveIconDrawable",
            ContextCompat.getDrawable(context, recurso) is AdaptiveIconDrawable,
        )
    }

    @Test
    @Config(sdk = [28])
    fun `icone redondo e AdaptiveIconDrawable tambem na API 28`() {
        // MEDIDO: em API 28 o Robolectric não reflete o roundIcon do manifesto em ApplicationInfo
        // (roundIconRes sai igual a icon), então a declaração é provada só na API 35 acima.
        val drawable = ContextCompat.getDrawable(context, R.mipmap.ic_launcher_round)
        assertTrue("ic_launcher_round deve ser AdaptiveIconDrawable", drawable is AdaptiveIconDrawable)
    }

    /** `roundIconRes` não é API pública do SDK; lido por reflexão a partir do manifesto empacotado. */
    private fun roundIconRes(appInfo: ApplicationInfo): Int =
        ApplicationInfo::class.java.getField("roundIconRes").getInt(appInfo)
}
