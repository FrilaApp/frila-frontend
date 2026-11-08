package br.com.frila.feature.turnos

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class GerenciadorNotificacaoTurnoTest {

    private val turnoId = "t-1"
    private val inicioTurno: Instant = Instant.parse("2026-11-01T20:00:00Z")
    private val fimTurno: Instant = Instant.parse("2026-11-02T02:00:00Z")

    @Test
    fun `turno em andamento sem checkout resulta em Montar com especificacao persistente`() {
        val instanteAtual = inicioTurno.plusSeconds(60)

        val resultado = GerenciadorNotificacaoTurno.avaliar(
            turnoId = turnoId,
            funcaoNome = "garçom",
            estabelecimentoNome = "Bar do Lago",
            inicioTurno = inicioTurno,
            fimTurno = fimTurno,
            checkoutRegistrado = false,
            instanteAtual = instanteAtual,
        )

        assertTrue(resultado is ResultadoNotificacaoTurno.Montar)
        val especificacao = (resultado as ResultadoNotificacaoTurno.Montar).especificacao
        assertTrue(especificacao.persistente)
        assertEquals(turnoId, especificacao.turnoId)
    }

    @Test
    fun `checkout registrado cancela a notificacao mesmo antes do fim previsto do turno`() {
        val instanteAtual = inicioTurno.plusSeconds(60)

        val resultado = GerenciadorNotificacaoTurno.avaliar(
            turnoId = turnoId,
            funcaoNome = "garçom",
            estabelecimentoNome = "Bar do Lago",
            inicioTurno = inicioTurno,
            fimTurno = fimTurno,
            checkoutRegistrado = true,
            instanteAtual = instanteAtual,
        )

        assertEquals(ResultadoNotificacaoTurno.Cancelar(turnoId), resultado)
    }

    @Test
    fun `turno ainda nao iniciado cancela a notificacao`() {
        val instanteAtual = inicioTurno.minusSeconds(60)

        val resultado = GerenciadorNotificacaoTurno.avaliar(
            turnoId = turnoId,
            funcaoNome = "garçom",
            estabelecimentoNome = "Bar do Lago",
            inicioTurno = inicioTurno,
            fimTurno = fimTurno,
            checkoutRegistrado = false,
            instanteAtual = instanteAtual,
        )

        assertEquals(ResultadoNotificacaoTurno.Cancelar(turnoId), resultado)
    }

    @Test
    fun `turno apos o fim previsto sem checkout tambem cancela a notificacao`() {
        val instanteAtual = fimTurno.plusSeconds(60)

        val resultado = GerenciadorNotificacaoTurno.avaliar(
            turnoId = turnoId,
            funcaoNome = "garçom",
            estabelecimentoNome = "Bar do Lago",
            inicioTurno = inicioTurno,
            fimTurno = fimTurno,
            checkoutRegistrado = false,
            instanteAtual = instanteAtual,
        )

        assertEquals(ResultadoNotificacaoTurno.Cancelar(turnoId), resultado)
    }

    @Test
    fun `canal da especificacao montada e CANAL_TURNOS`() {
        val instanteAtual = inicioTurno.plusSeconds(60)

        val resultado = GerenciadorNotificacaoTurno.avaliar(
            turnoId = turnoId,
            funcaoNome = "garçom",
            estabelecimentoNome = "Bar do Lago",
            inicioTurno = inicioTurno,
            fimTurno = fimTurno,
            checkoutRegistrado = false,
            instanteAtual = instanteAtual,
        )

        val especificacao = (resultado as ResultadoNotificacaoTurno.Montar).especificacao
        assertEquals(br.com.frila.core.notificacoes.GerenciadorDeCanais.CANAL_TURNOS, especificacao.canal)
    }
}
