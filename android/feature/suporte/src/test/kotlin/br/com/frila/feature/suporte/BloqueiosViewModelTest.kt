package br.com.frila.feature.suporte

import br.com.frila.core.rede.BloqueioDto
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ItemBloqueioDto
import br.com.frila.core.rede.ServicoConfianca
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.network.sockets.ConnectTimeoutException
import io.ktor.client.request.HttpRequestData
import io.ktor.client.request.HttpResponseData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

class BloqueiosViewModelTest {

    private val ana = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    private val bar = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"

    private fun item(tipo: String, id: String, nome: String) =
        """{"alvo_tipo":"$tipo","alvo_id":"$id","nome":"$nome","criado_em":"2026-11-10T12:00:00Z"}"""

    private val doisBloqueios = "[${item("profissional", ana, "Ana Souza")},${item("estabelecimento", bar, "Bar do Zé")}]"

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val desbloqueioOk = """{"alvo_tipo":"profissional","alvo_id":"$ana","criado_em":"2026-11-10T12:00:00Z"}"""

    private class Pedido(val caminho: String, val corpo: Map<String, String>)

    private class Rede(val resposta: MockRequestHandleScope.(HttpRequestData) -> HttpResponseData) {
        val pedidos = mutableListOf<Pedido>()
        fun desbloqueios() = pedidos.filter { it.caminho.endsWith("/desbloquear") }
    }

