package br.com.frila.core.designsystem.abertura

import androidx.compose.ui.graphics.Matrix
import androidx.compose.ui.graphics.Path
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.tan

/*
 * As letras do aperto de mão não são peças rígidas: o contorno de cada uma é uma malha de pontos, e cada ponto é
 * deslocado por um esqueleto simples (corpo que enverga, braço que dobra) e por um campo comum ao par (a sacudida do
 * aperto). É o que deixa o `r` e o `i` dobrarem, torcerem e esticarem em vez de só girar em torno da base, e formarem
 * as mãos só na hora do aperto. Porta do `LetraViva` do protótipo do Fabrício; todas as medidas estão no espaço do SVG
 * do rótulo (1311 x 439).
 */

/**
 * Pose do esqueleto de uma letra. Tudo em unidades do SVG do rótulo e em graus. "Para o par" é para a direita no `r`
 * e para a esquerda no `i`.
 */
internal data class PoseDaLetra(
    /** Deslocamento da letra inteira. */
    val x: Double = 0.0, val y: Double = 0.0,
    /** Envergadura do corpo, em graus no topo. Positivo inclina o topo para o par. */
    val curva: Double = 0.0,
    /** Esticamento vertical a partir da base (1 é o repouso). A largura compensa parte do volume. */
    val estica: Double = 1.0,
    /** Quanto o braço levanta, em graus: metade sobe o braço inteiro a partir do ombro, o resto dobra o antebraço no cotovelo. */
    val braco: Double = 0.0,
    /** Quanto a mão avança para o par. */
    val alcance: Double = 0.0,
    /** Torção em torno do eixo vertical, maior no topo que na base. */
    val torcao: Double = 0.0,
)

/**
 * Deformação comum ao par depois do encaixe. Por ser um campo só, aplicado às duas letras no mesmo espaço, o punho do
 * `r` e o recorte do `i` continuam encaixados enquanto se mexem.
 */
internal data class CampoDoPar(
    /** Subida e descida das mãos (positivo desce). As bases ficam plantadas. */
    val sacudida: Double = 0.0,
    /** Balanço do topo de cada corpo. Positivo vai em direção ao encaixe. */
    val balancoR: Double = 0.0, val balancoI: Double = 0.0,
    /** Amasso vertical no impacto (1 é o repouso). */
    val aperto: Double = 1.0,
) {
    /** Escreve em `saida` o ponto (`x`, `y`) deslocado pelo campo. */
    fun aplicar(x: Double, y: Double, saida: DoubleArray) {
        if (this == NEUTRO) {
            saida[0] = x
            saida[1] = y
            return
        }
        var px = x
        var py = y
        val chao = Esqueleto.CHAO

        // Amasso do impacto: o par inteiro cede para baixo e alarga um pouco.
        py = chao - (chao - py) * aperto
        px = CENTRO + (px - CENTRO) * (1 + (1 - aperto) * 0.45)

        val subida = max(0.0, chao - py)
        val nivel = min(subida / Esqueleto.ALTURA, 1.4)

        // Sacudida: as mãos sobem e descem inteiras; o ombro do `r` e o corpo do `i` acompanham em parte, e quem
        // toca o chão não sai do lugar.
        val naMao = degrauSuave(400.0, 540.0, px) * (1 - 0.45 * degrauSuave(672.0, 745.0, px))
        py += sacudida * naMao * degrauSuave(0.0, 95.0, subida)

        // Balanço: o topo de cada corpo chega atrasado e passa do ponto.
        val alavanca = nivel.pow(1.5)
        px += balancoR * alavanca * degrauSuave(CENTRO, 450.0, px)
        px -= balancoI * alavanca * degrauSuave(CENTRO, 700.0, px)
        saida[0] = px
        saida[1] = py
    }

    private companion object {
        val NEUTRO = CampoDoPar()

        /** Centro do par "ri" no espaço do SVG, por onde passa o encaixe. */
        const val CENTRO = 600.0
    }
}

/** Onde cada letra dobra. As medidas saem do desenho do rótulo. */
internal class Esqueleto(parte: ParteDaMarca) {
    /** +1 quando o par está à direita (o `r`), -1 quando está à esquerda (o `i` e o pingo). */
    private val sentido: Double

    /** Eixo vertical do corpo. */
    private val eixo: Double
    private val ombroX: Double
    private val cotoveloX: Double
    private val cotoveloY: Double
    private val faixaDoBraco: Pair<Double, Double>
    private val faixaDoAntebraco: Pair<Double, Double>

