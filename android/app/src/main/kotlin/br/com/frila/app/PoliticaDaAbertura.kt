package br.com.frila.app

import android.content.Intent
import android.os.SystemClock
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Quando a abertura animada toca (pedido 18-01): SÓ na abertura a frio do processo.
 *
 * - voltar do segundo plano não cria a Activity de novo, e recriá-la (rotação, tema, o sistema que a reconstrói) chega com
 *   estado salvo: nenhum dos dois toca;
 * - um processo que começou com a Activity restaurada (Android 9 a 11) gasta a vez dele sem tocar: abrir o app de novo
 *   pelo ícone nesse mesmo processo também não toca, nem a reabertura depois do primeiro toque (saiu pelo voltar e voltou);
 *   o sinal [ProcessoJaTocou] vive tanto quanto o processo;
 * - os testes (de interface e de unidade) desligam a abertura pela chave [EXTRA_PULAR_ABERTURA] no Intent de lançamento.
 */
internal class PoliticaDaAbertura(private val jaTocou: AtomicBoolean = ProcessoJaTocou) {

    /**
     * Decide se esta criação da Activity toca a abertura. A primeira criação de Activity do processo gasta a vez dele,
     * toque ou não: a abertura toca no máximo uma vez por processo, e só se o processo começou sem estado salvo (abertura
     * a frio de verdade). Processo novo com Activity restaurada (`primeiraCriacao` falso), recriação e reabertura no mesmo
     * processo nunca tocam. `primeiraCriacao` é "sem estado salvo" (`savedInstanceState == null`).
     */
    fun deveTocar(intent: Intent?, primeiraCriacao: Boolean): Boolean {
        val primeiraDoProcesso = jaTocou.compareAndSet(false, true)
        if (intent?.getBooleanExtra(EXTRA_PULAR_ABERTURA, false) == true) return false
        return primeiraDoProcesso && primeiraCriacao
    }

    companion object {
        /** A chave de teste: `true` no Intent de lançamento abre direto no app, sem abertura. */
        const val EXTRA_PULAR_ABERTURA = "frila.pular_abertura"

        /**
         * Só no debug: congela a abertura naquele instante, em segundos (`--ef frila.abertura_no_tempo 1.3`), para
         * conferir um quadro em captura. Ignorado no release.
         */
        const val EXTRA_ABERTURA_NO_TEMPO = "frila.abertura_no_tempo"

        fun tempoCongelado(intent: Intent?, debug: Boolean): Double? {
            if (!debug || intent == null || !intent.hasExtra(EXTRA_ABERTURA_NO_TEMPO)) return null
            return intent.getFloatExtra(EXTRA_ABERTURA_NO_TEMPO, -1f).takeIf { it >= 0f }?.toDouble()
        }
    }
}

/**
 * Prova de que o app carrega por baixo da abertura: no debug, cada marco (configuração do app resolvida, interface pronta,
 * abertura fora de cena) sai no log `FrilaAbertura` com o tempo desde a criação da Activity e se a abertura ainda cobria.
 * Só tempos; nada de dado de pessoa.
 */
internal fun registrarAbertura(marco: String, inicioDaActivity: Long, cobrindo: Boolean) {
    if (!BuildConfig.DEBUG) return
    Log.i("FrilaAbertura", "$marco: ${SystemClock.elapsedRealtime() - inicioDaActivity} ms desde a Activity, abertura cobrindo=$cobrindo")
}

/** O sinal de processo: vira verdadeiro na primeira abertura que toca e só volta a falso quando o processo morre. */
internal val ProcessoJaTocou = AtomicBoolean(false)
