package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.TurnoDto
import br.com.frila.core.rede.VagaResumoDto
import java.time.Instant
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * RN06 (Uu04zAt4): decide quando o alerta de aproximação geográfica deve ser ativado para um
 * turno, e se a posição atual está dentro do raio de 500m do estabelecimento. Lógica pura —
 * sem GeofencingClient, sem Context — para ficar testável em JVM.
 */
class MonitorProximidadeTurnoTest {

    private val agora = Instant.parse("2026-11-01T19:00:00Z")

    private fun turnoDeTeste(
        inicioEm: String,
        estado: String? = "confirmada",
        checkinEm: String? = null,
    ) = TurnoDto(
        id = "turno-1",
        posicaoId = "posicao-1",
        vaga = VagaResumoDto(
            id = "vaga-1",
            funcao = "garçom",
            local = "SQN 108",
            regiaoAdministrativa = "Asa Norte",
            inicioEm = inicioEm,
            fimEm = "2026-11-02T03:00:00Z",
            valorCentavos = 16_000,
        ),
        contraparte = PerfilPublicoDto(
            id = "e1",
            tipo = "estabelecimento",
            nome = "Bar do Zé",
            reputacao = ReputacaoDto(positivas = 1, total = 1, turnosConsiderados = 1, turnosRealizados = 1),
        ),
        contatoVisivelAte = "2026-11-02T03:00:00Z",
        checkinEm = checkinEm,
        verificacao = "pendente",
        valorAcordadoCentavos = 16_000,
        podeAvaliar = false,
        estado = estado,
    )

    @Test
    fun `ativa monitoramento quando turno confirmado comeca em 90 minutos`() {
        val turno = turnoDeTeste(inicioEm = "2026-11-01T20:30:00Z")
        assertTrue(MonitorProximidadeTurno.deveAtivarMonitoramento(turno, agora))
    }

    @Test
    fun `nao ativa monitoramento quando turno comeca em 3 horas`() {
        val turno = turnoDeTeste(inicioEm = "2026-11-01T22:00:00Z")
        assertFalse(MonitorProximidadeTurno.deveAtivarMonitoramento(turno, agora))
    }

    @Test
    fun `ativa monitoramento exatamente no limite de 2 horas`() {
        val turno = turnoDeTeste(inicioEm = "2026-11-01T21:00:00Z")
        assertTrue(MonitorProximidadeTurno.deveAtivarMonitoramento(turno, agora))
    }

    @Test
    fun `nao ativa monitoramento 1 segundo acima do limite de 2 horas`() {
        val turno = turnoDeTeste(inicioEm = "2026-11-01T21:00:01Z")
        assertFalse(MonitorProximidadeTurno.deveAtivarMonitoramento(turno, agora))
    }

    @Test
    fun `nao ativa monitoramento quando turno esta cancelado`() {
        val turno = turnoDeTeste(inicioEm = "2026-11-01T20:30:00Z", estado = "cancelada")
        assertFalse(MonitorProximidadeTurno.deveAtivarMonitoramento(turno, agora))
    }

    @Test
    fun `nao ativa monitoramento quando checkin ja foi feito`() {
        val turno = turnoDeTeste(inicioEm = "2026-11-01T20:30:00Z", checkinEm = "2026-11-01T19:50:00Z")
        assertFalse(MonitorProximidadeTurno.deveAtivarMonitoramento(turno, agora))
    }

    @Test
    fun `nao ativa monitoramento quando turno ja comecou`() {
        val turno = turnoDeTeste(inicioEm = "2026-11-01T18:00:00Z")
        assertFalse(MonitorProximidadeTurno.deveAtivarMonitoramento(turno, agora))
    }

    @Test
    fun `degrada graciosamente quando inicioEm nao pode ser interpretado`() {
        val turno = turnoDeTeste(inicioEm = "data-invalida")
        assertFalse(MonitorProximidadeTurno.deveAtivarMonitoramento(turno, agora))
    }

    @Test
    fun `dentro do raio de aproximacao a 450 metros`() {
        val centro = Coordenada(-15.793889, -47.882778)
        val a450m = Coordenada(-15.797929, -47.882778)
        assertTrue(MonitorProximidadeTurno.estaDentroDoRaioDeAproximacao(a450m, centro))
    }

    @Test
    fun `fora do raio de aproximacao a 550 metros`() {
        val centro = Coordenada(-15.793889, -47.882778)
        val a550m = Coordenada(-15.798833, -47.882778)
        assertFalse(MonitorProximidadeTurno.estaDentroDoRaioDeAproximacao(a550m, centro))
    }
}
