package br.com.frila.core.designsystem.componentes

import androidx.compose.foundation.layout.sizeIn
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.drawOutline
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsPropertyKey
import androidx.compose.ui.semantics.SemanticsPropertyReceiver
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.shape.CircleShape
import br.com.frila.core.designsystem.tema.FrilaMetricas
import br.com.frila.core.designsystem.tema.FrilaTema

/**
 * Contrato semântico, de toque e de foco dos chips que selecionam uma única opção de filtro.
 * O chip é cápsula (tudo que se toca é cápsula), e o contorno de foco acompanha essa forma.
 */
fun Modifier.semanticaDeFiltro(selecionado: Boolean): Modifier =
    sizeIn(
        minWidth = FrilaMetricas.alvoMinimo,
        minHeight = FrilaMetricas.alvoMinimo,
    )
        .focoAcessivelFrila(forma = CircleShape)
        .semantics {
            role = Role.RadioButton
            stateDescription = if (selecionado) "selecionado" else "não selecionado"
        }

/**
 * Chave semântica só para teste: expõe se o contorno de `focoAcessivelFrila` está
 * desenhado agora, sem depender de captura de pixel (que trava sob Robolectric neste
 * ambiente — MEDIDO, `androidx.compose.ui.test.captureToImage()` gera
 * `ComposeTimeoutException`). Não altera o anúncio de leitores de tela: é lida só via
 * `SemanticsNode.config` em teste, nunca por serviços de acessibilidade reais.
 */
val ContornoDeFocoVisivelFrila = SemanticsPropertyKey<Boolean>("ContornoDeFocoVisivelFrila")
private var SemanticsPropertyReceiver.contornoDeFocoVisivelFrila by ContornoDeFocoVisivelFrila

/**
 * Indicador visual de foco acessível para teclado físico/D-Pad (RNF10, WCAG 2.1 §1.4.11 e
 * WCAG 2.2 §2.4.13 — contraste mínimo 3,0:1 do indicador de foco contra o fundo adjacente).
 *
 * O contorno é de 2dp em TINTA, como o foco dos campos no desenho do Fabrício, e é desenhado
 * **fora** dos limites do componente, com uma folga (`distanciaExterna`) entre a borda do componente
 * e o traço. Assim ele é sempre medido contra o fundo da tela ou a superfície por trás (tinta contra
 * `fundo`: 17:1 no claro e no escuro), nunca contra o preenchimento do próprio componente — nem
 * contra o laranja do `BotaoPrimario`.
 *
 * `forma` deve espelhar a forma real do componente (cartão de raio 24, botão e chip em cápsula) para
 * o contorno acompanhar o desenho, não um retângulo genérico. Liga/desliga via `onFocusChanged`; não
 * substitui nem interfere no ripple nativo do Material 3 — os dois convivem no mesmo componente.
 */
fun Modifier.focoAcessivelFrila(
    forma: Shape,
    espessura: Dp = 2.dp,
    distanciaExterna: Dp = 2.dp,
): Modifier = composed {
    var focado by remember { mutableStateOf(false) }
    val cor = FrilaTema.cores.tinta

    this
        .onFocusChanged { estado -> focado = estado.isFocused }
        .semantics { contornoDeFocoVisivelFrila = focado }
        .drawWithContent {
            drawContent()
            if (focado) {
                val expansaoPx = distanciaExterna.toPx()
                val espessuraPx = espessura.toPx()
                val tamanhoExpandido = Size(
                    width = size.width + 2 * expansaoPx,
                    height = size.height + 2 * expansaoPx,
                )
                val contorno = forma.createOutline(tamanhoExpandido, layoutDirection, this)

                translate(left = -expansaoPx, top = -expansaoPx) {
                    drawOutline(
                        outline = contorno,
                        color = cor,
                        style = Stroke(width = espessuraPx),
                    )
                }
            }
        }
}
