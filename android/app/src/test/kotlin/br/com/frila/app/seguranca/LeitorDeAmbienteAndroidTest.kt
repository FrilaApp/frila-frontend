package br.com.frila.app.seguranca

import android.app.Application
import android.content.Context
import br.com.frila.app.BuildConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * RN15 (cartão Cdv0sS5w): prova MEDIDA de que [LeitorDeAmbienteAndroid] lê de verdade
 * `Build.*`/`File`/`PackageManager` sem lançar, sob o runtime Android simulado do Robolectric —
 * a decisão de root/emulador/assinatura em si é testada em JVM pura contra o dublê de
 * `LeitorDeAmbiente`, em `VerificadorDeIntegridadeTest` (`:core:seguranca`).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class LeitorDeAmbienteAndroidTest {

    private lateinit var contexto: Context
    private lateinit var leitor: LeitorDeAmbienteAndroid

    @Before
    fun preparar() {
        contexto = RuntimeEnvironment.getApplication()
        leitor = LeitorDeAmbienteAndroid(contexto)
    }

    @Test
    fun `arquivoExiste retorna false para caminho inexistente sem lancar`() {
        assertFalse(leitor.arquivoExiste("/caminho/que/nao/existe/su"))
    }

    @Test
    fun `leituras de build nunca retornam nulo`() {
        assertNotNull(leitor.buildTags())
        assertNotNull(leitor.buildFingerprint())
        assertNotNull(leitor.buildHardware())
        assertNotNull(leitor.buildProduct())
    }

    @Test
    fun `isDebug reflete BuildConfig DEBUG`() {
        assertEquals(BuildConfig.DEBUG, leitor.isDebug())
    }

    @Test
    fun `assinaturaEsperada e nula ate haver um hash de release embutido`() {
        assertEquals(null, leitor.assinaturaEsperada())
    }

    @Test
    fun `assinaturasDoPacote nao lanca mesmo sob o PackageManager simulado do Robolectric`() {
        val assinaturas = leitor.assinaturasDoPacote()
        assertNotNull(assinaturas)
    }
}
