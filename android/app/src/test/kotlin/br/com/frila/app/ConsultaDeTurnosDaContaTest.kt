package br.com.frila.app

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoConta
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.ServicoVagas
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import java.time.Instant
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * 9NpQTfGG (2ª fatia): o que a exclusão de conta consulta para listar os turnos futuros, como o iOS: o profissional lê
 * `meus_turnos`; o contratante lê o painel de cada casa dele, só as posições `confirmada`, e a consulta é limitada.
 */
class ConsultaDeTurnosDaContaTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val agora = Instant.parse("2026-11-20T15:00:00Z")

    private class Pedido(val caminho: String, val corpo: String)

    private fun usuario(perfil: String) = """
        {"id":"u1","perfil":"$perfil","nome":"Fulana","telefone":"+5561999990000","email":"f@t.test","nascimento":"1990-01-01","estado":"ativa"}
    """.trimIndent()

    private fun turno(id: String, inicio: String, estado: String?) = """
        {"id":"$id","posicao_id":"pos-$id",
         "vaga":{"id":"vaga-$id","funcao":"garçom","local":"CLS 405 $id","regiao_administrativa":"Plano Piloto",
                 "inicio_em":"$inicio","fim_em":"2027-01-01T02:00:00Z","valor_centavos":16000},
         "contraparte":{"id":"e-$id","tipo":"estabelecimento","nome":"Bar $id",
                        "reputacao":{"positivas":1,"total":1,"turnos_considerados":1,"turnos_realizados":1}},
         "verificacao":"pendente","valor_acordado_centavos":16000,"pode_avaliar":false,
         "estado":${estado?.let { "\"$it\"" } ?: "null"}}
    """.trimIndent()

    private fun posicao(id: String, estado: String, nome: String?, turnoId: String? = null) = """
        {"id":"$id","estado":"$estado","em_atraso":false,
         ${turnoId?.let { "\"turno_id\":\"$it\"," } ?: ""}
         "profissional":${nome?.let { """{"id":"p-$id","tipo":"profissional","nome":"$it","reputacao":{"positivas":0,"total":0,"turnos_considerados":0,"turnos_realizados":0}}""" } ?: "null"}}
    """.trimIndent()

    private fun painel(casa: String, vararg vagas: String) =
        """{"estabelecimento_id":"$casa","checkins_pendentes":[],"vagas":[${vagas.joinToString(",")}]}"""

    private fun vagaNoPainel(id: String, inicio: String, vararg posicoes: String) = """
        {"vaga":{"id":"$id","funcao":"bartender","local":"SCLN 406 $id","regiao_administrativa":"Plano Piloto",
                 "inicio_em":"$inicio","fim_em":"2027-02-01T02:00:00Z","valor_centavos":16000},
         "modo":"selecao","estado":"publicada","oculta":false,"alerta_vaga_vazia":false,"candidatos_pendentes":0,
         "posicoes":[${posicoes.joinToString(",")}]}
    """.trimIndent()

    private class Servicos(
        val conta: ServicoConta,
        val turnos: ServicoTurnos,
        val membros: ServicoMembros,
        val vagas: ServicoVagas,
        val pedidos: List<Pedido>,
    )

    /** [resposta] decide pelo caminho **e** pelo corpo do POST (o painel de cada casa vem no corpo). */
    private fun servicos(resposta: (caminho: String, corpo: String) -> Pair<HttpStatusCode, String>): Servicos {
        val pedidos = mutableListOf<Pedido>()
        val cliente = ClienteSupabase(
            "https://frila.supabase.co", "chave-teste",
            engine = MockEngine { request ->
                val corpoPedido = (request.body as? TextContent)?.text.orEmpty()
                pedidos += Pedido(request.url.encodedPath, corpoPedido)
                val (status, corpo) = resposta(request.url.encodedPath, corpoPedido)
                respond(corpo, status, json)
            },
        )
        return Servicos(ServicoConta(cliente), ServicoTurnos(cliente), ServicoMembros(cliente), ServicoVagas(cliente), pedidos)
    }

    private fun consultar(s: Servicos) = runBlocking { consultarTurnosDaConta(s.conta, s.turnos, s.membros, s.vagas, agora) }

    private val duasCasas = """[{"id":"casa-1","nome":"Bar 1","papel":"administrador"},{"id":"casa-2","nome":"Bar 2","papel":"operador"}]"""

    @Test
    fun `profissional le meus_turnos, sem os cancelados, e nao le casa nenhuma`() {
        val s = servicos { caminho, _ ->
            when {
                caminho.endsWith("/minha_conta") -> HttpStatusCode.OK to usuario("profissional")
                caminho.endsWith("/meus_turnos") ->
                    HttpStatusCode.OK to "[${turno("a", "2026-11-25T20:00:00Z", "confirmada")}," +
                        "${turno("b", "2026-11-26T20:00:00Z", "cancelada")},${turno("c", "2026-11-27T20:00:00Z", null)}]"
                else -> HttpStatusCode.InternalServerError to "{}"
            }
        }

        val consulta = consultar(s)

        assertEquals(listOf("a", "c"), consulta.turnos.map { it.id })
        assertEquals("Bar a", consulta.turnos.first().contraparte)
        assertFalse(consulta.limitada)
        assertTrue(s.pedidos.none { it.caminho.endsWith("/meus_estabelecimentos") || it.caminho.endsWith("/painel_estabelecimento") })
    }

    @Test
    fun `contratante le o painel de cada casa e lista so as posicoes confirmadas, com a contraparte`() {
        val s = servicos { caminho, corpoPedido ->
            when {
                caminho.endsWith("/minha_conta") -> HttpStatusCode.OK to usuario("contratante")
                caminho.endsWith("/meus_estabelecimentos") -> HttpStatusCode.OK to duasCasas
                caminho.endsWith("/painel_estabelecimento") && corpoPedido.contains("casa-1") -> HttpStatusCode.OK to painel(
                    "casa-1",
                    vagaNoPainel(
                        "v1", "2026-12-02T20:00:00Z",
                        posicao("p1", "confirmada", "Ana", turnoId = "turno-1"),
                        posicao("p2", "aberta", null),
                        posicao("p3", "cancelada", "Beto"),
                        posicao("p4", "cumprida", "Cris"),
                    ),
                )
                caminho.endsWith("/painel_estabelecimento") -> HttpStatusCode.OK to painel(
                    "casa-2",
                    vagaNoPainel("v2", "2026-12-09T20:00:00Z", posicao("p5", "confirmada", null)),
                )
                else -> HttpStatusCode.InternalServerError to "{}"
            }
        }

        val consulta = consultar(s)

        assertEquals(listOf("turno-1", "p5"), consulta.turnos.map { it.id }, "o id é o do turno, ou o da posição quando não há turno")
        assertEquals(listOf("Ana", "Profissional"), consulta.turnos.map { it.contraparte }, "sem profissional na posição, o nome genérico")
        assertEquals(listOf("bartender", "bartender"), consulta.turnos.map { it.funcao })
        assertEquals(listOf("SCLN 406 v1", "SCLN 406 v2"), consulta.turnos.map { it.local })
        assertTrue(consulta.limitada, "a consulta da casa é limitada à janela do painel")
        val paineis = s.pedidos.filter { it.caminho.endsWith("/painel_estabelecimento") }
        assertEquals(2, paineis.size)
        assertTrue(paineis[0].corpo.contains("\"estabelecimento_id\":\"casa-1\""), paineis[0].corpo)
        assertTrue(paineis[1].corpo.contains("\"estabelecimento_id\":\"casa-2\""), paineis[1].corpo)
        // A janela: do dia anterior (agora - 24 h) até 12 meses à frente.
        assertTrue(paineis[0].corpo.contains("\"de\":\"2026-11-19T15:00:00Z\""), paineis[0].corpo)
        assertTrue(paineis[0].corpo.contains("\"ate\":\"2027-11-20T"), paineis[0].corpo)
        assertTrue(s.pedidos.none { it.caminho.endsWith("/meus_turnos") }, "contratante não lê meus_turnos")
    }

    @Test
    fun `contratante sem casa nenhuma devolve lista vazia e nao limitada, sem ler painel`() {
        val s = servicos { caminho, _ ->
            when {
                caminho.endsWith("/minha_conta") -> HttpStatusCode.OK to usuario("contratante")
                caminho.endsWith("/meus_estabelecimentos") -> HttpStatusCode.OK to "[]"
                else -> HttpStatusCode.InternalServerError to "{}"
            }
        }

        val consulta = consultar(s)

        assertEquals(emptyList<Any>(), consulta.turnos)
        assertFalse(consulta.limitada)
        assertTrue(s.pedidos.none { it.caminho.endsWith("/painel_estabelecimento") })
    }

    @Test
    fun `painel de outra casa e ignorado`() {
        val s = servicos { caminho, _ ->
            when {
                caminho.endsWith("/minha_conta") -> HttpStatusCode.OK to usuario("contratante")
                caminho.endsWith("/meus_estabelecimentos") -> HttpStatusCode.OK to """[{"id":"casa-1","nome":"Bar 1","papel":"administrador"}]"""
                caminho.endsWith("/painel_estabelecimento") ->
                    HttpStatusCode.OK to painel("casa-OUTRA", vagaNoPainel("v1", "2026-12-02T20:00:00Z", posicao("p1", "confirmada", "Ana")))
                else -> HttpStatusCode.InternalServerError to "{}"
            }
        }

        assertEquals(emptyList<Any>(), consultar(s).turnos)
    }

    @Test
    fun `qualquer falha propaga, para a tela avisar que a lista esta indisponivel`() {
        val falhas = mapOf(
            "minha_conta" to "/minha_conta",
            "meus_estabelecimentos" to "/meus_estabelecimentos",
            "painel de uma casa" to "/painel_estabelecimento",
        )
        for ((nome, falhaEm) in falhas) {
            val s = servicos { caminho, _ ->
                when {
                    caminho.endsWith(falhaEm) -> HttpStatusCode.InternalServerError to """{"code":"erro_interno","message":"x"}"""
                    caminho.endsWith("/minha_conta") -> HttpStatusCode.OK to usuario("contratante")
                    caminho.endsWith("/meus_estabelecimentos") -> HttpStatusCode.OK to """[{"id":"casa-1","nome":"Bar 1","papel":"administrador"}]"""
                    else -> HttpStatusCode.InternalServerError to "{}"
                }
            }
            assertThrows(Exception::class.java, { consultar(s) }, nome)
        }
    }

    @Test
    fun `falha numa das casas derruba a consulta toda, em vez de listar so metade`() {
        val s = servicos { caminho, corpoPedido ->
            when {
                caminho.endsWith("/minha_conta") -> HttpStatusCode.OK to usuario("contratante")
                caminho.endsWith("/meus_estabelecimentos") -> HttpStatusCode.OK to duasCasas
                caminho.endsWith("/painel_estabelecimento") && corpoPedido.contains("casa-2") ->
                    HttpStatusCode.InternalServerError to """{"code":"erro_interno","message":"x"}"""
                caminho.endsWith("/painel_estabelecimento") ->
                    HttpStatusCode.OK to painel("casa-1", vagaNoPainel("v1", "2026-12-02T20:00:00Z", posicao("p1", "confirmada", "Ana")))
                else -> HttpStatusCode.InternalServerError to "{}"
            }
        }

        assertThrows(Exception::class.java) { consultar(s) }
    }
}
