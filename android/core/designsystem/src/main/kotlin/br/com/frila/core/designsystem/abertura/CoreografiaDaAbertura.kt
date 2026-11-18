package br.com.frila.core.designsystem.abertura

import androidx.compose.animation.core.CubicBezierEasing
import kotlin.math.max
import kotlin.math.min

/**
 * Valores de cada quadro da abertura, no desenho do Fabrício. Deslocamentos em unidades do SVG do rótulo (1311 x 439);
 * giros em graus. No `r` e no `i`, "para o par" é o sentido positivo de `curva` e de `alcance` ([PoseDaLetra]).
 */
internal data class QuadroDaAbertura(
    val rX: Double = -300.0, val rY: Double = 60.0, val rOpacidade: Double = 0.0,
    val rCurva: Double = -10.0, val rEstica: Double = 1.0, val rBraco: Double = 0.0,
    val rAlcance: Double = 0.0, val rTorcao: Double = 45.0,
    val iX: Double = 300.0, val iY: Double = 60.0, val iOpacidade: Double = 0.0,
    val iCurva: Double = -10.0, val iEstica: Double = 1.0, val iBraco: Double = 0.0,
    val iAlcance: Double = 0.0, val iTorcao: Double = 45.0,
    /** Quanto das mãos já se formou: 0 são as letras inteiras, 1 são as do rótulo, com o encaixe. */
    val maos: Double = 0.0,
    /** O par depois do encaixe: sacudida das mãos, balanço dos corpos e amasso do impacto. */
    val sacudida: Double = 0.0, val balancoR: Double = 0.0, val balancoI: Double = 0.0, val aperto: Double = 1.0,
    val pingoEscala: Double = 0.0, val pingoY: Double = 30.0,
    /** Aproximação da câmera e quanto ela já trocou o centro do "ri" pelo do rótulo (0 a 1). */
    val zoom: Double = 2.0, val enquadramento: Double = 0.0,
    val fX: Double = -160.0, val fOpacidade: Double = 0.0,
    val lX: Double = 160.0, val lOpacidade: Double = 0.0,
    val aX: Double = 220.0, val aOpacidade: Double = 0.0,
    val rotuloEscala: Double = 1.0, val rotuloOpacidade: Double = 1.0,
    /** Abertura da janela do pingo (0 a 1). */
    val abertura: Double = 0.0,
    val halo: Double = 0.0,
) {
    val poseDoR: PoseDaLetra
        get() = PoseDaLetra(x = rX, y = rY, curva = rCurva, estica = rEstica, braco = rBraco, alcance = rAlcance, torcao = rTorcao)

    /**
     * O `i` inteiro é uma haste: só tem braço para levantar e mão para avançar depois que a mão se forma. Antes
     * disso, quem se inclina para o `r` é o corpo.
     */
    val poseDoI: PoseDaLetra
        get() = PoseDaLetra(
            x = iX, y = iY, curva = iCurva, estica = iEstica, braco = iBraco * maos,
            alcance = iAlcance * maos, torcao = iTorcao,
        )

    val campo: CampoDoPar
        get() = CampoDoPar(sacudida = sacudida, balancoR = balancoR, balancoI = balancoI, aperto = aperto)

    /** O mesmo quadro com as mãos formadas até `quanto`. */
    fun comMaos(quanto: Double): QuadroDaAbertura = copy(maos = quanto)

    /**
     * O mesmo quadro com a deformação das letras multiplicada por `fator`. Os deslocamentos, a câmera e a saída
     * não mudam. O braço não passa do desenhado: além disso o polegar do `r` vira ponta e a mão do `i` encosta no pingo.
     */
    fun comElasticidade(fator: Double): QuadroDaAbertura {
        val noBraco = min(fator, 1.0)
        return copy(
            rCurva = rCurva * fator, rBraco = rBraco * noBraco, rAlcance = rAlcance * fator, rTorcao = rTorcao * fator,
            iCurva = iCurva * fator, iBraco = iBraco * noBraco, iAlcance = iAlcance * fator, iTorcao = iTorcao * fator,
            rEstica = 1 + (rEstica - 1) * fator,
            iEstica = 1 + (iEstica - 1) * fator,
            sacudida = sacudida * fator, balancoR = balancoR * fator, balancoI = balancoI * fator,
            aperto = 1 + (aperto - 1) * fator,
        )
    }

    companion object {
        /** O rótulo montado e parado, sem janela aberta. Usado com "reduzir movimento". */
        val repouso = QuadroDaAbertura(
            rX = 0.0, rY = 0.0, rOpacidade = 1.0, rCurva = 0.0, rTorcao = 0.0,
            iX = 0.0, iY = 0.0, iOpacidade = 1.0, iCurva = 0.0, iTorcao = 0.0,
            maos = 1.0, pingoEscala = 1.0, pingoY = 0.0,
            zoom = 1.0, enquadramento = 1.0,
            fX = 0.0, fOpacidade = 1.0, lX = 0.0, lOpacidade = 1.0, aX = 0.0, aOpacidade = 1.0,
            halo = 1.0,
        )
    }
}

