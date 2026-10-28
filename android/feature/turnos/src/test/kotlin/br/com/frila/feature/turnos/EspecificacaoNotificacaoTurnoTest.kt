package br.com.frila.feature.turnos

import br.com.frila.core.notificacoes.GerenciadorDeCanais
import java.time.Duration
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class EspecificacaoNotificacaoTurnoTest {

    private val turnoId = "t-1"
    private val fimTurno: Instant = Instant.parse("2026-11-02T02:00:00Z")

    @Test
    fun `montagem da notificacao e persistente e traz cronometro regressivo com fim do turno`() {
        val instanteAtual = Instant.parse("2026-11-02T01:30:00Z")

        val especificacao = EspecificacaoNotificacaoTurno.paraTurnoEmAndamento(
            turnoId = turnoId,
            funcaoNome = "garçom",
            estabelecimentoNome = "Bar do Lago",
            fimTurno = fimTurno,
            instanteAtual = instanteAtual,
        )

        assertTrue(especificacao.persistente)
        assertEquals(Duration.ofMinutes(30), especificacao.tempoRestante)
        assertTrue(especificacao.corpo.contains("30min 00s"))
        assertTrue(especificacao.titulo.contains("garçom"))
        assertTrue(especificacao.corpo.contains("Bar do Lago"))
    }

    @Test
    fun `cronometro nunca fica negativo mesmo com relogio adiantado alem do fim do turno`() {
        val instanteAposOFim = fimTurno.plusSeconds(120)

        val especificacao = EspecificacaoNotificacaoTurno.paraTurnoEmAndamento(
            turnoId = turnoId,
            funcaoNome = "garçom",
            estabelecimentoNome = "Bar do Lago",
            fimTurno = fimTurno,
            instanteAtual = instanteAposOFim,
        )

        assertEquals(Duration.ZERO, especificacao.tempoRestante)
    }

    @Test
    fun `acoes rapidas de detalhes do turno e suporte estao presentes`() {
        val especificacao = EspecificacaoNotificacaoTurno.paraTurnoEmAndamento(
            turnoId = turnoId,
            funcaoNome = "cozinheiro",
            estabelecimentoNome = "Restaurante Central",
            fimTurno = fimTurno,
            instanteAtual = fimTurno.minusSeconds(60),
        )

        assertTrue(especificacao.acoesRapidas.contains(AcaoRapidaNotificacaoTurno.DETALHES_DO_TURNO))
        assertTrue(especificacao.acoesRapidas.contains(AcaoRapidaNotificacaoTurno.SUPORTE))
        assertEquals(2, especificacao.acoesRapidas.size)
    }

    @Test
    fun `canal da notificacao e sempre CANAL_TURNOS`() {
        val especificacao = EspecificacaoNotificacaoTurno.paraTurnoEmAndamento(
            turnoId = turnoId,
            funcaoNome = "garçom",
            estabelecimentoNome = "Bar do Lago",
            fimTurno = fimTurno,
            instanteAtual = fimTurno.minusSeconds(60),
        )

        assertEquals(GerenciadorDeCanais.CANAL_TURNOS, especificacao.canal)
    }

    @Test
    fun `titulo e corpo nao ficam vazios`() {
        val especificacao = EspecificacaoNotificacaoTurno.paraTurnoEmAndamento(
            turnoId = turnoId,
            funcaoNome = "garçom",
            estabelecimentoNome = "Bar do Lago",
            fimTurno = fimTurno,
            instanteAtual = fimTurno.minusSeconds(60),
        )

        assertTrue(especificacao.titulo.isNotBlank())
        assertTrue(especificacao.corpo.isNotBlank())
    }
}
