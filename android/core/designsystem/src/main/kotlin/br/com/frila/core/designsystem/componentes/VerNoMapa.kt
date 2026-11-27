package br.com.frila.core.designsystem.componentes

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import java.math.BigDecimal
import java.math.RoundingMode
import java.net.URLEncoder

/** Os textos do atalho para o app de mapas. */
object TextosVerNoMapa {
    const val BOTAO = "Ver no mapa"
    const val SEM_APP = "Não encontramos um app para abrir o mapa."

    /** O mesmo identificador de acessibilidade do iOS (`TelaMeuTurno.swift`). */
    const val TAG = "atalho-mapas"
}

/**
 * O link `geo:` que abre [texto] no app de mapas. Com [latitude] e [longitude], o mapa centra no ponto e procura o
 * texto ali perto (como o `ll` + `q` do iOS); sem elas, `geo:0,0?q=` procura só pelo texto. O texto vai codificado
 * em UTF-8, com `%20` no espaço: vírgula, acento e `&` não quebram a consulta.
 */
fun linkDoMapa(texto: String, latitude: Double? = null, longitude: Double? = null): String {
    val centro = if (latitude != null && longitude != null) "${grau(latitude)},${grau(longitude)}" else "0,0"
    return "geo:$centro?q=${codificar(texto.trim())}"
}

/** Seis casas, ponto decimal e sem notação científica, qualquer que seja o `Locale` do aparelho. */
private fun grau(valor: Double): String = BigDecimal.valueOf(valor).setScale(6, RoundingMode.HALF_UP).toPlainString()

private fun codificar(texto: String): String = URLEncoder.encode(texto, Charsets.UTF_8.name()).replace("+", "%20")

/**
 * Abre [link] (de [linkDoMapa]) no app de mapas. Sem nenhum app que trate `geo:`, tenta o Google Maps na web com a
 * mesma consulta. Devolve `false` se nem o navegador abrir.
 */
fun abrirNoMapa(contexto: Context, link: String): Boolean {
    if (iniciar(contexto, Uri.parse(link))) return true
    val consulta = link.substringAfter("?q=", missingDelimiterValue = "")
    return iniciar(contexto, Uri.parse("https://www.google.com/maps/search/?api=1&query=$consulta"))
}

private fun iniciar(contexto: Context, uri: Uri): Boolean = try {
    contexto.startActivity(Intent(Intent.ACTION_VIEW, uri))
    true
} catch (_: ActivityNotFoundException) {
    false
}

/**
 * "Ver no mapa": link discreto que abre [link] no app de mapas. Se o aparelho não abrir nem o mapa nem o navegador,
 * avisa em vez de não fazer nada.
 */
@Composable
fun BotaoVerNoMapa(
    link: String,
    modifier: Modifier = Modifier,
    abrir: (Context, String) -> Boolean = ::abrirNoMapa,
) {
    val contexto = LocalContext.current
    LinkFrila(
        texto = TextosVerNoMapa.BOTAO,
        aoClicar = {
            if (!abrir(contexto, link)) Toast.makeText(contexto, TextosVerNoMapa.SEM_APP, Toast.LENGTH_SHORT).show()
        },
        modifier = modifier.testTag(TextosVerNoMapa.TAG),
    )
}