    /** Faixa em y abaixo da qual a mão não se mexe (no `i`, a perna fica fora). */
    private val faixaDaMao: Pair<Double, Double>
    private val temBraco: Boolean

    init {
        when (parte) {
            ParteDaMarca.R -> {
                sentido = 1.0; eixo = 421.0; temBraco = true
                ombroX = 478.0
                cotoveloX = 560.0; cotoveloY = 205.0
                faixaDoBraco = 476.0 to 580.0; faixaDoAntebraco = 545.0 to 630.0
                faixaDaMao = CHAO to 350.0
            }
            ParteDaMarca.I -> {
                sentido = -1.0; eixo = 674.0; temBraco = true
                ombroX = 700.0
                cotoveloX = 640.0; cotoveloY = 215.0
                faixaDoBraco = 700.0 to 610.0; faixaDoAntebraco = 650.0 to 590.0
                faixaDaMao = 335.0 to 265.0
            }
            else -> {
                sentido = -1.0; eixo = 674.0; temBraco = false
                ombroX = 0.0; cotoveloX = 0.0; cotoveloY = 0.0
                faixaDoBraco = 0.0 to 0.0; faixaDoAntebraco = 0.0 to 0.0; faixaDaMao = 0.0 to 0.0
            }
        }
    }

    /** Escreve em `saida` o ponto (`x`, `y`) deformado pela `pose`. */
    fun aplicar(pose: PoseDaLetra, x: Double, y: Double, saida: DoubleArray) {
        var px = x
        var py = y

        if (temBraco && (pose.braco != 0.0 || pose.alcance != 0.0)) {
            val foraDoChao = degrauSuave(CHAO, 350.0, py)
            val noBraco = degrauSuave(faixaDoBraco.first, faixaDoBraco.second, px) * foraDoChao
            val giro = pose.braco * PI / 180
            // O braço inteiro sobe sem girar (as paredes do recorte continuam em pé)...
            py -= abs(px - ombroX) * tan(giro * 0.5) * noBraco
            // ...e o antebraço dobra em torno do cotovelo.
            val naMao = degrauSuave(faixaDaMao.first, faixaDaMao.second, py)
            val noAntebraco = degrauSuave(faixaDoAntebraco.first, faixaDoAntebraco.second, px) * naMao
            val angulo = -sentido * giro * 0.6 * noAntebraco
            val dx = px - cotoveloX
            val dy = py - cotoveloY
            px = cotoveloX + dx * cos(angulo) - dy * sin(angulo) + sentido * pose.alcance * noBraco * naMao
            py = cotoveloY + dx * sin(angulo) + dy * cos(angulo)
        }

        var lado = px - eixo
        var subida = CHAO - py
        val nivel = subida / ALTURA

        // Torção: a letra gira em torno do próprio eixo, mais em cima que embaixo.
        if (pose.torcao != 0.0) {
            lado *= cos(pose.torcao * PI / 180 * (0.3 + 0.7 * nivel))
        }
        // Esticar e amassar a partir do chão, devolvendo na largura parte do volume.
        subida *= pose.estica
        lado *= 1 + (1 - pose.estica) * 0.5

        // Envergar: o eixo do corpo vira um arco, e cada corte horizontal acompanha o arco.
        val total = sentido * pose.curva * PI / 180
        if (abs(total) > 0.0001) {
            val k = total / ALTURA
            val a = k * subida
            px = eixo + (1 - cos(a)) / k + lado * cos(a)
            py = CHAO - (sin(a) / k - lado * sin(a))
        } else {
            px = eixo + lado
            py = CHAO - subida
        }
        saida[0] = px + pose.x
        saida[1] = py + pose.y
    }

    companion object {
        /** Linha do chão e altura do corpo das letras minúsculas. */
        const val CHAO = 432.0
        const val ALTURA = 300.0
    }
}

/** A malha do `r` ou do `i`: a letra inteira e a encaixada, com os mesmos pontos na mesma ordem. */
internal class MalhaDaLetra(inteira: String, encaixada: String) {
    private val inteira: DoubleArray = ler(inteira)
    private val encaixada: DoubleArray = ler(encaixada)

    init {
        require(this.inteira.size == this.encaixada.size) { "As duas formas da malha precisam ter os mesmos pontos." }
    }

    val pontos: Int get() = inteira.size / 2

