package br.com.frila.app.desempenho

import android.app.Activity
import android.os.Build
import android.os.Process
import android.os.SystemClock
import android.util.Log

/**
 * Medidor de inicialização a frio (cold start) (Cartão 53, RNF04).
 *
 * Mede:
 * 1. Início do processo real via [Process.getStartElapsedRealtime] (API 24+) / [SystemClock.elapsedRealtime].
 * 2. Primeiro quadro desenhado (TTID - Time to Initial Display) via [androidx.core.view.doOnPreDraw].
 * 3. Prontidão real da interface (TTFD - Time to Full Display) via [Activity.reportFullyDrawn].
 */
object MedidorDeColdStart {
    const val TAG = "ColdStart"

    @Volatile
    var instanteInicioMillis: Long = 0L
        private set

    @Volatile
    var duracaoPrimeiroQuadroMs: Long? = null
        private set

    @Volatile
    var duracaoInterfaceProntaMs: Long? = null
        private set

    val estaIniciado: Boolean
        get() = instanteInicioMillis > 0L

    val primeiroQuadroConcluido: Boolean
        get() = duracaoPrimeiroQuadroMs != null

    val interfaceProntaConcluida: Boolean
        get() = duracaoInterfaceProntaMs != null

    /**
     * Retorna o timestamp de início do processo Android (elapsedRealtime).
     */
    fun obterInicioDoProcesso(): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                val start = Process.getStartElapsedRealtime()
                if (start > 0L) start else SystemClock.elapsedRealtime()
            } catch (_: Throwable) {
                SystemClock.elapsedRealtime()
            }
        } else {
            SystemClock.elapsedRealtime()
        }
    }

    /**
     * Inicia a contagem de tempo do cold start a partir do início do processo.
     */
    fun iniciar(inicioMillis: Long = obterInicioDoProcesso()) {
        instanteInicioMillis = inicioMillis
        duracaoPrimeiroQuadroMs = null
        duracaoInterfaceProntaMs = null
    }

    /**
     * Registra o primeiro quadro renderizado (TTID) via ViewTreeObserver/doOnPreDraw.
     * Retorna a duração em milissegundos desde o início do processo, ou null se não iniciado ou já medido.
     */
    fun marcarPrimeiroQuadro(fimMillis: Long = SystemClock.elapsedRealtime()): Long? {
        if (!estaIniciado || primeiroQuadroConcluido) return null
        val duracao = (fimMillis - instanteInicioMillis).coerceAtLeast(0L)
        duracaoPrimeiroQuadroMs = duracao
        Log.i(TAG, formatarMensagemPrimeiroQuadro(duracao))
        return duracao
    }

    /**
     * Registra a prontidão real da interface (TTFD) e notifica o sistema via [Activity.reportFullyDrawn].
     * Retorna a duração em milissegundos desde o início do processo, ou null se não iniciado ou já medido.
     */
    fun marcarInterfacePronta(
        activity: Activity? = null,
        fimMillis: Long = SystemClock.elapsedRealtime(),
    ): Long? {
        if (!estaIniciado || interfaceProntaConcluida) return null
        val duracao = (fimMillis - instanteInicioMillis).coerceAtLeast(0L)
        duracaoInterfaceProntaMs = duracao
        try {
            activity?.reportFullyDrawn()
        } catch (_: Throwable) {
            // reportFullyDrawn pode falhar em versões legadas de teste ou ambientes sem suporte
        }
        Log.i(TAG, formatarMensagemProntidao(duracao))
        return duracao
    }

    fun formatarMensagemPrimeiroQuadro(duracaoMs: Long): String =
        "Cold start concluído até o primeiro quadro (TTID): ${duracaoMs}ms"

    fun formatarMensagemProntidao(duracaoMs: Long): String =
        "Cold start concluído com interface totalmente pronta (TTFD): ${duracaoMs}ms"

    fun formatarMensagem(duracaoMs: Long): String =
        formatarMensagemPrimeiroQuadro(duracaoMs)

    fun resetarParaTestes() {
        instanteInicioMillis = 0L
        duracaoPrimeiroQuadroMs = null
        duracaoInterfaceProntaMs = null
    }
}
