package br.com.frila.feature.vagas.publicacao

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.CoordenadaDto
import br.com.frila.core.rede.ServicoVagas
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

class PublicarVagaViewModelTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val html = headersOf(HttpHeaders.ContentType, "text/html")

    /** Quarta-feira, 12h em Brasília. Tudo o que depende do relógio parte daqui. */
    private val base: Instant = Instant.parse("2026-11-10T15:00:00Z")

    private val funcoesJson = """
        [{"id":"f1","nome":"Garçom","categoria":"Salão"},{"id":"f2","nome":"Cozinheiro","categoria":"Cozinha"}]
    """.trimIndent()
    private val publicadaJson = """{"vaga_id":"v1","posicoes":["p1","p2"]}"""

    private class Pedido(val caminho: String, val corpo: JsonObject?)

    private class Rede(
        val publicar: MockRequestHandleScope.(HttpRequestData) -> HttpResponseData,
        val funcoes: MockRequestHandleScope.(HttpRequestData) -> HttpResponseData = { respond("[]", HttpStatusCode.OK) },
    ) {
        val pedidos = mutableListOf<Pedido>()
        val publicacoes get() = pedidos.filter { it.caminho.endsWith("/publicar_vaga") }
    }

    private var agora: Instant = base
    private var chaves = 0

    private fun viewModelCom(rede: Rede): PublicarVagaViewModel {
        val engine = MockEngine { request ->
            val corpo = (request.body as? TextContent)?.text?.let { ClienteSupabase.jsonFrila.parseToJsonElement(it).jsonObject }
            rede.pedidos += Pedido(request.url.encodedPath, corpo)
            if (request.url.encodedPath.endsWith("/funcao")) rede.funcoes(this, request) else rede.publicar(this, request)
        }
        val servico = ServicoVagas(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
        return PublicarVagaViewModel(
            estabelecimento = EstabelecimentoDaVaga(
                id = "e1",
                endereco = "CLS 408, Bloco B, Loja 12",
                regiaoAdministrativa = "Plano Piloto",
                ponto = CoordenadaDto(-15.7942, -47.8822),
            ),
            buscarFuncoes = servico::listarFuncoes,
            enviarVaga = servico::publicarVaga,
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

    /** Formulário válido: função, valor R$ 140,00, 2 posições e responsável. O início é daqui a 3 horas. */
    private fun PublicarVagaViewModel.preencher(
        valor: String = "140",
        posicoes: String = "2",
        responsavel: String = "  Lia  ",
    ) {
        runBlocking { carregarFuncoes().join() }
        escolherFuncao("f1")
        editarValor(valor)
        editarPosicoes(posicoes)
        editarResponsavel(responsavel)
    }

    @Test
    fun `publicacao valida manda POST rpc publicar_vaga com o corpo do contrato`() = runBlocking {
        val rede = redeOk()
        val vm = viewModelCom(rede)
        vm.preencher()
        vm.editarLocal("  CLS 408, Bloco B  ")
        vm.alternarRefeicao(true)
        vm.alternarMaterialProprio(true)
        vm.editarTraje("  Preto  ")

        vm.publicar().join()

        val pedido = rede.publicacoes.single()
        assertEquals("/rest/v1/rpc/publicar_vaga", pedido.caminho)
        val corpo = pedido.corpo!!
        assertEquals(
            setOf(
                "estabelecimento_id", "funcao_id", "inicio_em", "fim_em", "local", "regiao_administrativa", "ponto",
                "valor_centavos", "posicoes", "inclui_refeicao", "inclui_transporte", "exige_material_proprio",
                "responsavel_local", "traje", "participa_rateio", "observacoes", "modo", "alerta_antecedencia_min", "chave",
            ),
            corpo.keys,
        )
        assertEquals("e1", corpo["estabelecimento_id"]!!.jsonPrimitive.content)
        assertEquals("f1", corpo["funcao_id"]!!.jsonPrimitive.content)
        assertEquals("2026-11-10T18:00:00Z", corpo["inicio_em"]!!.jsonPrimitive.content)
        assertEquals("2026-11-10T21:00:00Z", corpo["fim_em"]!!.jsonPrimitive.content)
        assertEquals("CLS 408, Bloco B", corpo["local"]!!.jsonPrimitive.content)
        assertEquals("Plano Piloto", corpo["regiao_administrativa"]!!.jsonPrimitive.content)
        assertEquals(-15.7942, corpo["ponto"]!!.jsonObject["latitude"]!!.jsonPrimitive.content.toDouble(), 0.0)
        assertEquals("14000", corpo["valor_centavos"]!!.jsonPrimitive.content)
        assertEquals("2", corpo["posicoes"]!!.jsonPrimitive.content)
        assertEquals("true", corpo["inclui_refeicao"]!!.jsonPrimitive.content)
        assertEquals("false", corpo["inclui_transporte"]!!.jsonPrimitive.content)
        assertEquals("true", corpo["exige_material_proprio"]!!.jsonPrimitive.content)
        assertEquals("Lia", corpo["responsavel_local"]!!.jsonPrimitive.content)
        assertEquals("Preto", corpo["traje"]!!.jsonPrimitive.content)
        assertEquals("urgencia", corpo["modo"]!!.jsonPrimitive.content)
        assertEquals("180", corpo["alerta_antecedencia_min"]!!.jsonPrimitive.content)
        assertEquals("chave-1", corpo["chave"]!!.jsonPrimitive.content)
        assertEquals("v1", vm.estado.value.publicada?.vagaId)
        assertNull(vm.estado.value.pendente)
        assertFalse(vm.estado.value.enviando)
    }

    @Test
    fun `depois de publicada um novo toque nao cria outra vaga`() = runBlocking {
        val rede = redeOk()
        val vm = viewModelCom(rede)
        vm.preencher()

        vm.publicar().join()
        vm.publicar().join()
        vm.editarValor("999")

        assertEquals(1, rede.publicacoes.size)
        assertEquals("140", vm.estado.value.valor)
    }

    @Test
    fun `formulario vazio aponta todos os campos obrigatorios e nao chama a rede`() = runBlocking {
        val rede = redeOk()
        val vm = viewModelCom(rede)

        vm.publicar().join()

        assertEquals(
            setOf(CampoPublicacao.FUNCAO, CampoPublicacao.VALOR, CampoPublicacao.RESPONSAVEL),
            vm.estado.value.errosDeCampo.keys,
        )
        assertTrue(rede.publicacoes.isEmpty())
        assertFalse(vm.estado.value.enviando)
    }

    @Test
    fun `inicio no passado e fim antes do inicio sao recusados`() = runBlocking {
        val rede = redeOk()
        val vm = viewModelCom(rede)
        vm.preencher()
        vm.editarInicio(base.minusSeconds(60))
        vm.editarFim(base.minusSeconds(3600))

        vm.publicar().join()

        assertEquals(TextosPublicarVaga.HORARIO_INICIO_CAMPO, vm.estado.value.errosDeCampo[CampoPublicacao.INICIO])
        assertEquals(TextosPublicarVaga.HORARIO_FIM_CAMPO, vm.estado.value.errosDeCampo[CampoPublicacao.FIM])
        assertTrue(rede.publicacoes.isEmpty())
    }

    @Test
    fun `fim igual ao inicio e recusado`() = runBlocking {
        val vm = viewModelCom(redeOk())
        vm.preencher()
        vm.editarFim(vm.estado.value.inicio)

        vm.publicar().join()

        assertNotNull(vm.estado.value.errosDeCampo[CampoPublicacao.FIM])
    }

    @Test
    fun `selecao com exatas 24 horas de antecedencia e recusada e com 24 horas e um minuto passa`() = runBlocking {
        val rede = redeOk()
        val vm = viewModelCom(rede)
        vm.preencher()
        vm.editarInicio(base.plus(Duration.ofHours(24).plusSeconds(60)))
        vm.escolherModo(ModoDaVaga.SELECAO)
        // O início encosta nas 24 horas: a seleção deixou de caber e o servidor a recusaria.
        agora = base.plusSeconds(60)

        vm.publicar().join()

        assertEquals(TextosPublicarVaga.SELECAO_SEM_ANTECEDENCIA_CAMPO, vm.estado.value.errosDeCampo[CampoPublicacao.INICIO])
        assertTrue(rede.publicacoes.isEmpty())

        agora = base
        vm.publicar().join()

        assertEquals("selecao", rede.publicacoes.single().corpo!!["modo"]!!.jsonPrimitive.content)
    }

    @Test
    fun `escolher selecao sem antecedencia e ignorado e explica o motivo`() = runBlocking {
        val vm = viewModelCom(redeOk())

        vm.escolherModo(ModoDaVaga.SELECAO)

        assertEquals(ModoDaVaga.URGENCIA, vm.estado.value.modo)
        assertEquals(TextosPublicarVaga.SELECAO_SEM_ANTECEDENCIA_CAMPO, vm.estado.value.errosDeCampo[CampoPublicacao.MODO])
    }

    @Test
    fun `mover o inicio para menos de 24 horas devolve a selecao para urgencia`() = runBlocking {
        val vm = viewModelCom(redeOk())
        vm.editarInicio(base.plus(Duration.ofHours(48)))
        vm.escolherModo(ModoDaVaga.SELECAO)
        assertEquals(ModoDaVaga.SELECAO, vm.estado.value.modo)

        vm.editarInicio(base.plus(Duration.ofHours(5)))

        assertEquals(ModoDaVaga.URGENCIA, vm.estado.value.modo)
    }

    @Test
    fun `mover o inicio leva o fim junto e preserva a duracao`() = runBlocking {
        val vm = viewModelCom(redeOk())
        vm.editarFim(vm.estado.value.inicio.plus(Duration.ofHours(6)))

        vm.editarInicio(base.plus(Duration.ofHours(10)))

        assertEquals(Duration.ofHours(6), vm.estado.value.duracao)
        assertEquals(base.plus(Duration.ofHours(10)), vm.estado.value.inicio)
    }

    @Test
    fun `posicoes aceitam de 1 a 200`() = runBlocking {
        val rede = redeOk()
        val vm = viewModelCom(rede)
        vm.preencher()

        for (invalida in listOf("0", "201", "")) {
            vm.editarPosicoes(invalida)
            vm.publicar().join()
            assertEquals(TextosPublicarVaga.POSICOES_CAMPO, vm.estado.value.errosDeCampo[CampoPublicacao.POSICOES], invalida)
        }
        assertTrue(rede.publicacoes.isEmpty())

        vm.editarPosicoes("200")
        vm.publicar().join()

        assertEquals("200", rede.publicacoes.single().corpo!!["posicoes"]!!.jsonPrimitive.content)
    }

    @Test
    fun `valor zero ou ilegivel e recusado`() = runBlocking {
        val rede = redeOk()
        val vm = viewModelCom(rede)
        vm.preencher()

        for (invalido in listOf("0", "abc", "", "10,555")) {
            vm.editarValor(invalido)
            vm.publicar().join()
            assertEquals(TextosPublicarVaga.VALOR_CAMPO, vm.estado.value.errosDeCampo[CampoPublicacao.VALOR], invalido)
        }
        assertTrue(rede.publicacoes.isEmpty())
    }

    @Test
    fun `local em branco e recusado e responsavel em branco tambem`() = runBlocking {
        val vm = viewModelCom(redeOk())
        vm.preencher(responsavel = "   ")
        vm.editarLocal("   ")

        vm.publicar().join()

        assertEquals(setOf(CampoPublicacao.LOCAL, CampoPublicacao.RESPONSAVEL), vm.estado.value.errosDeCampo.keys)
    }

    @Test
    fun `total e valor por hora vem do valor por pessoa, das posicoes e da duracao`() = runBlocking {
        val vm = viewModelCom(redeOk())
        vm.editarValor("140")
        vm.editarPosicoes("3")

        val estado = vm.estado.value
        assertEquals(42_000L, estado.valorTotalCentavos)
        // 14.000 centavos em 3 horas: 4.666,67 por hora, arredondado.
        assertEquals(4_667L, estado.valorPorHoraCentavos)

        vm.editarFim(estado.inicio.plus(Duration.ofHours(1)))
        assertEquals(14_000L, vm.estado.value.valorPorHoraCentavos)
        vm.editarPosicoes("")
        assertNull(vm.estado.value.valorTotalCentavos)
    }

    @Test
    fun `mais e menos uma posicao respeitam os limites`() = runBlocking {
        val vm = viewModelCom(redeOk())

        vm.menosUmaPosicao()
        assertEquals("1", vm.estado.value.posicoes)
        vm.maisUmaPosicao()
        assertEquals("2", vm.estado.value.posicoes)
        vm.editarPosicoes("200")
        vm.maisUmaPosicao()
        assertEquals("200", vm.estado.value.posicoes)
    }

    @Test
    fun `editar um campo limpa o erro dele e o erro global`() = runBlocking {
        val vm = viewModelCom(Rede(publicar = { recusa(HttpStatusCode.UnprocessableEntity, "campo_invalido", "valor_centavos") }, funcoes = { respond(funcoesJson, HttpStatusCode.OK, json) }))
        vm.preencher()
        vm.publicar().join()
        assertEquals(setOf(CampoPublicacao.VALOR), vm.estado.value.errosDeCampo.keys)
        assertNotNull(vm.estado.value.erro)

        vm.editarValor("150")

        assertTrue(vm.estado.value.errosDeCampo.isEmpty())
        assertNull(vm.estado.value.erro)
    }

    // ---- Recusas do servidor ----

    private fun recusaDe(status: HttpStatusCode, codigo: String, detalhes: String? = null): PublicarVagaViewModel {
        val vm = viewModelCom(Rede(publicar = { recusa(status, codigo, detalhes) }, funcoes = { respond(funcoesJson, HttpStatusCode.OK, json) }))
        vm.preencher()
        runBlocking { vm.publicar().join() }
        return vm
    }

    @Test
    fun `422 campo_obrigatorio marca o campo indicado em details`() {
        val estado = recusaDe(HttpStatusCode.UnprocessableEntity, "campo_obrigatorio", "responsavel_local").estado.value

        assertEquals(TextosPublicarVaga.CAMPO_OBRIGATORIO, estado.errosDeCampo[CampoPublicacao.RESPONSAVEL])
        assertEquals(ErroGlobalPublicacao.CONFIRA_CAMPOS, estado.erro)
        assertNull(estado.pendente)
    }

    @Test
    fun `422 campo_invalido marca o campo e ponto vira estabelecimento`() {
        val valor = recusaDe(HttpStatusCode.UnprocessableEntity, "campo_invalido", "valor_centavos").estado.value
        val ponto = recusaDe(HttpStatusCode.UnprocessableEntity, "campo_invalido", "ponto").estado.value

        assertEquals(TextosPublicarVaga.CAMPO_INVALIDO, valor.errosDeCampo[CampoPublicacao.VALOR])
        assertEquals(TextosPublicarVaga.CAMPO_INVALIDO, ponto.errosDeCampo[CampoPublicacao.ESTABELECIMENTO])
    }

    @Test
    fun `422 campo_invalido sem campo conhecido mostra so o erro global`() {
        val estado = recusaDe(HttpStatusCode.UnprocessableEntity, "campo_invalido", "campo_novo").estado.value

        assertTrue(estado.errosDeCampo.isEmpty())
        assertEquals(ErroGlobalPublicacao.CONFIRA_CAMPOS, estado.erro)
    }

    @Test
    fun `422 selecao_sem_antecedencia aponta o inicio e libera a edicao`() {
        val vm = recusaDe(HttpStatusCode.UnprocessableEntity, "selecao_sem_antecedencia")
        val estado = vm.estado.value

        assertEquals(TextosPublicarVaga.SELECAO_SEM_ANTECEDENCIA_CAMPO, estado.errosDeCampo[CampoPublicacao.INICIO])
        assertEquals(ErroGlobalPublicacao.SELECAO_SEM_ANTECEDENCIA, estado.erro)
        assertTrue(estado.podeEditar)
    }

    @Test
    fun `422 horario_invalido aponta inicio e fim`() {
        val estado = recusaDe(HttpStatusCode.UnprocessableEntity, "horario_invalido").estado.value

        assertEquals(setOf(CampoPublicacao.INICIO, CampoPublicacao.FIM), estado.errosDeCampo.keys)
    }

    @Test
    fun `422 perfil_incompativel e 403 sem_permissao tem mensagem propria`() {
        assertEquals(ErroGlobalPublicacao.PERFIL_INCOMPATIVEL, recusaDe(HttpStatusCode.UnprocessableEntity, "perfil_incompativel").estado.value.erro)
        assertEquals(ErroGlobalPublicacao.SEM_PERMISSAO, recusaDe(HttpStatusCode.Forbidden, "sem_permissao").estado.value.erro)
    }

    @Test
    fun `403 sem_permissao com details conta_suspensa vira conta suspensa`() {
        val estado = recusaDe(HttpStatusCode.Forbidden, "sem_permissao", "conta_suspensa").estado.value

        assertEquals(ErroGlobalPublicacao.CONTA_SUSPENSA, estado.erro)
        assertTrue(estado.podeEditar)
    }

    @Test
    fun `401 vira sessao expirada e mantem a publicacao pendente`() {
        val estado = recusaDe(HttpStatusCode.Unauthorized, "nao_autenticado").estado.value

        assertEquals(ErroGlobalPublicacao.SESSAO_EXPIRADA, estado.erro)
        assertNotNull(estado.pendente)
    }

    @Test
    fun `erro 500 em JSON cai no generico e mantem a publicacao pendente`() {
        val estado = recusaDe(HttpStatusCode.InternalServerError, "erro_interno").estado.value

        assertEquals(ErroGlobalPublicacao.GENERICO, estado.erro)
        assertNotNull(estado.pendente)
        assertFalse(estado.enviando)
    }

    @Test
    fun `sem rede mostra mensagem propria e mantem a publicacao pendente`() = runBlocking {
        val vm = viewModelCom(Rede(publicar = { throw ConnectTimeoutException("sem rede") }, funcoes = { respond(funcoesJson, HttpStatusCode.OK, json) }))
        vm.preencher()

        vm.publicar().join()

        assertEquals(ErroGlobalPublicacao.SEM_REDE, vm.estado.value.erro)
        assertNotNull(vm.estado.value.pendente)
        assertFalse(vm.estado.value.enviando)
    }

    // ---- Resposta que não é o JSON esperado (Yugao R1) ----

    private fun comResposta(resposta: MockRequestHandleScope.(HttpRequestData) -> HttpResponseData): PublicarVagaViewModel {
        val vm = viewModelCom(Rede(publicar = resposta, funcoes = { respond(funcoesJson, HttpStatusCode.OK, json) }))
        vm.preencher()
        runBlocking { vm.publicar().join() }
        return vm
    }

    @Test
    fun `200 com HTML cai no catch generico e libera o botao`() {
        val estado = comResposta { respond("<html>ok</html>", HttpStatusCode.OK, html) }.estado.value

        assertEquals(ErroGlobalPublicacao.GENERICO, estado.erro)
        assertFalse(estado.enviando)
        assertNull(estado.publicada)
    }

    @Test
    fun `502 com HTML do gateway cai no catch generico e libera o botao`() {
        val estado = comResposta { respond("<html>502 Bad Gateway</html>", HttpStatusCode.BadGateway, html) }.estado.value

        assertEquals(ErroGlobalPublicacao.GENERICO, estado.erro)
        assertFalse(estado.enviando)
    }

    @Test
    fun `200 sem o campo obrigatorio vaga_id cai no catch generico e libera o botao`() {
        val estado = comResposta { respond("""{"posicoes":[]}""", HttpStatusCode.OK, json) }.estado.value

        assertEquals(ErroGlobalPublicacao.GENERICO, estado.erro)
        assertFalse(estado.enviando)
        assertNull(estado.publicada)
    }

    // ---- Idempotência pela chave ----

    @Test
    fun `reenviar depois de falha incerta manda o mesmo corpo e a mesma chave e trava a edicao`() = runBlocking {
        var tentativa = 0
        val rede = Rede(
            publicar = { if (++tentativa == 1) respond("<html>502</html>", HttpStatusCode.BadGateway, html) else respond(publicadaJson, HttpStatusCode.OK, json) },
            funcoes = { respond(funcoesJson, HttpStatusCode.OK, json) },
        )
        val vm = viewModelCom(rede)
        vm.preencher()

        vm.publicar().join()
        vm.editarValor("999")
        agora = base.plusSeconds(30)
        vm.publicar().join()

        assertEquals(2, rede.publicacoes.size)
        assertEquals(rede.publicacoes[0].corpo, rede.publicacoes[1].corpo)
        assertEquals("chave-1", rede.publicacoes[1].corpo!!["chave"]!!.jsonPrimitive.content)
        assertEquals("14000", rede.publicacoes[1].corpo!!["valor_centavos"]!!.jsonPrimitive.content)
        assertEquals(1, chaves)
        assertEquals("v1", vm.estado.value.publicada?.vagaId)
        assertNull(vm.estado.value.pendente)
    }

    @Test
    fun `com publicacao pendente o formulario fica travado`() = runBlocking {
        val vm = viewModelCom(Rede(publicar = { throw ConnectTimeoutException("sem rede") }, funcoes = { respond(funcoesJson, HttpStatusCode.OK, json) }))
        vm.preencher()
        vm.publicar().join()

        vm.editarValor("999")
        vm.escolherFuncao("f2")
        vm.alternarTransporte(true)
        vm.escolherModo(ModoDaVaga.SELECAO)

        val estado = vm.estado.value
        assertFalse(estado.podeEditar)
        assertEquals("140", estado.valor)
        assertEquals("f1", estado.funcaoId)
        assertFalse(estado.incluiTransporte)
    }

    @Test
    fun `recusa definitiva descarta o corpo e a proxima tentativa usa chave nova`() = runBlocking {
        var tentativa = 0
        val rede = Rede(
            publicar = { if (++tentativa == 1) recusa(HttpStatusCode.UnprocessableEntity, "campo_invalido", "valor_centavos") else respond(publicadaJson, HttpStatusCode.OK, json) },
            funcoes = { respond(funcoesJson, HttpStatusCode.OK, json) },
        )
        val vm = viewModelCom(rede)
        vm.preencher()

        vm.publicar().join()
        assertNull(vm.estado.value.pendente)
        vm.editarValor("150")
        vm.publicar().join()

        assertEquals("chave-1", rede.publicacoes[0].corpo!!["chave"]!!.jsonPrimitive.content)
        assertEquals("chave-2", rede.publicacoes[1].corpo!!["chave"]!!.jsonPrimitive.content)
        assertEquals("15000", rede.publicacoes[1].corpo!!["valor_centavos"]!!.jsonPrimitive.content)
    }

    @Test
    fun `segundo toque durante o envio nao manda segunda publicacao`() = runBlocking {
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
        assertEquals("v1", vm.estado.value.publicada?.vagaId)
    }

    // ---- Funções ----

    @Test
    fun `carregarFuncoes preenche o catalogo e le a tabela funcao`() = runBlocking {
        val rede = redeOk()
        val vm = viewModelCom(rede)

        vm.carregarFuncoes().join()

        assertEquals(listOf("Garçom", "Cozinheiro"), vm.estado.value.funcoes.map { it.nome })
        assertEquals("/rest/v1/funcao", rede.pedidos.single().caminho)
        assertFalse(vm.estado.value.carregandoFuncoes)
        assertFalse(vm.estado.value.falhaAoCarregarFuncoes)
    }

    @Test
    fun `carregarFuncoes com falha marca a falha e permite tentar de novo`() = runBlocking {
        var tentativa = 0
        val rede = Rede(
            publicar = { respond(publicadaJson, HttpStatusCode.OK, json) },
            // 200 com HTML: um 502 seria repetido pelo retry de GET do cliente e a primeira chamada já teria sucesso.
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

    @Test
    fun `catalogo vazio conta como falha e funcao fora do catalogo e recusada`() = runBlocking {
        val vm = viewModelCom(Rede(publicar = { respond(publicadaJson, HttpStatusCode.OK, json) }, funcoes = { respond("[]", HttpStatusCode.OK, json) }))
        vm.carregarFuncoes().join()
        assertTrue(vm.estado.value.falhaAoCarregarFuncoes)

        val outro = viewModelCom(redeOk())
        outro.preencher()
        outro.escolherFuncao("inexistente")
        outro.publicar().join()
        assertEquals(TextosPublicarVaga.FUNCAO_CAMPO, outro.estado.value.errosDeCampo[CampoPublicacao.FUNCAO])
    }
}
