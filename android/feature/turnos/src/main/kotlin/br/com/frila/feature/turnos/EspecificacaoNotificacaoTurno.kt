package br.com.frila.feature.turnos

import br.com.frila.core.notificacoes.GerenciadorDeCanais
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/** Ação rápida exposta na notificação persistente de turno em andamento (RF11). */
enum class AcaoRapidaNotificacaoTurno { DETALHES_DO_TURNO, SUPORTE }

/**
 * Especificação pura (sem `NotificationManager`/`Context`) da notificação persistente de
 * turno em andamento (RF11/RN06): cronômetro regressivo até o fim previsto, ações rápidas
 * de "Detalhes do turno" e "Suporte", canal fixo em `GerenciadorDeCanais.CANAL_TURNOS`.
 *
 * `persistente = true` (notificação "ongoing"): o profissional não a descarta com swipe
 * enquanto o turno está em andamento — quem decide quando ela deixa de existir é
 * [GerenciadorNotificacaoTurno], nunca o próprio usuário arrastando a notificação.
 */
data class EspecificacaoNotificacaoTurno(
    val turnoId: String,
    val canal: String,
    val titulo: String,
    val corpo: String,
    val persistente: Boolean,
    val tempoRestante: Duration,
    val acoesRapidas: List<AcaoRapidaNotificacaoTurno>,
) {
    companion object {
        private val FUSO_BRASILIA: ZoneId = ZoneId.of("America/Sao_Paulo")
        private val FORMATO_HORARIO: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm")

        /**
         * Monta a especificação para um turno em andamento. `instanteAtual` é injetável para
         * teste determinístico. O tempo restante nunca é negativo — turno já finalizado não
         * deveria nem chegar aqui (ver [GerenciadorNotificacaoTurno.avaliar]), mas o cálculo
         * em si é defensivo contra drift de relógio.
         */
        fun paraTurnoEmAndamento(
            turnoId: String,
            funcaoNome: String,
            estabelecimentoNome: String,
            fimTurno: Instant,
            instanteAtual: Instant = Instant.now(),
        ): EspecificacaoNotificacaoTurno {
            val bruto = Duration.between(instanteAtual, fimTurno)
            val restante = if (bruto.isNegative) Duration.ZERO else bruto
            val horarioFim = FORMATO_HORARIO.withZone(FUSO_BRASILIA).format(fimTurno)
            val textoRestante = CalculadorContagemRegressiva.formatarTempoRestante(restante)

            return EspecificacaoNotificacaoTurno(
                turnoId = turnoId,
                canal = GerenciadorDeCanais.CANAL_TURNOS,
                titulo = "Turno em andamento — $funcaoNome",
                corpo = "$estabelecimentoNome · termina às $horarioFim · $textoRestante restantes",
                persistente = true,
                tempoRestante = restante,
                acoesRapidas = listOf(
                    AcaoRapidaNotificacaoTurno.DETALHES_DO_TURNO,
                    AcaoRapidaNotificacaoTurno.SUPORTE,
                ),
            )
        }
    }
}
