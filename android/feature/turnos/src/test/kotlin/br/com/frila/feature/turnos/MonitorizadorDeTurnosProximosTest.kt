package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.GerenciadorGeofencingTurnos
import br.com.frila.core.notificacoes.GerenciadorDeCanais
import br.com.frila.core.notificacoes.GerenciadorPreferenciasNotificacao
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.TurnoDto
import br.com.frila.core.rede.VagaResumoDto
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.time.Instant
import org.junit.jupiter.api.Test

/**
 * RN06/RNF04/RF06 (Uu04zAt4): orquestra [MonitorProximidadeTurno] e [ResolvedorCoordenadaDaVaga]
 * contra [GerenciadorGeofencingTurnos] — a cada atualização da lista de turnos (`MeusTurnosViewModel`),
 * decide quais turnos entram ou saem da janela de monitoramento, respeitando a preferência de
 * canal do usuário (`GerenciadorPreferenciasNotificacao`, cartão 2L0Su2C7).
 */
class MonitorizadorDeTurnosProximosTest {

    private val agora = Instant.parse("2026-11-01T19:00:00Z")

    private fun preferenciasCom(canalTurnosAtivado: Boolean): GerenciadorPreferenciasNotificacao {
        val preferencias = mockk<GerenciadorPreferenciasNotificacao>(relaxed = true)
        every { preferencias.estaAtivado(GerenciadorDeCanais.CANAL_TURNOS) } returns canalTurnosAtivado
        return preferencias
    }

    private fun turno(
        id: String,
        inicioEm: String,
        estado: String? = "confirmada",
        checkinEm: String? = null,
        local: String = "SQN 108, Asa Norte",
        regiaoAdministrativa: String = "Plano Piloto",
    ) = TurnoDto(
        id = id,
        posicaoId = "posicao-$id",
        vaga = VagaResumoDto(
            id = "vaga-$id",
            funcao = "garçom",
            local = local,
            regiaoAdministrativa = regiaoAdministrativa,
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
    fun `registra alerta para turno confirmado dentro da janela com coordenada resolvivel e canal ativado`() {
        val gerenciador = mockk<GerenciadorGeofencingTurnos>(relaxed = true)
        val monitorizador = MonitorizadorDeTurnosProximos(gerenciador, preferenciasCom(canalTurnosAtivado = true), instanteAtual = { agora })

        monitorizador.avaliarTurnos(listOf(turno(id = "t1", inicioEm = "2026-11-01T20:30:00Z")))

        verify(exactly = 1) {
            gerenciador.registrarAlerta(
                id = eq("t1"),
                centro = eq(Coordenada(-15.7600, -47.8850)),
                raioMetros = eq(MonitorProximidadeTurno.RAIO_APROXIMACAO_METROS.toFloat()),
                expiraEm = eq(Instant.parse("2026-11-02T03:00:00Z")),
                canalNotificacao = eq(GerenciadorDeCanais.CANAL_TURNOS),
                titulo = any(),
                corpo = any(),
            )
        }
    }

    @Test
    fun `nao registra alerta quando o canal de turnos esta desativado nas preferencias`() {
        val gerenciador = mockk<GerenciadorGeofencingTurnos>(relaxed = true)
        val monitorizador = MonitorizadorDeTurnosProximos(gerenciador, preferenciasCom(canalTurnosAtivado = false), instanteAtual = { agora })

        monitorizador.avaliarTurnos(listOf(turno(id = "t1", inicioEm = "2026-11-01T20:30:00Z")))

        verify(exactly = 1) { gerenciador.removerAlerta("t1") }
        verify(exactly = 0) { gerenciador.registrarAlerta(any(), any(), any(), any(), any(), any(), any()) }
    }

    @Test
    fun `remove alerta quando turno sai da janela de ativacao`() {
        val gerenciador = mockk<GerenciadorGeofencingTurnos>(relaxed = true)
        val monitorizador = MonitorizadorDeTurnosProximos(gerenciador, preferenciasCom(canalTurnosAtivado = true), instanteAtual = { agora })

        monitorizador.avaliarTurnos(listOf(turno(id = "t1", inicioEm = "2026-11-01T22:00:00Z")))

        verify(exactly = 1) { gerenciador.removerAlerta("t1") }
        verify(exactly = 0) { gerenciador.registrarAlerta(any(), any(), any(), any(), any(), any(), any()) }
    }

    @Test
    fun `remove alerta quando a coordenada nao pode ser resolvida mesmo dentro da janela`() {
        val gerenciador = mockk<GerenciadorGeofencingTurnos>(relaxed = true)
        val monitorizador = MonitorizadorDeTurnosProximos(gerenciador, preferenciasCom(canalTurnosAtivado = true), instanteAtual = { agora })

        monitorizador.avaliarTurnos(
            listOf(
                turno(
                    id = "t1",
                    inicioEm = "2026-11-01T20:30:00Z",
                    local = "endereço sem bairro reconhecivel",
                    regiaoAdministrativa = "regiao inexistente",
                ),
            ),
        )

        verify(exactly = 1) { gerenciador.removerAlerta("t1") }
        verify(exactly = 0) { gerenciador.registrarAlerta(any(), any(), any(), any(), any(), any(), any()) }
    }

    @Test
    fun `removerAlerta delega direto ao gerenciador de geofencing`() {
        val gerenciador = mockk<GerenciadorGeofencingTurnos>(relaxed = true)
        val monitorizador = MonitorizadorDeTurnosProximos(gerenciador, preferenciasCom(canalTurnosAtivado = true), instanteAtual = { agora })

        monitorizador.removerAlerta("turno-x")

        verify(exactly = 1) { gerenciador.removerAlerta("turno-x") }
    }
}
