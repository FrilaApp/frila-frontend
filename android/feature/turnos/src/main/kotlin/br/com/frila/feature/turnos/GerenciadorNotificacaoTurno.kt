package br.com.frila.feature.turnos

import java.time.Instant

/**
 * Resultado da avaliação de [GerenciadorNotificacaoTurno.avaliar]: montar/atualizar a
 * notificação persistente, ou cancelá-la. Quem de fato posta ou cancela a notificação no
 * sistema (`NotificationManagerCompat`) é uma camada Android fina por cima deste resultado,
 * fora do escopo deste arquivo — propositalmente, para o que importa (quando mostrar, o quê
 * mostrar, quando cancelar) ficar testável em JVM pura, sem instrumentação.
 */
sealed interface ResultadoNotificacaoTurno {
    data class Montar(val especificacao: EspecificacaoNotificacaoTurno) : ResultadoNotificacaoTurno
    data class Cancelar(val turnoId: String) : ResultadoNotificacaoTurno
}

/**
 * Decide o ciclo de vida da notificação persistente de turno em andamento (RF11/RN06).
 */
object GerenciadorNotificacaoTurno {

    /**
     * `checkoutRegistrado = true` cancela a notificação imediatamente: assim que o check-out
     * é confirmado, o turno deixa de estar "em andamento" para fins de notificação, mesmo que
     * o horário previsto de término ainda não tenha chegado (RF11). Fora da janela do turno
     * (antes do início ou depois do fim previsto, sem check-out) também cancela — a
     * notificação só existe enquanto o turno de fato está em curso.
     */
    fun avaliar(
        turnoId: String,
        funcaoNome: String,
        estabelecimentoNome: String,
        inicioTurno: Instant,
        fimTurno: Instant,
        checkoutRegistrado: Boolean,
        instanteAtual: Instant = Instant.now(),
    ): ResultadoNotificacaoTurno {
        if (checkoutRegistrado) {
            return ResultadoNotificacaoTurno.Cancelar(turnoId)
        }

        val turnoEmAndamento = !instanteAtual.isBefore(inicioTurno) && instanteAtual.isBefore(fimTurno)
        if (!turnoEmAndamento) {
            return ResultadoNotificacaoTurno.Cancelar(turnoId)
        }

        return ResultadoNotificacaoTurno.Montar(
            EspecificacaoNotificacaoTurno.paraTurnoEmAndamento(
                turnoId = turnoId,
                funcaoNome = funcaoNome,
                estabelecimentoNome = estabelecimentoNome,
                fimTurno = fimTurno,
                instanteAtual = instanteAtual,
            ),
        )
    }
}