/** Uma cópia do par num instante pouco atrás, para o desfoque de movimento. */
internal class Rastro(val atraso: Double, val opacidade: Double)

/**
 * A coreografia do protótipo (a do "Laboratório" com os valores que o Fabrício deixou como padrão: elasticidade
 * contida e mãos no toque), em segundos do roteiro de referência de [DURACAO_DE_REFERENCIA] s. O desenho a estica ou
 * encolhe pela proporção entre a duração pedida e a de referência (ver [RoteiroDaAbertura]).
 *
 * Roteiro (segundos de referência):
 * - 0 a 0,45: o `r` entra pela esquerda e o `i` pela direita, em arco, destorcendo; o topo de cada um chega atrasado,
 *   passa do ponto uma vez e assenta (o corpo enverga, não gira). Os dois são as letras inteiras da fonte;
 * - 0,40 a 0,85: o `r` levanta o braço e acena, com o corpo fazendo o contrapeso;
 * - 0,62 a 0,97: o pingo surge; o `i` estica e inclina para o `r`;
 * - 0,85 a 0,97: antecipação: os dois recuam, amassam e recolhem o braço;
 * - 0,97 a 1,11: bote: esticam, a mão vai na frente e o topo do corpo fica para trás;
 * - 1,05 a 1,23: as mãos (o punho do `r`, o dedo e o recorte do `i`) se formam, a partir do toque;
 * - 1,11: encaixe: amasso do impacto, e o topo dos corpos chega atrasado (balanço);
 * - 1,15 a 1,62: três sacudidas das mãos juntas, cada uma menor; corpos e pingo vão atrás;
 * - 1,50 a 2,00: a câmera se afasta e pousa; o rótulo se forma: F, l e a em cascata (até 2,23);
 * - 2,40 a 2,82: o pingo vira a janela, o rótulo some em 0,16 s e o app assenta.
 */
internal object CoreografiaDaAbertura {
    /** Duração do roteiro do protótipo (2,82 s): a base das proporções. */
    const val DURACAO_DE_REFERENCIA = 2.82

    /** O app começa a 94% do tamanho e cresce até 100% quando a janela abre. */
    const val ESCALA_INICIAL_DO_APP = 0.94f

    /** Elasticidade "contida" do protótipo: o quanto o `r` e o `i` deformam. */
    const val ELASTICIDADE = 0.6

    /** Janela, em segundos de referência, em que as mãos se formam ("no toque"). */
    private const val MAOS_INICIO = 1.05
    private const val MAOS_FIM = 1.23

    private val molaDaEntrada = MolaDaAbertura(0.45, 0.2)
    private val molaDoRotulo = MolaDaAbertura(0.40, 0.25)

    /** Sai devagar e pousa sem cauda: a câmera chega e para, em vez de se arrastar. */
    private val pouso = CubicBezierEasing(0.35f, 0f, 0.2f, 1f)

    /** O voo do rótulo até o da tela: arranca logo e pousa sem cauda, dentro da saída. */
    val pousoDoVoo = CubicBezierEasing(0.3f, 0.1f, 0.15f, 1f)

