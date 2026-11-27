package br.com.frila.app

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoVagas
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** iUpi3Es4: a releitura do painel que a escolha de candidato usa para saber se a pessoa já foi confirmada. */
class RelerVagaNoPainelTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")

    private fun vaga(id: String, estado: String) = """
        {"vaga":{"id":"$id","funcao":"garçom","local":"CLS 405","regiao_administrativa":"Plano Piloto",
                 "inicio_em":"2026-11-12T20:00:00Z","fim_em":"2026-11-13T02:00:00Z","valor_centavos":16000},
         "modo":"selecao","estado":"$estado","oculta":false,"alerta_vaga_vazia":false,"candidatos_pendentes":0,"posicoes":[]}
    """.trimIndent()

    private fun painel(casa: String, vararg vagas: String) =
        """{"estabelecimento_id":"$casa","checkins_pendentes":[],"vagas":[${vagas.joinToString(",")}]}"""

    private fun servico(status: HttpStatusCode, corpo: String, corpos: MutableList<String> = mutableListOf()) = ServicoVagas(
        ClienteSupabase(
            "https://frila.supabase.co", "chave-teste",
            engine = MockEngine { request ->
                corpos += (request.body as? TextContent)?.text.orEmpty()
                respond(corpo, status, json)
            },
        ),
    )

    @Test
    fun `devolve a vaga pedida entre as da casa e pede o painel da casa certa`() = runBlocking {
        val corpos = mutableListOf<String>()
        val servico = servico(HttpStatusCode.OK, painel("casa-1", vaga("vaga-A", "publicada"), vaga("vaga-B", "preenchida")), corpos)

        val vaga = relerVagaNoPainel(servico, "casa-1", "vaga-B")

        assertEquals("vaga-B", vaga?.vaga?.id)
        assertEquals("preenchida", vaga?.estado)
        assertTrue(corpos.single().contains("\"estabelecimento_id\":\"casa-1\""), corpos.toString())
    }

    @Test
    fun `sem a vaga no painel, com painel de outra casa ou com a leitura falhando, devolve nulo`() = runBlocking {
        assertNull(relerVagaNoPainel(servico(HttpStatusCode.OK, painel("casa-1", vaga("vaga-A", "publicada"))), "casa-1", "vaga-B"))
        assertNull(relerVagaNoPainel(servico(HttpStatusCode.OK, painel("casa-2", vaga("vaga-B", "publicada"))), "casa-1", "vaga-B"))
        assertNull(relerVagaNoPainel(servico(HttpStatusCode.InternalServerError, """{"code":"erro_interno","message":"x"}"""), "casa-1", "vaga-B"))
        assertNull(relerVagaNoPainel(servico(HttpStatusCode.OK, "isto não é json"), "casa-1", "vaga-B"))
    }
}
