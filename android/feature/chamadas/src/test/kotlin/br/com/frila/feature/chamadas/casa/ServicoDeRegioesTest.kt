package br.com.frila.feature.chamadas.casa

import br.com.frila.core.rede.ClienteSupabase
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class ServicoDeRegioesTest {

    @Test
    fun `lista as regioes ativas na ordem do id pela tabela, como o iOS`() = runBlocking {
        val urls = mutableListOf<io.ktor.http.Url>()
        val cliente = ClienteSupabase(
            "https://frila.supabase.co",
            "chave-teste",
            engine = MockEngine { request ->
                urls += request.url
                respond(
                    """[{"id":1,"numero":"I","nome":"Plano Piloto","ativo":true},{"id":2,"numero":"II","nome":"Gama","ativo":true}]""",
                    HttpStatusCode.OK,
                    headersOf(HttpHeaders.ContentType, "application/json"),
                )
            },
        )

        val regioes = ServicoDeRegioes(cliente).regioesAtivas()

        assertEquals(listOf("Plano Piloto", "Gama"), regioes.map { it.nome })
        val url = urls.single()
        assertEquals("/rest/v1/regiao_administrativa", url.encodedPath)
        assertEquals("eq.true", url.parameters["ativo"])
        assertEquals("id.asc", url.parameters["order"])
        assertEquals("id,numero,nome,ativo", url.parameters["select"])
    }
}
