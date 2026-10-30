package br.com.frila.app.conectividade

import android.app.Application
import android.content.Context
import android.net.NetworkCapabilities
import br.com.frila.core.rede.StatusConectividade
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlin.reflect.full.memberFunctions
import kotlin.reflect.jvm.isAccessible
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * RNF01 (cartão 9Q0sJIzW): prova medida de que [MonitorDeConectividadeAndroid] lê de verdade
 * `ConnectivityManager`/`NetworkCapabilities` sob o runtime Android simulado do Robolectric —
 * sem rede nenhuma configurada, o `ConnectivityManager` simulado não tem `activeNetwork`, então
 * o estado inicial correto é `SEM_CONEXAO` (a decisão de CONECTADO/SEM_CONEXAO em si, para cada
 * combinação de `NetworkCapabilities`, é testada em JVM pura via dublê — ver
 * `MonitorDeConectividadeTest` em `:core:rede`).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class MonitorDeConectividadeAndroidTest {

    private lateinit var contexto: Context
    private lateinit var escopo: TestScope

    @Before
    fun preparar() {
        contexto = RuntimeEnvironment.getApplication()
        escopo = TestScope(StandardTestDispatcher())
    }

    @Test
    fun `estado inicial sem rede ativa e SEM_CONEXAO`() {
        val monitor = MonitorDeConectividadeAndroid(contexto, escopo)

        assertEquals(StatusConectividade.SEM_CONEXAO, monitor.status.value)
    }

    @Test
    fun `construir e ler o status nao lanca sob o ConnectivityManager simulado`() {
        val monitor = MonitorDeConectividadeAndroid(contexto, escopo)
        assertNotNull(monitor.status.value)
    }

    // MEDIDO (Shisui, prova de mutação): statusDeCapacidades() só é alcançado em runtime quando
    // há uma rede ativa com capabilities — o ConnectivityManager simulado do Robolectric não
    // expõe isso facilmente. A reflexão aqui chama a MESMA função privada de produção, não uma
    // cópia, para provar o filtro rigoroso INTERNET + VALIDATED (evita falso positivo de captive
    // portal) sem depender da infraestrutura de shadow de rede do Robolectric.

    @Test
    fun `internet e validated resulta em CONECTADO`() {
        val capacidades = capacidadesCom(internet = true, validated = true)
        assertEquals(StatusConectividade.CONECTADO, chamarStatusDeCapacidades(capacidades))
    }

    @Test
    fun `internet sem validated (captive portal) resulta em SEM_CONEXAO`() {
        val capacidades = capacidadesCom(internet = true, validated = false)
        assertEquals(StatusConectividade.SEM_CONEXAO, chamarStatusDeCapacidades(capacidades))
    }

    @Test
    fun `validated sem internet resulta em SEM_CONEXAO`() {
        val capacidades = capacidadesCom(internet = false, validated = true)
        assertEquals(StatusConectividade.SEM_CONEXAO, chamarStatusDeCapacidades(capacidades))
    }

    private fun capacidadesCom(internet: Boolean, validated: Boolean): NetworkCapabilities {
        val capacidades = mockk<NetworkCapabilities>()
        every { capacidades.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) } returns internet
        every { capacidades.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) } returns validated
        return capacidades
    }

    private fun chamarStatusDeCapacidades(capacidades: NetworkCapabilities): StatusConectividade {
        val monitor = MonitorDeConectividadeAndroid(contexto, escopo)
        val funcao = MonitorDeConectividadeAndroid::class.memberFunctions
            .first { it.name == "statusDeCapacidades" }
            .apply { isAccessible = true }
        return funcao.call(monitor, capacidades) as StatusConectividade
    }
}
