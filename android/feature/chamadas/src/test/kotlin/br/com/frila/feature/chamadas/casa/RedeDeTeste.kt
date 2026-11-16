package br.com.frila.feature.chamadas.casa

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoChamadaDireta
import br.com.frila.core.rede.ServicoMembros
import br.com.frila.core.rede.ServicoVagas
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpResponseData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject

/**
 * O servidor falso dos testes do lado da casa: um `MockEngine` que guarda cada pedido (nome do RPC e corpo) e
 * responde pelo último trecho do caminho (`chamar_profissional`, `funcao`...). Os ViewModels recebem as funções
 * dos serviços reais, então o que o teste confere é o que iria ao fio.
 */
internal class RedeDeTeste {
    class Pedido(val nome: String, val corpo: JsonObject)

    val pedidos = mutableListOf<Pedido>()
    private val rotas = mutableMapOf<String, suspend MockRequestHandleScope.(Pedido) -> HttpResponseData>()

    private val json = headersOf(HttpHeaders.ContentType, "application/json")

    private val cliente = ClienteSupabase(
        "https://frila.supabase.co",
        "chave-teste",
        engine = MockEngine { request ->
            val corpo = (request.body as? TextContent)?.text
                ?.let { ClienteSupabase.jsonFrila.parseToJsonElement(it).jsonObject }
                ?: JsonObject(emptyMap())
            val pedido = Pedido(request.url.encodedPath.substringAfterLast('/'), corpo)
            pedidos += pedido
            val rota = rotas[pedido.nome]
            if (rota != null) rota(this, pedido) else respond("""{"code":"nao_encontrado","message":"x"}""", HttpStatusCode.NotFound, json)
        },
    )

    val chamadas = ServicoChamadaDireta(cliente)
    val membros = ServicoMembros { cliente }
    val vagas = ServicoVagas { cliente }

    fun rota(nome: String, resposta: suspend MockRequestHandleScope.(Pedido) -> HttpResponseData) {
        rotas[nome] = resposta
    }

    fun ok(nome: String, corpo: String) = rota(nome) { respond(corpo, HttpStatusCode.OK, json) }

    fun recusa(nome: String, status: HttpStatusCode, codigo: String, detalhes: String? = null) = rota(nome) {
        respond(
            content = """{"code":"$codigo","message":"x","details":${detalhes?.let { "\"$it\"" } ?: "null"}}""",
            status = status,
            headers = json,
        )
    }

    fun doNome(nome: String): List<Pedido> = pedidos.filter { it.nome == nome }
}
