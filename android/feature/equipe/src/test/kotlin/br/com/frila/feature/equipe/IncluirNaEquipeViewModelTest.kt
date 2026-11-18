package br.com.frila.feature.equipe

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.MembroDaEquipeDto
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

class IncluirNaEquipeViewModelTest {

    private val casa = "11111111-1111-1111-1111-111111111111"
    private val ana = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    private val beto = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"

    private fun perfil(id: String, nome: String) = """
        {"id":"$id","tipo":"profissional","nome":"$nome","funcoes":["garçom"],
         "reputacao":{"positivas":7,"total":8,"turnos_considerados":8,"turnos_realizados":8}}
    """.trimIndent()

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val inclusaoOk = """{"estabelecimento_id":"$casa","profissional_id":"$ana"}"""

    private class Pedido(val caminho: String, val corpo: Map<String, String>)

    private class Rede(val resposta: MockRequestHandleScope.(HttpRequestData) -> HttpResponseData) {
        val pedidos = mutableListOf<Pedido>()
        fun inclusoes() = pedidos.filter { it.caminho.endsWith("/incluir_na_equipe") }
    }

    private fun viewModelCom(rede: Rede): IncluirNaEquipeViewModel {
        val engine = MockEngine { request ->
            val corpo = (request.body as? TextContent)?.text
                ?.let { ClienteSupabase.jsonFrila.parseToJsonElement(it).jsonObject.mapValues { e -> e.value.jsonPrimitive.content } }
                .orEmpty()
            rede.pedidos += Pedido(request.url.encodedPath, corpo)
            rede.resposta(this, request)
        }
        val servico = ServicoConfianca(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
        return IncluirNaEquipeViewModel(
            estabelecimentoId = casa,
            profissionalId = ana,
            listar = servico::equipeDeConfianca,
            incluirMembro = servico::incluirNaEquipe,
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

    private fun MockRequestHandleScope.lista(vararg perfis: String) = ok("[${perfis.joinToString(",")}]")

    @Test
    fun `carregar sabe se o profissional ja esta na equipe`() = runBlocking {
        val dentro = viewModelCom(Rede { lista(perfil(ana, "Ana"), perfil(beto, "Beto")) })
        val fora = viewModelCom(Rede { lista(perfil(beto, "Beto")) })
        assertEquals(SituacaoNaEquipe.DESCONHECIDA, dentro.estado.value.situacao)

        dentro.carregar().join()
        fora.carregar().join()

        assertEquals(SituacaoNaEquipe.NA_EQUIPE, dentro.estado.value.situacao)
        assertEquals(SituacaoNaEquipe.FORA_DA_EQUIPE, fora.estado.value.situacao)
    }

    @Test
    fun `falha ao ler a equipe mostra o botao mesmo assim`() = runBlocking {
        val vm = viewModelCom(Rede { recusa(HttpStatusCode.InternalServerError, "erro_interno") })

        vm.carregar().join()

        assertEquals(SituacaoNaEquipe.FORA_DA_EQUIPE, vm.estado.value.situacao)
        assertNull(vm.estado.value.mensagemErro)
    }

    @Test
    fun `incluir manda POST incluir_na_equipe com o par e marca o profissional como da equipe`() = runBlocking {
        val rede = Rede { request ->
            if (request.url.encodedPath.endsWith("/incluir_na_equipe")) ok(inclusaoOk) else lista(perfil(beto, "Beto"))
        }
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.incluir().join()

        assertEquals("/rest/v1/rpc/incluir_na_equipe", rede.inclusoes().single().caminho)
        assertEquals(mapOf("estabelecimento_id" to casa, "profissional_id" to ana), rede.inclusoes().single().corpo)
        assertEquals(SituacaoNaEquipe.NA_EQUIPE, vm.estado.value.situacao)
        assertFalse(vm.estado.value.incluindo)
        assertNull(vm.estado.value.mensagemErro)
    }

    @Test
    fun `quem ja esta na equipe nao dispara outro envio`() = runBlocking {
        val rede = Rede { lista(perfil(ana, "Ana")) }
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.incluir().join()

        assertEquals(0, rede.inclusoes().size)
    }

    @Test
    fun `um envio por vez - o segundo toque com a inclusao em voo nao dispara outro pedido`() = runBlocking {
        val solta = CompletableDeferred<Unit>()
        var envios = 0
        val vm = IncluirNaEquipeViewModel(
            estabelecimentoId = casa,
            profissionalId = ana,
            listar = { emptyList() },
            incluirMembro = { e, p -> envios++; solta.await(); MembroDaEquipeDto(e, p) },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )

        val primeiro = vm.incluir()
        assertEquals(true, vm.estado.value.incluindo)
        vm.incluir().join()
        solta.complete(Unit)
        primeiro.join()

        assertEquals(1, envios)
        assertEquals(SituacaoNaEquipe.NA_EQUIPE, vm.estado.value.situacao)
    }

    private fun recusaAoIncluir(status: HttpStatusCode, codigo: String, detalhes: String?, esperado: String) = runBlocking {
        val vm = viewModelCom(
            Rede { request ->
                if (request.url.encodedPath.endsWith("/incluir_na_equipe")) recusa(status, codigo, detalhes) else lista(perfil(beto, "Beto"))
            },
        )
        vm.carregar().join()

        vm.incluir().join()

        assertEquals(esperado, vm.estado.value.mensagemErro)
        assertFalse(vm.estado.value.incluindo)
        assertEquals(SituacaoNaEquipe.FORA_DA_EQUIPE, vm.estado.value.situacao)
    }

    @Test
    fun `403 sem turno cumprido diz que so entra quem cumpriu turno com presenca verificada`() =
        recusaAoIncluir(HttpStatusCode.Forbidden, "sem_permissao", "sem_turno_cumprido", TextosEquipe.SEM_TURNO_CUMPRIDO)

    @Test
    fun `403 sem details diz que so o administrador altera a equipe`() =
        recusaAoIncluir(HttpStatusCode.Forbidden, "sem_permissao", null, TextosEquipe.SO_ADMINISTRADOR)

    @Test
    fun `403 conta suspensa diz que a equipe nao muda enquanto durar a suspensao`() =
        recusaAoIncluir(HttpStatusCode.Forbidden, "sem_permissao", "conta_suspensa", TextosEquipe.CONTA_SUSPENSA)

    @Test
    fun `404 diz que o perfil nao esta mais disponivel`() =
        recusaAoIncluir(HttpStatusCode.NotFound, "nao_encontrado", null, TextosEquipe.INDISPONIVEL)

    @Test
    fun `422 vira o erro generico, sem o corpo cru`() =
        recusaAoIncluir(HttpStatusCode.UnprocessableEntity, "campo_obrigatorio", "profissional_id", TextosEquipe.ERRO)

    @Test
    fun `sem rede ao incluir vira a mensagem de conexao e tentar de novo funciona`() = runBlocking {
        var offline = true
        val vm = viewModelCom(
            Rede { request ->
                if (!request.url.encodedPath.endsWith("/incluir_na_equipe")) lista(perfil(beto, "Beto"))
                else if (offline) throw ConnectTimeoutException("sem rota", null)
                else ok(inclusaoOk)
            },
        )
        vm.carregar().join()

        vm.incluir().join()
        assertEquals(TextosEquipe.SEM_REDE, vm.estado.value.mensagemErro)
        assertFalse(vm.estado.value.incluindo)

        offline = false
        vm.incluir().join()
        assertEquals(SituacaoNaEquipe.NA_EQUIPE, vm.estado.value.situacao)
        assertNull(vm.estado.value.mensagemErro)
    }

    @Test
    fun `resposta ilegivel de gateway nao prende o botao em incluindo`() = runBlocking {
        val vm = viewModelCom(
            Rede { request ->
                if (request.url.encodedPath.endsWith("/incluir_na_equipe")) {
                    respond("<html>502</html>", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "text/html"))
                } else {
                    lista(perfil(beto, "Beto"))
                }
            },
        )
        vm.carregar().join()

        vm.incluir().join()

        assertFalse(vm.estado.value.incluindo)
        assertEquals(TextosEquipe.ERRO, vm.estado.value.mensagemErro)
    }

    @Test
    fun `depois de uma falha a equipe e lida de novo e, se o servidor ja incluiu, o botao some`() = runBlocking {
        var incluiu = false
        val vm = viewModelCom(
            Rede { request ->
                if (request.url.encodedPath.endsWith("/incluir_na_equipe")) {
                    incluiu = true
                    throw ConnectTimeoutException("resposta perdida", null)
                } else if (incluiu) lista(perfil(ana, "Ana")) else lista(perfil(beto, "Beto"))
            },
        )
        vm.carregar().join()

        vm.incluir().join()

        assertEquals(SituacaoNaEquipe.NA_EQUIPE, vm.estado.value.situacao)
        assertEquals(TextosEquipe.SEM_REDE, vm.estado.value.mensagemErro)
    }
}
