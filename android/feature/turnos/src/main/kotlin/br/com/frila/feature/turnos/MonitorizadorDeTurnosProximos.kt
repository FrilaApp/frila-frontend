package br.com.frila.feature.turnos

import br.com.frila.core.localizacao.GerenciadorGeofencingTurnos
import br.com.frila.core.notificacoes.GerenciadorDeCanais
import br.com.frila.core.rede.TurnoDto
import java.time.Instant

/**
 * Orquestra o geofencing passivo de aproximação de turno (RN06/RNF04, cartão Uu04zAt4): a cada
 * atualização da lista de `/rpc/meus_turnos`, decide — via [MonitorProximidadeTurno] — quais
 * turnos devem ter um alerta de 500m registrado, e remove o alerta dos que saíram da janela
 * (RN12 cancelado, check-in já feito, ou fora das 2h anteriores ao início).
 */
class MonitorizadorDeTurnosProximos(
    private val gerenciadorGeofencing: GerenciadorGeofencingTurnos,
    private val instanteAtual: () -> Instant = Instant::now,
) {

    fun avaliarTurnos(turnos: List<TurnoDto>) {
        val agora = instanteAtual()
        turnos.forEach { turno ->
            if (!MonitorProximidadeTurno.deveAtivarMonitoramento(turno, agora)) {
                gerenciadorGeofencing.removerAlerta(turno.id)
                return@forEach
            }

            val coordenada = ResolvedorCoordenadaDaVaga.resolver(turno)
            if (coordenada == null) {
                gerenciadorGeofencing.removerAlerta(turno.id)
                return@forEach
            }

            val expiraEm = runCatching { Instant.parse(turno.vaga.fimEm) }.getOrNull()
            gerenciadorGeofencing.registrarAlerta(
                id = turno.id,
                centro = coordenada,
                raioMetros = MonitorProximidadeTurno.RAIO_APROXIMACAO_METROS.toFloat(),
                expiraEm = expiraEm,
                canalNotificacao = GerenciadorDeCanais.CANAL_TURNOS,
                titulo = "Você está chegando",
                corpo = "Você está a menos de 500m do estabelecimento. O check-in estará liberado ao chegar.",
            )
        }
    }

    /** RNF04: chamado assim que o check-in é feito ou o turno é cancelado. */
    fun removerAlerta(turnoId: String) {
        gerenciadorGeofencing.removerAlerta(turnoId)
    }
}
