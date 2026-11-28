package br.com.frila.feature.estabelecimento

import android.app.Application
import android.location.Address
import java.util.Locale
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowGeocoder

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class BuscadorDeEnderecoDoSistemaTest {

    // Um casamento mínimo, só para mostrar de qual campo do Address o texto vem; o casamento real tem a suíte dele em core:localizacao.
    private val casar: (String) -> String? = { texto ->
        when {
            "asa sul" in texto.lowercase() -> "Plano Piloto"
            "ceilândia" in texto.lowercase() -> "Ceilândia"
            else -> null
        }
    }

    @After
    fun depois() = ShadowGeocoder.reset()

    private fun endereco(
        linhas: List<String> = emptyList(),
        subLocalidade: String? = null,
        subArea: String? = null,
        nome: String? = null,
        localidade: String? = null,
        ponto: Pair<Double, Double>? = -15.815 to -47.915,
    ) = Address(Locale.forLanguageTag("pt-BR")).apply {
        linhas.forEachIndexed { i, l -> setAddressLine(i, l) }
        this.subLocality = subLocalidade
        this.subAdminArea = subArea
        this.featureName = nome
        this.locality = localidade
        ponto?.let { latitude = it.first; longitude = it.second }
    }

    @Test
    fun `o texto e a primeira linha do endereco e o ponto vem junto`() {
        val achado = paraEnderecoEncontrado(endereco(linhas = listOf("CLS 408 - Asa Sul, Brasília - DF", "Brasil")), casar)!!
        assertEquals("CLS 408 - Asa Sul, Brasília - DF", achado.texto)
        assertEquals(-15.815, achado.latitude, 0.0)
        assertEquals(-47.915, achado.longitude, 0.0)
    }

    @Test
    fun `sem linhas o texto vem dos nomes sem repetir`() {
        val achado = paraEnderecoEncontrado(endereco(nome = "Gama", localidade = "Gama", subLocalidade = "Setor Sul"), casar)!!
        assertEquals("Gama, Setor Sul", achado.texto)
    }

    @Test
    fun `endereco sem ponto ou sem nenhum texto e descartado`() {
        assertNull(paraEnderecoEncontrado(endereco(linhas = listOf("CLS 408"), ponto = null), casar))
        assertNull(paraEnderecoEncontrado(endereco(), casar))
    }

    @Test
    fun `a regiao vem primeiro da sublocalidade, depois da subarea, das linhas e do nome`() {
        assertEquals("Ceilândia", paraEnderecoEncontrado(endereco(linhas = listOf("Rua X, Asa Sul"), subLocalidade = "Ceilândia"), casar)!!.regiaoAdministrativa)
        assertEquals("Ceilândia", paraEnderecoEncontrado(endereco(linhas = listOf("Rua X, Asa Sul"), subArea = "Ceilândia"), casar)!!.regiaoAdministrativa)
        assertEquals("Plano Piloto", paraEnderecoEncontrado(endereco(linhas = listOf("CLS 408, Asa Sul")), casar)!!.regiaoAdministrativa)
        assertEquals("Ceilândia", paraEnderecoEncontrado(endereco(linhas = listOf("Rua X"), nome = "Posto Ceilândia"), casar)!!.regiaoAdministrativa)
        assertNull(paraEnderecoEncontrado(endereco(linhas = listOf("Rua X, Cidade Tal")), casar)!!.regiaoAdministrativa)
    }

    @Test
    fun `disponivel segue o Geocoder isPresent do aparelho`() {
        val contexto = org.robolectric.RuntimeEnvironment.getApplication()
        val buscador = BuscadorDeEnderecoDoSistema(contexto, casar)
        ShadowGeocoder.setIsPresent(true)
        assertTrue(buscador.disponivel)
        ShadowGeocoder.setIsPresent(false)
        assertFalse(buscador.disponivel)
    }
}
