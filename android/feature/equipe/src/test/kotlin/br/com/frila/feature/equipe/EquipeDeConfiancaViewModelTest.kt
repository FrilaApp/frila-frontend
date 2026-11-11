package br.com.frila.feature.equipe

import br.com.frila.core.rede.ClienteSupabase
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
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class EquipeDeConfiancaViewModelTest {

    private val casa = "11111111-1111-1111-1111-111111111111"
    private val ana = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    private val beto = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"

    private fun perfil(id: String, nome: String) = """
        {"id":"$id","tipo":"profissional","nome":"$nome","funcoes":["garçom","barman"],
         "reputacao":{"positivas":7,"total":8,"turnos_considerados":8,"turnos_realizados":8}}
    """.trimIndent()

    private val listaComDois = "[${perfil(ana, "Ana")},${perfil(beto, "Beto")}]"

    private val json = headersOf(HttpHeaders.ContentType, "application/json")

    private class Pedido(val caminho: String, val corpo: Map<String, String>)

    private class Rede(val resposta: MockRequestHandleScope.(HttpRequestData) -> HttpResponseData) {
        val pedidos = mutableListOf<Pedido>()
    }

    private fun viewModelCom(rede: Rede, estabelecimento: String = casa): EquipeDeConfiancaViewModel {
        val engine = MockEngine { request ->
            val corpo = (request.body as? TextContent)?.text
                ?.let { ClienteSupabase.jsonFrila.parseToJsonElement(it).jsonObject.mapValues { e -> e.value.jsonPrimitive.content } }
                .orEmpty()
            rede.pedidos += Pedido(request.url.encodedPath, corpo)
            rede.resposta(this, request)
        }
        val servico = ServicoConfianca(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
        return EquipeDeConfiancaViewModel(
            estabelecimentoId = estabelecimento,
            listar = servico::equipeDeConfianca,
            removerMembro = servico::removerDaEquipe,
            sair = servico::sairDaEquipe,
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

    private fun EquipeDeConfiancaViewModel.membros() =
        (estado.value.estado as EstadoEquipe.Conteudo).membros.map { it.nome }

    @Test
    fun `comeca carregando e carregar mostra a lista lida de POST rpc equipe_de_confianca`() = runBlocking {
        val rede = Rede { ok(listaComDois) }
        val vm = viewModelCom(rede)
        assertEquals(EstadoEquipe.Carregando, vm.estado.value.estado)

        vm.carregar().join()

        assertEquals(listOf("Ana", "Beto"), vm.membros())
        assertEquals("/rest/v1/rpc/equipe_de_confianca", rede.pedidos.single().caminho)
        assertEquals(mapOf("estabelecimento_id" to casa), rede.pedidos.single().corpo)
    }

    @Test
    fun `lista vazia e estado Vazio, nao erro`() = runBlocking {
        val vm = viewModelCom(Rede { ok("[]") })

        vm.carregar().join()

        assertEquals(EstadoEquipe.Vazio, vm.estado.value.estado)
    }

    @Test
    fun `sem rede vira SemRede e tentar novamente recupera`() = runBlocking {
        var offline = true
        val vm = viewModelCom(Rede { if (offline) throw ConnectTimeoutException("sem rota", null) else ok(listaComDois) })

        vm.carregar().join()
        assertEquals(EstadoEquipe.SemRede, vm.estado.value.estado)

        offline = false
        vm.carregar().join()
        assertEquals(listOf("Ana", "Beto"), vm.membros())
    }

    @Test
    fun `erro 500 vira Erro com a mensagem de carregar, e corpo nao JSON tambem`() = runBlocking {
        val vm500 = viewModelCom(Rede { recusa(HttpStatusCode.InternalServerError, "erro_interno") })
        vm500.carregar().join()
        assertEquals(EstadoEquipe.Erro(TextosEquipe.ERRO_CARREGAR), vm500.estado.value.estado)

        val vmHtml = viewModelCom(Rede { respond("<html>502</html>", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "text/html")) })
        vmHtml.carregar().join()
        assertEquals(EstadoEquipe.Erro(TextosEquipe.ERRO_CARREGAR), vmHtml.estado.value.estado)
    }

    @Test
    fun `quem nao e membro recebe a recusa de permissao em vez do erro generico`() = runBlocking {
        val vm = viewModelCom(Rede { recusa(HttpStatusCode.Forbidden, "sem_permissao") })

        vm.carregar().join()

        assertEquals(EstadoEquipe.Erro(TextosEquipe.SO_ADMINISTRADOR), vm.estado.value.estado)
    }

    @Test
    fun `conta suspensa ao carregar mostra o texto da suspensao`() = runBlocking {
        val vm = viewModelCom(Rede { recusa(HttpStatusCode.Forbidden, "sem_permissao", "conta_suspensa") })

        vm.carregar().join()

        assertEquals(EstadoEquipe.Erro(TextosEquipe.CONTA_SUSPENSA), vm.estado.value.estado)
    }

    @Test
    fun `duas cargas ao mesmo tempo viram um unico pedido`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        var chamadas = 0
        val vm = EquipeDeConfiancaViewModel(
            estabelecimentoId = casa,
            listar = { chamadas++; liberar.await(); emptyList() },
            removerMembro = { _, _ -> error("não deveria remover") },
            sair = { error("não deveria sair") },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )

        val primeira = vm.carregar()
        val segunda = vm.carregar()
        liberar.complete(Unit)
        withTimeout(5_000) { primeira.join(); segunda.join() }

        assertEquals(1, chamadas)
    }

    @Test
    fun `remover manda o par certo, tira so aquele da lista e avisa`() = runBlocking {
        val rede = Rede { request ->
            if (request.url.encodedPath.endsWith("/equipe_de_confianca")) ok(listaComDois)
            else ok("""{"estabelecimento_id":"$casa","profissional_id":"$ana"}""")
        }
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.remover((vm.estado.value.estado as EstadoEquipe.Conteudo).membros.first { it.id == ana }).join()

        val pedido = rede.pedidos.last()
        assertEquals("/rest/v1/rpc/remover_da_equipe", pedido.caminho)
        assertEquals(mapOf("estabelecimento_id" to casa, "profissional_id" to ana), pedido.corpo)
        assertEquals(listOf("Beto"), vm.membros())
        assertEquals(TextosEquipe.REMOVIDO, vm.estado.value.aviso)
        assertNull(vm.estado.value.removendo)
    }

    @Test
    fun `remover o ultimo membro leva ao estado Vazio`() = runBlocking {
        val rede = Rede { request ->
            if (request.url.encodedPath.endsWith("/equipe_de_confianca")) ok("[${perfil(ana, "Ana")}]")
            else ok("""{"estabelecimento_id":"$casa","profissional_id":"$ana"}""")
        }
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.remover((vm.estado.value.estado as EstadoEquipe.Conteudo).membros.single()).join()

        assertEquals(EstadoEquipe.Vazio, vm.estado.value.estado)
    }

    @Test
    fun `recusas de remover mantem a lista e mostram a mensagem de cada caso`() = runBlocking {
        data class Caso(val status: HttpStatusCode, val codigo: String, val detalhes: String?, val mensagem: String)
        val casos = listOf(
            Caso(HttpStatusCode.Forbidden, "sem_permissao", null, TextosEquipe.SO_ADMINISTRADOR),
            Caso(HttpStatusCode.Forbidden, "sem_permissao", "conta_suspensa", TextosEquipe.CONTA_SUSPENSA),
            Caso(HttpStatusCode.Forbidden, "conta_suspensa", null, TextosEquipe.CONTA_SUSPENSA),
            Caso(HttpStatusCode.Forbidden, "sem_permissao", "sem_turno_cumprido", TextosEquipe.SEM_TURNO_CUMPRIDO),
            Caso(HttpStatusCode.NotFound, "nao_encontrado", null, TextosEquipe.INDISPONIVEL),
            Caso(HttpStatusCode.InternalServerError, "erro_interno", null, TextosEquipe.ERRO),
        )
        casos.forEach { caso ->
            val vm = viewModelCom(Rede { request ->
                if (request.url.encodedPath.endsWith("/equipe_de_confianca")) ok(listaComDois)
                else recusa(caso.status, caso.codigo, caso.detalhes)
            })
            vm.carregar().join()

            vm.remover((vm.estado.value.estado as EstadoEquipe.Conteudo).membros.first()).join()

            assertEquals(caso.mensagem, vm.estado.value.mensagemErro, "${caso.codigo} ${caso.detalhes}")
            assertEquals(listOf("Ana", "Beto"), vm.membros())
            assertNull(vm.estado.value.removendo)
            assertNull(vm.estado.value.aviso)
        }
    }

    @Test
    fun `remover sem rede mostra a mensagem de conexao e libera os botoes`() = runBlocking {
        var offline = false
        val vm = viewModelCom(Rede { request ->
            if (request.url.encodedPath.endsWith("/equipe_de_confianca")) ok(listaComDois)
            else if (offline) throw ConnectTimeoutException("sem rota", null)
            else ok("""{"estabelecimento_id":"$casa","profissional_id":"$ana"}""")
        })
        vm.carregar().join()
        offline = true

        vm.remover((vm.estado.value.estado as EstadoEquipe.Conteudo).membros.first()).join()

        assertEquals(TextosEquipe.SEM_REDE, vm.estado.value.mensagemErro)
        assertFalse(vm.estado.value.ocupado)
    }

    @Test
    fun `segundo toque em remover durante o pedido nao dispara outro`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        var remocoes = 0
        val ana = PerfilPublicoParaTeste.perfil("a1", "Ana")
        val beto = PerfilPublicoParaTeste.perfil("b1", "Beto")
        val vm = EquipeDeConfiancaViewModel(
            estabelecimentoId = casa,
            listar = { listOf(ana, beto) },
            removerMembro = { est, prof -> remocoes++; liberar.await(); br.com.frila.core.rede.MembroDaEquipeDto(est, prof) },
            sair = { error("não deveria sair") },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        vm.carregar().join()

        val primeiro = vm.remover(ana)
        assertEquals("a1", vm.estado.value.removendo)
        val segundo = vm.remover(beto)
        liberar.complete(Unit)
        withTimeout(5_000) { primeiro.join(); segundo.join() }

        assertEquals(1, remocoes)
        assertEquals(listOf("Beto"), vm.membros())
    }

    @Test
    fun `remover fora do estado Conteudo nao chama a API`() = runBlocking {
        var remocoes = 0
        val vm = EquipeDeConfiancaViewModel(
            estabelecimentoId = casa,
            listar = { emptyList() },
            removerMembro = { est, prof -> remocoes++; br.com.frila.core.rede.MembroDaEquipeDto(est, prof) },
            sair = { },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )

        vm.remover(PerfilPublicoParaTeste.perfil("x", "Xis")).join()

        assertEquals(0, remocoes)
    }

    @Test
    fun `sairDaEquipe chama POST rpc sair_da_equipe com a casa e marca que saiu`() = runBlocking {
        val rede = Rede { ok("{}") }
        val vm = viewModelCom(rede)

        vm.sairDaEquipe(casa).join()

        assertEquals("/rest/v1/rpc/sair_da_equipe", rede.pedidos.single().caminho)
        assertEquals(mapOf("estabelecimento_id" to casa), rede.pedidos.single().corpo)
        assertTrue(vm.estado.value.saiu)
        assertFalse(vm.estado.value.saindo)
        assertEquals(TextosEquipe.SAIU, vm.estado.value.aviso)
    }

    @Test
    fun `sairDaEquipe mapeia as recusas do contrato e nao marca que saiu`() = runBlocking {
        data class Caso(val status: HttpStatusCode, val codigo: String, val detalhes: String?, val mensagem: String)
        val casos = listOf(
            Caso(HttpStatusCode.UnprocessableEntity, "campo_invalido", "estabelecimento_id", TextosEquipe.NAO_ESTA_NA_EQUIPE),
            Caso(HttpStatusCode.Forbidden, "sem_permissao", null, TextosEquipe.SO_PROFISSIONAL),
            Caso(HttpStatusCode.Forbidden, "sem_permissao", "conta_suspensa", TextosEquipe.CONTA_SUSPENSA),
            Caso(HttpStatusCode.InternalServerError, "erro_interno", null, TextosEquipe.ERRO),
        )
        casos.forEach { caso ->
            val vm = viewModelCom(Rede { recusa(caso.status, caso.codigo, caso.detalhes) })

            vm.sairDaEquipe(casa).join()

            assertEquals(caso.mensagem, vm.estado.value.mensagemErro, "${caso.codigo} ${caso.detalhes}")
            assertFalse(vm.estado.value.saiu)
            assertFalse(vm.estado.value.saindo)
        }
    }

    @Test
    fun `sairDaEquipe sem rede mostra conexao e depois de sair nao repete`() = runBlocking {
        var offline = true
        val rede = Rede { if (offline) throw ConnectTimeoutException("sem rota", null) else ok("{}") }
        val vm = viewModelCom(rede)

        vm.sairDaEquipe(casa).join()
        assertEquals(TextosEquipe.SEM_REDE, vm.estado.value.mensagemErro)

        offline = false
        vm.sairDaEquipe(casa).join()
        vm.sairDaEquipe(casa).join()

        assertTrue(vm.estado.value.saiu)
        assertNull(vm.estado.value.mensagemErro)
        assertEquals(2, rede.pedidos.size)
    }

    private val html = headersOf(HttpHeaders.ContentType, "text/html")

    @Test
    fun `remover com resposta nao JSON cai no catch generico, mantem a lista e libera os botoes`() = runBlocking {
        var gateway = true
        val vm = viewModelCom(Rede { request ->
            if (request.url.encodedPath.endsWith("/equipe_de_confianca")) ok(listaComDois)
            else if (gateway) respond("<html>502 Bad Gateway</html>", HttpStatusCode.OK, html)
            else ok("""{"estabelecimento_id":"$casa","profissional_id":"$ana"}""")
        })
        vm.carregar().join()
        val primeiro = (vm.estado.value.estado as EstadoEquipe.Conteudo).membros.first { it.id == ana }

        vm.remover(primeiro).join()

        assertEquals(TextosEquipe.ERRO, vm.estado.value.mensagemErro)
        assertEquals(listOf("Ana", "Beto"), vm.membros())
        assertNull(vm.estado.value.removendo)
        assertNull(vm.estado.value.aviso)

        gateway = false
        vm.remover(primeiro).join()
        assertEquals(listOf("Beto"), vm.membros())
        assertNull(vm.estado.value.mensagemErro)
    }

    @Test
    fun `remover com erro 502 em HTML tambem cai no catch generico`() = runBlocking {
        val vm = viewModelCom(Rede { request ->
            if (request.url.encodedPath.endsWith("/equipe_de_confianca")) ok(listaComDois)
            else respond("<html>502</html>", HttpStatusCode.BadGateway, html)
        })
        vm.carregar().join()

        vm.remover((vm.estado.value.estado as EstadoEquipe.Conteudo).membros.first()).join()

        assertEquals(TextosEquipe.ERRO, vm.estado.value.mensagemErro)
        assertNull(vm.estado.value.removendo)
    }

    @Test
    fun `sairDaEquipe com erro 502 em HTML cai no catch generico e nao marca que saiu`() = runBlocking {
        val vm = viewModelCom(Rede { respond("<html>502</html>", HttpStatusCode.BadGateway, html) })

        vm.sairDaEquipe(casa).join()

        assertEquals(TextosEquipe.ERRO, vm.estado.value.mensagemErro)
        assertFalse(vm.estado.value.saiu)
        assertFalse(vm.estado.value.saindo)
    }
}

/** Perfil mínimo para testes que não passam pela rede. */
private object PerfilPublicoParaTeste {
    fun perfil(id: String, nome: String) = br.com.frila.core.rede.PerfilPublicoDto(
        id = id,
        tipo = "profissional",
        nome = nome,
        funcoes = listOf("garçom"),
        reputacao = br.com.frila.core.rede.ReputacaoDto(
            positivas = 1,
            total = 1,
            turnosConsiderados = 1,
            turnosRealizados = 1,
        ),
    )
}
