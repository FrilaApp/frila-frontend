package br.com.frila.core.designsystem.abertura

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.ClipOp
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.withTransform
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/** As cores da abertura: o laranja do fundo, o branco do rótulo sobre ele e a tinta com que ele pousa no app. */
internal class CoresDaAbertura(val acao: Color, val sobreAcao: Color, val tinta: Color)

/**
 * Desenho de um quadro da abertura no instante `t` (segundos desde o primeiro quadro), porta do `quadro(em:destino:)`
 * do protótipo do Fabrício. Tudo em pixels; `densidade` converte as medidas que o protótipo dá em pontos.
 *
 * `destino` são os limites, em pixels, do rótulo da tela para onde o rótulo da abertura voa na saída; nulo é a saída
 * simples (o rótulo cresce e some). Com `pulando` o rótulo não voa: a cena esmaece de onde está.
 *
 * O fundo usa `BlendMode.DstOut`: quem chama precisa desenhar numa camada própria (`CompositingStrategy.Offscreen`),
 * para o furo da janela só apagar o laranja da abertura e não o app que está por baixo.
 */
internal fun DrawScope.desenharAbertura(
    t: Double,
    roteiro: RoteiroDaAbertura,
    destino: Rect?,
    pulando: Boolean,
    cores: CoresDaAbertura,
) {
    val tRef = roteiro.tempoDeReferencia(t)

    fun estado(no: Double): QuadroDaAbertura =
        if (roteiro.reduzido) QuadroDaAbertura.repouso else CoreografiaDaAbertura.quadro(no)

    val voa = destino != null && !roteiro.reduzido && !pulando
    val q = estado(tRef).let { if (voa) it.copy(rotuloEscala = 1.0, rotuloOpacidade = 1.0) else it }
    // O quadro de 1/60 s atrás mede quanto a borda da janela corre, para esfumá-la na mesma medida.
    val anterior = estado(tRef - 1.0 / 60)
    val rastro = if (roteiro.reduzido) {
        emptyList()
    } else {
        CoreografiaDaAbertura.rastro(tRef).map { Fantasma(estado(tRef - it.atraso), it.opacidade) }
    }

    val tela = size
    val largura = min(tela.width - 96 * density, 320 * density)
    val s = largura / ParteDaMarca.LARGURA
    val altura = ParteDaMarca.ALTURA * s
    val centro = Offset(tela.width / 2, tela.height / 2)

    desenharFundo(q, anterior, centro, s, cores)
    if (voa && t >= roteiro.saida) {
        val inicio = Rect(centro.x - largura / 2, centro.y - altura / 2, centro.x + largura / 2, centro.y + altura / 2)
        desenharRotuloEmVoo(t, roteiro, inicio, destino, janela(q, centro, s), cores)
    } else {
        desenharRotuloVivo(q, rastro, largura, altura, s, centro, cores)
    }
}

/** Uma cópia do par num instante pouco atrás, para o desfoque de movimento. */
private class Fantasma(val quadro: QuadroDaAbertura, val opacidade: Double)

/** O furo da janela: centro e raio, em pixels. */
private class Janela(val centro: Offset, val raio: Float)

/** A borda esfumada da janela mede até 15 dp: o raio final passa do canto mais longe por essa folga. */
private const val PLUMA_MAXIMA_DP = 15f

/** O pingo vira a janela: o furo nasce do tamanho e do lugar do pingo e cresce até cobrir a tela. */
private fun DrawScope.janela(q: QuadroDaAbertura, centro: Offset, s: Float): Janela {
    val pingo = ParteDaMarca.centroDoPingo
    val escala = q.rotuloEscala.toFloat()
    val c = Offset(
        centro.x + (pingo.x - ParteDaMarca.LARGURA / 2) * s * escala,
        centro.y + (pingo.y - ParteDaMarca.ALTURA / 2) * s * escala,
    )
    if (q.abertura <= 0) return Janela(c, 0f)
    val inicial = ParteDaMarca.RAIO_DO_PINGO * s * escala
    val tela = size
    val final = hypot(max(c.x, tela.width - c.x), max(c.y, tela.height - c.y)) + PLUMA_MAXIMA_DP * density
    return Janela(c, inicial + (final - inicial) * q.abertura.toFloat())
}

private fun DrawScope.desenharFundo(q: QuadroDaAbertura, anterior: QuadroDaAbertura, centro: Offset, s: Float, cores: CoresDaAbertura) {
    val tela = size
    val atual = janela(q, centro, s)
    drawRect(cores.acao)
    // Camada de fundo: um halo claro que respira devagar atrás do rótulo.
    drawRect(
        Brush.radialGradient(
            colors = listOf(cores.sobreAcao.copy(alpha = (0.14 * q.halo).toFloat()), Color.Transparent),
            center = Offset(tela.width / 2, tela.height / 2),
            radius = tela.width * 0.75f,
        ),
    )
    if (atual.raio <= 0f) return
    // Desfoque de movimento da borda: uma borda dura que cresce 20 pt por quadro pisca. A pluma acompanha o quanto
    // ela andou desde o quadro anterior (1 dp parada, até 15 dp no fim).
    val correu = max(0f, atual.raio - janela(anterior, centro, s).raio)
    val pluma = min(PLUMA_MAXIMA_DP * density, density + correu * 0.6f)
    val noMeio = ((atual.raio - pluma) / atual.raio).coerceIn(0f, 1f)
    // Dentro do furo o laranja some por inteiro; a borda esfumada sobe de zero até o laranja cheio.
    drawCircle(
        brush = Brush.radialGradient(
            colorStops = arrayOf(0f to Color.Black, noMeio to Color.Black, 1f to Color.Transparent),
            center = atual.centro,
            radius = atual.raio,
        ),
        radius = atual.raio,
        center = atual.centro,
        blendMode = BlendMode.DstOut,
    )
}

