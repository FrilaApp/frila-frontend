package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.rede.TurnoDto
import java.time.Duration
import java.time.Instant

/**
 * Geofencing passivo de aproximação de turno (RN06, cartão Uu04zAt4). Decide quando o alerta de
 * proximidade deve ser ativado para um turno confirmado, e se a posição atual está dentro do
 * raio de aproximação do estabelecimento — lógica pura, sem `GeofencingClient` nem `Context`,
 * para ficar testável em JVM. A camada Android real fica em `GerenciadorGeofencingTurnos`
 * (`:core:localizacao`).
 *
 * Fora de escopo: o check-in presencial de 200m já implementado em [CheckinViewModel] — este
 * monitor é só o alerta prévio de "você está chegando", nunca confirma presença.
 */
object MonitorProximidadeTurno {

    /** RN06: raio do círculo de aproximação, centrado no estabelecimento. */
    const val RAIO_APROXIMACAO_METROS = 500.0

    /** RN06: a ativação é estritamente nas 2 horas anteriores ao início do turno. */
    val JANELA_ATIVACAO: Duration = Duration.ofHours(2)

    private const val ESTADO_CONFIRMADA = "confirmada"

    /**
     * Verdadeiro quando o turno está `confirmada`, sem check-in registrado, e o início está a
     * até [JANELA_ATIVACAO] no futuro (nunca depois de já ter começado). `inicioEm`
     * ilegível/malformado degrada para `false` — nunca lança exceção (tratamento defensivo).
     */
    fun deveAtivarMonitoramento(turno: TurnoDto, agora: Instant): Boolean {
        if (turno.estado != ESTADO_CONFIRMADA) return false
        if (turno.checkinEm != null) return false

        val inicio = runCatching { Instant.parse(turno.vaga.inicioEm) }.getOrNull() ?: return false
        if (!agora.isBefore(inicio)) return false

        val restante = Duration.between(agora, inicio)
        return restante <= JANELA_ATIVACAO
    }

    /** Verdadeiro quando a distância entre [atual] e [vaga] está dentro de [RAIO_APROXIMACAO_METROS]. */
    fun estaDentroDoRaioDeAproximacao(atual: Coordenada, vaga: Coordenada): Boolean {
        val distanciaMetros = atual.distanciaKmAte(vaga) * 1000.0
        return distanciaMetros <= RAIO_APROXIMACAO_METROS
    }
}
