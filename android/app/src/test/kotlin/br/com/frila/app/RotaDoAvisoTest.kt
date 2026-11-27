package br.com.frila.app

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/**
 * A tela que o toque num push abre, por tipo e papel. Os payloads são os do iOS (`RoteadorDePushTests`,
 * `CasoDoAviso.todos`, conferidos nas migrações do backend); o destino do profissional espelha o
 * `DestinoDoProfissional` do iOS onde o Android já tem a rota.
 */
class RotaDoAvisoTest {

    private val vaga = "40000000-0000-0000-0000-000000000001"
    private val turno = "60000000-0000-0000-0000-000000000001"
    private val posicao = "50000000-0000-0000-0000-000000000001"
    private val chamada = "70000000-0000-0000-0000-000000000001"
    private val casa = PapelDaRaiz.Contratante(rotaDeMinhasVagas = "minhas_vagas/casa-1?nomeEstabelecimento=Bar")

    private class Caso(val aviso: AvisoDoToque, val profissional: String?)

    private val casos = listOf(
        Caso(AvisoDoToque("vaga", vagaId = vaga), Rotas.detalhe(vaga)),
        Caso(AvisoDoToque("vagas_agrupadas"), null),
        Caso(AvisoDoToque("vaga_sem_elegiveis", vagaId = vaga), null),
        Caso(AvisoDoToque("confirmacao", vagaId = vaga, turnoId = turno), Rotas.turnoAviso(turno)),
        Caso(AvisoDoToque("lembrete_24h", turnoId = turno), Rotas.turnoAviso(turno)),
        Caso(AvisoDoToque("lembrete_3h", turnoId = turno), Rotas.turnoAviso(turno)),
        Caso(AvisoDoToque("inicio_sem_checkin", turnoId = turno), Rotas.turnoAviso(turno)),
        Caso(AvisoDoToque("atraso_15min", turnoId = turno, posicaoId = posicao), null),
        Caso(AvisoDoToque("fim_sem_checkout", turnoId = turno), Rotas.turnoAviso(turno)),
        Caso(AvisoDoToque("vaga_vazia", vagaId = vaga, posicaoId = posicao), null),
        Caso(AvisoDoToque("checkin", vagaId = vaga, turnoId = turno), null),
        Caso(AvisoDoToque("checkin_manual_pendente", vagaId = vaga, turnoId = turno), null),
        // Quem tinha a posição: o payload traz a posição e a vaga, e nunca o turno.
        Caso(AvisoDoToque("cancelamento", vagaId = vaga, posicaoId = posicao), Rotas.MEUS_TURNOS),
        // O candidato de uma vaga recolhida: sem posição.
        Caso(AvisoDoToque("cancelamento", vagaId = vaga), Rotas.detalhe(vaga)),
        Caso(AvisoDoToque("avaliacao_disponivel", turnoId = turno), Rotas.turnoAviso(turno)),
        Caso(AvisoDoToque("suspensao"), null),
        Caso(AvisoDoToque("reativacao"), null),
        Caso(AvisoDoToque("candidatura_recusada", vagaId = vaga), Rotas.detalhe(vaga)),
        Caso(AvisoDoToque("selecao_encerrada", vagaId = vaga), Rotas.detalhe(vaga)),
        Caso(AvisoDoToque("selecao_lembrete", vagaId = vaga), null),
        Caso(AvisoDoToque("midia_recusada"), null),
        Caso(AvisoDoToque("chamada_recebida", vagaId = vaga, chamadaId = chamada), RotasChamadaProfissional.recebida(chamada)),
        Caso(AvisoDoToque("chamada_lembrete", vagaId = vaga, chamadaId = chamada), RotasChamadaProfissional.recebida(chamada)),
        Caso(AvisoDoToque("chamada_aceita", vagaId = vaga, chamadaId = chamada), null),
        Caso(AvisoDoToque("chamada_recusada", vagaId = vaga, chamadaId = chamada), null),
        Caso(AvisoDoToque("chamada_expirada", vagaId = vaga, chamadaId = chamada), RotasChamadaProfissional.recebida(chamada)),
        Caso(AvisoDoToque("chamada_cancelada", vagaId = vaga, chamadaId = chamada), RotasChamadaProfissional.recebida(chamada)),
        Caso(AvisoDoToque("chamada_encerrada", vagaId = vaga, chamadaId = chamada), RotasChamadaProfissional.recebida(chamada)),
        Caso(AvisoDoToque("turno_nao_verificado", turnoId = turno), Rotas.turnoAviso(turno)),
        Caso(AvisoDoToque("lembrete_30min_fim_turno", vagaId = vaga), null),
        Caso(AvisoDoToque("lembrete_fim_turno", vagaId = vaga), null),
    )

    @Test
    fun `a tabela cobre os trinta tipos do contrato`() {
        val doContrato = setOf(
            "vaga", "vagas_agrupadas", "vaga_sem_elegiveis", "confirmacao", "lembrete_24h", "lembrete_3h",
            "inicio_sem_checkin", "atraso_15min", "fim_sem_checkout", "vaga_vazia", "checkin", "checkin_manual_pendente",
            "cancelamento", "avaliacao_disponivel", "suspensao", "reativacao", "candidatura_recusada", "selecao_encerrada",
            "selecao_lembrete", "midia_recusada", "chamada_recebida", "chamada_lembrete", "chamada_aceita", "chamada_recusada",
            "chamada_expirada", "chamada_cancelada", "chamada_encerrada", "turno_nao_verificado",
            "lembrete_30min_fim_turno", "lembrete_fim_turno",
        )

        assertEquals(doContrato, casos.map { it.aviso.tipo }.toSet())
    }

    @Test
    fun `para quem trabalha, cada tipo abre a tela do iOS que ja tem rota no Android`() {
        for (caso in casos) {
            assertEquals(caso.profissional, rotaDoAviso(caso.aviso, PapelDaRaiz.Profissional), caso.aviso.toString())
        }
    }

    @Test
    fun `para a casa, todo aviso abre Minhas vagas e nunca tela do profissional`() {
        for (caso in casos) {
            assertEquals(casa.rotaDeMinhasVagas, rotaDoAviso(caso.aviso, casa), caso.aviso.toString())
        }
        assertEquals(casa.rotaDeMinhasVagas, rotaDoAviso(AvisoDoToque("tipo_futuro", vagaId = vaga), casa))
    }

    @Test
    fun `id que nao e UUID, ou ausente, nao abre tela, e tipo desconhecido tambem nao`() {
        assertEquals(null, rotaDoAviso(AvisoDoToque("confirmacao", turnoId = "turno-1"), PapelDaRaiz.Profissional))
        assertEquals(null, rotaDoAviso(AvisoDoToque("vaga"), PapelDaRaiz.Profissional))
        assertEquals(null, rotaDoAviso(AvisoDoToque("cancelamento", posicaoId = "x"), PapelDaRaiz.Profissional))
        assertEquals(null, rotaDoAviso(AvisoDoToque("tipo_futuro", vagaId = vaga), PapelDaRaiz.Profissional))
    }
}
