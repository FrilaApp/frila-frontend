package br.com.frila.core.designsystem.abertura

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Easing
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/*
 * Quadros-chave da abertura, no modelo do `KeyframeTrack` do protótipo do Fabrício: cada faixa é uma lista de chaves em
 * sequência (linear, cúbica ou mola) que partem do valor e da velocidade em que a anterior terminou, e depois da
 * última chave a faixa segura o valor final. Vale para qualquer valor (deslocamento, giro, opacidade), em segundos
 * do roteiro de referência.
 */

/** Mola no jeito do `Spring(duration:bounce:)`: `duracao` é a duração percebida e `oscilacao` (0 a 1) a sobra. */
internal class MolaDaAbertura(val duracao: Double, val oscilacao: Double) {
    /** Frequência natural, em rad/s. */
    val omega: Double = 2 * PI / duracao

    /** Razão de amortecimento: 1 é sem sobra. */
    val amortecimento: Double = (1 - oscilacao).coerceIn(0.05, 1.0)

    companion object {
        val snappy = MolaDaAbertura(0.5, 0.15)
        val bouncy = MolaDaAbertura(0.5, 0.3)
    }
}

/** Curvas de tempo do protótipo (as de `UnitCurve`). */
internal object CurvasDaAbertura {
    val easeIn: Easing = CubicBezierEasing(0.42f, 0f, 1f, 1f)
    val easeOut: Easing = CubicBezierEasing(0f, 0f, 0.58f, 1f)
}

internal sealed class Chave(val alvo: Double, val duracao: Double) {
    /** Reta do valor anterior ao alvo, com uma curva de tempo opcional (`LinearKeyframe`). */
    class Linear(alvo: Double, duracao: Double, val curva: Easing? = null) : Chave(alvo, duracao)

    /** Curva suave entre os pontos (`CubicKeyframe`): as velocidades das pontas saem dos vizinhos, salvo quando dadas. */
    class Cubica(
        alvo: Double,
        duracao: Double,
        val velocidadeInicial: Double? = null,
        val velocidadeFinal: Double? = null,
    ) : Chave(alvo, duracao)

    /** Mola até o alvo, cortada ao fim da chave (`SpringKeyframe`). */
    class Mola(alvo: Double, duracao: Double, val mola: MolaDaAbertura) : Chave(alvo, duracao)
}

/** Uma faixa de quadros-chave de um valor. Em segundos. */
internal class FaixaDoTempo(private val inicial: Double, private val chaves: List<Chave>) {
    private class Trecho(
        val inicio: Double,
        val chave: Chave,
        val de: Double,
        val velocidadeDeEntrada: Double,
        val velocidadeDeSaida: Double,
    ) {
        val fim: Double get() = inicio + chave.duracao
    }

    private val trechos: List<Trecho>

    /** Duração total da faixa; depois dela o valor fica parado no último alvo. */
    val duracao: Double

    init {
        val lista = ArrayList<Trecho>(chaves.size)
        var t = 0.0
        var valor = inicial
        var velocidade = 0.0
        chaves.forEachIndexed { k, chave ->
            val entrada = if (chave is Chave.Cubica) chave.velocidadeInicial ?: velocidade else velocidade
            val saida = velocidadeDeSaida(k, chave, valor, entrada)
            lista += Trecho(t, chave, valor, entrada, saida)
            t += chave.duracao
            valor = chave.alvo
            // Depois de uma reta a velocidade não passa adiante: a chave seguinte parte do repouso.
            velocidade = if (chave is Chave.Linear) 0.0 else saida
        }
        trechos = lista
        duracao = t
    }

