package br.com.frila.feature.estabelecimento

import android.content.Context
import android.location.Address
import android.location.Geocoder
import android.os.Build
import java.io.IOException
import java.util.Locale
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext

/** Um endereço achado pela busca: o texto para o campo, o ponto e a Região Administrativa, se o texto a revelou. */
data class EnderecoEncontrado(
    val texto: String,
    val latitude: Double,
    val longitude: Double,
    val regiaoAdministrativa: String?,
)

/** A busca de endereço do cadastro (iOS `buscarEndereco`). Atrás de uma interface para o ViewModel não depender do sistema. */
interface BuscadorDeEndereco {
    /** `false` quando o aparelho não tem serviço de geocodificação: a tela então só oferece as coordenadas digitadas. */
    val disponivel: Boolean

    /** Falha de serviço ou de rede é uma exceção; "nada achado" é uma lista vazia. */
    suspend fun buscar(consulta: String): List<EnderecoEncontrado>
}

/**
 * [BuscadorDeEndereco] sobre o `android.location.Geocoder` da plataforma: sem dependência nova nem chave de API. Nem todo aparelho
 * tem backend para ele (`Geocoder.isPresent`). A busca é inclinada para o Distrito Federal, como a do iOS.
 *
 * [casarRegiao] é o `GeocodificadorDfOffline.casarRegiaoAdministrativa`, injetado para o módulo não depender do `core:localizacao`.
 */
class BuscadorDeEnderecoDoSistema(
    private val contexto: Context,
    private val casarRegiao: (String) -> String?,
) : BuscadorDeEndereco {

    override val disponivel: Boolean get() = Geocoder.isPresent()

    override suspend fun buscar(consulta: String): List<EnderecoEncontrado> {
        val geocoder = Geocoder(contexto, Locale.forLanguageTag("pt-BR"))
        val enderecos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            suspendCancellableCoroutine { continuacao ->
                geocoder.getFromLocationName(
                    consulta, MAXIMO, SUL, OESTE, NORTE, LESTE,
                    object : Geocoder.GeocodeListener {
                        override fun onGeocode(addresses: MutableList<Address>) = continuacao.resume(addresses)
                        override fun onError(errorMessage: String?) = continuacao.resumeWithException(IOException(errorMessage))
                    },
                )
            }
        } else {
            // Antes do 33 a chamada bloqueia e o sistema lança IOException sem serviço ou sem rede.
            withContext(Dispatchers.IO) {
                @Suppress("DEPRECATION")
                geocoder.getFromLocationName(consulta, MAXIMO, SUL, OESTE, NORTE, LESTE).orEmpty()
            }
        }
        return enderecos.mapNotNull { paraEnderecoEncontrado(it, casarRegiao) }
    }

    private companion object {
        const val MAXIMO = 5

        // O retângulo do Distrito Federal (o mesmo `regiaoDaBusca` do iOS): só inclina a busca, não filtra.
        const val SUL = -16.05
        const val OESTE = -48.30
        const val NORTE = -15.50
        const val LESTE = -47.30
    }
}

/** `null` se o endereço não tem ponto nem texto para mostrar. A Região Administrativa segue a ordem do iOS (`inferirRegiaoAdministrativa`). */
internal fun paraEnderecoEncontrado(endereco: Address, casarRegiao: (String) -> String?): EnderecoEncontrado? {
    if (!endereco.hasLatitude() || !endereco.hasLongitude()) return null
    val linhas = (0..endereco.maxAddressLineIndex).mapNotNull { endereco.getAddressLine(it)?.trim()?.takeIf(String::isNotEmpty) }
    val texto = linhas.firstOrNull()
        ?: listOfNotNull(endereco.featureName, endereco.subLocality, endereco.locality, endereco.adminArea)
            .map(String::trim).filter(String::isNotEmpty).distinct().joinToString(", ").ifEmpty { return null }
    val candidatos = listOf(endereco.subLocality, endereco.subAdminArea, linhas.joinToString(", "), endereco.featureName)
    val regiao = candidatos.firstNotNullOfOrNull { c -> c?.takeIf(String::isNotBlank)?.let(casarRegiao) }
    return EnderecoEncontrado(texto, endereco.latitude, endereco.longitude, regiao)
}
