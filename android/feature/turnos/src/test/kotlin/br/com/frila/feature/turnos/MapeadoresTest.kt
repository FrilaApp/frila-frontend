package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.TipoVerificacaoCheckin
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.TurnoDto
import br.com.frila.core.rede.VagaResumoDto
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

class MapeadoresTest {

    private fun criarTurnoDto(
        id: String = "turno-123",
        checkinEm: String? = "2026-11-01T21:05:00Z",
        checkinTipo: String? = "geolocalizado",
        checkinDistanciaM: Int? = 50,
        checkinConfirmadoEm: String? = null,
        verificacao: String = "verificado",
    ) = TurnoDto(
        id = id,
        posicaoId = "posicao-1",
        vaga = VagaResumoDto(
            id = "vaga-1",
            funcao = "Garçom",
            local = "CLS 405 Bloco C",
            regiaoAdministrativa = "Plano Piloto",
            inicioEm = "2026-11-01T21:00:00Z",
            fimEm = "2026-11-02T03:00:00Z",
            valorCentavos = 15000,
        ),
        contraparte = PerfilPublicoDto(
            id = "contraparte-1",
            tipo = "estabelecimento",
            nome = "Restaurante Teste",
            reputacao = ReputacaoDto(
                positivas = 1,
                total = 1,
                turnosConsiderados = 1,
                turnosRealizados = 1,
            ),
        ),
        contatoVisivelAte = "2026-11-02T12:00:00Z",
        checkinEm = checkinEm,
        checkinTipo = checkinTipo,
        checkinDistanciaM = checkinDistanciaM,
        checkinConfirmadoEm = checkinConfirmadoEm,
        verificacao = verificacao,
        valorAcordadoCentavos = 15000,
        podeAvaliar = false,
    )

    @Test
    fun `checkin geolocalizado verificado mapeia para GEOLOCALIZADO`() {
        val dto = criarTurnoDto(
            checkinTipo = "geolocalizado",
            checkinDistanciaM = 50,
            verificacao = "verificado",
        )
        val item = dto.paraItem()

        assertNotNull(item.comprovante)
        assertEquals(TipoVerificacaoCheckin.GEOLOCALIZADO, item.comprovante!!.tipoVerificacao)
        assertEquals("Geolocalizado na vaga", item.comprovante!!.tipoVerificacao.descricao)
    }

    @Test
    fun `checkin manual pendente mapeia para MANUAL_PENDENTE`() {
        val dto = criarTurnoDto(
            checkinTipo = "manual",
            checkinDistanciaM = null,
            checkinConfirmadoEm = null,
            verificacao = "pendente",
        )
        val item = dto.paraItem()

        assertNotNull(item.comprovante)
        assertEquals(TipoVerificacaoCheckin.MANUAL_PENDENTE, item.comprovante!!.tipoVerificacao)
        assertEquals("Check-in manual pendente de confirmação", item.comprovante!!.tipoVerificacao.descricao)
    }

    @Test
    fun `checkin manual confirmado pela casa mapeia para MANUAL_CONFIRMADO`() {
        val dto = criarTurnoDto(
            checkinTipo = "manual",
            checkinDistanciaM = null,
            checkinConfirmadoEm = "2026-11-01T21:15:00Z",
            verificacao = "verificado",
        )
        val item = dto.paraItem()

        assertNotNull(item.comprovante)
        assertEquals(TipoVerificacaoCheckin.MANUAL_CONFIRMADO, item.comprovante!!.tipoVerificacao)
        assertEquals("Check-in manual confirmado pelo contratante", item.comprovante!!.tipoVerificacao.descricao)
    }

    @Test
    fun `checkin manual sem confirmacao ate o fechamento mapeia para NAO_VERIFICADO`() {
        val dto = criarTurnoDto(
            checkinTipo = "manual",
            checkinDistanciaM = null,
            checkinConfirmadoEm = null,
            verificacao = "nao_verificado",
        )
        val item = dto.paraItem()

        assertNotNull(item.comprovante)
        assertEquals(TipoVerificacaoCheckin.NAO_VERIFICADO, item.comprovante!!.tipoVerificacao)
        assertEquals("Sem verificação", item.comprovante!!.tipoVerificacao.descricao)
    }

    @Test
    fun `reproducao do defeito - checkin manual confirmado com distancia maior que 200m nao fica preso em pendente`() {
        // Antes do fix, Mapeadores olhava só checkinDistanciaM <= 200. Com distancia = 350m,
        // virava MANUAL_PENDENTE mesmo com verificacao=verificado e checkinConfirmadoEm preenchido.
        val dto = criarTurnoDto(
            checkinTipo = "manual",
            checkinDistanciaM = 350,
            checkinConfirmadoEm = "2026-11-01T21:15:00Z",
            verificacao = "verificado",
        )
        val item = dto.paraItem()

        assertNotNull(item.comprovante)
        assertEquals(TipoVerificacaoCheckin.MANUAL_CONFIRMADO, item.comprovante!!.tipoVerificacao)
    }

    @Test
    fun `valor desconhecido de verificacao cai no estado conservador NAO_VERIFICADO sem quebrar`() {
        val dto = criarTurnoDto(
            checkinTipo = "manual",
            checkinDistanciaM = null,
            verificacao = "em_auditoria_futura",
        )
        val item = dto.paraItem()

        assertNotNull(item.comprovante)
        assertEquals(TipoVerificacaoCheckin.NAO_VERIFICADO, item.comprovante!!.tipoVerificacao)
    }

    @Test
    fun `turno sem checkin gera comprovante nulo`() {
        val dto = criarTurnoDto(checkinEm = null)
        val item = dto.paraItem()

        assertNull(item.comprovante)
    }

    @Test
    fun `funcao isolada mapearTipoVerificacaoCheckin cobre todas as combinacoes normativas`() {
        // Geolocalizado padrão
        assertEquals(
            TipoVerificacaoCheckin.GEOLOCALIZADO,
            mapearTipoVerificacaoCheckin("verificado", checkinTipo = "geolocalizado"),
        )
        // Manual confirmado por tipo
        assertEquals(
            TipoVerificacaoCheckin.MANUAL_CONFIRMADO,
            mapearTipoVerificacaoCheckin("verificado", checkinTipo = "manual"),
        )
        // Manual confirmado por timestamp de confirmacao
        assertEquals(
            TipoVerificacaoCheckin.MANUAL_CONFIRMADO,
            mapearTipoVerificacaoCheckin("verificado", checkinTipo = null, checkinConfirmadoEm = "2026-11-01T21:10:00Z"),
        )
        // Verificado sem tipo nem timestamp assume geolocalizado
        assertEquals(
            TipoVerificacaoCheckin.GEOLOCALIZADO,
            mapearTipoVerificacaoCheckin("verificado", checkinTipo = null, checkinConfirmadoEm = null),
        )
        // Pendente
        assertEquals(
            TipoVerificacaoCheckin.MANUAL_PENDENTE,
            mapearTipoVerificacaoCheckin("pendente", checkinTipo = "manual"),
        )
        // Não verificado
        assertEquals(
            TipoVerificacaoCheckin.NAO_VERIFICADO,
            mapearTipoVerificacaoCheckin("nao_verificado", checkinTipo = "manual"),
        )
        // Desconhecido cai no conservador
        assertEquals(
            TipoVerificacaoCheckin.NAO_VERIFICADO,
            mapearTipoVerificacaoCheckin("desconhecido_xyz"),
        )
    }
}
