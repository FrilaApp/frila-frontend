package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** Lote 2 (L2-0): `situacao_da_conta`, `contestar_suspensao` e `pedir_revisao_despacho`. Contrato 0.2.95. */
class ServicoContaLote2Test {

    private val relato = "Não reconheço a falta do turno de sábado."

    private fun protocoloJson(tipo: String) =
        """{"ocorrencia_id":"6f1c2a4e-aaaa-4aaa-8aaa-aaaaaaaaaaaa","tipo":"$tipo","criada_em":"2026-11-17T12:00:00Z","prazo_resposta_ate":"2026-11-24"}"""

    private val contestacaoJaAberta = Recusa(HttpStatusCode.Conflict, "contestacao_ja_aberta", CodigoErroAPI.CONTESTACAO_JA_ABERTA)
    private val relatoVazio = Recusa(HttpStatusCode.UnprocessableEntity, "campo_obrigatorio", CodigoErroAPI.CAMPO_OBRIGATORIO, "relato")
    private val relatoCurto = Recusa(HttpStatusCode.UnprocessableEntity, "campo_invalido", CodigoErroAPI.CAMPO_INVALIDO, "relato")

    // ---- situacao_da_conta ----

    @Test
    fun `situacaoDaConta faz POST com corpo vazio e decodifica a conta ativa, com suspensao nula ou ausente`() = runTest {
        val visto = PedidoVisto()
        val ativa = ServicoConta(clienteDeTeste(visto, """{"estado":"ativa","suspensao":null}""")).situacaoDaConta()

        visto.conferirPost("situacao_da_conta")
        assertTrue(visto.corpo!!.isEmpty())
        assertEquals("ativa", ativa.estado)
        assertNull(ativa.suspensao)

        val semCampo = ServicoConta(clienteDeTeste(PedidoVisto(), """{"estado":"ativa"}""")).situacaoDaConta()
        assertNull(semCampo.suspensao)
    }

    @Test
    fun `situacaoDaConta de conta suspensa decodifica motivo e data, sem contestacao`() = runTest {
        val json = """{"estado":"suspensa","suspensao":{"motivo":"Faltas sem aviso","desde":"2026-11-10T09:00:00Z","contestacao":null}}"""

        val situacao = ServicoConta(clienteDeTeste(PedidoVisto(), json)).situacaoDaConta()

        assertEquals("suspensa", situacao.estado)
        assertEquals("Faltas sem aviso", situacao.suspensao!!.motivo)
        assertEquals("2026-11-10T09:00:00Z", situacao.suspensao!!.desde)
        assertNull(situacao.suspensao!!.contestacao)
    }

    @Test
    fun `situacaoDaConta de conta suspensa ja contestada decodifica o protocolo da contestacao`() = runTest {
        val json = """{"estado":"suspensa","suspensao":{"motivo":"Faltas sem aviso","desde":"2026-11-10T09:00:00Z","contestacao":${protocoloJson("contestacao")}}}"""

        val contestacao = ServicoConta(clienteDeTeste(PedidoVisto(), json)).situacaoDaConta().suspensao!!.contestacao!!

        assertEquals("6f1c2a4e-aaaa-4aaa-8aaa-aaaaaaaaaaaa", contestacao.ocorrenciaId)
        assertEquals("contestacao", contestacao.tipo)
        assertEquals("2026-11-24", contestacao.prazoRespostaAte)
    }

    @Test
    fun `situacaoDaConta lanca nao_autenticado com o token vencido`() = runTest {
        conferirRecusas(listOf(TOKEN_VENCIDO)) { ServicoConta(it).situacaoDaConta() }
    }

    // ---- contestar_suspensao ----

    @Test
    fun `contestarSuspensao faz POST so com o relato e decodifica o protocolo`() = runTest {
        val visto = PedidoVisto()
        val servico = ServicoConta(clienteDeTeste(visto, protocoloJson("contestacao")))

        val protocolo = servico.contestarSuspensao(relato)

        visto.conferirPost("contestar_suspensao")
        assertEquals(setOf("relato"), visto.corpo!!.keys)
        assertEquals(relato, visto.corpo!!["relato"]!!.jsonPrimitive.content)
        assertEquals("contestacao", protocolo.tipo)
        assertEquals("2026-11-17T12:00:00Z", protocolo.criadaEm)
    }

    @Test
    fun `contestarSuspensao lanca o codigo de cada recusa do contrato`() = runTest {
        conferirRecusas(
            listOf(
                contestacaoJaAberta,
                Recusa(HttpStatusCode.UnprocessableEntity, "sem_suspensao_ativa", CodigoErroAPI.SEM_SUSPENSAO_ATIVA),
                relatoVazio,
                relatoCurto,
                TOKEN_VENCIDO,
            ),
        ) { ServicoConta(it).contestarSuspensao(relato) }
    }

    // ---- pedir_revisao_despacho ----

    @Test
    fun `pedirRevisaoDespacho faz POST so com o relato e decodifica o protocolo`() = runTest {
        val visto = PedidoVisto()
        val servico = ServicoConta(clienteDeTeste(visto, protocoloJson("revisao_despacho")))

        val protocolo = servico.pedirRevisaoDespacho(relato)

        visto.conferirPost("pedir_revisao_despacho")
        assertEquals(setOf("relato"), visto.corpo!!.keys)
        assertEquals(relato, visto.corpo!!["relato"]!!.jsonPrimitive.content)
        assertEquals("revisao_despacho", protocolo.tipo)
        assertEquals("6f1c2a4e-aaaa-4aaa-8aaa-aaaaaaaaaaaa", protocolo.ocorrenciaId)
    }

    @Test
    fun `pedirRevisaoDespacho lanca o codigo de cada recusa do contrato`() = runTest {
        conferirRecusas(listOf(contestacaoJaAberta, relatoVazio, relatoCurto, CONTA_SUSPENSA, TOKEN_VENCIDO)) {
            ServicoConta(it).pedirRevisaoDespacho(relato)
        }
    }
}