/**
 * O rótulo da saída, já parado, a caminho do rótulo da tela: o desenho é o mesmo, então a troca pelo rótulo da tela não
 * aparece. O lugar e o tamanho seguem uma curva de pouso. A cor vira onde a janela passa: branco sobre o laranja,
 * tinta dentro da janela, sobre o app. Assim nunca há um meio-termo cinza.
 */
private fun DrawScope.desenharRotuloEmVoo(
    t: Double,
    roteiro: RoteiroDaAbertura,
    inicio: Rect,
    fim: Rect,
    janela: Janela,
    cores: CoresDaAbertura,
) {
    val duracao = roteiro.duracao - roteiro.saida
    val x = ((t - roteiro.saida) / duracao).coerceIn(0.0, 1.0)
    val p = CoreografiaDaAbertura.pousoDoVoo.transform(x.toFloat())
    fun entre(a: Float, b: Float) = a + (b - a) * p
    val quadro = Rect(
        left = entre(inicio.left, fim.left),
        top = entre(inicio.top, fim.top),
        right = entre(inicio.right, fim.right),
        bottom = entre(inicio.bottom, fim.bottom),
    )
    if (janela.raio <= 0f) {
        desenharRotulo(cores.sobreAcao, quadro.topLeft, quadro.width, quadro.height)
        return
    }
    val disco = Path().apply { addOval(Rect(janela.centro, janela.raio)) }
    clipPath(disco, ClipOp.Difference) {
        desenharRotulo(cores.sobreAcao, quadro.topLeft, quadro.width, quadro.height)
    }
    clipPath(disco, ClipOp.Intersect) {
        desenharRotulo(cores.tinta, quadro.topLeft, quadro.width, quadro.height)
    }
}

private fun DrawScope.desenharRotuloVivo(
    q: QuadroDaAbertura,
    rastro: List<Fantasma>,
    largura: Float,
    altura: Float,
    s: Float,
    centro: Offset,
    cores: CoresDaAbertura,
) {
    val cor = cores.sobreAcao
    // Enquanto o par se cumprimenta, a câmera fica perto e centrada no "ri"; depois se afasta e centra o rótulo
    // inteiro.
    val centroDoPar = (352f + 742f) / 2
    val deslocamentoDoPar = (ParteDaMarca.LARGURA / 2 - centroDoPar) * s * q.zoom.toFloat() * (1 - q.enquadramento.toFloat())
    val topoEsquerdo = Offset(centro.x - largura / 2, centro.y - altura / 2)

    withTransform({
        // O rótulo sai crescendo em torno do centro da tela (escala do quadro); a câmera aproxima em torno do mesmo.
        scale(q.rotuloEscala.toFloat(), q.rotuloEscala.toFloat(), pivot = centro)
        translate(left = deslocamentoDoPar)
        scale(q.zoom.toFloat(), q.zoom.toFloat(), pivot = centro)
        translate(topoEsquerdo.x, topoEsquerdo.y)
        scale(s, s, pivot = Offset.Zero)
    }) {
        val alfaGeral = q.rotuloOpacidade.toFloat()
        desenharLetra(ParteDaMarca.F, q.fX, q.fOpacidade * alfaGeral, cor)
        desenharLetra(ParteDaMarca.L, q.lX, q.lOpacidade * alfaGeral, cor)
        desenharLetra(ParteDaMarca.A, q.aX, q.aOpacidade * alfaGeral, cor)
        // Desfoque de movimento: o par alguns milissegundos atrás, mais fraco a cada cópia, por baixo do par de agora.
        // Como a cópia é a própria malha, o rastro dobra junto com o braço.
        rastro.forEach { desenharPar(it.quadro, it.opacidade * alfaGeral, cor) }
        desenharPar(q, alfaGeral.toDouble(), cor)
    }
}

/** Uma letra do rótulo no espaço do SVG, deslocada `x` unidades. */
private fun DrawScope.desenharLetra(parte: ParteDaMarca, x: Double, opacidade: Double, cor: Color) {
    if (opacidade <= 0.0) return
    translate(left = x.toFloat()) {
        drawPath(parte.caminho, cor, alpha = opacidade.toFloat().coerceIn(0f, 1f))
    }
}

/**
 * O `r` e o `i` são malhas: nascem inteiros, como a fonte os desenha, e formam as mãos no aperto; o esqueleto de cada
 * um e o campo do par deformam o contorno ponto a ponto. O pingo é a cabeça do `i` e segue o corpo dele. Quando a janela
 * começa a abrir, o pingo dá lugar a ela.
 */
private fun DrawScope.desenharPar(q: QuadroDaAbertura, opacidadeGeral: Double, cor: Color) {
    val campo = q.campo
    if (q.rOpacidade > 0) {
        val r = LetraViva.caminho(ParteDaMarca.R, q.poseDoR, campo, q.maos)
        drawPath(r, cor, alpha = (q.rOpacidade * opacidadeGeral).toFloat().coerceIn(0f, 1f))
    }
    if (q.iOpacidade > 0) {
        val alfa = (q.iOpacidade * opacidadeGeral).toFloat().coerceIn(0f, 1f)
        val i = LetraViva.caminho(ParteDaMarca.I, q.poseDoI, campo, q.maos)
        drawPath(i, cor, alpha = alfa)
        if (q.abertura <= 0) {
            val pingo = LetraViva.caminhoDoPingo(q.poseDoI, campo, q.pingoEscala, q.pingoY)
            drawPath(pingo, cor, alpha = alfa)
        }
    }
}
