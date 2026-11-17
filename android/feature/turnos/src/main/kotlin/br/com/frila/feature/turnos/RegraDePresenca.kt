package br.com.frila.feature.turnos

import java.time.Duration
import java.time.Instant

/**
 * Regras de presença do profissional (paridade com `RegraDePresenca` do iOS, `Localizacao.swift`).
 */
object RegraDePresenca {
    /** Raio de proximidade do código no servidor (0.2.76): acima dele o servidor recusa `422 fora_do_raio`. */
    const val RAIO_DO_CODIGO_METROS = 50

    /** O servidor recusa o check-out recebido depois de `fim_em + 60 min`, sem tolerância (0.2.83). */
    val JANELA_DO_CHECKOUT_DEPOIS_DO_FIM: Duration = Duration.ofMinutes(60)

    sealed interface DecisaoDoEnvioDoCodigo {
        data object Liberado : DecisaoDoEnvioDoCodigo

        /** Sem posição: nada é enviado e a distância não é inventada (nada de "0 m"). */
        data object SemLocalizacao : DecisaoDoEnvioDoCodigo

        /** Acima do raio: nada é enviado, e a tentativa não é gasta contra o servidor. */
        data class ChegueMaisPerto(val distanciaMetros: Int) : DecisaoDoEnvioDoCodigo
    }

    /** O servidor recusa distância nula e acima de 50 m com 422 sem contar erro; o app nem envia (`decisaoDoEnvioDoCodigoSemiauto`). */
    fun decisaoDoEnvioDoCodigo(distanciaMetros: Int?): DecisaoDoEnvioDoCodigo = when {
        distanciaMetros == null -> DecisaoDoEnvioDoCodigo.SemLocalizacao
        distanciaMetros > RAIO_DO_CODIGO_METROS -> DecisaoDoEnvioDoCodigo.ChegueMaisPerto(distanciaMetros)
        else -> DecisaoDoEnvioDoCodigo.Liberado
    }

    /** `^[0-9]{6}$` do contrato, só dígitos ASCII (nada de dígitos árabes ou de largura total). */
    fun formatoDoCodigoValido(codigo: String): Boolean = codigo.length == 6 && codigo.all { it in '0'..'9' }

    /**
     * Como o iOS (`PresencaDoTurnoViewModel.podeFazerCheckout`): check-in feito, check-out ainda não, e até 60 min
     * depois do fim. Sem o fim do turno o servidor decide.
     */
    fun podeFazerCheckout(checkinFeito: Boolean, checkoutFeito: Boolean, fim: Instant?, agora: Instant): Boolean {
        if (!checkinFeito || checkoutFeito) return false
        return fim == null || !agora.isAfter(fim.plus(JANELA_DO_CHECKOUT_DEPOIS_DO_FIM))
    }
}