    /** Ponto `k` entre a letra inteira (`maos` 0) e a encaixada (`maos` 1), em `saida`. */
    fun ponto(k: Int, maos: Double, saida: DoubleArray) {
        val ax = inteira[2 * k]
        val ay = inteira[2 * k + 1]
        saida[0] = ax + (encaixada[2 * k] - ax) * maos
        saida[1] = ay + (encaixada[2 * k + 1] - ay) * maos
    }

    private fun ler(texto: String): DoubleArray {
        val pares = texto.split(';').filter { it.isNotEmpty() }
        val valores = DoubleArray(pares.size * 2)
        pares.forEachIndexed { k, par ->
            val v = par.split(',')
            valores[2 * k] = v[0].toDouble()
            valores[2 * k + 1] = v[1].toDouble()
        }
        return valores
    }

    companion object {
        val r: MalhaDaLetra by lazy { MalhaDaLetra(DadosDaMalhaDoAperto.R_INTEIRO, DadosDaMalhaDoAperto.R_ENCAIXADO) }
        val i: MalhaDaLetra by lazy { MalhaDaLetra(DadosDaMalhaDoAperto.I_INTEIRO, DadosDaMalhaDoAperto.I_ENCAIXADO) }
    }
}

/**
 * O `r`, o `i` ou o pingo da abertura, montados a cada quadro no espaço do SVG do rótulo.
 *
 * O `r` e o `i` são malhas: cada ponto do contorno sai da letra inteira ou da encaixada, conforme `maos`, e depois é
 * deslocado pelo esqueleto e pelo campo do par. Com as mãos formadas e pose e campo neutros, o desenho é o do rótulo.
 * O pingo não deforma: é levado.
 */
internal object LetraViva {
    private val esqueletos = mapOf(
        ParteDaMarca.R to Esqueleto(ParteDaMarca.R),
        ParteDaMarca.I to Esqueleto(ParteDaMarca.I),
        ParteDaMarca.PINGO to Esqueleto(ParteDaMarca.PINGO),
    )

    fun caminho(parte: ParteDaMarca, pose: PoseDaLetra, campo: CampoDoPar, maos: Double = 1.0): Path {
        val esqueleto = esqueletos.getValue(parte)
        if (parte == ParteDaMarca.PINGO) return Path()
        val malha = if (parte == ParteDaMarca.R) MalhaDaLetra.r else MalhaDaLetra.i
        val caminho = Path()
        val p = DoubleArray(2)
        val q = DoubleArray(2)
        for (k in 0 until malha.pontos) {
            malha.ponto(k, maos, p)
            esqueleto.aplicar(pose, p[0], p[1], q)
            campo.aplicar(q[0], q[1], p)
            if (k == 0) caminho.moveTo(p[0].toFloat(), p[1].toFloat()) else caminho.lineTo(p[0].toFloat(), p[1].toFloat())
        }
        caminho.close()
        return caminho
    }

    /**
     * O pingo é levado inteiro. De lado, segue o arco do corpo do `i`; em altura, segue o topo do `i` logo abaixo
     * dele (o pescoço), para a folga entre os dois não fechar. Cresce a partir do próprio pé, pelo mesmo motivo.
     */
    fun caminhoDoPingo(pose: PoseDaLetra, campo: CampoDoPar, escalaPropria: Double, yProprio: Double): Path {
        val esqueleto = esqueletos.getValue(ParteDaMarca.PINGO)
        val centro = ParteDaMarca.centroDoPingo
        val pe = centro.y + ParteDaMarca.RAIO_DO_PINGO
        val pescocoY = 135.0
        val noArco = DoubleArray(2)
        val noPescoco = DoubleArray(2)
        val tmp = DoubleArray(2)
        esqueleto.aplicar(pose, centro.x.toDouble(), centro.y.toDouble(), tmp)
        campo.aplicar(tmp[0], tmp[1], noArco)
        esqueleto.aplicar(pose, centro.x.toDouble(), pescocoY, tmp)
        campo.aplicar(tmp[0], tmp[1], noPescoco)
        val origemX = noArco[0]
        val origemY = pe + (noPescoco[1] - pescocoY) + yProprio
        val e = escalaPropria.toFloat()
        // Ponto do pingo p vira origem + e * (p - (centro.x, pe)): escala e deslocamento em uma matriz só.
        val matriz = Matrix().apply {
            values[Matrix.ScaleX] = e
            values[Matrix.ScaleY] = e
            values[Matrix.TranslateX] = origemX.toFloat() - e * centro.x
            values[Matrix.TranslateY] = origemY.toFloat() - e * pe
        }
        return Path().apply {
            addPath(ParteDaMarca.PINGO.caminho)
            transform(matriz)
        }
    }
}