    private val aberturaDaJanela = CubicBezierEasing(0.3f, 0f, 1f, 1f)

    /** Quanto das mãos já se formou no instante `t` (referência), de 0 a 1. */
    fun maosFormadas(t: Double): Double = degrauSuave(MAOS_INICIO, MAOS_FIM, t)

    /**
     * O quadro da coreografia no instante `t` (segundos de referência), com a elasticidade contida e as mãos
     * formadas no toque.
     */
    fun quadro(t: Double): QuadroDaAbertura = brutoEm(t).comMaos(maosFormadas(t)).comElasticidade(ELASTICIDADE)

    /**
     * Desfoque de movimento: cópias do par alguns milissegundos atrás, só onde a malha corre mais de uns 8 pt por
     * quadro de 60 Hz (a entrada e o bote). Nos outros trechos o rastro só borraria. A força entra e sai em degrau
     * suave, sem estalo.
     */
    fun rastro(t: Double): List<Rastro> {
        fun janela(a: Double, b: Double, c: Double, d: Double): Double =
            min(degrauSuave(a, b, t), 1 - degrauSuave(c, d, t))
        val forca = max(janela(0.0, 0.03, 0.17, 0.26), janela(0.96, 1.00, 1.105, 1.12))
        if (forca <= 0) return emptyList()
        return listOf(
            Rastro(1.0 / 240, 0.40 * forca),
            Rastro(2.0 / 240, 0.22 * forca),
            Rastro(3.0 / 240, 0.10 * forca),
        )
    }

    private fun brutoEm(t: Double) = QuadroDaAbertura(
        rX = rX.valor(t), rY = rY.valor(t), rOpacidade = rOpacidade.valor(t),
        rCurva = rCurva.valor(t), rEstica = rEstica.valor(t), rBraco = rBraco.valor(t),
        rAlcance = rAlcance.valor(t), rTorcao = rTorcao.valor(t),
        iX = iX.valor(t), iY = iY.valor(t), iOpacidade = iOpacidade.valor(t),
        iCurva = iCurva.valor(t), iEstica = iEstica.valor(t), iBraco = iBraco.valor(t),
        iAlcance = iAlcance.valor(t), iTorcao = iTorcao.valor(t),
        sacudida = sacudida.valor(t), balancoR = balancoR.valor(t), balancoI = balancoI.valor(t),
        aperto = aperto.valor(t),
        pingoEscala = pingoEscala.valor(t), pingoY = pingoY.valor(t),
        zoom = zoom.valor(t), enquadramento = enquadramento.valor(t),
        fX = fX.valor(t), fOpacidade = fOpacidade.valor(t),
        lX = lX.valor(t), lOpacidade = lOpacidade.valor(t),
        aX = aX.valor(t), aOpacidade = aOpacidade.valor(t),
        rotuloEscala = rotuloEscala.valor(t), rotuloOpacidade = rotuloOpacidade.valor(t),
        abertura = abertura.valor(t), halo = halo.valor(t),
    )

    // Uma mola com duração fixa termina antes de assentar, e a faixa segura o último valor. Por isso toda mola que
    // leva ao repouso ganha depois uma chave cúbica curta até o valor exato.

    // O `r`: deslocamento
    private val rX = faixa(-300.0) {
        mola(-110.0, 0.45, molaDaEntrada)
        linear(-110.0, 0.40)
        cubica(-130.0, 0.12)
        // O bote acelera até o contato: é o impacto que o amasso responde.
        linear(0.0, 0.14, CurvasDaAbertura.easeIn)
    }
    private val rY = faixa(60.0) {
        cubica(-18.0, 0.22)
        mola(0.0, 0.30, molaDaEntrada)
        cubica(0.0, 0.15)
    }
    private val rOpacidade = faixa(0.0) { linear(1.0, 0.22) }

