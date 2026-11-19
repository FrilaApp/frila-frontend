package br.com.frila.core.designsystem.abertura

import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned

/**
 * Verdadeiro enquanto a abertura cobre o app: o rótulo de destino fica escondido, porque quem o mostra é a abertura,
 * em voo; e a arte da tela de entrada espera a abertura sair para entrar.
 */
val LocalAberturaCobrindo = compositionLocalOf { false }

/**
 * Onde o rótulo da abertura pousa: o primeiro rótulo marcado no conteúdo. Guarda as coordenadas, e não os limites,
 * porque o app cresce por baixo da abertura (94% a 100%) e o alvo anda junto: a abertura consulta a cada quadro.
 */
internal class DestinoDoRotuloDaAbertura {
    private var coordenadas: LayoutCoordinates? = null

    fun marcar(novas: LayoutCoordinates?) {
        coordenadas = novas
    }

    fun desmarcar(daqui: LayoutCoordinates?) {
        if (coordenadas === daqui) coordenadas = null
    }

    /** Os limites do rótulo na raiz da janela, agora; nulo se a tela do rótulo não está montada. */
    fun limitesNaRaiz(): Rect? = coordenadas?.takeIf { it.isAttached }?.boundsInRoot()
}

internal val LocalDestinoDoRotuloDaAbertura = staticCompositionLocalOf<DestinoDoRotuloDaAbertura?> { null }

/**
 * Marca este rótulo como o lugar onde o rótulo da abertura pousa, e o esconde enquanto ela cobre. Fora de uma
 * [AberturaAnimada] não faz nada.
 */
fun Modifier.destinoDoRotuloDaAbertura(): Modifier = composed {
    val destino = LocalDestinoDoRotuloDaAbertura.current
    val cobrindo = LocalAberturaCobrindo.current
    val minhas = remember { arrayOfNulls<LayoutCoordinates>(1) }
    DisposableEffect(destino) {
        onDispose { destino?.desmarcar(minhas[0]) }
    }
    this
        .onGloballyPositioned {
            minhas[0] = it
            destino?.marcar(it)
        }
        .alpha(if (cobrindo) 0f else 1f)
}
