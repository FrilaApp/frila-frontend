package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** Lote 2 (L2-0): `incluir_na_equipe`, `listar_bloqueios` e `desbloquear`. Contrato 0.2.95. */
class ServicoConfiancaLote2Test {

    private val casa = "11111111-1111-1111-1111-111111111111"
    private val profissional = "7c1d2b3a-4e5f-4a6b-8c7d-9e0f1a2b3c4d"

    private val naoEncontrado = Recusa(HttpStatusCode.NotFound, "nao_encontrado", CodigoErroAPI.NAO_ENCONTRADO)

    // ---- incluir_na_equipe ----

    @Test
    fun `incluirNaEquipe faz POST com a casa e o profissional e decodifica o par incluido`() = runTest {
        val visto = PedidoVisto()
        val servico = ServicoConfianca(clienteDeTeste(visto, """{"estabelecimento_id":"$casa","profissional_id":"$profissional"}"""))

        val membro = servico.incluirNaEquipe(estabelecimentoId = casa, profissionalId = profissional)

        visto.conferirPost("incluir_na_equipe")
        assertEquals(setOf("estabelecimento_id", "profissional_id"), visto.corpo!!.keys)
        assertEquals(casa, visto.corpo!!["estabelecimento_id"]!!.jsonPrimitive.content)
        assertEquals(profissional, visto.corpo!!["profissional_id"]!!.jsonPrimitive.content)
        assertEquals(casa, membro.estabelecimentoId)
        assertEquals(profissional, membro.profissionalId)
    }

    @Test
    fun `incluirNaEquipe lanca o codigo de cada recusa do contrato, com o motivo em details`() = runTest {
        conferirRecusas(
            listOf(
                Recusa(HttpStatusCode.Forbidden, "sem_permissao", CodigoErroAPI.SEM_PERMISSAO, "sem_turno_cumprido"),
                Recusa(HttpStatusCode.Forbidden, "sem_permissao", CodigoErroAPI.SEM_PERMISSAO),
                CONTA_SUSPENSA,
                naoEncontrado,
                Recusa(HttpStatusCode.UnprocessableEntity, "campo_obrigatorio", CodigoErroAPI.CAMPO_OBRIGATORIO, "profissional_id"),
                TOKEN_VENCIDO,
            ),
        ) { ServicoConfianca(it).incluirNaEquipe(casa, profissional) }
    }

    // ---- listar_bloqueios ----

    @Test
    fun `listarBloqueios faz POST com corpo vazio e decodifica o exemplo do contrato`() = runTest {
        val visto = PedidoVisto()
        val json = """
            [{"alvo_tipo":"profissional","alvo_id":"$profissional","nome":"Carlos M.","criado_em":"2026-11-03T14:20:00Z"},
             {"alvo_tipo":"estabelecimento","alvo_id":"0b8a7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d","nome":"Bar do Zé","criado_em":"2026-10-28T22:05:00Z"}]
        """.trimIndent()
        val servico = ServicoConfianca(clienteDeTeste(visto, json))

        val bloqueios = servico.listarBloqueios()

        visto.conferirPost("listar_bloqueios")
        assertTrue(visto.corpo!!.isEmpty())
        assertEquals(2, bloqueios.size)
        assertEquals("profissional", bloqueios[0].alvoTipo)
        assertEquals(profissional, bloqueios[0].alvoId)
        assertEquals("Carlos M.", bloqueios[0].nome)
        assertEquals("2026-10-28T22:05:00Z", bloqueios[1].criadoEm)
    }

    @Test
    fun `listarBloqueios sem nenhum bloqueio decodifica lista vazia`() = runTest {
        assertTrue(ServicoConfianca(clienteDeTeste(PedidoVisto(), "[]")).listarBloqueios().isEmpty())
    }

    @Test
    fun `listarBloqueios lanca o codigo de cada recusa do contrato`() = runTest {
        conferirRecusas(listOf(CONTA_SUSPENSA, TOKEN_VENCIDO)) { ServicoConfianca(it).listarBloqueios() }
    }

    // ---- desbloquear ----

    @Test
    fun `desbloquear faz POST com o par do alvo e decodifica o bloqueio desfeito`() = runTest {
        val visto = PedidoVisto()
        val servico = ServicoConfianca(
            clienteDeTeste(visto, """{"alvo_tipo":"profissional","alvo_id":"$profissional","criado_em":"2026-11-03T14:20:00Z"}"""),
        )

        val desfeito = servico.desbloquear(alvoTipo = "profissional", alvoId = profissional)

        visto.conferirPost("desbloquear")
        assertEquals(setOf("alvo_tipo", "alvo_id"), visto.corpo!!.keys)
        assertEquals("profissional", visto.corpo!!["alvo_tipo"]!!.jsonPrimitive.content)
        assertEquals(profissional, visto.corpo!!["alvo_id"]!!.jsonPrimitive.content)
        assertEquals(profissional, desfeito.alvoId)
        assertEquals("2026-11-03T14:20:00Z", desfeito.criadoEm)
    }

    @Test
    fun `desbloquear lanca o codigo de cada recusa do contrato, com o campo em details`() = runTest {
        conferirRecusas(
            listOf(
                Recusa(HttpStatusCode.UnprocessableEntity, "campo_obrigatorio", CodigoErroAPI.CAMPO_OBRIGATORIO, "alvo_id"),
                Recusa(HttpStatusCode.UnprocessableEntity, "campo_invalido", CodigoErroAPI.CAMPO_INVALIDO, "alvo_tipo"),
                naoEncontrado,
                CONTA_SUSPENSA,
                TOKEN_VENCIDO,
            ),
        ) { ServicoConfianca(it).desbloquear("profissional", profissional) }
    }
}