    private fun viewModelCom(rede: Rede): BloqueiosViewModel {
        val engine = MockEngine { request ->
            val corpo = (request.body as? TextContent)?.text
                ?.let { ClienteSupabase.jsonFrila.parseToJsonElement(it).jsonObject.mapValues { e -> e.value.jsonPrimitive.content } }
                .orEmpty()
            rede.pedidos += Pedido(request.url.encodedPath, corpo)
            rede.resposta(this, request)
        }
        val servico = ServicoConfianca(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
        return BloqueiosViewModel(
            listar = servico::listarBloqueios,
            desfazer = servico::desbloquear,
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
    }

    private fun MockRequestHandleScope.ok(corpo: String) = respond(corpo, HttpStatusCode.OK, json)

    private fun MockRequestHandleScope.recusa(status: HttpStatusCode, codigo: String, detalhes: String? = null) =
        respond(
            content = """{"code":"$codigo","message":"x","details":${detalhes?.let { "\"$it\"" } ?: "null"}}""",
            status = status,
            headers = json,
        )

    private fun BloqueiosViewModel.nomes() = (estado.value.estado as EstadoBloqueios.Conteudo).itens.map { it.nome }

    @Test
    fun `comeca carregando e carregar mostra a lista lida de POST rpc listar_bloqueios`() = runBlocking {
        val rede = Rede { ok(doisBloqueios) }
        val vm = viewModelCom(rede)
        assertEquals(EstadoBloqueios.Carregando, vm.estado.value.estado)

        vm.carregar().join()

        assertEquals(listOf("Ana Souza", "Bar do Zé"), vm.nomes())
        assertEquals("/rest/v1/rpc/listar_bloqueios", rede.pedidos.single().caminho)
    }

    @Test
    fun `lista vazia e estado Vazio, nao erro`() = runBlocking {
        val vm = viewModelCom(Rede { ok("[]") })

        vm.carregar().join()

        assertEquals(EstadoBloqueios.Vazio, vm.estado.value.estado)
    }

    @Test
    fun `sem rede sem lista vira SemRede e tentar novamente recupera`() = runBlocking {
        var offline = true
        val vm = viewModelCom(Rede { if (offline) throw ConnectTimeoutException("sem rota", null) else ok(doisBloqueios) })

        vm.carregar().join()
        assertEquals(EstadoBloqueios.SemRede, vm.estado.value.estado)

        offline = false
        vm.carregar().join()
        assertEquals(listOf("Ana Souza", "Bar do Zé"), vm.nomes())
    }

    @Test
    fun `erro 500 e corpo nao JSON viram Erro com a mensagem de carregar`() = runBlocking {
        val vm500 = viewModelCom(Rede { recusa(HttpStatusCode.InternalServerError, "erro_interno") })
        vm500.carregar().join()
        assertEquals(EstadoBloqueios.Erro(TextosBloqueios.ERRO_CARREGAR), vm500.estado.value.estado)

        val vmHtml = viewModelCom(Rede { respond("<html>502</html>", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "text/html")) })
        vmHtml.carregar().join()
        assertEquals(EstadoBloqueios.Erro(TextosBloqueios.ERRO_CARREGAR), vmHtml.estado.value.estado)
    }

    @Test
    fun `conta suspensa ao carregar mostra o texto da suspensao`() = runBlocking {
        val vm = viewModelCom(Rede { recusa(HttpStatusCode.Forbidden, "sem_permissao", "conta_suspensa") })

        vm.carregar().join()

        assertEquals(EstadoBloqueios.Erro(TextosBloqueios.CONTA_SUSPENSA), vm.estado.value.estado)
    }

    @Test
    fun `recarga que falha com a lista na tela mantem a lista e mostra a mensagem`() = runBlocking {
        var offline = false
        val vm = viewModelCom(Rede { if (offline) throw ConnectTimeoutException("sem rota", null) else ok(doisBloqueios) })
        vm.carregar().join()

        offline = true
        vm.carregar().join()

        assertEquals(listOf("Ana Souza", "Bar do Zé"), vm.nomes())
        assertEquals(TextosBloqueios.SEM_REDE, vm.estado.value.mensagemErro)
    }

    @Test
    fun `desbloquear manda POST desbloquear com o par tipo e id e tira o item da lista`() = runBlocking {
        val rede = Rede { request -> if (request.url.encodedPath.endsWith("/desbloquear")) ok(desbloqueioOk) else ok(doisBloqueios) }
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.desbloquear((vm.estado.value.estado as EstadoBloqueios.Conteudo).itens.first()).join()

        assertEquals("/rest/v1/rpc/desbloquear", rede.desbloqueios().single().caminho)
        assertEquals(mapOf("alvo_tipo" to "profissional", "alvo_id" to ana), rede.desbloqueios().single().corpo)
        assertEquals(listOf("Bar do Zé"), vm.nomes())
        assertNull(vm.estado.value.desbloqueando)
        assertNull(vm.estado.value.mensagemErro)
    }

    @Test
    fun `desbloquear o ultimo item leva ao estado Vazio`() = runBlocking {
        val vm = viewModelCom(
            Rede { request ->
                if (request.url.encodedPath.endsWith("/desbloquear")) ok(desbloqueioOk) else ok("[${item("profissional", ana, "Ana Souza")}]")
            },
        )
        vm.carregar().join()

        vm.desbloquear((vm.estado.value.estado as EstadoBloqueios.Conteudo).itens.single()).join()

        assertEquals(EstadoBloqueios.Vazio, vm.estado.value.estado)
    }

    @Test
    fun `profissional e estabelecimento com o mesmo id sao itens diferentes`() = runBlocking {
        val mesmo = "cccccccc-cccc-cccc-cccc-cccccccccccc"
        val vm = viewModelCom(
            Rede { request ->
                if (request.url.encodedPath.endsWith("/desbloquear")) ok(desbloqueioOk)
                else ok("[${item("profissional", mesmo, "Pessoa")},${item("estabelecimento", mesmo, "Casa")}]")
            },
        )
        vm.carregar().join()

        vm.desbloquear((vm.estado.value.estado as EstadoBloqueios.Conteudo).itens.first()).join()

        assertEquals(listOf("Casa"), vm.nomes())
    }

    @Test
    fun `um desbloqueio por vez - o segundo toque com o primeiro em voo nao dispara outro pedido`() = runBlocking {
        val solta = CompletableDeferred<Unit>()
        var envios = 0
        val itens = listOf(
            ItemBloqueioDto("profissional", ana, "Ana Souza", "2026-11-10T12:00:00Z"),
            ItemBloqueioDto("estabelecimento", bar, "Bar do Zé", "2026-11-10T12:00:00Z"),
        )
        val vm = BloqueiosViewModel(
            listar = { itens },
            desfazer = { tipo, id -> envios++; solta.await(); BloqueioDto(tipo, id, "2026-11-10T12:00:00Z") },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        vm.carregar().join()

        val primeiro = vm.desbloquear(itens[0])
        assertEquals("profissional:$ana", vm.estado.value.desbloqueando)
        vm.desbloquear(itens[1]).join()
        solta.complete(Unit)
        primeiro.join()

        assertEquals(1, envios)
        assertEquals(listOf("Bar do Zé"), vm.nomes())
    }

    private fun recusaAoDesbloquear(status: HttpStatusCode, codigo: String, detalhes: String?, esperado: String) = runBlocking {
        val vm = viewModelCom(
            Rede { request ->
                if (request.url.encodedPath.endsWith("/desbloquear")) recusa(status, codigo, detalhes) else ok(doisBloqueios)
            },
        )
        vm.carregar().join()

        vm.desbloquear((vm.estado.value.estado as EstadoBloqueios.Conteudo).itens.first()).join()

        assertEquals(esperado, vm.estado.value.mensagemErro)
        assertNull(vm.estado.value.desbloqueando)
        assertEquals(listOf("Ana Souza", "Bar do Zé"), vm.nomes())
    }

    @Test
    fun `403 conta suspensa diz que os bloqueios nao mudam enquanto durar a suspensao`() =
        recusaAoDesbloquear(HttpStatusCode.Forbidden, "sem_permissao", "conta_suspensa", TextosBloqueios.CONTA_SUSPENSA)

    @Test
    fun `404 vira o erro de desbloquear, sem o corpo cru`() =
        recusaAoDesbloquear(HttpStatusCode.NotFound, "nao_encontrado", null, TextosBloqueios.ERRO_DESBLOQUEAR)

    @Test
    fun `422 alvo invalido vira o erro de desbloquear`() =
        recusaAoDesbloquear(HttpStatusCode.UnprocessableEntity, "campo_invalido", "alvo_tipo", TextosBloqueios.ERRO_DESBLOQUEAR)

    @Test
    fun `sem rede ao desbloquear mostra a mensagem de conexao e tentar de novo funciona`() = runBlocking {
        var offline = true
        val vm = viewModelCom(
            Rede { request ->
                if (!request.url.encodedPath.endsWith("/desbloquear")) ok(doisBloqueios)
                else if (offline) throw ConnectTimeoutException("sem rota", null)
                else ok(desbloqueioOk)
            },
        )
        vm.carregar().join()
        val primeiro = (vm.estado.value.estado as EstadoBloqueios.Conteudo).itens.first()

        vm.desbloquear(primeiro).join()
        assertEquals(TextosBloqueios.SEM_REDE, vm.estado.value.mensagemErro)
        assertNull(vm.estado.value.desbloqueando)

        offline = false
        vm.desbloquear(primeiro).join()
        assertEquals(listOf("Bar do Zé"), vm.nomes())
        assertNull(vm.estado.value.mensagemErro)
    }

    @Test
    fun `resposta ilegivel de gateway nao prende a tela em desbloqueando`() = runBlocking {
        val vm = viewModelCom(
            Rede { request ->
                if (request.url.encodedPath.endsWith("/desbloquear")) {
                    respond("<html>502</html>", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "text/html"))
                } else {
                    ok(doisBloqueios)
                }
            },
        )
        vm.carregar().join()

        vm.desbloquear((vm.estado.value.estado as EstadoBloqueios.Conteudo).itens.first()).join()

        assertFalse(vm.estado.value.desbloqueando != null)
        assertEquals(TextosBloqueios.ERRO_DESBLOQUEAR, vm.estado.value.mensagemErro)
    }
}
