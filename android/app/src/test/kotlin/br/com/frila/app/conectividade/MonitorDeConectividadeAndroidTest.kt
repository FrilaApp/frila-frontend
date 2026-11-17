package br.com.frila.app.conectividade

import android.app.Application
import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import br.com.frila.core.rede.StatusConectividade
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlin.reflect.full.memberFunctions
import kotlin.reflect.jvm.isAccessible
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
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

    // Ressalva CallbackFlow do Shisui (PR #604): exercita de verdade o callback registrado no
    // ConnectivityManager simulado do Robolectric — onCapabilitiesChanged/onLost mudando o
    // StateFlow de produção, e unregisterNetworkCallback acontecendo ao cancelar o escopo após
    // o timeout de WhileSubscribed(5_000L) (RNF04).
    @Test
    fun `callback registrado reage a onCapabilitiesChanged e onLost, e e desregistrado apos o timeout do escopo`() = kotlinx.coroutines.test.runTest {
        val gerenciador = contexto.getSystemService(ConnectivityManager::class.java)
        val shadow = Shadows.shadowOf(gerenciador)
        val escopoDoMonitor = kotlinx.coroutines.CoroutineScope(coroutineContext + kotlinx.coroutines.Job())
        val monitor = MonitorDeConectividadeAndroid(contexto, escopoDoMonitor)

        val coletor = launch { monitor.status.collect { } }
        advanceUntilIdle()

        assertTrue("callback deveria estar registrado enquanto há assinante", shadow.networkCallbacks.isNotEmpty())
        val callback = shadow.networkCallbacks.first()
        val rede = mockk<Network>(relaxed = true)

        callback.onCapabilitiesChanged(rede, capacidadesCom(internet = true, validated = true))
        advanceUntilIdle()
        assertEquals(StatusConectividade.CONECTADO, monitor.status.value)

        callback.onLost(rede)
        advanceUntilIdle()
        assertEquals(StatusConectividade.SEM_CONEXAO, monitor.status.value)

        coletor.cancel()
        advanceTimeBy(5_001L)
        advanceUntilIdle()
        assertTrue(
            "unregisterNetworkCallback deveria ter sido chamado após o timeout de WhileSubscribed(5s)",
            shadow.networkCallbacks.isEmpty(),
        )
        escopoDoMonitor.cancel()
    }

    // C0-5: o que barra o pedido de rede é a leitura do sistema na hora, não o valor guardado do fluxo.

    @Test
    fun `sem ninguem observando, estaConectado acompanha a rede na hora do pedido`() {
        var capacidades: NetworkCapabilities? = null
        val monitor = MonitorDeConectividadeAndroid(contexto, escopo, capacidadesDaRedeAtiva = { capacidades })
        assertEquals(false, monitor.estaConectado)

        // A rede volta com o app em segundo plano: ninguém observa o fluxo, então o status guardado não muda.
        capacidades = capacidadesCom(internet = true, validated = true)

        assertEquals(StatusConectividade.SEM_CONEXAO, monitor.status.value)
        assertEquals(true, monitor.estaConectado)
    }

    @Test
    fun `rede com internet e sem a validacao do Google nao barra o pedido`() {
        val monitor = MonitorDeConectividadeAndroid(
            contexto,
            escopo,
            capacidadesDaRedeAtiva = { capacidadesCom(internet = true, validated = false) },
        )

        assertEquals(true, monitor.estaConectado)
        // O aviso da tela continua rigoroso (portal de login não conta como conectado).
        assertEquals(StatusConectividade.SEM_CONEXAO, monitor.status.value)
    }

    @Test
    fun `sem rede ativa ou sem internet o pedido e barrado na hora`() {
        val semRede = MonitorDeConectividadeAndroid(contexto, escopo, capacidadesDaRedeAtiva = { null })
        val semInternet = MonitorDeConectividadeAndroid(
            contexto,
            escopo,
            capacidadesDaRedeAtiva = { capacidadesCom(internet = false, validated = false) },
        )

        assertEquals(false, semRede.estaConectado)
        assertEquals(false, semInternet.estaConectado)
    }

    @Test
    fun `falha ao consultar o sistema nao barra o pedido`() {
        val monitor = MonitorDeConectividadeAndroid(
            contexto,
            escopo,
            capacidadesDaRedeAtiva = { throw SecurityException("sem acesso ao estado da rede") },
        )

        assertEquals(true, monitor.estaConectado)
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