    // O `r`: corpo. Cada movimento passa do ponto uma vez e assenta: mais que isso fica mole.
    private val rTorcao = faixa(45.0) { linear(0.0, 0.34, CurvasDaAbertura.easeOut) }
    private val rCurva = faixa(-10.0) {
        cubica(-8.0, 0.14)
        cubica(5.0, 0.22)
        cubica(-1.5, 0.14)
        cubica(0.0, 0.12)
        linear(0.0, 0.23)
        // Nos extremos da antecipação e do bote a velocidade é zero dos dois lados.
        cubica(3.0, 0.12, velocidadeFinal = 0.0)
        cubica(-7.0, 0.08, velocidadeInicial = 0.0, velocidadeFinal = 0.0)
        cubica(0.0, 0.06, velocidadeInicial = 0.0)
    }
    private val rEstica = faixa(1.0) {
        linear(1.0, 0.26)
        cubica(0.96, 0.12)
        cubica(1.02, 0.10)
        cubica(1.0, 0.12)
        linear(1.0, 0.25)
        cubica(0.94, 0.12)
        cubica(1.05, 0.08)
        cubica(1.0, 0.06)
    }
    private val rBraco = faixa(0.0) {
        linear(0.0, 0.40)
        cubica(24.0, 0.13)
        cubica(8.0, 0.10)
        cubica(20.0, 0.10)
        cubica(-3.0, 0.12)
        cubica(8.0, 0.12)
        cubica(-2.0, 0.09)
        cubica(0.0, 0.05)
    }
    private val rAlcance = faixa(0.0) {
        linear(0.0, 0.85)
        cubica(-12.0, 0.12, velocidadeFinal = 0.0)
        cubica(18.0, 0.08, velocidadeInicial = 0.0, velocidadeFinal = 0.0)
        cubica(0.0, 0.06, velocidadeInicial = 0.0)
    }

    // O `i`, 60 ms depois do `r`
    private val iX = faixa(300.0) {
        linear(300.0, 0.06)
        mola(110.0, 0.42, molaDaEntrada)
        linear(110.0, 0.37)
        cubica(130.0, 0.12)
        linear(0.0, 0.14, CurvasDaAbertura.easeIn)
    }
    private val iY = faixa(60.0) {
        linear(60.0, 0.06)
        cubica(-18.0, 0.22)
        mola(0.0, 0.30, molaDaEntrada)
        cubica(0.0, 0.15)
    }
    private val iOpacidade = faixa(0.0) {
        linear(0.0, 0.06)
        linear(1.0, 0.22)
    }
    private val iTorcao = faixa(45.0) {
        linear(45.0, 0.06)
        linear(0.0, 0.34, CurvasDaAbertura.easeOut)
    }
    private val iCurva = faixa(-10.0) {
        linear(-10.0, 0.06)
        cubica(-8.0, 0.14)
        cubica(5.0, 0.22)
        cubica(-1.5, 0.12)
        cubica(0.0, 0.10)
        cubica(5.0, 0.14)
        cubica(2.0, 0.09)
        cubica(4.0, 0.10, velocidadeFinal = 0.0)
        cubica(-8.0, 0.08, velocidadeInicial = 0.0, velocidadeFinal = 0.0)
        cubica(0.0, 0.06, velocidadeInicial = 0.0)
    }
    private val iEstica = faixa(1.0) {
        linear(1.0, 0.32)
        cubica(0.96, 0.12)
        cubica(1.02, 0.10)
        cubica(1.0, 0.08)
        cubica(1.06, 0.10)
        cubica(0.99, 0.10)
        cubica(0.93, 0.15)
        cubica(1.05, 0.08)
        cubica(1.0, 0.06)
    }
    private val iBraco = faixa(0.0) {
        linear(0.0, 0.86)
        cubica(10.0, 0.11)
        cubica(-2.0, 0.09)
        cubica(0.0, 0.05)
    }
    private val iAlcance = faixa(0.0) {
        linear(0.0, 0.85)
        cubica(-10.0, 0.12, velocidadeFinal = 0.0)
        cubica(16.0, 0.08, velocidadeInicial = 0.0, velocidadeFinal = 0.0)
        cubica(0.0, 0.06, velocidadeInicial = 0.0)
    }

