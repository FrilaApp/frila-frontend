package br.com.frila.core.designsystem.componentes

import android.content.ActivityNotFoundException
import android.content.ContextWrapper
import android.content.Intent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * Zm76EAz0: o [abrirNoMapa] de verdade. Sem app que trate `geo:`, ele cai no Google Maps na web com a mesma consulta; o
 * [VerNoMapaTest] injeta o `abrir` e não passava por aqui.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class AbrirNoMapaTest {

    /** Guarda o que o app pediu para abrir; recusa (como o sistema, sem app) os esquemas em [semApp]. */
    private class Aparelho(private val semApp: Set<String>) : ContextWrapper(RuntimeEnvironment.getApplication()) {
        val pedidos = mutableListOf<String>()

        override fun startActivity(intent: Intent) {
            val dado = intent.data
            pedidos += dado.toString()
            if (dado?.scheme in semApp) throw ActivityNotFoundException("sem app para ${dado?.scheme}")
        }
    }

    @Test
    fun `sem app de mapas abre o Google Maps na web com o endereco por extenso`() {
        val aparelho = Aparelho(semApp = setOf("geo"))

        val abriu = abrirNoMapa(aparelho, linkDoMapa("SQN 108"))

        assertTrue(abriu)
        assertEquals(
            listOf("geo:0,0?q=SQN%20108", "https://www.google.com/maps/search/?api=1&query=SQN%20108"),
            aparelho.pedidos,
        )
    }

    @Test
    fun `com coordenadas a web leva so o endereco, codificado como no geo`() {
        val aparelho = Aparelho(semApp = setOf("geo"))

        assertTrue(abrirNoMapa(aparelho, linkDoMapa("Bar do Zé, CLN 201", latitude = -15.7942, longitude = -47.8822)))

        assertEquals(
            "https://www.google.com/maps/search/?api=1&query=Bar%20do%20Z%C3%A9%2C%20CLN%20201",
            aparelho.pedidos.last(),
        )
    }

    @Test
    fun `com app de mapas abre so o geo, sem ir a web`() {
        val aparelho = Aparelho(semApp = emptySet())

        assertTrue(abrirNoMapa(aparelho, linkDoMapa("SQN 108")))

        assertEquals(listOf("geo:0,0?q=SQN%20108"), aparelho.pedidos)
    }

    @Test
    fun `sem app de mapas e sem navegador devolve false depois de tentar os dois`() {
        val aparelho = Aparelho(semApp = setOf("geo", "https"))

        assertFalse(abrirNoMapa(aparelho, linkDoMapa("SQN 108")))

        assertEquals(2, aparelho.pedidos.size)
    }
}
