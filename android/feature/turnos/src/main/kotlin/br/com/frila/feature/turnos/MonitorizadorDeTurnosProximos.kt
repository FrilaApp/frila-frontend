package br.com.frila.feature.turnos

import br.com.frila.core.localizacao.GerenciadorGeofencingTurnos
import br.com.frila.core.notificacoes.GerenciadorDeCanais
import br.com.frila.core.notificacoes.GerenciadorPreferenciasNotificacao
import br.com.frila.core.rede.TurnoDto
import java.time.Instant

/**
 * Orquestra o geofencing passivo de aproximação de turno (RN06/RNF04, cartão Uu04zAt4): a cada
 * atualização da lista de `/rpc/meus_turnos`, decide — via [MonitorProximidadeTurno] — quais
 * turnos devem ter um alerta de 500m registrado, e remove o alerta dos que saíram da janela
 * (RN12 cancelado, check-in já feito, ou fora das 2h anteriores ao início).
 *
 * RF06 (bloqueante do Shisui, PR #598): quem desativou o canal `canal_turnos` nas preferências
 * (`GerenciadorPreferenciasNotificacao`, cartão 2L0Su2C7) não deve nem ter a geofence registrada
 * — `GeofenceAlertaReceiver` repete a mesma checagem no momento do disparo, como segunda camada,
 * porque uma geofence já registrada antes do usuário desligar a preferência continua ativa no
 * sistema até expirar.
 */
class MonitorizadorDeTurnosProximos(
    private val gerenciadorGeofencing: GerenciadorGeofencingTurnos,
    private val preferenciasNotificacao: GerenciadorPreferenciasNotificacao,
    private val instanteAtual: () -> Instant = Instant::now,
) {

    fun avaliarTurnos(turnos: List<TurnoDto>) {
        val agora = instanteAtual()
        turnos.forEach { turno ->
            if (!MonitorProximidadeTurno.deveAtivarMonitoramento(turno, agora)) {
                gerenciadorGeofencing.removerAlerta(turno.id)
                return@forEach
            }

            if (!preferenciasNotificacao.estaAtivado(GerenciadorDeCanais.CANAL_TURNOS)) {
                gerenciadorGeofencing.removerAlerta(turno.id)
                return@forEach
            }

            val resolvida = ResolvedorCoordenadaDaVaga.resolver(turno)
            if (resolvida == null) {
                gerenciadorGeofencing.removerAlerta(turno.id)
                return@forEach
            }

            val expiraEm = runCatching { Instant.parse(turno.vaga.fimEm) }.getOrNull()
            gerenciadorGeofencing.registrarAlerta(
                id = turno.id,
                centro = resolvida.coordenada,
                raioMetros = MonitorProximidadeTurno.RAIO_APROXIMACAO_METROS.toFloat(),
                expiraEm = expiraEm,
                canalNotificacao = GerenciadorDeCanais.CANAL_TURNOS,
                titulo = "Você está chegando",
                corpo = "Você está se aproximando da região do turno (${resolvida.rotulo}). " +
                    "O check-in estará liberado ao chegar no estabelecimento.",
            )
        }
    }

    /** RNF04: chamado assim que o check-in é feito ou o turno é cancelado. */
    fun removerAlerta(turnoId: String) {
        gerenciadorGeofencing.removerAlerta(turnoId)
    }
}
