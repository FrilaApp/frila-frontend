package br.com.frila.app

import android.app.Application
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * A tela que o toque num push abre, por tipo e papel. Os payloads são os do iOS (`RoteadorDePushTests`,
 * `CasoDoAviso.todos`, conferidos nas migrações do backend); o destino do profissional espelha o
 * `DestinoDoProfissional` do iOS onde o Android já tem a rota, e o da casa o `AvisoDoContratante`.
 *
 * Robolectric pelo `Uri.encode` das rotas: no JVM puro ele devolve `null`, e a rota esperada e a obtida empatavam sem o id.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class RotaDoAvisoTest {

    private val vaga = "40000000-0000-0000-0000-000000000001"
    private val turno = "60000000-0000-0000-0000-000000000001"
    private val posicao = "50000000-0000-0000-0000-000000000001"
    private val chamada = "70000000-0000-0000-0000-000000000001"
    private val casa = PapelDaRaiz.Contratante(estabelecimentoId = "casa-1", rotaDeMinhasVagas = "minhas_vagas/casa-1?nomeEstabelecimento=Bar")

    /** [casa] nulo: Minhas vagas. */
    private class Caso(val aviso: AvisoDoToque, val profissional: String?, val casa: String? = null)

    private val candidatos = "candidatos_da_vaga/$vaga"
    private val turnoDaCasa = "turno_do_contratante_aviso/casa-1/$turno"

    private val casos = listOf(
        Caso(AvisoDoToque("vaga", vagaId = vaga), Rotas.detalhe(vaga)),
        Caso(AvisoDoToque("vagas_agrupadas"), Rotas.FEED),
        Caso(AvisoDoToque("vaga_sem_elegiveis", vagaId = vaga), null, candidatos),
        Caso(AvisoDoToque("confirmacao", vagaId = vaga, turnoId = turno), Rotas.turnoAviso(turno), turnoDaCasa),
        Caso(AvisoDoToque("lembrete_24h", turnoId = turno), Rotas.turnoAviso(turno), turnoDaCasa),
        Caso(AvisoDoToque("lembrete_3h", turnoId = turno), Rotas.turnoAviso(turno), turnoDaCasa),
        Caso(AvisoDoToque("inicio_sem_checkin", turnoId = turno), Rotas.turnoAviso(turno)),
        Caso(AvisoDoToque("atraso_15min", turnoId = turno, posicaoId = posicao), null, turnoDaCasa),
        Caso(AvisoDoToque("fim_sem_checkout", turnoId = turno), Rotas.turnoAviso(turno), turnoDaCasa),
        Caso(AvisoDoToque("vaga_vazia", vagaId = vaga, posicaoId = posicao), null, candidatos),
        Caso(AvisoDoToque("checkin", vagaId = vaga, turnoId = turno), null, turnoDaCasa),
        Caso(AvisoDoToque("checkin_manual_pendente", vagaId = vaga, turnoId = turno), null, turnoDaCasa),
        // Quem tinha a posição: o payload traz a posição e a vaga, e nunca o turno.
        Caso(AvisoDoToque("cancelamento", vagaId = vaga, posicaoId = posicao), Rotas.MEUS_TURNOS, candidatos),
        // O candidato de uma vaga recolhida: sem posição.
        Caso(AvisoDoToque("cancelamento", vagaId = vaga), Rotas.detalhe(vaga), candidatos),
        Caso(AvisoDoToque("avaliacao_disponivel", turnoId = turno), "avaliacao/$turno", "avaliacao_contratante/$turno"),
        Caso(AvisoDoToque("suspensao"), Rotas.ABERTURA, Rotas.ABERTURA),
        Caso(AvisoDoToque("reativacao"), Rotas.ABERTURA, Rotas.ABERTURA),
        Caso(AvisoDoToque("candidatura_recusada", vagaId = vaga), Rotas.detalhe(vaga)),
        Caso(AvisoDoToque("selecao_encerrada", vagaId = vaga), Rotas.detalhe(vaga)),
        Caso(AvisoDoToque("selecao_lembrete", vagaId = vaga), null, candidatos),
        Caso(AvisoDoToque("midia_recusada"), null),
        Caso(AvisoDoToque("chamada_recebida", vagaId = vaga, chamadaId = chamada), "chamada/recebida/$chamada"),
        Caso(AvisoDoToque("chamada_lembrete", vagaId = vaga, chamadaId = chamada), "chamada/recebida/$chamada"),
        Caso(AvisoDoToque("chamada_aceita", vagaId = vaga, chamadaId = chamada), null),
        Caso(AvisoDoToque("chamada_recusada", vagaId = vaga, chamadaId = chamada), null),
        Caso(AvisoDoToque("chamada_expirada", vagaId = vaga, chamadaId = chamada), "chamada/recebida/$chamada"),
        Caso(AvisoDoToque("chamada_cancelada", vagaId = vaga, chamadaId = chamada), "chamada/recebida/$chamada"),
        Caso(AvisoDoToque("chamada_encerrada", vagaId = vaga, chamadaId = chamada), "chamada/recebida/$chamada"),
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
            assertEquals(caso.aviso.toString(), caso.profissional, rotaDoAviso(caso.aviso, PapelDaRaiz.Profissional))
        }
    }

    @Test
    fun `para a casa, os avisos de vaga abrem os candidatos e o resto Minhas vagas, nunca tela do profissional`() {
        for (caso in casos) {
            assertEquals(caso.aviso.toString(), caso.casa ?: casa.rotaDeMinhasVagas, rotaDoAviso(caso.aviso, casa))
        }
        assertEquals(casa.rotaDeMinhasVagas, rotaDoAviso(AvisoDoToque("tipo_futuro", vagaId = vaga), casa))
    }

    @Test
    fun `para a casa, turno_id que nao e UUID ou ausente cai em Minhas vagas`() {
        for (tipo in listOf("confirmacao", "lembrete_24h", "lembrete_3h", "fim_sem_checkout", "checkin", "checkin_manual_pendente", "atraso_15min")) {
            assertEquals(tipo, casa.rotaDeMinhasVagas, rotaDoAviso(AvisoDoToque(tipo, turnoId = "turno-1", vagaId = vaga), casa))
            assertEquals(tipo, casa.rotaDeMinhasVagas, rotaDoAviso(AvisoDoToque(tipo, vagaId = vaga), casa))
        }
    }

    @Test
    fun `para a casa, vaga_id que nao e UUID ou ausente cai em Minhas vagas`() {
        for (tipo in listOf("vaga_sem_elegiveis", "vaga_vazia", "selecao_lembrete", "cancelamento")) {
            assertEquals(tipo, casa.rotaDeMinhasVagas, rotaDoAviso(AvisoDoToque(tipo, vagaId = "vaga-1"), casa))
            assertEquals(tipo, casa.rotaDeMinhasVagas, rotaDoAviso(AvisoDoToque(tipo, vagaId = "../detalhe/x"), casa))
            assertEquals(tipo, casa.rotaDeMinhasVagas, rotaDoAviso(AvisoDoToque(tipo), casa))
        }
    }

    @Test
    fun `id que nao e UUID, ou ausente, nao abre tela, e tipo desconhecido tambem nao`() {
        assertEquals(null, rotaDoAviso(AvisoDoToque("confirmacao", turnoId = "turno-1"), PapelDaRaiz.Profissional))
        assertEquals(null, rotaDoAviso(AvisoDoToque("vaga"), PapelDaRaiz.Profissional))
        assertEquals(null, rotaDoAviso(AvisoDoToque("cancelamento", posicaoId = "x"), PapelDaRaiz.Profissional))
        assertEquals(null, rotaDoAviso(AvisoDoToque("tipo_futuro", vagaId = vaga), PapelDaRaiz.Profissional))
        assertEquals(null, rotaDoAviso(AvisoDoToque("avaliacao_disponivel", turnoId = "turno-1"), PapelDaRaiz.Profissional))
        assertEquals(null, rotaDoAviso(AvisoDoToque("avaliacao_disponivel"), PapelDaRaiz.Profissional))
        assertEquals(casa.rotaDeMinhasVagas, rotaDoAviso(AvisoDoToque("avaliacao_disponivel", turnoId = "turno-1"), casa))
        assertEquals(null, rotaDoAviso(AvisoDoToque("chamada_recebida", chamadaId = "chamada-9"), PapelDaRaiz.Profissional))
        assertEquals(null, rotaDoAviso(AvisoDoToque("chamada_recebida", chamadaId = "../vagas"), PapelDaRaiz.Profissional))
    }
}
