package br.com.frila.feature.vagas.feed

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoVagas
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpResponseData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Cartão qmheBhAK, fatia 1: o feed pagina de 30 em 30 com `deslocamento`, tira as repetidas e não perde o que está na tela
 * (paridade com `carregarMais` do `FeedVagasViewModel` do iOS). A página passa pelo cliente real (`ServicoVagas` + `MockEngine`).
 */
class FeedPaginadoTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")

    private fun vagaJson(id: String) = """
        {"id":"$id","funcao":{"id":"f1","nome":"garçom","categoria":"Salão"},
         "estabelecimento":{"id":"e1","tipo":"estabelecimento","nome":"Bar do Zé",
           "reputacao":{"positivas":7,"total":7,"taxa_comparecimento":1.0,"turnos_considerados":7,"turnos_realizados":7}},
         "inicio_em":"2026-11-01T21:00:00Z","fim_em":"2026-11-02T03:00:00Z","local":"SQN 108","regiao_administrativa":"Asa Norte",
         "distancia_km":4.2,"valor_centavos":16000,"posicoes_abertas":2,
         "inclusos":{"inclui_refeicao":true,"inclui_transporte":false,"exige_material_proprio":false},"modo":"selecao"}
    """.trimIndent()

    private fun pagina(ids: List<String>) = ids.joinToString(",", "[", "]") { vagaJson(it) }

    private val primeira = (0 until 30).map { "v$it" }

    /** O servidor falso: a resposta de cada `deslocamento` (ou `null` para 503). Guarda os deslocamentos pedidos. */
    private class Rede(val responder: suspend MockRequestHandleScope.(deslocamento: Int) -> HttpResponseData) {
        val deslocamentos = mutableListOf<Int>()
        val servico = ServicoVagas(
            ClienteSupabase(
                baseUrl = "https://frila.supabase.co",
                apiKey = "chave-teste",
                engine = MockEngine { request ->
                    val d = request.url.parameters["deslocamento"]!!.toInt()
                    deslocamentos += d
                    responder(d)
                },
            ),
        )
    }

    private fun viewModel(rede: Rede) = FeedVagasViewModel(servicoVagas = rede.servico, escopo = CoroutineScope(Dispatchers.Unconfined))

    private fun FeedVagasViewModel.ids() = estado.value.vagas.map { it.id }

    @Test
    fun `primeira pagina cheia deixa pedir a seguinte, que junta as vagas e fecha a lista quando vem menor`() = runBlocking {
        val rede = Rede { d ->
            respond(if (d == 0) pagina(primeira) else pagina((30 until 35).map { "v$it" }), HttpStatusCode.OK, json)
        }
        val vm = viewModel(rede)
        vm.carregar().join()
        assertTrue(vm.estado.value.haMaisPaginas)
        assertEquals(30, vm.ids().size)

        vm.carregarMais().join()

        assertEquals(listOf(0, 30), rede.deslocamentos)
        assertEquals((0 until 35).map { "v$it" }.toSet(), vm.ids().toSet())
        assertFalse(vm.estado.value.haMaisPaginas)
        assertFalse(vm.estado.value.carregandoMais)
        vm.carregarMais().join()
        assertEquals(listOf(0, 30), rede.deslocamentos)
    }

    @Test
    fun `primeira pagina menor que 30 nao pede mais`() = runBlocking {
        val rede = Rede { respond(pagina(listOf("v0", "v1")), HttpStatusCode.OK, json) }
        val vm = viewModel(rede)
        vm.carregar().join()

        assertFalse(vm.estado.value.haMaisPaginas)
        vm.carregarMais().join()
        assertEquals(listOf(0), rede.deslocamentos)
    }

    @Test
    fun `vaga repetida entre as paginas aparece uma vez`() = runBlocking {
        // A ordem do servidor mudou entre as páginas: v29 e v28 voltam na segunda.
        val rede = Rede { d -> respond(if (d == 0) pagina(primeira) else pagina(listOf("v29", "v28", "v30")), HttpStatusCode.OK, json) }
        val vm = viewModel(rede)
        vm.carregar().join()

        vm.carregarMais().join()

        assertEquals(31, vm.ids().size)
        assertEquals(31, vm.ids().toSet().size)
    }

    @Test
    fun `segundo pedido com a pagina em voo nao sai`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        val rede = Rede { d ->
            if (d > 0) liberar.await()
            respond(if (d == 0) pagina(primeira) else pagina(listOf("v30")), HttpStatusCode.OK, json)
        }
        val vm = viewModel(rede)
        vm.carregar().join()

        val primeiroPedido = vm.carregarMais()
        assertTrue(vm.estado.value.carregandoMais)
        vm.carregarMais().join()
        liberar.complete(Unit)
        primeiroPedido.join()

        assertEquals(listOf(0, 30), rede.deslocamentos)
    }

    @Test
    fun `falha da pagina seguinte nao apaga a lista e o proximo pedido tenta de novo`() = runBlocking {
        var falhar = true
        val rede = Rede { d ->
            when {
                d == 0 -> respond(pagina(primeira), HttpStatusCode.OK, json)
                falhar -> respond("""{"code":"indisponivel","message":"x"}""", HttpStatusCode.ServiceUnavailable, json)
                else -> respond(pagina(listOf("v30")), HttpStatusCode.OK, json)
            }
        }
        val vm = viewModel(rede)
        vm.carregar().join()

        vm.carregarMais().join()
        assertEquals(30, vm.ids().size)
        assertTrue(vm.estado.value.haMaisPaginas)
        assertFalse(vm.estado.value.carregandoMais)
        assertEquals(StatusFeed.SUCESSO, vm.estado.value.status)

        falhar = false
        vm.carregarMais().join()
        assertEquals(31, vm.ids().size)
    }

    @Test
    fun `pagina pedida antes de puxar para atualizar nao se junta a lista nova`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        var leiturasDaPrimeira = 0
        val rede = Rede { d ->
            if (d == 0) {
                leiturasDaPrimeira++
                respond(pagina(if (leiturasDaPrimeira == 1) primeira else (100 until 130).map { "n$it" }), HttpStatusCode.OK, json)
            } else {
                liberar.await()
                respond(pagina(listOf("velha")), HttpStatusCode.OK, json)
            }
        }
        val vm = viewModel(rede)
        vm.carregar().join()

        val pedido = vm.carregarMais()
        vm.atualizar().join()
        liberar.complete(Unit)
        pedido.join()

        assertFalse("velha" in vm.ids())
        assertEquals((100 until 130).map { "n$it" }.toSet(), vm.ids().toSet())
    }

    @Test
    fun `releitura em silencio nao troca uma lista que ja passou da primeira pagina`() = runBlocking {
        val rede = Rede { d -> respond(if (d == 0) pagina(primeira) else pagina(listOf("v30")), HttpStatusCode.OK, json) }
        val vm = viewModel(rede)
        vm.carregar().join()
        vm.carregarMais().join()

        vm.atualizarEmSilencio().join()

        assertEquals(listOf(0, 30), rede.deslocamentos)
        assertEquals(31, vm.ids().size)
    }
}
