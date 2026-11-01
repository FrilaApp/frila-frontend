package br.com.frila.app.desempenho

import android.os.SystemClock
import android.util.Log

/**
 * Medidor de inicialização a frio (cold start) (Cartão 53, RNF04).
 *
 * Registra o instante de inicialização no [android.app.Application.onCreate] e mede
 * a duração total até o primeiro quadro ser desenhado e a interface estar pronta
 * ([android.app.Activity.reportFullyDrawn]), emitindo a métrica no Logcat.
 */
object MedidorDeColdStart {
    const val TAG = "ColdStart"

    @Volatile
    private var instanteInicioMillis: Long = 0L

    @Volatile
    private var medicaoConcluida: Boolean = false

    /**
     * Inicia a contagem de tempo do cold start.
     */
    fun iniciar(inicioMillis: Long = SystemClock.uptimeMillis()) {
        instanteInicioMillis = inicioMillis
        medicaoConcluida = false
    }

    /**
     * Registra o primeiro quadro renderizado e emite a medição no log.
     * Retorna a duração em milissegundos, ou null se não iniciado ou já medido.
     */
    fun marcarPrimeiroQuadro(fimMillis: Long = SystemClock.uptimeMillis()): Long? {
        if (instanteInicioMillis <= 0L || medicaoConcluida) return null
        val duracaoMs = (fimMillis - instanteInicioMillis).coerceAtLeast(0L)
        medicaoConcluida = true
        Log.i(TAG, formatarMensagem(duracaoMs))
        return duracaoMs
    }

    fun formatarMensagem(duracaoMs: Long): String =
        "Cold start concluído até o primeiro quadro: ${duracaoMs}ms"

    fun resetarParaTestes() {
        instanteInicioMillis = 0L
        medicaoConcluida = false
    }
}
