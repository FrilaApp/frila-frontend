package br.com.frila.feature.vagas.painel

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.PainelDto
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
import java.time.Instant
import java.time.ZoneId
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
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.CsvSource

class MinhasVagasViewModelTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val html = headersOf(HttpHeaders.ContentType, "text/html")

    /** Terça-feira, 10/11/2026, 12h em Brasília. */
    private val agora: Instant = Instant.parse("2026-11-10T15:00:00Z")
    private val saoPaulo = ZoneId.of("America/Sao_Paulo")

    private fun posicao(estado: String, emAtraso: Boolean = false) =
        """{"id":"pos-${posicaoSeq++}","estado":"$estado","profissional":null,"turno_id":null,"verificacao":null,"em_atraso":$emAtraso,"a_caminho_em":null}"""

    private var posicaoSeq = 0

    private fun vaga(
        id: String,
        funcao: String = "garçom",
        inicio: String,
        fim: String,
        modo: String = "urgencia",
        estado: String = "publicada",
        alerta: Boolean = false,
        pendentes: Int = 0,
        oculta: Boolean = false,
        posicoes: List<String> = listOf("aberta"),
        emAtraso: Boolean = false,
    ) = """
        {"vaga":{"id":"$id","funcao":"$funcao","local":"SQN 108","regiao_administrativa":"Asa Norte",
                 "inicio_em":"$inicio","fim_em":"$fim","valor_centavos":16000},
         "modo":"$modo","estado":"$estado","oculta":$oculta,"alerta_vaga_vazia":$alerta,"candidatos_pendentes":$pendentes,
         "posicoes":[${posicoes.joinToString(",") { posicao(it, emAtraso) }}]}
    """.trimIndent()

    private fun painel(vararg vagas: String, estabelecimento: String = "est-1") =
        """{"estabelecimento_id":"$estabelecimento","vagas":[${vagas.joinToString(",")}],"checkins_pendentes":[]}"""

    private class Pedido(val caminho: String, val corpo: JsonObject?)

    private class Rede(val resposta: MockRequestHandleScope.(HttpRequestData) -> HttpResponseData) {
        val pedidos = mutableListOf<Pedido>()
    }

    private fun viewModelCom(
        rede: Rede,
        recemPublicada: String? = null,
        nome: String? = "Bar da Lia",
    ): MinhasVagasViewModel {
        val engine = MockEngine { request ->
            val corpo = (request.body as? TextContent)?.text?.let { ClienteSupabase.jsonFrila.parseToJsonElement(it).jsonObject }
            rede.pedidos += Pedido(request.url.encodedPath, corpo)
            rede.resposta(this, request)
        }
        val servico = ServicoVagas(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
        return MinhasVagasViewModel(
            estabelecimentoId = "est-1",
            nomeEstabelecimento = nome,
            vagaRecemPublicadaId = recemPublicada,
            buscarPainel = servico::painelEstabelecimento,
            relogio = { agora },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
    }

    private fun redeCom(conteudo: String) = Rede { respond(conteudo, HttpStatusCode.OK, json) }

    private fun MockRequestHandleScope.recusa(status: HttpStatusCode, codigo: String) =
        respond("""{"code":"$codigo","message":"x"}""", status, json)

    private fun MinhasVagasViewModel.itens(): List<ItemMinhaVaga> = (estado.value.lista as ListaMinhasVagas.Sucesso).itens

    // ---- Leitura ----

    @Test
    fun `carregar faz POST com o estabelecimento e a janela de 365 dias para os dois lados`() = runBlocking {
        val rede = redeCom(painel(vaga("v1", inicio = "2026-11-10T18:00:00Z", fim = "2026-11-10T21:00:00Z")))
        val vm = viewModelCom(rede)

        vm.carregar().join()

        val pedido = rede.pedidos.single()
        assertEquals("/rest/v1/rpc/painel_estabelecimento", pedido.caminho)
        assertEquals("est-1", pedido.corpo!!["estabelecimento_id"]!!.jsonPrimitive.content)
        assertEquals("2025-11-10T15:00:00Z", pedido.corpo!!["de"]!!.jsonPrimitive.content)
        assertEquals("2027-11-10T15:00:00Z", pedido.corpo!!["ate"]!!.jsonPrimitive.content)
        assertEquals(1, vm.itens().size)
        assertFalse(vm.estado.value.atualizando)
    }

    @Test
    fun `painel sem vagas vira Vazio`() = runBlocking {
        val vm = viewModelCom(redeCom(painel()))

        vm.carregar().join()

        assertEquals(ListaMinhasVagas.Vazio, vm.estado.value.lista)
    }

    @Test
    fun `duas chamadas seguidas de carregar fazem uma so leitura`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        val rede = Rede { runBlocking { liberar.await() }; respond(painel(), HttpStatusCode.OK, json) }
        val vm = viewModelCom(rede)

        val primeira = vm.carregar()
        vm.carregar()
        liberar.complete(Unit)
        withTimeout(5_000) { primeira.join() }

        assertEquals(1, rede.pedidos.size)
    }

    // ---- Erros ----

    private fun erroDe(rede: Rede): ErroMinhasVagas {
        val vm = viewModelCom(rede)
        runBlocking { vm.carregar().join() }
        return (vm.estado.value.lista as ListaMinhasVagas.Erro).erro
    }

    @Test
    fun `403 vira sem permissao e nao oferece tentar de novo`() {
        val erro = erroDe(Rede { recusa(HttpStatusCode.Forbidden, "sem_permissao") })

        assertEquals(ErroMinhasVagas.SEM_PERMISSAO, erro)
        assertFalse(erro.podeTentarDeNovo)
    }

    @Test
    fun `401 vira sessao expirada`() {
        assertEquals(ErroMinhasVagas.SESSAO_EXPIRADA, erroDe(Rede { recusa(HttpStatusCode.Unauthorized, "nao_autenticado") }))
    }

    @Test
    fun `sem rede vira SEM_REDE e oferece tentar de novo`() {
        val erro = erroDe(Rede { throw ConnectTimeoutException("sem rede") })

        assertEquals(ErroMinhasVagas.SEM_REDE, erro)
        assertTrue(erro.podeTentarDeNovo)
    }

    @Test
    fun `erro 500 em JSON vira generico`() {
        assertEquals(ErroMinhasVagas.GENERICO, erroDe(Rede { recusa(HttpStatusCode.InternalServerError, "erro_interno") }))
    }

    @Test
    fun `200 com HTML e 502 com HTML viram generico, nunca carregando eterno`() {
        assertEquals(ErroMinhasVagas.GENERICO, erroDe(Rede { respond("<html>ok</html>", HttpStatusCode.OK, html) }))
        assertEquals(ErroMinhasVagas.GENERICO, erroDe(Rede { respond("<html>502</html>", HttpStatusCode.BadGateway, html) }))
    }

    @Test
    fun `200 sem o campo obrigatorio checkins_pendentes vira generico`() {
        val rede = redeCom("""{"estabelecimento_id":"est-1","vagas":[]}""")

        assertEquals(ErroMinhasVagas.GENERICO, erroDe(rede))
    }

    @Test
    fun `painel de outro estabelecimento e recusado`() {
        assertEquals(ErroMinhasVagas.SEM_ESTABELECIMENTO, erroDe(redeCom(painel(estabelecimento = "outro"))))
    }

    @Test
    fun `lancamento escapando do servico tambem vira generico`() = runBlocking {
        val vm = MinhasVagasViewModel(
            estabelecimentoId = "est-1",
            buscarPainel = { _, _, _ -> error("explodiu") },
            relogio = { agora },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )

        vm.carregar().join()

        assertEquals(ListaMinhasVagas.Erro(ErroMinhasVagas.GENERICO), vm.estado.value.lista)
    }

    @Test
    fun `tentar de novo depois do erro carrega as vagas`() = runBlocking {
        var tentativa = 0
        val vm = viewModelCom(Rede { if (++tentativa == 1) recusa(HttpStatusCode.InternalServerError, "x") else respond(painel(vaga("v1", inicio = "2026-11-10T18:00:00Z", fim = "2026-11-10T21:00:00Z")), HttpStatusCode.OK, json) })

        vm.carregar().join()
        assertTrue(vm.estado.value.lista is ListaMinhasVagas.Erro)
        vm.carregar().join()

        assertEquals(1, vm.itens().size)
    }

    @Test
    fun `falha ao atualizar com vagas na tela mantem a lista e avisa que pode estar velha`() = runBlocking {
        var tentativa = 0
        val vm = viewModelCom(
            Rede {
                if (++tentativa == 1) {
                    respond(painel(vaga("v1", inicio = "2026-11-10T18:00:00Z", fim = "2026-11-10T21:00:00Z")), HttpStatusCode.OK, json)
                } else {
                    respond("<html>x</html>", HttpStatusCode.OK, html)
                }
            },
        )
        vm.carregar().join()

        vm.atualizar().join()

        assertEquals(1, vm.itens().size)
        assertTrue(vm.estado.value.desatualizada)
        assertFalse(vm.estado.value.atualizando)
    }

    @Test
    fun `atualizar com sucesso depois da falha limpa o aviso`() = runBlocking {
        var tentativa = 0
        val vm = viewModelCom(
            Rede {
                when (++tentativa) {
                    2 -> throw ConnectTimeoutException("sem rede")
                    else -> respond(painel(vaga("v$tentativa", inicio = "2026-11-10T18:00:00Z", fim = "2026-11-10T21:00:00Z")), HttpStatusCode.OK, json)
                }
            },
        )
        vm.carregar().join()
        vm.atualizar().join()
        assertTrue(vm.estado.value.desatualizada)

        vm.atualizar().join()

        assertFalse(vm.estado.value.desatualizada)
        assertEquals("v3", vm.itens().single().id)
    }

    // ---- Seções ----

    private fun secaoDe(
        inicio: String?,
        fim: String?,
        estado: String = "publicada",
        alerta: Boolean = false,
        zona: ZoneId = saoPaulo,
    ) = classificarVaga(estado, inicio?.let(Instant::parse), fim?.let(Instant::parse), alerta, agora, zona)

    @ParameterizedTest
    @CsvSource(
        "2026-11-10T18:00:00Z, 2026-11-10T21:00:00Z, publicada, false, HOJE",
        "2026-11-11T18:00:00Z, 2026-11-11T21:00:00Z, publicada, false, PROXIMAS",
        "2026-11-10T18:00:00Z, 2026-11-10T21:00:00Z, encerrada, false, ENCERRADAS",
        "2026-11-10T18:00:00Z, 2026-11-10T21:00:00Z, cancelada, false, ENCERRADAS",
        "2026-11-10T10:00:00Z, 2026-11-10T15:00:00Z, publicada, false, ENCERRADAS",
        "2026-11-10T10:00:00Z, 2026-11-10T15:00:01Z, publicada, false, HOJE",
        "2026-11-11T18:00:00Z, 2026-11-11T21:00:00Z, publicada, true, EM_ALERTA",
        "2026-11-10T18:00:00Z, 2026-11-10T21:00:00Z, publicada, true, EM_ALERTA",
        "2026-11-10T18:00:00Z, 2026-11-10T21:00:00Z, cancelada, true, ENCERRADAS",
        "2026-11-09T20:00:00Z, 2026-11-10T20:00:00Z, publicada, false, HOJE",
        "2026-11-11T02:00:00Z, 2026-11-11T05:00:00Z, publicada, false, HOJE",
        "2026-11-11T03:00:00Z, 2026-11-11T06:00:00Z, publicada, false, PROXIMAS",
        "2026-11-08T12:00:00Z, 2026-11-12T12:00:00Z, publicada, false, ENCERRADAS",
    )
    fun `classificarVaga segue as regras do iOS no horario de Brasilia`(
        inicio: String,
        fim: String,
        estado: String,
        alerta: Boolean,
        esperada: SecaoMinhasVagas,
    ) {
        assertEquals(esperada, secaoDe(inicio, fim, estado, alerta))
    }

    @Test
    fun `o dia de hoje e o de Brasilia, nao o de UTC`() {
        // 23h de 10/11 em Brasilia ja e 11/11 em UTC.
        val noite = secaoDe("2026-11-11T02:00:00Z", "2026-11-11T05:00:00Z")
        val emUtc = secaoDe("2026-11-11T02:00:00Z", "2026-11-11T05:00:00Z", zona = ZoneId.of("UTC"))

        assertEquals(SecaoMinhasVagas.HOJE, noite)
        assertEquals(SecaoMinhasVagas.PROXIMAS, emUtc)
    }

    @Test
    fun `o ViewModel decide o dia de hoje pelo fuso de Brasilia por padrao`() = runBlocking {
        // 23h de 10/11 em Brasilia, que em UTC já é 11/11.
        val vm = viewModelCom(redeCom(painel(vaga("noite", inicio = "2026-11-11T02:00:00Z", fim = "2026-11-11T05:00:00Z"))))

        vm.carregar().join()

        assertEquals(SecaoMinhasVagas.HOJE, vm.itens().single().secao)
    }

    @Test
    fun `instante ilegivel vai para encerradas`() {
        assertEquals(SecaoMinhasVagas.ENCERRADAS, secaoDe(null, "2026-11-10T21:00:00Z"))
        assertEquals(SecaoMinhasVagas.ENCERRADAS, secaoDe("2026-11-10T18:00:00Z", null))
    }

    @Test
    fun `um instante ilegivel do servidor nao derruba a lista`() = runBlocking {
        val vm = viewModelCom(redeCom(painel(vaga("v1", inicio = "amanha", fim = "2026-11-10T21:00:00Z"))))

        vm.carregar().join()

        assertEquals(SecaoMinhasVagas.ENCERRADAS, vm.itens().single().secao)
        assertNull(vm.itens().single().inicio)
    }

    // ---- Itens ----

    @Test
    fun `as vagas ficam nas secoes certas, na ordem de inicio, com a recem publicada primeiro`() = runBlocking {
        val vm = viewModelCom(
            redeCom(
                painel(
                    vaga("hoje-tarde", inicio = "2026-11-10T22:00:00Z", fim = "2026-11-10T23:30:00Z"),
                    vaga("hoje-cedo", inicio = "2026-11-10T18:00:00Z", fim = "2026-11-10T20:00:00Z"),
                    vaga("hoje-nova", inicio = "2026-11-10T21:00:00Z", fim = "2026-11-10T21:30:00Z"),
                    vaga("amanha", inicio = "2026-11-11T18:00:00Z", fim = "2026-11-11T21:00:00Z"),
                    vaga("velha", inicio = "2026-11-01T18:00:00Z", fim = "2026-11-01T21:00:00Z", estado = "encerrada"),
                    vaga("alerta", inicio = "2026-11-12T18:00:00Z", fim = "2026-11-12T21:00:00Z", alerta = true),
                ),
            ),
            recemPublicada = "hoje-nova",
        )

        vm.carregar().join()

        val lista = vm.estado.value.lista as ListaMinhasVagas.Sucesso
        assertEquals(listOf("alerta"), lista.daSecao(SecaoMinhasVagas.EM_ALERTA).map { it.id })
        assertEquals(listOf("hoje-nova", "hoje-cedo", "hoje-tarde"), lista.daSecao(SecaoMinhasVagas.HOJE).map { it.id })
        assertEquals(listOf("amanha"), lista.daSecao(SecaoMinhasVagas.PROXIMAS).map { it.id })
        assertEquals(listOf("velha"), lista.daSecao(SecaoMinhasVagas.ENCERRADAS).map { it.id })
        assertTrue(lista.itens.single { it.id == "hoje-nova" }.recemPublicada)
        assertFalse(lista.itens.single { it.id == "hoje-cedo" }.recemPublicada)
    }

    @Test
    fun `conta confirmadas, cumpridas, abertas e atrasos por vaga`() = runBlocking {
        val vm = viewModelCom(
            redeCom(
                painel(
                    vaga(
                        "v1", inicio = "2026-11-10T18:00:00Z", fim = "2026-11-10T21:00:00Z",
                        posicoes = listOf("confirmada", "cumprida", "aberta", "aberta", "cancelada"), emAtraso = true,
                    ),
                ),
            ),
        )

        vm.carregar().join()

        val item = vm.itens().single()
        assertEquals(5, item.totalPosicoes)
        assertEquals(2, item.confirmadas)
        assertEquals(2, item.posicoesAbertas)
        assertEquals(5, item.emAtraso)
        assertEquals(16_000L, item.valorCentavos)
        assertEquals("garçom", item.funcao)
        assertEquals(Instant.parse("2026-11-10T18:00:00Z"), item.inicio)
    }

    @ParameterizedTest
    @CsvSource(
        "publicada, urgencia, 2, true",
        "publicada, selecao, 0, true",
        "publicada, selecao, 3, true",
        "publicada, urgencia, 0, false",
        "preenchida, selecao, 0, false",
        "preenchida, urgencia, 1, false",
        "cancelada, selecao, 2, false",
        "encerrada, selecao, 0, false",
    )
    fun `ver candidatos so aparece em vaga publicada com candidatos ou em modo selecao`(
        estado: String,
        modo: String,
        pendentes: Int,
        esperado: Boolean,
    ) = runBlocking {
        val vm = viewModelCom(
            redeCom(painel(vaga("v1", inicio = "2026-11-11T18:00:00Z", fim = "2026-11-11T21:00:00Z", estado = estado, modo = modo, pendentes = pendentes))),
        )

        vm.carregar().join()

        assertEquals(esperado, vm.itens().single().podeVerCandidatos)
    }

    @Test
    fun `quanto falta para comecar so e calculado para quem precisa de atencao`() = runBlocking {
        val vm = viewModelCom(
            redeCom(
                painel(
                    vaga("alerta", inicio = "2026-11-10T17:15:00Z", fim = "2026-11-10T21:00:00Z", alerta = true),
                    vaga("normal", inicio = "2026-11-10T18:00:00Z", fim = "2026-11-10T21:00:00Z"),
                ),
            ),
        )

        vm.carregar().join()

        assertEquals(java.time.Duration.ofMinutes(135), vm.itens().single { it.id == "alerta" }.comecaEm)
        assertNull(vm.itens().single { it.id == "normal" }.comecaEm)
    }

    @Test
    fun `vaga oculta, em modo selecao e com candidatos chega marcada ao item`() = runBlocking {
        val vm = viewModelCom(
            redeCom(
                painel(
                    vaga("v1", inicio = "2026-11-11T18:00:00Z", fim = "2026-11-11T21:00:00Z", oculta = true, modo = "selecao", pendentes = 2),
                ),
            ),
        )

        vm.carregar().join()

        val item = vm.itens().single()
        assertTrue(item.oculta)
        assertTrue(item.selecao)
        assertEquals(2, item.candidatosPendentes)
    }

    @Test
    fun `o nome e o id do estabelecimento ficam disponiveis para a tela`() {
        val vm = viewModelCom(redeCom(painel()))

        assertEquals("est-1", vm.estabelecimentoId)
        assertEquals("Bar da Lia", vm.nomeEstabelecimento)
    }

    @Test
    fun `codigo de erro desconhecido vira generico`() {
        assertEquals(ErroMinhasVagas.GENERICO, erroDe(Rede { recusa(HttpStatusCode.UnprocessableEntity, "codigo_novo") }))
    }

    @Test
    fun `os turnos do item sao so as posicoes confirmadas ou cumpridas com turno`() = runBlocking {
        fun pos(id: String, estado: String, turno: String?, nome: String?) =
            """{"id":"$id","estado":"$estado","turno_id":${turno?.let { "\"$it\"" }},"verificacao":null,"em_atraso":false,"a_caminho_em":null,
               "profissional":${nome?.let { """{"id":"p-$id","tipo":"profissional","nome":"$it","reputacao":{"positivas":0,"total":0,"turnos_considerados":0,"turnos_realizados":0}}""" }}}"""
        val corpo = """
            {"estabelecimento_id":"est-1","checkins_pendentes":[],"vagas":[{
              "vaga":{"id":"v1","funcao":"garçom","local":"SQN 108","regiao_administrativa":"Asa Norte","inicio_em":"2026-11-10T18:00:00Z","fim_em":"2026-11-10T21:00:00Z","valor_centavos":16000},
              "modo":"urgencia","estado":"publicada","oculta":false,"alerta_vaga_vazia":false,"candidatos_pendentes":0,
              "posicoes":[${pos("a", "confirmada", "t1", "Ana")},${pos("b", "cumprida", "t2", null)},${pos("c", "aberta", null, null)},${pos("d", "cancelada", "t4", "Duda")},${pos("e", "confirmada", null, "Eva")}]
            }]}
        """.trimIndent()
        val vm = viewModelCom(redeCom(corpo))

        vm.carregar().join()

        assertEquals(listOf(TurnoDoItem("a", "Ana"), TurnoDoItem("b", null)), vm.itens().single().turnos)
    }
}