    // O par, do encaixe em diante
    private val aperto = faixa(1.0) {
        linear(1.0, 1.11)
        cubica(0.94, 0.04)
        mola(1.0, 0.25, MolaDaAbertura.snappy)
        cubica(1.0, 0.15)
    }
    private val balancoR = faixa(0.0) {
        linear(0.0, 1.09)
        cubica(11.0, 0.07)
        cubica(-4.0, 0.12)
        cubica(1.5, 0.12)
        cubica(0.0, 0.14)
    }
    private val balancoI = faixa(0.0) {
        linear(0.0, 1.10)
        cubica(14.0, 0.08)
        cubica(-5.0, 0.12)
        cubica(2.0, 0.12)
        cubica(0.0, 0.14)
    }
    private val sacudida = faixa(0.0) {
        linear(0.0, 1.15)
        cubica(-28.0, 0.09)
        cubica(18.0, 0.10)
        cubica(-10.0, 0.09)
        cubica(4.0, 0.09)
        cubica(0.0, 0.10)
    }

    // O pingo: surge, e depois vai atrás das mãos, sempre um pouco atrás
    private val pingoEscala = faixa(0.0) {
        linear(0.0, 0.62)
        mola(1.0, 0.35, MolaDaAbertura(0.35, 0.35))
        cubica(1.0, 0.15)
    }
    private val pingoY = faixa(30.0) {
        linear(30.0, 0.62)
        mola(0.0, 0.35, MolaDaAbertura.bouncy)
        linear(0.0, 0.14)
        // A folga entre o pingo e o `i` é de 16 unidades: o atraso para baixo fica bem aquém disso.
        cubica(5.0, 0.06)
        cubica(2.0, 0.07)
        cubica(-10.0, 0.07)
        cubica(3.0, 0.08)
        cubica(-6.0, 0.09)
        cubica(1.0, 0.08)
        cubica(0.0, 0.10)
    }

    // A câmera: começa encostada na última sacudida, sem quadro parado entre as duas. A curva pousa de vez.
    private val zoom = faixa(2.0) {
        linear(2.0, 1.50)
        linear(1.0, 0.50, pouso)
    }
    private val enquadramento = faixa(0.0) {
        linear(0.0, 1.50)
        linear(1.0, 0.50, pouso)
    }

    // O rótulo se forma
    private val fX = faixa(-160.0) {
        linear(-160.0, 1.57)
        mola(0.0, 0.40, molaDoRotulo)
        cubica(0.0, 0.10)
    }
    private val fOpacidade = faixa(0.0) {
        linear(0.0, 1.57)
        linear(1.0, 0.18)
    }
    private val lX = faixa(160.0) {
        linear(160.0, 1.65)
        mola(0.0, 0.40, molaDoRotulo)
        cubica(0.0, 0.10)
    }
    private val lOpacidade = faixa(0.0) {
        linear(0.0, 1.65)
        linear(1.0, 0.18)
    }
    private val aX = faixa(220.0) {
        linear(220.0, 1.73)
        mola(0.0, 0.40, molaDoRotulo)
        cubica(0.0, 0.10)
    }
    private val aOpacidade = faixa(0.0) {
        linear(0.0, 1.73)
        linear(1.0, 0.18)
    }

    // Fundo
    private val halo = faixa(0.0) {
        linear(0.0, 0.2)
        cubica(1.0, 1.2)
        cubica(0.75, 0.6)
        cubica(1.0, 0.6)
    }

    // Saída: mais curta que a entrada (0,42 s contra 0,45 s), acelerando. O pingo vira a janela no primeiro quadro,
    // e o rótulo some em 0,16 s, antes de a janela passar por cima das letras.
    private val abertura = faixa(0.0) {
        linear(0.0, 2.40)
        linear(1.0, 0.42, aberturaDaJanela)
    }
    private val rotuloEscala = faixa(1.0) {
        linear(1.0, 2.40)
        linear(1.12, 0.30, CurvasDaAbertura.easeIn)
    }
    private val rotuloOpacidade = faixa(1.0) {
        linear(1.0, 2.40)
        linear(0.0, 0.16, CurvasDaAbertura.easeIn)
    }
}
