package br.com.frila.feature.entrada.entrada

import android.provider.Settings
import androidx.annotation.DrawableRes
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import br.com.frila.core.designsystem.abertura.LocalAberturaCobrindo
import br.com.frila.feature.entrada.R
import kotlin.math.PI
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * A arte da T6 no desenho do Fabrício: a Turma, a chave e o copo, soltos, sem mancha atrás, em três camadas (a Turma
 * atrás; o copo, na mão do cozinheiro, e a chave, no alto, na frente). O quadro é o da arte da Turma, 1376 x 880
 * unidades; o copo e a chave ficam nas posições exatas da arte original.
 *
 * **Entrada.** Quando a abertura sai de cima ([LocalAberturaCobrindo]), as camadas entram em sequência: a Turma
 * esmaece subindo um pouco, e o copo e a chave chegam depois, crescendo com uma pequena sobra. Acontece uma vez por
 * montagem da tela; voltar da tela do código não repete.
 *
 * **Parada**, a chave e o copo flutuam devagar e fora de fase. Com as animações do sistema desligadas ("reduzir
 * movimento"), nada se desloca: a entrada é só o esmaecimento em sequência e a arte fica parada.
 *
 * O paralaxe pelo sensor do aparelho (a versão do iOS) fica desligado: aqui não se lê sensor nenhum.
 *
 * Decorativa: o leitor de tela pula a arte.
 */
@Composable
fun IlustracaoDeBoasVindas(modifier: Modifier = Modifier) {
    val cobrindo = LocalAberturaCobrindo.current
    val contexto = LocalContext.current
    val comMovimento = remember {
        Settings.Global.getFloat(contexto.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) != 0f
    }
    // Uma vez por montagem: guardado para a volta da tela seguinte não repetir a entrada.
    var concluida by rememberSaveable { mutableStateOf(false) }
    val tempo = remember { Animatable(if (concluida) EntradaDaArte.DURACAO else -1f) }

    LaunchedEffect(cobrindo) {
        if (cobrindo || concluida) return@LaunchedEffect
        tempo.snapTo(0f)
        tempo.animateTo(EntradaDaArte.DURACAO, tween((EntradaDaArte.DURACAO * 1000).toInt(), easing = LinearEasing))
        concluida = true
    }

    val flutuando = comMovimento && !cobrindo
    // Flutuação: ±1,2% da altura, em 3,6 s (a chave) e 4,2 s (o copo), fora de fase.
    val ondaDaChave = rememberOnda(flutuando, periodoMs = 3600, fase = 0f)
    val ondaDoCopo = rememberOnda(flutuando, periodoMs = 4200, fase = 1.3f)

    Box(
        modifier = modifier
            .fillMaxWidth()
            .clearAndSetSemantics { },
        contentAlignment = Alignment.TopCenter,
    ) {
        BoxWithConstraints(
            modifier = Modifier
                .widthIn(max = ALTURA_MAXIMA * PROPORCAO)
                .fillMaxWidth()
                .aspectRatio(PROPORCAO)
                .esmaecerABase(),
        ) {
            val w = maxWidth
            val h = maxHeight
            val alturaPx = with(LocalDensity.current) { h.toPx() }
            val larguraPx = with(LocalDensity.current) { w.toPx() }

            fun peca(x: Float, y: Float, largura: Float, altura: Float): Modifier =
                Modifier
                    .offset(x = w * (x / QUADRO_L), y = h * (y / QUADRO_A))
                    .size(w * (largura / QUADRO_L), h * (altura / QUADRO_A))

            Camada(
                R.drawable.turma_boas_vindas, peca(0f, 0f, QUADRO_L, QUADRO_A), larguraPx,
                { tempo.value }, ATRASO_DA_TURMA, 0.55f, 14f, 0.96f, sobra = false, comMovimento = comMovimento,
            )
            Camada(
                R.drawable.turma_copo, peca(469.15f, 59.48f, 74f, 99f), larguraPx * 74f / QUADRO_L,
                { tempo.value }, ATRASO_DO_COPO, 0.5f, 18f, 0.6f, sobra = true, comMovimento = comMovimento,
                flutuacaoPx = { 0.012f * ondaDoCopo() * alturaPx },
            )
            Camada(
                R.drawable.turma_chave, peca(787f, 1f, 113f, 131f), larguraPx * 113f / QUADRO_L,
                { tempo.value }, ATRASO_DA_CHAVE, 0.5f, 18f, 0.6f, sobra = true, comMovimento = comMovimento,
                flutuacaoPx = { 0.012f * ondaDaChave() * alturaPx },
            )
        }
    }
}

private val SemOnda: () -> Float = { 0f }

/** Uma onda de -1 a 1 com o período dado; sem `ativa` nem o relógio infinito existe (parada, não gasta quadro). */
@Composable
private fun rememberOnda(ativa: Boolean, periodoMs: Int, fase: Float): () -> Float {
    if (!ativa) return SemOnda
    val relogio = rememberInfiniteTransition(label = "flutuacao-da-arte")
    val angulo = relogio.animateFloat(
        initialValue = 0f,
        targetValue = (2 * PI).toFloat(),
        animationSpec = infiniteRepeatable(tween(periodoMs, easing = LinearEasing), RepeatMode.Restart),
        label = "onda",
    )
    return { sin(angulo.value + fase) }
}

private const val QUADRO_L = 1376f
private const val QUADRO_A = 880f
private const val PROPORCAO = QUADRO_L / QUADRO_A
private val ALTURA_MAXIMA: Dp = 176.dp
private const val ATRASO_DA_TURMA = 0f
private const val ATRASO_DO_COPO = 0.22f
private const val ATRASO_DA_CHAVE = 0.32f

/**
 * O estado de cada camada na entrada: a Turma primeiro, em 0,55 s, saindo rápido e assentando devagar; o copo 0,22 s
 * depois e a chave 0,32 s depois, em 0,5 s, crescendo com uma sobra pequena (curva com recuo), porque são os objetos
 * que "chegam" à cena. Em segundos desde o começo da entrada; antes dela (negativo) tudo fica invisível.
 */
internal object EntradaDaArte {
    const val DURACAO = 0.82f

    class Estado(val opacidade: Float, val subida: Float, val escala: Float)

    fun camada(
        t: Float,
        atraso: Float,
        duracao: Float,
        subida: Float,
        escalaInicial: Float,
        sobra: Boolean,
        comMovimento: Boolean,
    ): Estado {
        val x = ((t - atraso) / duracao).coerceIn(0f, 1f)
        // Sai rápido e assenta devagar (cúbica); a escala dos objetos passa um pouco de 1 e volta.
        val suave = 1 - (1 - x).pow(3)
        val comSobra = run {
            val c1 = 1.4f
            val c3 = c1 + 1
            1 + c3 * (x - 1).pow(3) + c1 * (x - 1).pow(2)
        }
        val opacidade = minOf(x / 0.6f, 1f)
        if (!comMovimento) return Estado(opacidade, 0f, 1f)
        return Estado(
            opacidade = opacidade,
            subida = subida * (1 - suave),
            escala = escalaInicial + (1 - escalaInicial) * (if (sobra) comSobra else suave),
        )
    }
}

@Composable
private fun Camada(
    @DrawableRes recurso: Int,
    modifier: Modifier,
    larguraAlvoPx: Float,
    tempo: () -> Float,
    atraso: Float,
    duracao: Float,
    subida: Float,
    escalaInicial: Float,
    sobra: Boolean,
    comMovimento: Boolean,
    flutuacaoPx: () -> Float = { 0f },
) {
    val imagem = rememberImagemAmostrada(recurso, larguraAlvoPx.roundToInt()) ?: return
    Image(
        bitmap = imagem,
        contentDescription = null,
        contentScale = ContentScale.FillBounds,
        modifier = modifier.graphicsLayer {
            val estado = EntradaDaArte.camada(tempo(), atraso, duracao, subida, escalaInicial, sobra, comMovimento)
            alpha = estado.opacidade
            translationY = (estado.subida * density) + flutuacaoPx()
            scaleX = estado.escala
            scaleY = estado.escala
        },
    )
}

/**
 * A base esmaece no fundo da tela: a figura não termina num corte reto. Opaco até 80% da altura; dali até a base, cai
 * para zero numa curva de suavidade dupla (6t⁵ − 15t⁴ + 10t³): a velocidade e a aceleração começam e terminam em zero,
 * então não há marca onde o esmaecimento começa nem onde ele termina. 24 paradas para não formar faixas.
 */
private fun Modifier.esmaecerABase(): Modifier = this
    .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
    .drawWithContent {
        drawContent()
        drawRect(brush = MascaraDaBase, blendMode = BlendMode.DstIn)
    }

private val MascaraDaBase: Brush = Brush.verticalGradient(
    colorStops = (
        listOf(0f to Color.Black) + (0..24).map { passo ->
            val t = passo / 24f
            val opacidade = 1 - t * t * t * (t * (t * 6 - 15) + 10)
            (0.80f + 0.20f * t) to Color.Black.copy(alpha = opacidade)
        }
        ).toTypedArray(),
)
