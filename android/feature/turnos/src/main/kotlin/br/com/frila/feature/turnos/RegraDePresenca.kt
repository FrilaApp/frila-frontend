package br.com.frila.feature.turnos

import java.time.Duration
import java.time.Instant

/**
 * Regras de presença do profissional (paridade com `RegraDePresenca` do iOS, `Localizacao.swift`).
 */
object RegraDePresenca {
    /** O servidor recusa o check-out recebido depois de `fim_em + 60 min`, sem tolerância (0.2.83). */
    val JANELA_DO_CHECKOUT_DEPOIS_DO_FIM: Duration = Duration.ofMinutes(60)

    /**
     * Como o iOS (`PresencaDoTurnoViewModel.podeFazerCheckout`): check-in feito, check-out ainda não, e até 60 min
     * depois do fim. Sem o fim do turno o servidor decide.
     */
    fun podeFazerCheckout(checkinFeito: Boolean, checkoutFeito: Boolean, fim: Instant?, agora: Instant): Boolean {
        if (!checkinFeito || checkoutFeito) return false
        return fim == null || !agora.isAfter(fim.plus(JANELA_DO_CHECKOUT_DEPOIS_DO_FIM))
    }
}
