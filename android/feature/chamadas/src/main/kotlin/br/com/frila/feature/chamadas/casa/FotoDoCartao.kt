// TELA PROVISÓRIA: substituir pelo high-fi do Fabrício
package br.com.frila.feature.chamadas.casa

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Baixa a foto de um link e devolve a imagem, ou `null` se não for possível (o cartão mostra a inicial). */
typealias CarregadorDeFoto = suspend (url: String) -> ImageBitmap?

/**
 * Carrega a miniatura pelo link de 1 h da `ler-midia` (`CartaoProfissional.foto_url`, 0.2.90): um GET simples, sem
 * cabeçalho, só por `https`. Qualquer falha (rede, prazo, resposta que não é imagem) devolve `null`; nunca derruba a
 * lista. O app não tinha carregador de imagem por URL e não ganhou dependência nova por causa dele.
 */
internal suspend fun carregarFotoPorUrl(url: String): ImageBitmap? = withContext(Dispatchers.IO) {
    if (!url.startsWith("https://")) return@withContext null
    var conexao: HttpURLConnection? = null
    try {
        conexao = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = PRAZO_DA_FOTO_MS
            readTimeout = PRAZO_DA_FOTO_MS
            instanceFollowRedirects = false
        }
        if (conexao.responseCode != HttpURLConnection.HTTP_OK) return@withContext null
        conexao.inputStream.use { fluxo -> BitmapFactory.decodeStream(fluxo)?.asImageBitmap() }
    } catch (erro: CancellationException) {
        throw erro
    } catch (_: Exception) {
        null
    } finally {
        conexao?.disconnect()
    }
}

private const val PRAZO_DA_FOTO_MS = 10_000

/** A inicial do nome para quando não há foto (ou ela não carregou). */
internal fun inicialDoNome(nome: String): String = nome.trim().firstOrNull()?.uppercase() ?: "?"

/**
 * A foto circular de ~40 dp no cartão da busca: a imagem quando há [fotoUrl] e ela carrega; senão a inicial do nome.
 * Decorativa para o leitor de tela (o nome já está no texto do cartão).
 */
@Composable
internal fun FotoDoCartao(
    id: String,
    nome: String,
    fotoUrl: String?,
    carregar: CarregadorDeFoto,
    modifier: Modifier = Modifier,
) {
    val imagem by produceState<ImageBitmap?>(initialValue = null, fotoUrl) {
        value = if (fotoUrl == null) {
            null
        } else {
            try {
                carregar(fotoUrl)
            } catch (erro: CancellationException) {
                throw erro
            } catch (_: Exception) {
                null
            }
        }
    }
    val recorte = modifier.size(40.dp).clip(CircleShape)
    val carregada = imagem
    if (carregada != null) {
        Image(
            bitmap = carregada,
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = recorte.testTag("busca-foto-$id"),
        )
    } else {
        Box(
            modifier = recorte.background(MaterialTheme.colorScheme.secondaryContainer).testTag("busca-inicial-$id"),
            contentAlignment = Alignment.Center,
        ) {
            Text(inicialDoNome(nome), style = MaterialTheme.typography.titleMedium)
        }
    }
}
