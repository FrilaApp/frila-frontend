package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** Lote 2 (L2-0): `avisar_a_caminho` e `reabrir_por_atraso`. Pedido, resposta e as recusas do contrato 0.2.95. */
class ServicoTurnosLote2Test {

    private val turno = "11111111-1111-1111-1111-111111111111"
    private val posicao = "33333333-3333-3333-3333-333333333333"
    private val novaPosicao = "44444444-4444-4444-4444-444444444444"

    @Test
    fun `avisarACaminho faz POST so com turno_id e decodifica o instante do aviso`() = runTest {
        val visto = PedidoVisto()
        val servico = ServicoTurnos(clienteDeTeste(visto, """{"turno_id":"$turno","a_caminho_em":"2026-11-20T18:30:00Z"}"""))

        val resultado = servico.avisarACaminho(turno)

        visto.conferirPost("avisar_a_caminho")
        assertEquals(setOf("turno_id"), visto.corpo!!.keys)
        assertEquals(turno, visto.corpo!!["turno_id"]!!.jsonPrimitive.content)
        assertEquals(turno, resultado.turnoId)
        assertEquals("2026-11-20T18:30:00Z", resultado.aCaminhoEm)
    }

    @Test
    fun `avisarACaminho lanca o codigo de cada recusa do contrato`() = runTest {
        conferirRecusas(
            listOf(
                Recusa(HttpStatusCode.UnprocessableEntity, "a_caminho_fora_da_janela", CodigoErroAPI.A_CAMINHO_FORA_DA_JANELA),
                Recusa(HttpStatusCode.Forbidden, "sem_permissao", CodigoErroAPI.SEM_PERMISSAO),
                CONTA_SUSPENSA,
                Recusa(HttpStatusCode.UnprocessableEntity, "campo_obrigatorio", CodigoErroAPI.CAMPO_OBRIGATORIO, "turno_id"),
                TOKEN_VENCIDO,
            ),
        ) { ServicoTurnos(it).avisarACaminho(turno) }
    }

    @Test
    fun `reabrirPorAtraso faz POST so com posicao_id e decodifica a falta e a posicao nova`() = runTest {
        val visto = PedidoVisto()
        val servico = ServicoTurnos(
            clienteDeTeste(visto, """{"posicao_id":"$posicao","falta":true,"reaberta":true,"nova_posicao_id":"$novaPosicao"}"""),
        )

        val resultado = servico.reabrirPorAtraso(posicao)

        visto.conferirPost("reabrir_por_atraso")
        assertEquals(setOf("posicao_id"), visto.corpo!!.keys)
        assertEquals(posicao, visto.corpo!!["posicao_id"]!!.jsonPrimitive.content)
        assertEquals(posicao, resultado.posicaoId)
        assertTrue(resultado.falta)
        assertTrue(resultado.reaberta)
        assertEquals(novaPosicao, resultado.novaPosicaoId)
    }

    @Test
    fun `reabrirPorAtraso com o turno descoberto decodifica reaberta falsa e posicao nova nula`() = runTest {
        val servico = ServicoTurnos(
            clienteDeTeste(PedidoVisto(), """{"posicao_id":"$posicao","falta":true,"reaberta":false,"nova_posicao_id":null}"""),
        )

        val resultado = servico.reabrirPorAtraso(posicao)

        assertFalse(resultado.reaberta)
        assertNull(resultado.novaPosicaoId)
    }

    @Test
    fun `reabrirPorAtraso lanca o codigo de cada recusa do contrato`() = runTest {
        conferirRecusas(
            listOf(
                Recusa(HttpStatusCode.UnprocessableEntity, "reabertura_antes_da_tolerancia", CodigoErroAPI.REABERTURA_ANTES_DA_TOLERANCIA),
                Recusa(HttpStatusCode.Conflict, "posicao_nao_cancelavel", CodigoErroAPI.POSICAO_NAO_CANCELAVEL, "checkin_registrado"),
                Recusa(HttpStatusCode.Conflict, "posicao_nao_cancelavel", CodigoErroAPI.POSICAO_NAO_CANCELAVEL),
                Recusa(HttpStatusCode.Forbidden, "sem_permissao", CodigoErroAPI.SEM_PERMISSAO),
                Recusa(HttpStatusCode.UnprocessableEntity, "campo_obrigatorio", CodigoErroAPI.CAMPO_OBRIGATORIO, "posicao_id"),
                TOKEN_VENCIDO,
            ),
        ) { ServicoTurnos(it).reabrirPorAtraso(posicao) }
    }

    @Test
    fun `reabrirPorAtraso nunca repete sozinho, nem em falha passageira do servidor`() = runTest {
        // Reabrir marca falta e abre posição nova: repetir sozinho poderia reabrir duas vezes.
        val visto = PedidoVisto()
        val servico = ServicoTurnos(clienteDeTeste(visto, "", HttpStatusCode.ServiceUnavailable))

        erroDaApiDe { servico.reabrirPorAtraso(posicao) }

        assertEquals(1, visto.vezes)
    }
}
