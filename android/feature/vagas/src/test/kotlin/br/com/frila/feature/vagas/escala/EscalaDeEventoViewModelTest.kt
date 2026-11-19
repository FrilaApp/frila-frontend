package br.com.frila.feature.vagas.escala

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.ServicoVagas
import br.com.frila.feature.vagas.publicacao.EstabelecimentoDaVaga
import br.com.frila.feature.vagas.publicacao.ModoDaVaga
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
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class EscalaDeEventoViewModelTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val html = headersOf(HttpHeaders.ContentType, "text/html")

    /** Quarta-feira, 12h em Brasília. O evento nasce daqui a 7 dias (17/11), às 18h. */
    private val base: Instant = Instant.parse("2026-11-10T15:00:00Z")

    private val funcoesJson = """
        [{"id":"f1","nome":"Garçom","categoria":"Salão"},{"id":"f2","nome":"Cozinheiro","categoria":"Cozinha"}]
    """.trimIndent()
    private val publicadaJson = """{"evento_id":"ev1","vagas":[{"vaga_id":"v1","posicoes":["p1","p2"]},{"vaga_id":"v2","posicoes":["p3"]}]}"""

    private class Pedido(val caminho: String, val corpo: JsonObject?)

    private class Rede(
        val publicar: MockRequestHandleScope.(HttpRequestData) -> HttpResponseData,
        val funcoes: MockRequestHandleScope.(HttpRequestData) -> HttpResponseData = { respond("[]", HttpStatusCode.OK) },
    ) {
        val pedidos = mutableListOf<Pedido>()
        val publicacoes get() = pedidos.filter { it.caminho.endsWith("/publicar_escala") }
    }

    private var agora: Instant = base
    private var chaves = 0

    private fun viewModelCom(rede: Rede): EscalaDeEventoViewModel {
        val engine = MockEngine { request ->
            val corpo = (request.body as? TextContent)?.text?.let { ClienteSupabase.jsonFrila.parseToJsonElement(it).jsonObject }
            rede.pedidos += Pedido(request.url.encodedPath, corpo)
            if (request.url.encodedPath.endsWith("/funcao")) rede.funcoes(this, request) else rede.publicar(this, request)
        }
        val servico = ServicoVagas(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
        return EscalaDeEventoViewModel(
            estabelecimento = EstabelecimentoDaVaga(
                id = "e1",
                endereco = "CLS 408, Bloco B, Loja 12",
                regiaoAdministrativa = "Plano Piloto",
                ponto = CoordenadaDto(-15.7942, -47.8822),
            ),
            buscarFuncoes = servico::listarFuncoes,
            enviarEscala = servico::publicarEscala,
            relogio = { agora },
            novaChave = { "chave-${++chaves}" },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
    }

    private fun redeOk() = Rede(
        publicar = { respond(publicadaJson, HttpStatusCode.OK, json) },
        funcoes = { respond(funcoesJson, HttpStatusCode.OK, json) },
    )

    private fun MockRequestHandleScope.recusa(status: HttpStatusCode, codigo: String, detalhes: String? = null) =
        respond(
            content = """{"code":"$codigo","message":"x","details":${detalhes?.let { "\"$it\"" } ?: "null"}}""",
            status = status,
            headers = json,
        )

    /** Evento com nome e duas vagas válidas: Garçom (R$ 180, 4 pessoas) e Cozinheiro (R$ 220, 2 pessoas). */
    private fun EscalaDeEventoViewModel.preencher() {
        runBlocking { carregarFuncoes().join() }
        editarNome("  Formatura de Direito  ")
        val primeira = estado.value.itens.single().id
        escolherFuncao(primeira, "f1")
        editarValor(primeira, "180")
        editarPosicoes(primeira, "4")
        editarResponsavel(primeira, "  Lia  ")
        adicionarVaga()
        val segunda = estado.value.itens.last().id
        escolherFuncao(segunda, "f2")
        editarValor(segunda, "220,50")
        editarPosicoes(segunda, "2")
    }

    // ---- Publicação válida ----

    @Test
    fun `escala valida manda um POST so com o evento, as vagas e a chave unica`() = runBlocking {
        val rede = redeOk()
        val vm = viewModelCom(rede)
        vm.preencher()

        vm.publicar().join()

        val pedido = rede.publicacoes.single()
        assertEquals("/rest/v1/rpc/publicar_escala", pedido.caminho)
        val corpo = pedido.corpo!!
        assertEquals(setOf("estabelecimento_id", "evento", "vagas", "chave"), corpo.keys)
        assertEquals("e1", corpo["estabelecimento_id"]!!.jsonPrimitive.content)
        assertEquals("chave-1", corpo["chave"]!!.jsonPrimitive.content)
        val evento = corpo["evento"]!!.jsonObject
        assertEquals("Formatura de Direito", evento["nome"]!!.jsonPrimitive.content)
        assertEquals("2026-11-17", evento["data"]!!.jsonPrimitive.content)
        assertEquals("CLS 408, Bloco B, Loja 12", evento["local"]!!.jsonPrimitive.content)
        assertEquals("Plano Piloto", evento["regiao_administrativa"]!!.jsonPrimitive.content)
        val vagas = corpo["vagas"]!!.jsonArray
        assertEquals(2, vagas.size)
        val primeira = vagas[0].jsonObject
        assertEquals("f1", primeira["funcao_id"]!!.jsonPrimitive.content)
        assertEquals("2026-11-17T21:00:00Z", primeira["inicio_em"]!!.jsonPrimitive.content)
        assertEquals("2026-11-18T01:00:00Z", primeira["fim_em"]!!.jsonPrimitive.content)
        assertEquals("18000", primeira["valor_centavos"]!!.jsonPrimitive.content)
        assertEquals("4", primeira["posicoes"]!!.jsonPrimitive.content)
        assertEquals("Lia", primeira["responsavel_local"]!!.jsonPrimitive.content)
        assertEquals("urgencia", primeira["modo"]!!.jsonPrimitive.content)
        // A segunda vaga herda o horário e o responsável da primeira; só o que mudou é dela.
        val segunda = vagas[1].jsonObject
        assertEquals("f2", segunda["funcao_id"]!!.jsonPrimitive.content)
        assertEquals("22050", segunda["valor_centavos"]!!.jsonPrimitive.content)
        assertEquals("Lia", segunda["responsavel_local"]!!.jsonPrimitive.content)
        assertTrue("chave" !in primeira.keys && "local" !in primeira.keys)

        val estado = vm.estado.value
        assertEquals("ev1", estado.publicada?.eventoId)
        assertEquals(2, estado.publicada?.vagas?.size)
        assertTrue(estado.concluida)
        assertNull(estado.pendente)
        assertFalse(estado.enviando)
    }

    // ---- Tudo ou nada, antes da rede ----

    @Test
    fun `uma vaga errada impede a escala inteira e nada vai ao servidor`() = runBlocking {
        val rede = redeOk()
        val vm = viewModelCom(rede)
        vm.preencher()
        val segunda = vm.estado.value.itens.last().id
        vm.editarValor(segunda, "")

        vm.publicar().join()

        assertTrue(rede.publicacoes.isEmpty())
        val estado = vm.estado.value
        assertEquals(ErroGlobalEscala.CONFIRA_CAMPOS, estado.erro)
        assertEquals(setOf(CampoDoItem.VALOR), estado.errosDosItens[segunda]!!.keys)
        assertNull(estado.errosDosItens[estado.itens.first().id])
        assertNull(estado.publicada)
        assertTrue(estado.podeEditar)
    }

    @Test
    fun `mostra todos os campos errados de uma vez`() = runBlocking {
        val rede = redeOk()
        val vm = viewModelCom(rede)
        runBlocking { vm.carregarFuncoes().join() }
        vm.editarNome("ab")

        vm.publicar().join()

        val estado = vm.estado.value
        assertTrue(rede.publicacoes.isEmpty())
        assertNotNull(estado.errosDoEvento[CampoDoEvento.NOME])
        assertEquals(
            setOf(CampoDoItem.FUNCAO, CampoDoItem.VALOR, CampoDoItem.RESPONSAVEL),
            estado.errosDosItens[estado.itens.single().id]!!.keys,
        )
    }

    @Test
    fun `a soma de posicoes acima de 100 recusa antes da rede`() = runBlocking {
        val rede = redeOk()
        val vm = viewModelCom(rede)
        vm.preencher()
        vm.editarPosicoes(vm.estado.value.itens[0].id, "60")
        vm.editarPosicoes(vm.estado.value.itens[1].id, "41")

        vm.publicar().join()

        assertTrue(rede.publicacoes.isEmpty())
        assertEquals(ErroGlobalEscala.SOMA_DE_POSICOES, vm.estado.value.erro)
        assertEquals(101, vm.estado.value.totalDePessoas)
    }

    @Test
    fun `posicoes por vaga vao de 1 a 100 na escala`() = runBlocking {
        val vm = viewModelCom(redeOk())
        vm.preencher()
        val id = vm.estado.value.itens[0].id

        vm.editarPosicoes(id, "101")
        vm.publicar().join()
        assertNotNull(vm.estado.value.errosDosItens[id]?.get(CampoDoItem.POSICOES))

        vm.editarPosicoes(id, "0")
        vm.publicar().join()
        assertNotNull(vm.estado.value.errosDosItens[id]?.get(CampoDoItem.POSICOES))
    }

    @Test
    fun `a selecao exige inicio a mais de 24 horas e volta para urgencia ao mover o inicio`() = runBlocking {
        val vm = viewModelCom(redeOk())
        vm.preencher()
        val id = vm.estado.value.itens[0].id

        vm.escolherModo(id, ModoDaVaga.SELECAO)
        assertEquals(ModoDaVaga.SELECAO, vm.estado.value.itens[0].modo)

        vm.editarInicio(id, base.plus(Duration.ofHours(3)))
        assertEquals(ModoDaVaga.URGENCIA, vm.estado.value.itens[0].modo)
        vm.escolherModo(id, ModoDaVaga.SELECAO)
        assertEquals(ModoDaVaga.URGENCIA, vm.estado.value.itens[0].modo)
        assertEquals(TextosEscala.SELECAO_SEM_ANTECEDENCIA_CAMPO, vm.estado.value.errosDosItens[id]?.get(CampoDoItem.MODO))
    }

    // ---- Vagas da escala ----

    @Test
    fun `de 1 a 10 vagas, a unica nao sai e a decima primeira nao entra`() {
        val vm = viewModelCom(redeOk())
        vm.removerVaga(vm.estado.value.itens.single().id)
        assertEquals(1, vm.estado.value.itens.size)

        repeat(12) { vm.adicionarVaga() }
        assertEquals(10, vm.estado.value.itens.size)
        assertFalse(vm.estado.value.podeAdicionar)
        assertEquals(10, vm.estado.value.itens.map { it.id }.toSet().size)

        val removida = vm.estado.value.itens[3].id
        vm.removerVaga(removida)
        assertEquals(9, vm.estado.value.itens.size)
        assertTrue(vm.estado.value.itens.none { it.id == removida })
    }

    @Test
    fun `mudar o dia do evento leva os horarios de todas as vagas junto`() {
        val vm = viewModelCom(redeOk())
        vm.adicionarVaga()
        val antes = vm.estado.value.itens.map { it.inicio to it.fim }

        vm.editarData(LocalDate.of(2026, 11, 20))

        val estado = vm.estado.value
        assertEquals(LocalDate.of(2026, 11, 20), estado.data)
        estado.itens.forEachIndexed { indice, item ->
            assertEquals(antes[indice].first.plus(Duration.ofDays(3)), item.inicio)
            assertEquals(antes[indice].second.plus(Duration.ofDays(3)), item.fim)
        }
    }

    // ---- Recusas do servidor: nada foi gravado ----

    @Test
    fun `422 com o caminho de um item marca a vaga certa e libera a edicao`() = runBlocking {
        var tentativa = 0
        val rede = Rede(
            publicar = { if (++tentativa == 1) recusa(HttpStatusCode.UnprocessableEntity, "campo_invalido", "vagas[1].valor_centavos") else respond(publicadaJson, HttpStatusCode.OK, json) },
            funcoes = { respond(funcoesJson, HttpStatusCode.OK, json) },
        )
        val vm = viewModelCom(rede)
        vm.preencher()

        vm.publicar().join()

        val estado = vm.estado.value
        val segunda = estado.itens[1].id
        assertEquals(ErroGlobalEscala.CONFIRA_CAMPOS, estado.erro)
        assertEquals(mapOf(segunda to mapOf(CampoDoItem.VALOR to TextosEscala.CAMPO_INVALIDO)), estado.errosDosItens)
        assertNull(estado.pendente)
        assertNull(estado.publicada)
        assertTrue(estado.podeEditar)
        assertFalse(estado.enviando)

        // A tentativa seguinte é outra publicação, com chave nova.
        vm.editarValor(segunda, "200")
        vm.publicar().join()
        assertEquals("chave-1", rede.publicacoes[0].corpo!!["chave"]!!.jsonPrimitive.content)
        assertEquals("chave-2", rede.publicacoes[1].corpo!!["chave"]!!.jsonPrimitive.content)
        assertTrue(vm.estado.value.concluida)
    }

    @Test
    fun `a recusa de uma vaga apos remover outra continua na vaga certa`() = runBlocking {
        var tentativa = 0
        val rede = Rede(
            publicar = { if (++tentativa == 1) recusa(HttpStatusCode.UnprocessableEntity, "campo_obrigatorio", "vagas[2].responsavel_local") else respond(publicadaJson, HttpStatusCode.OK, json) },
            funcoes = { respond(funcoesJson, HttpStatusCode.OK, json) },
        )
        val vm = viewModelCom(rede)
        vm.preencher()
        vm.adicionarVaga()
        val terceira = vm.estado.value.itens[2].id
        vm.escolherFuncao(terceira, "f1")
        vm.editarValor(terceira, "100")

        vm.publicar().join()

        assertEquals(setOf(terceira), vm.estado.value.errosDosItens.keys)
        assertEquals(TextosEscala.CAMPO_OBRIGATORIO, vm.estado.value.errosDosItens[terceira]?.get(CampoDoItem.RESPONSAVEL))
        // Remover a primeira vaga não desloca o erro: ele é da vaga, não da posição na lista.
        vm.removerVaga(vm.estado.value.itens[0].id)
        assertEquals(setOf(terceira), vm.estado.value.errosDosItens.keys)
    }

    @Test
    fun `422 do evento marca o nome e o resto vira erro geral`() = runBlocking {
        val casos = listOf(
            Triple("campo_invalido", "evento.nome", ErroGlobalEscala.CONFIRA_CAMPOS),
            Triple("campo_invalido", "evento.local", ErroGlobalEscala.CADASTRO_DA_CASA),
            Triple("campo_invalido", "vagas", ErroGlobalEscala.QUANTIDADE),
            Triple("campo_invalido", "posicoes", ErroGlobalEscala.SOMA_DE_POSICOES),
            Triple("perfil_incompativel", null, ErroGlobalEscala.PERFIL_INCOMPATIVEL),
        )
        casos.forEach { (codigo, detalhes, esperado) ->
            val vm = viewModelCom(Rede(publicar = { recusa(HttpStatusCode.UnprocessableEntity, codigo, detalhes) }, funcoes = { respond(funcoesJson, HttpStatusCode.OK, json) }))
            vm.preencher()
            vm.publicar().join()
            assertEquals(esperado, vm.estado.value.erro, "$codigo $detalhes")
            assertNull(vm.estado.value.pendente, "$codigo $detalhes")
            if (detalhes == "evento.nome") assertEquals(TextosEscala.NOME_CAMPO, vm.estado.value.errosDoEvento[CampoDoEvento.NOME])
        }
    }

    @Test
    fun `horario invalido e selecao sem antecedencia por vaga apontam o item`() = runBlocking {
        listOf("horario_invalido" to CampoDoItem.FIM, "selecao_sem_antecedencia" to CampoDoItem.MODO).forEach { (codigo, campo) ->
            val vm = viewModelCom(Rede(publicar = { recusa(HttpStatusCode.UnprocessableEntity, codigo, "vagas[0]") }, funcoes = { respond(funcoesJson, HttpStatusCode.OK, json) }))
            vm.preencher()
            vm.publicar().join()
            val primeira = vm.estado.value.itens[0].id
            assertTrue(campo in vm.estado.value.errosDosItens[primeira]!!.keys, codigo)
            assertEquals(ErroGlobalEscala.CONFIRA_CAMPOS, vm.estado.value.erro)
        }
    }

    @Test
    fun `403 do servidor mostra a mensagem certa`() = runBlocking {
        val casos = listOf(
            Triple(HttpStatusCode.Forbidden, "sem_permissao" to null, ErroGlobalEscala.SEM_PERMISSAO),
            Triple(HttpStatusCode.Forbidden, "sem_permissao" to "conta_suspensa", ErroGlobalEscala.CONTA_SUSPENSA),
            Triple(HttpStatusCode.Unauthorized, "PGRST301" to null, ErroGlobalEscala.SESSAO_EXPIRADA),
        )
        casos.forEach { (status, codigo, esperado) ->
            val vm = viewModelCom(Rede(publicar = { recusa(status, codigo.first, codigo.second) }, funcoes = { respond(funcoesJson, HttpStatusCode.OK, json) }))
            vm.preencher()
            vm.publicar().join()
            assertEquals(esperado, vm.estado.value.erro, "$status ${codigo.first}")
            assertFalse(vm.estado.value.enviando)
            assertNull(vm.estado.value.publicada)
        }
    }

    // ---- Erro de rede e idempotência ----

    @Test
    fun `sem rede o corpo fica pendente e o reenvio manda a mesma escala com a mesma chave`() = runBlocking {
        var tentativa = 0
        val rede = Rede(
            publicar = { if (++tentativa == 1) throw ConnectTimeoutException("sem rede") else respond(publicadaJson, HttpStatusCode.OK, json) },
            funcoes = { respond(funcoesJson, HttpStatusCode.OK, json) },
        )
        val vm = viewModelCom(rede)
        vm.preencher()

        vm.publicar().join()
        assertEquals(ErroGlobalEscala.SEM_REDE, vm.estado.value.erro)
        assertNotNull(vm.estado.value.pendente)
        assertFalse(vm.estado.value.enviando)
        assertFalse(vm.estado.value.podeEditar)

        // Com a escala pendente nada muda: o reenvio é exatamente o que saiu.
        vm.editarNome("Outro nome")
        vm.adicionarVaga()
        vm.removerVaga(vm.estado.value.itens[0].id)
        assertEquals("  Formatura de Direito  ", vm.estado.value.nome)
        assertEquals(2, vm.estado.value.itens.size)

        agora = base.plusSeconds(30)
        vm.publicar().join()

        assertEquals(2, rede.publicacoes.size)
        assertEquals(rede.publicacoes[0].corpo, rede.publicacoes[1].corpo)
        assertEquals("chave-1", rede.publicacoes[1].corpo!!["chave"]!!.jsonPrimitive.content)
        assertEquals(1, chaves)
        assertEquals("ev1", vm.estado.value.publicada?.eventoId)
        assertNull(vm.estado.value.pendente)
    }

    @Test
    fun `resposta que nao e o JSON esperado libera o botao e deixa a escala pendente`() {
        listOf(
            { s: MockRequestHandleScope -> s.respond("<html>ok</html>", HttpStatusCode.OK, html) },
            { s: MockRequestHandleScope -> s.respond("<html>502</html>", HttpStatusCode.BadGateway, html) },
            { s: MockRequestHandleScope -> s.respond("""{"vagas":[]}""", HttpStatusCode.OK, json) },
        ).forEach { resposta ->
            val vm = viewModelCom(Rede(publicar = { resposta(this) }, funcoes = { respond(funcoesJson, HttpStatusCode.OK, json) }))
            vm.preencher()
            runBlocking { vm.publicar().join() }
            val estado = vm.estado.value
            assertEquals(ErroGlobalEscala.GENERICO, estado.erro)
            assertFalse(estado.enviando)
            assertNull(estado.publicada)
            assertNotNull(estado.pendente)
        }
    }

    @Test
    fun `segundo toque durante o envio nao manda segunda escala`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        val rede = Rede(
            publicar = { runBlocking { liberar.await() }; respond(publicadaJson, HttpStatusCode.OK, json) },
            funcoes = { respond(funcoesJson, HttpStatusCode.OK, json) },
        )
        val vm = viewModelCom(rede)
        vm.preencher()

        val primeiro = vm.publicar()
        assertTrue(vm.estado.value.enviando)
        vm.publicar()
        liberar.complete(Unit)
        withTimeout(5_000) { primeiro.join() }

        assertEquals(1, rede.publicacoes.size)
        assertEquals("ev1", vm.estado.value.publicada?.eventoId)
    }

    // ---- Funções ----

    @Test
    fun `carregarFuncoes preenche o catalogo e falha com mensagem para tentar de novo`() = runBlocking {
        var tentativa = 0
        val rede = Rede(
            publicar = { respond(publicadaJson, HttpStatusCode.OK, json) },
            funcoes = { if (++tentativa == 1) respond("<html>ok</html>", HttpStatusCode.OK, html) else respond(funcoesJson, HttpStatusCode.OK, json) },
        )
        val vm = viewModelCom(rede)

        vm.carregarFuncoes().join()
        assertTrue(vm.estado.value.falhaAoCarregarFuncoes)
        assertFalse(vm.estado.value.carregandoFuncoes)

        vm.carregarFuncoes().join()
        assertFalse(vm.estado.value.falhaAoCarregarFuncoes)
        assertEquals(2, vm.estado.value.funcoes.size)
    }
}