    private fun velocidadeDeSaida(k: Int, chave: Chave, de: Double, entrada: Double): Double = when (chave) {
        is Chave.Linear -> 0.0
        is Chave.Cubica -> chave.velocidadeFinal ?: run {
            val seguinte = chaves.getOrNull(k + 1)
            if (seguinte == null || seguinte is Chave.Linear) {
                0.0
            } else {
                // Inclinação entre o ponto de antes e o de depois: a curva passa pela chave sem quebra.
                (seguinte.alvo - de) / (chave.duracao + seguinte.duracao)
            }
        }
        is Chave.Mola -> velocidadeDaMola(chave.mola, de, chave.alvo, entrada, chave.duracao).second
    }

    fun valor(t: Double): Double {
        if (trechos.isEmpty()) return inicial
        if (t <= 0.0) return inicial
        if (t >= duracao) return trechos.last().chave.alvo
        val trecho = trechos.firstOrNull { t < it.fim } ?: return trechos.last().chave.alvo
        val local = t - trecho.inicio
        val chave = trecho.chave
        return when (chave) {
            is Chave.Linear -> {
                val x = (local / chave.duracao).coerceIn(0.0, 1.0)
                val p = chave.curva?.transform(x.toFloat())?.toDouble() ?: x
                trecho.de + (chave.alvo - trecho.de) * p
            }
            is Chave.Cubica -> hermite(trecho.de, chave.alvo, trecho.velocidadeDeEntrada, trecho.velocidadeDeSaida, local, chave.duracao)
            is Chave.Mola -> velocidadeDaMola(chave.mola, trecho.de, chave.alvo, trecho.velocidadeDeEntrada, local).first
        }
    }

    private fun hermite(x0: Double, x1: Double, v0: Double, v1: Double, t: Double, duracao: Double): Double {
        val s = (t / duracao).coerceIn(0.0, 1.0)
        val s2 = s * s
        val s3 = s2 * s
        return (2 * s3 - 3 * s2 + 1) * x0 + (s3 - 2 * s2 + s) * duracao * v0 +
            (-2 * s3 + 3 * s2) * x1 + (s3 - s2) * duracao * v1
    }

    /** Posição e velocidade da mola `t` segundos depois de partir de `de` com a velocidade `v0`, rumo a `alvo`. */
    private fun velocidadeDaMola(mola: MolaDaAbertura, de: Double, alvo: Double, v0: Double, t: Double): Pair<Double, Double> {
        val w = mola.omega
        val z = mola.amortecimento
        val u0 = de - alvo
        if (z >= 1.0) {
            val e = exp(-w * t)
            val b = v0 + w * u0
            return Pair(alvo + e * (u0 + b * t), e * (b - w * (u0 + b * t)))
        }
        val wd = w * sqrt(1 - z * z)
        val e = exp(-z * w * t)
        val b = (v0 + z * w * u0) / wd
        val c = cos(wd * t)
        val s = sin(wd * t)
        val u = e * (u0 * c + b * s)
        val du = e * (-z * w * (u0 * c + b * s) + wd * (-u0 * s + b * c))
        return Pair(alvo + u, du)
    }
}

/** Atalhos para montar as faixas do roteiro com a mesma leitura do protótipo. */
internal class ConstrutorDeFaixa {
    val chaves = ArrayList<Chave>()

    fun linear(alvo: Double, duracao: Double, curva: Easing? = null) {
        chaves += Chave.Linear(alvo, duracao, curva)
    }

    fun cubica(alvo: Double, duracao: Double, velocidadeInicial: Double? = null, velocidadeFinal: Double? = null) {
        chaves += Chave.Cubica(alvo, duracao, velocidadeInicial, velocidadeFinal)
    }

    fun mola(alvo: Double, duracao: Double, mola: MolaDaAbertura) {
        chaves += Chave.Mola(alvo, duracao, mola)
    }
}

internal fun faixa(inicial: Double, montar: ConstrutorDeFaixa.() -> Unit): FaixaDoTempo =
    FaixaDoTempo(inicial, ConstrutorDeFaixa().apply(montar).chaves)

/** Degrau suave de 0 (em `a`) a 1 (em `b`). Aceita `a` maior que `b`. */
internal fun degrauSuave(a: Double, b: Double, x: Double): Double {
    val t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)
}
