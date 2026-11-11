package br.com.frila.feature.estabelecimento

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoMembros
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
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class CadastroEstabelecimentoViewModelTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val html = headersOf(HttpHeaders.ContentType, "text/html")

    private val criadoJson = """
        {"id":"11111111-1111-1111-1111-111111111111","nome":"Bar da Lia","documento":"12345678000199",
         "tipo":"evento","endereco":"CLS 408, Bloco B, Loja 12","regiao_administrativa":"Plano Piloto",
         "ponto":{"latitude":-15.7942,"longitude":-47.8822},"papel":"administrador"}
    """.trimIndent()

    private class Pedido(val caminho: String, val corpo: JsonObject?)

    private class Rede(val resposta: MockRequestHandleScope.(HttpRequestData) -> HttpResponseData) {
        val pedidos = mutableListOf<Pedido>()
    }

    private fun viewModelCom(rede: Rede): CadastroEstabelecimentoViewModel {
        val engine = MockEngine { request ->
            val corpo = (request.body as? TextContent)?.text?.let { ClienteSupabase.jsonFrila.parseToJsonElement(it).jsonObject }
            rede.pedidos += Pedido(request.url.encodedPath, corpo)
            rede.resposta(this, request)
        }
        val servico = ServicoMembros(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
        return CadastroEstabelecimentoViewModel(
            cadastrar = servico::cadastrarEstabelecimento,
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
    }

    private fun MockRequestHandleScope.ok() = respond(criadoJson, HttpStatusCode.OK, json)

    private fun MockRequestHandleScope.recusa(status: HttpStatusCode, codigo: String, detalhes: String? = null) =
        respond(
            content = """{"code":"$codigo","message":"x","details":${detalhes?.let { "\"$it\"" } ?: "null"}}""",
            status = status,
            headers = json,
        )

    private fun CadastroEstabelecimentoViewModel.preencher(
        nome: String = "  Bar da Lia  ",
        documento: String = "12.345.678/0001-99",
        endereco: String = " CLS 408, Bloco B, Loja 12 ",
        regiao: String = "Plano Piloto",
        latitude: String = "-15,7942",
        longitude: String = "-47.8822",
    ) {
        editarNome(nome)
        editarDocumento(documento)
        escolherTipo(TipoEstabelecimento.EVENTO)
        editarEndereco(endereco)
        escolherRegiao(regiao)
        editarLatitude(latitude)
        editarLongitude(longitude)
    }

    @Test
    fun `cadastro valido manda POST rpc cadastrar_estabelecimento com o corpo do contrato`() = runBlocking {
        val rede = Rede { ok() }
        val vm = viewModelCom(rede)
        vm.preencher()

        vm.cadastrar().join()

        val pedido = rede.pedidos.single()
        assertEquals("/rest/v1/rpc/cadastrar_estabelecimento", pedido.caminho)
        val corpo = pedido.corpo!!
        assertEquals(setOf("nome", "documento", "tipo", "endereco", "regiao_administrativa", "ponto"), corpo.keys)
        assertEquals("Bar da Lia", corpo["nome"]!!.jsonPrimitive.content)
        assertEquals("12345678000199", corpo["documento"]!!.jsonPrimitive.content)
        assertEquals("evento", corpo["tipo"]!!.jsonPrimitive.content)
        assertEquals("CLS 408, Bloco B, Loja 12", corpo["endereco"]!!.jsonPrimitive.content)
        assertEquals("Plano Piloto", corpo["regiao_administrativa"]!!.jsonPrimitive.content)
        assertEquals(-15.7942, corpo["ponto"]!!.jsonObject["latitude"]!!.jsonPrimitive.content.toDouble(), 0.0)
        assertEquals(-47.8822, corpo["ponto"]!!.jsonObject["longitude"]!!.jsonPrimitive.content.toDouble(), 0.0)
        assertEquals("administrador", vm.estado.value.estabelecimentoCriado?.papel)
        assertFalse(vm.estado.value.enviando)
        assertNull(vm.estado.value.erro)
    }

    @Test
    fun `formulario vazio mostra todos os campos obrigatorios de uma vez e nao chama a rede`() = runBlocking {
        val rede = Rede { ok() }
        val vm = viewModelCom(rede)

        vm.cadastrar().join()

        assertTrue(rede.pedidos.isEmpty())
        assertEquals(CampoCadastro.entries.toSet(), vm.estado.value.errosDeCampo.keys)
        assertEquals(TextosCadastroEstabelecimento.CAMPO_OBRIGATORIO, vm.estado.value.errosDeCampo[CampoCadastro.NOME])
        assertEquals(TextosCadastroEstabelecimento.DOCUMENTO_INVALIDO, vm.estado.value.errosDeCampo[CampoCadastro.DOCUMENTO])
    }

    @Test
    fun `nome so com espacos nao vale`() = runBlocking {
        val rede = Rede { ok() }
        val vm = viewModelCom(rede)
        vm.preencher(nome = "    ")

        vm.cadastrar().join()

        assertTrue(rede.pedidos.isEmpty())
        assertEquals(setOf(CampoCadastro.NOME), vm.estado.value.errosDeCampo.keys)
    }

    @Test
    fun `documento aceita 11 ou 14 digitos e recusa os outros tamanhos`() = runBlocking {
        val invalidos = listOf("1234567890", "123456789012", "1234567890123")
        invalidos.forEach { documento ->
            val rede = Rede { ok() }
            val vm = viewModelCom(rede)
            vm.preencher(documento = documento)
            vm.cadastrar().join()
            assertTrue(rede.pedidos.isEmpty(), documento)
            assertEquals(setOf(CampoCadastro.DOCUMENTO), vm.estado.value.errosDeCampo.keys, documento)
        }
        listOf("12345678901", "12345678000199").forEach { documento ->
            val rede = Rede { ok() }
            val vm = viewModelCom(rede)
            vm.preencher(documento = documento)
            vm.cadastrar().join()
            assertEquals(1, rede.pedidos.size, documento)
        }
    }

    @Test
    fun `editarDocumento fica so com digitos e no maximo 14`() {
        val vm = viewModelCom(Rede { ok() })

        vm.editarDocumento("12.345.678/0001-99 e mais 55")

        assertEquals("12345678000199", vm.estado.value.documento)
    }

    @Test
    fun `regiao precisa ser uma das 35 do DF`() = runBlocking {
        assertEquals(35, REGIOES_ADMINISTRATIVAS_DF.size)
        val rede = Rede { ok() }
        val vm = viewModelCom(rede)
        vm.preencher(regiao = "Goiânia")

        vm.cadastrar().join()

        assertTrue(rede.pedidos.isEmpty())
        assertEquals(TextosCadastroEstabelecimento.REGIAO_INVALIDA, vm.estado.value.errosDeCampo[CampoCadastro.REGIAO_ADMINISTRATIVA])
    }

    @Test
    fun `coordenadas fora da faixa, nao numericas ou nao finitas sao recusadas, virgula e ponto valem`() = runBlocking {
        val casos = listOf(
            Triple("91", "-47", CampoCadastro.LATITUDE),
            Triple("-90,5", "-47", CampoCadastro.LATITUDE),
            Triple("-15", "181", CampoCadastro.LONGITUDE),
            Triple("-15", "abc", CampoCadastro.LONGITUDE),
            Triple("NaN", "-47", CampoCadastro.LATITUDE),
            Triple("Infinity", "-47", CampoCadastro.LATITUDE),
        )
        casos.forEach { (lat, lon, campo) ->
            val rede = Rede { ok() }
            val vm = viewModelCom(rede)
            vm.preencher(latitude = lat, longitude = lon)
            vm.cadastrar().join()
            assertTrue(rede.pedidos.isEmpty(), "$lat/$lon")
            assertEquals(setOf(campo), vm.estado.value.errosDeCampo.keys, "$lat/$lon")
        }
        val rede = Rede { ok() }
        val vm = viewModelCom(rede)
        vm.preencher(latitude = "-90", longitude = "180")
        vm.cadastrar().join()
        assertEquals(1, rede.pedidos.size)
    }

    @Test
    fun `editar um campo limpa o proprio erro e o erro global, sem tocar nos outros`() = runBlocking {
        val vm = viewModelCom(Rede { ok() })
        vm.cadastrar().join()
        assertTrue(CampoCadastro.NOME in vm.estado.value.errosDeCampo)

        vm.editarNome("Bar")

        assertFalse(CampoCadastro.NOME in vm.estado.value.errosDeCampo)
        assertTrue(CampoCadastro.DOCUMENTO in vm.estado.value.errosDeCampo)
    }

    @Test
    fun `segundo toque durante o envio e depois de concluido nao cria outro estabelecimento`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        var chamadas = 0
        val vm = CadastroEstabelecimentoViewModel(
            cadastrar = { chamadas++; liberar.await(); br.com.frila.core.rede.EstabelecimentoDto("e1", "Bar", "12345678901", "outro", "Rua", "Gama", br.com.frila.core.rede.CoordenadaDto(-16.0, -48.0), "administrador") },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        vm.preencher()

        val primeiro = vm.cadastrar()
        assertTrue(vm.estado.value.enviando)
        vm.editarNome("outro nome")
        val segundo = vm.cadastrar()
        liberar.complete(Unit)
        withTimeout(5_000) { primeiro.join(); segundo.join() }
        vm.cadastrar().join()
        vm.editarNome("depois de concluido")

        assertEquals(1, chamadas)
        assertEquals("  Bar da Lia  ", vm.estado.value.nome)
        assertTrue(vm.estado.value.concluido)
    }

    private data class Recusa(val status: HttpStatusCode, val codigo: String, val detalhes: String?, val esperado: ErroGlobalCadastro)

    @Test
    fun `cada recusa do contrato vira o erro certo e o botao e liberado`() = runBlocking {
        val casos = listOf(
            Recusa(HttpStatusCode.Conflict, "documento_ja_cadastrado", null, ErroGlobalCadastro.DOCUMENTO_DUPLICADO),
            Recusa(HttpStatusCode.UnprocessableEntity, "perfil_incompativel", null, ErroGlobalCadastro.PERFIL_INCOMPATIVEL),
            Recusa(HttpStatusCode.Forbidden, "sem_permissao", null, ErroGlobalCadastro.SEM_PERMISSAO),
            Recusa(HttpStatusCode.Forbidden, "sem_permissao", "conta_suspensa", ErroGlobalCadastro.CONTA_SUSPENSA),
            Recusa(HttpStatusCode.Forbidden, "conta_suspensa", null, ErroGlobalCadastro.CONTA_SUSPENSA),
            Recusa(HttpStatusCode.Unauthorized, "nao_autenticado", null, ErroGlobalCadastro.SESSAO_EXPIRADA),
            Recusa(HttpStatusCode.InternalServerError, "erro_interno", null, ErroGlobalCadastro.GENERICO),
            Recusa(HttpStatusCode.UnprocessableEntity, "campo_invalido", "desconhecido", ErroGlobalCadastro.CONFIRA_CAMPOS),
        )
        casos.forEach { caso ->
            val vm = viewModelCom(Rede { recusa(caso.status, caso.codigo, caso.detalhes) })
            vm.preencher()

            vm.cadastrar().join()

            assertEquals(caso.esperado, vm.estado.value.erro, "${caso.codigo} ${caso.detalhes}")
            assertFalse(vm.estado.value.enviando)
            assertNull(vm.estado.value.estabelecimentoCriado)
            assertTrue(vm.estado.value.podeEditar)
        }
    }

    @Test
    fun `documento repetido marca o campo do documento`() = runBlocking {
        val vm = viewModelCom(Rede { recusa(HttpStatusCode.Conflict, "documento_ja_cadastrado") })
        vm.preencher()

        vm.cadastrar().join()

        assertEquals(setOf(CampoCadastro.DOCUMENTO), vm.estado.value.errosDeCampo.keys)
        assertEquals(TextosCadastroEstabelecimento.ERRO_DOCUMENTO_DUPLICADO, vm.estado.value.errosDeCampo[CampoCadastro.DOCUMENTO])
    }

    @Test
    fun `campo_obrigatorio e campo_invalido do servidor marcam o campo indicado em details`() = runBlocking {
        val casos = listOf(
            Triple("campo_obrigatorio", "nome", setOf(CampoCadastro.NOME)),
            Triple("campo_invalido", "documento", setOf(CampoCadastro.DOCUMENTO)),
            Triple("campo_invalido", "endereco", setOf(CampoCadastro.ENDERECO)),
            Triple("campo_invalido", "regiao_administrativa", setOf(CampoCadastro.REGIAO_ADMINISTRATIVA)),
            Triple("campo_invalido", "ponto", setOf(CampoCadastro.LATITUDE, CampoCadastro.LONGITUDE)),
        )
        casos.forEach { (codigo, detalhe, campos) ->
            val vm = viewModelCom(Rede { recusa(HttpStatusCode.UnprocessableEntity, codigo, detalhe) })
            vm.preencher()

            vm.cadastrar().join()

            assertEquals(campos, vm.estado.value.errosDeCampo.keys, "$codigo $detalhe")
            assertEquals(ErroGlobalCadastro.CONFIRA_CAMPOS, vm.estado.value.erro)
        }
    }

    @Test
    fun `sem rede mostra a mensagem de conexao e permite tentar de novo com sucesso`() = runBlocking {
        var offline = true
        val vm = viewModelCom(Rede { if (offline) throw ConnectTimeoutException("sem rota", null) else ok() })
        vm.preencher()

        vm.cadastrar().join()
        assertEquals(ErroGlobalCadastro.SEM_REDE, vm.estado.value.erro)
        assertFalse(vm.estado.value.enviando)

        offline = false
        vm.cadastrar().join()
        assertNotNull(vm.estado.value.estabelecimentoCriado)
        assertNull(vm.estado.value.erro)
    }

    @Test
    fun `resposta nao JSON cai no catch generico, libera o botao e deixa tentar de novo (R1)`() = runBlocking {
        var gateway = true
        val vm = viewModelCom(Rede { if (gateway) respond("<html>502 Bad Gateway</html>", HttpStatusCode.OK, html) else ok() })
        vm.preencher()

        vm.cadastrar().join()

        assertEquals(ErroGlobalCadastro.GENERICO, vm.estado.value.erro)
        assertFalse(vm.estado.value.enviando)
        assertNull(vm.estado.value.estabelecimentoCriado)

        gateway = false
        vm.cadastrar().join()
        assertNotNull(vm.estado.value.estabelecimentoCriado)
    }

    @Test
    fun `erro 502 em HTML tambem cai no catch generico`() = runBlocking {
        val vm = viewModelCom(Rede { respond("<html>502</html>", HttpStatusCode.BadGateway, html) })
        vm.preencher()

        vm.cadastrar().join()

        assertEquals(ErroGlobalCadastro.GENERICO, vm.estado.value.erro)
        assertFalse(vm.estado.value.enviando)
    }

    @Test
    fun `corpo de sucesso sem campo obrigatorio tambem cai no catch generico`() = runBlocking {
        val vm = viewModelCom(Rede { respond("""{"id":"e1"}""", HttpStatusCode.OK, json) })
        vm.preencher()

        vm.cadastrar().join()

        assertEquals(ErroGlobalCadastro.GENERICO, vm.estado.value.erro)
        assertFalse(vm.estado.value.enviando)
    }

    @Test
    fun `tipos mandam a chave de fio do contrato`() {
        assertEquals(
            listOf("food_service", "evento", "varejo", "logistica", "servico_domestico", "outro"),
            TipoEstabelecimento.entries.map { it.chave },
        )
    }
}
