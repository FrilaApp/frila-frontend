package br.com.frila.feature.vagas.candidatos

import br.com.frila.core.rede.CandidatoDto
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.PerfilPublicoDto
import br.com.frila.core.rede.ReputacaoDto
import br.com.frila.core.rede.ResultadoConfirmacaoDto
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

class CandidatosDaVagaViewModelTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val html = headersOf(HttpHeaders.ContentType, "text/html")

    private fun candidato(id: String, nome: String, daEquipe: Boolean = false) = """
        {"candidatura_id":"$id","criada_em":"2026-11-10T12:00:00Z","da_equipe":$daEquipe,
         "profissional":{"id":"p-$id","tipo":"profissional","nome":"$nome","funcoes":["garçom"],
           "reputacao":{"positivas":4,"total":5,"taxa_comparecimento":0.9,"turnos_considerados":5,"turnos_realizados":5}}}
    """.trimIndent()

    private val tres = "[${candidato("c1", "Ana", daEquipe = true)},${candidato("c2", "Beto")},${candidato("c3", "Cris")}]"
    private val confirmadoJson = """{"estado":"confirmada","posicao_id":"pos-1","turno_id":"t1"}"""

    private class Pedido(val caminho: String, val corpo: JsonObject?)

    private class Rede(
        val lista: MockRequestHandleScope.(HttpRequestData) -> HttpResponseData,
        val escolha: MockRequestHandleScope.(HttpRequestData) -> HttpResponseData = { respond("{}", HttpStatusCode.OK) },
    ) {
        val pedidos = mutableListOf<Pedido>()
        val leituras get() = pedidos.count { it.caminho.endsWith("/candidatos_da_vaga") }
        val escolhas get() = pedidos.filter { it.caminho.endsWith("/escolher_candidato") }
    }

    private fun viewModelCom(
        rede: Rede,
        posicoesAbertas: Int? = null,
        inicioDaVaga: Instant? = null,
        agora: Instant = Instant.parse("2026-11-10T15:00:00Z"),
    ): CandidatosDaVagaViewModel {
        val engine = MockEngine { request ->
            val corpo = (request.body as? TextContent)?.text?.let { ClienteSupabase.jsonFrila.parseToJsonElement(it).jsonObject }
            rede.pedidos += Pedido(request.url.encodedPath, corpo)
            if (request.url.encodedPath.endsWith("/escolher_candidato")) rede.escolha(this, request) else rede.lista(this, request)
        }
        val servico = ServicoVagas(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
        return CandidatosDaVagaViewModel(
            vagaId = "vaga-1",
            buscar = servico::candidatosDaVaga,
            escolher = servico::escolherCandidato,
            posicoesAbertas = posicoesAbertas,
            inicioDaVaga = inicioDaVaga,
            relogio = { agora },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
    }

    private fun MockRequestHandleScope.recusa(status: HttpStatusCode, codigo: String, detalhes: String? = null) =
        respond(
            content = """{"code":"$codigo","message":"x","details":${detalhes?.let { "\"$it\"" } ?: "null"}}""",
            status = status,
            headers = json,
        )

    private fun redeComTres(escolha: MockRequestHandleScope.(HttpRequestData) -> HttpResponseData = { respond(confirmadoJson, HttpStatusCode.OK, json) }) =
        Rede(lista = { respond(tres, HttpStatusCode.OK, json) }, escolha = escolha)

    private fun CandidatosDaVagaViewModel.candidata(id: String): CandidatoDto =
        estado.value.candidatos.first { it.candidaturaId == id }

    // ---- Leitura ----

    @Test
    fun `carregar faz POST com vaga_id e mostra os candidatos na ordem em que chegaram`() = runBlocking {
        val rede = redeComTres()
        val vm = viewModelCom(rede)

        vm.carregar().join()

        val pedido = rede.pedidos.single()
        assertEquals("/rest/v1/rpc/candidatos_da_vaga", pedido.caminho)
        assertEquals("vaga-1", pedido.corpo!!["vaga_id"]!!.jsonPrimitive.content)
        assertEquals(listOf("c1", "c2", "c3"), vm.estado.value.candidatos.map { it.candidaturaId })
        assertTrue(vm.estado.value.candidatos[0].daEquipe)
        assertFalse(vm.estado.value.candidatos[1].daEquipe)
        assertFalse(vm.estado.value.atualizando)
    }

    @Test
    fun `lista vazia vira o estado Vazio`() = runBlocking {
        val vm = viewModelCom(Rede(lista = { respond("[]", HttpStatusCode.OK, json) }))

        vm.carregar().join()

        assertEquals(EstadoDosCandidatos.Vazio, vm.estado.value.lista)
    }

    @Test
    fun `sem rede na primeira leitura vira SemConexao`() = runBlocking {
        val vm = viewModelCom(Rede(lista = { throw ConnectTimeoutException("sem rede") }))

        vm.carregar().join()

        assertEquals(EstadoDosCandidatos.SemConexao, vm.estado.value.lista)
    }

    @Test
    fun `erro 500 em JSON na primeira leitura vira Falha`() = runBlocking {
        val vm = viewModelCom(Rede(lista = { recusa(HttpStatusCode.InternalServerError, "erro_interno") }))

        vm.carregar().join()

        assertEquals(EstadoDosCandidatos.Falha, vm.estado.value.lista)
    }

    @Test
    fun `200 com HTML e 502 com HTML na leitura viram Falha, nunca spinner eterno`() = runBlocking {
        val ok = viewModelCom(Rede(lista = { respond("<html>ok</html>", HttpStatusCode.OK, html) }))
        val gateway = viewModelCom(Rede(lista = { respond("<html>502</html>", HttpStatusCode.BadGateway, html) }))

        ok.carregar().join()
        gateway.carregar().join()

        assertEquals(EstadoDosCandidatos.Falha, ok.estado.value.lista)
        assertEquals(EstadoDosCandidatos.Falha, gateway.estado.value.lista)
    }

    @Test
    fun `tentar novamente depois da falha carrega a lista`() = runBlocking {
        var tentativa = 0
        val vm = viewModelCom(Rede(lista = { if (++tentativa == 1) recusa(HttpStatusCode.InternalServerError, "x") else respond(tres, HttpStatusCode.OK, json) }))

        vm.carregar().join()
        assertEquals(EstadoDosCandidatos.Falha, vm.estado.value.lista)
        vm.carregar().join()

        assertEquals(3, vm.estado.value.candidatos.size)
    }

    @Test
    fun `falha ao atualizar com candidatos na tela mantem a lista e avisa que pode estar velha`() = runBlocking {
        var tentativa = 0
        val vm = viewModelCom(Rede(lista = { if (++tentativa == 1) respond(tres, HttpStatusCode.OK, json) else respond("<html>x</html>", HttpStatusCode.OK, html) }))
        vm.carregar().join()

        vm.atualizar().join()

        assertEquals(3, vm.estado.value.candidatos.size)
        assertTrue(vm.estado.value.desatualizada)
        assertFalse(vm.estado.value.atualizando)
    }

    @Test
    fun `atualizar com sucesso limpa o aviso de lista velha e traz a lista nova`() = runBlocking {
        var tentativa = 0
        val vm = viewModelCom(
            Rede(
                lista = {
                    when (++tentativa) {
                        1 -> respond(tres, HttpStatusCode.OK, json)
                        2 -> throw ConnectTimeoutException("sem rede")
                        else -> respond("[${candidato("c9", "Duda")}]", HttpStatusCode.OK, json)
                    }
                },
            ),
        )
        vm.carregar().join()
        vm.atualizar().join()
        assertTrue(vm.estado.value.desatualizada)

        vm.atualizar().join()

        assertFalse(vm.estado.value.desatualizada)
        assertEquals(listOf("c9"), vm.estado.value.candidatos.map { it.candidaturaId })
    }

    @Test
    fun `prazo de escolha e 24 horas antes do inicio e o aviso de prazo passado depende do relogio`() = runBlocking {
        val inicio = Instant.parse("2026-11-12T18:00:00Z")
        val antes = viewModelCom(redeComTres(), inicioDaVaga = inicio, agora = Instant.parse("2026-11-11T17:59:00Z"))
        val depois = viewModelCom(redeComTres(), inicioDaVaga = inicio, agora = Instant.parse("2026-11-11T18:00:00Z"))
        val semInicio = viewModelCom(redeComTres())

        assertEquals(Instant.parse("2026-11-11T18:00:00Z"), antes.estado.value.prazoDeEscolha)
        assertFalse(antes.estado.value.prazoPassou)
        assertTrue(depois.estado.value.prazoPassou)
        assertNull(semInicio.estado.value.prazoDeEscolha)
        assertFalse(semInicio.estado.value.prazoPassou)
    }

    // ---- Escolha ----

    @Test
    fun `so se pede a escolha de quem esta na lista`() = runBlocking {
        val vm = viewModelCom(redeComTres())
        vm.carregar().join()
        val fantasma = vm.candidata("c1").copy(candidaturaId = "fantasma")

        vm.pedirEscolha(fantasma)
        assertNull(vm.estado.value.emConfirmacao)
        vm.pedirEscolha(vm.candidata("c2"))

        assertEquals("c2", vm.estado.value.emConfirmacao?.candidaturaId)
    }

    @Test
    fun `desistir limpa o pedido e confirmar sem pedido nao manda nada`() = runBlocking {
        val rede = redeComTres()
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.pedirEscolha(vm.candidata("c2"))
        vm.desistirDaEscolha()
        vm.confirmarEscolha().join()

        assertNull(vm.estado.value.emConfirmacao)
        assertTrue(rede.escolhas.isEmpty())
    }

    @Test
    fun `escolha confirmada manda candidatura_id, tira o escolhido da lista e rele o resto`() = runBlocking {
        val rede = redeComTres()
        val vm = viewModelCom(rede, posicoesAbertas = 2)
        vm.carregar().join()

        vm.pedirEscolha(vm.candidata("c2"))
        vm.confirmarEscolha().join()

        val escolha = rede.escolhas.single()
        assertEquals("/rest/v1/rpc/escolher_candidato", escolha.caminho)
        assertEquals(setOf("candidatura_id"), escolha.corpo!!.keys)
        assertEquals("c2", escolha.corpo!!["candidatura_id"]!!.jsonPrimitive.content)
        assertEquals(ResultadoDaEscolha("Beto", vagaPreenchida = false), vm.estado.value.resultado)
        assertEquals(1, vm.estado.value.posicoesAbertas)
        assertNull(vm.estado.value.escolhendo)
        assertNull(vm.estado.value.emConfirmacao)
        assertNull(vm.estado.value.falha)
        assertEquals(2, rede.leituras)
    }

    @Test
    fun `a ultima posicao e avisada antes e depois da escolha a vaga enche sem reler a lista`() = runBlocking {
        val rede = redeComTres()
        val vm = viewModelCom(rede, posicoesAbertas = 1)
        vm.carregar().join()
        assertTrue(vm.estado.value.ultimaPosicao)

        vm.pedirEscolha(vm.candidata("c1"))
        vm.confirmarEscolha().join()

        assertEquals(ResultadoDaEscolha("Ana", vagaPreenchida = true), vm.estado.value.resultado)
        assertEquals(EstadoDosCandidatos.Vazio, vm.estado.value.lista)
        assertEquals(0, vm.estado.value.posicoesAbertas)
        assertEquals(1, rede.leituras)
    }

    @Test
    fun `sem saber as posicoes nao ha aviso de ultima posicao`() = runBlocking {
        val vm = viewModelCom(redeComTres())

        assertFalse(vm.estado.value.ultimaPosicao)
        assertFalse(viewModelCom(redeComTres(), posicoesAbertas = 2).estado.value.ultimaPosicao)
    }

    @Test
    fun `segundo toque com a escolha em voo nao manda outra`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        val rede = redeComTres(escolha = { runBlocking { liberar.await() }; respond(confirmadoJson, HttpStatusCode.OK, json) })
        val vm = viewModelCom(rede)
        vm.carregar().join()
        vm.pedirEscolha(vm.candidata("c1"))

        val primeira = vm.confirmarEscolha()
        assertEquals("c1", vm.estado.value.escolhendo)
        vm.pedirEscolha(vm.candidata("c2"))
        assertNull(vm.estado.value.emConfirmacao)
        vm.confirmarEscolha()
        liberar.complete(Unit)
        withTimeout(5_000) { primeira.join() }

        assertEquals(1, rede.escolhas.size)
        assertNull(vm.estado.value.escolhendo)
    }

    @Test
    fun `leitura que saiu antes da escolha e descartada e nao traz de volta o confirmado`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        var leitura = 0
        val vm = CandidatosDaVagaViewModel(
            vagaId = "vaga-1",
            buscar = {
                val numero = ++leitura
                val ana = candidatoDto("c1", "Ana")
                val beto = candidatoDto("c2", "Beto")
                when (numero) {
                    1 -> listOf(ana, beto)
                    2 -> { liberar.await(); listOf(ana, beto) } // leitura lenta, que saiu antes da escolha
                    else -> listOf(beto)
                }
            },
            escolher = { ResultadoConfirmacaoDto("confirmada", "pos-1", "t1") },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        vm.carregar().join()
        val lenta = vm.atualizar()
        vm.pedirEscolha(vm.estado.value.candidatos.first { it.candidaturaId == "c1" })
        vm.confirmarEscolha().join()
        assertEquals(listOf("c2"), vm.estado.value.candidatos.map { it.candidaturaId })

        liberar.complete(Unit)
        withTimeout(5_000) { lenta.join() }

        assertEquals(listOf("c2"), vm.estado.value.candidatos.map { it.candidaturaId })
        assertEquals(4, leitura)
    }

    private fun candidatoDto(id: String, nome: String) = CandidatoDto(
        candidaturaId = id,
        profissional = PerfilPublicoDto(
            id = "p-$id", tipo = "profissional", nome = nome,
            reputacao = ReputacaoDto(positivas = 1, total = 1, turnosConsiderados = 1, turnosRealizados = 1),
        ),
        criadaEm = "2026-11-10T12:00:00Z",
    )

    // ---- Recusas ----

    private fun escolhaRecusada(
        status: HttpStatusCode,
        codigo: String,
        detalhes: String? = null,
    ): Pair<CandidatosDaVagaViewModel, Rede> {
        val rede = redeComTres(escolha = { recusa(status, codigo, detalhes) })
        val vm = viewModelCom(rede)
        runBlocking {
            vm.carregar().join()
            vm.pedirEscolha(vm.candidata("c1"))
            vm.confirmarEscolha().join()
        }
        return vm to rede
    }

    @Test
    fun `409 posicao_ja_preenchida avisa e rele a lista`() {
        val (vm, rede) = escolhaRecusada(HttpStatusCode.Conflict, "posicao_ja_preenchida")

        assertEquals(FalhaDaEscolha.PosicaoJaPreenchida, vm.estado.value.falha)
        assertEquals(2, rede.leituras)
        assertNull(vm.estado.value.escolhendo)
        assertNull(vm.estado.value.resultado)
    }

    @Test
    fun `409 candidatura_indisponivel cita o candidato e rele a lista`() {
        val (vm, rede) = escolhaRecusada(HttpStatusCode.Conflict, "candidatura_indisponivel")

        assertEquals(FalhaDaEscolha.CandidaturaIndisponivel("Ana"), vm.estado.value.falha)
        assertEquals(2, rede.leituras)
    }

    @Test
    fun `409 vaga_encerrada e a selecao encerrada e rele a lista`() {
        val (vm, rede) = escolhaRecusada(HttpStatusCode.Conflict, "vaga_encerrada")

        assertEquals(FalhaDaEscolha.SelecaoEncerrada, vm.estado.value.falha)
        assertEquals(2, rede.leituras)
    }

    @Test
    fun `422 inelegivel com turno_sobreposto cita o candidato e deixa a lista como esta`() {
        val (vm, rede) = escolhaRecusada(HttpStatusCode.UnprocessableEntity, "inelegivel", "turno_sobreposto")

        assertEquals(FalhaDaEscolha.TurnoSobreposto("Ana"), vm.estado.value.falha)
        assertEquals(3, vm.estado.value.candidatos.size)
        assertEquals(1, rede.leituras)
    }

    @Test
    fun `422 inelegivel com outro motivo e inelegivel`() {
        val (vm, _) = escolhaRecusada(HttpStatusCode.UnprocessableEntity, "inelegivel", "perfil_suspenso")

        assertEquals(FalhaDaEscolha.Inelegivel("Ana"), vm.estado.value.falha)
    }

    @Test
    fun `422 vaga_oculta avisa e rele a lista`() {
        val (vm, rede) = escolhaRecusada(HttpStatusCode.UnprocessableEntity, "vaga_oculta")

        assertEquals(FalhaDaEscolha.VagaOculta, vm.estado.value.falha)
        assertEquals(2, rede.leituras)
    }

    @Test
    fun `403 sem_permissao e 403 com conta_suspensa tem mensagem propria`() {
        assertEquals(FalhaDaEscolha.SemPermissao, escolhaRecusada(HttpStatusCode.Forbidden, "sem_permissao").first.estado.value.falha)
        assertEquals(
            FalhaDaEscolha.ContaSuspensa,
            escolhaRecusada(HttpStatusCode.Forbidden, "sem_permissao", "conta_suspensa").first.estado.value.falha,
        )
    }

    @Test
    fun `422 perfil_incompativel e 401 tem mensagem propria`() {
        assertEquals(FalhaDaEscolha.PerfilIncompativel, escolhaRecusada(HttpStatusCode.UnprocessableEntity, "perfil_incompativel").first.estado.value.falha)
        assertEquals(FalhaDaEscolha.SessaoExpirada, escolhaRecusada(HttpStatusCode.Unauthorized, "nao_autenticado").first.estado.value.falha)
    }

    @Test
    fun `sem rede na escolha avisa, nao rele e a escolha nao entra em fila`() = runBlocking {
        val rede = redeComTres(escolha = { throw ConnectTimeoutException("sem rede") })
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.pedirEscolha(vm.candidata("c1"))
        vm.confirmarEscolha().join()

        assertEquals(FalhaDaEscolha.SemRede, vm.estado.value.falha)
        assertEquals(1, rede.leituras)
        assertEquals(3, vm.estado.value.candidatos.size)
        assertNull(vm.estado.value.escolhendo)
    }

    // ---- Resposta que não é o JSON esperado (Yugao R1) ----

    private fun escolhaIncerta(
        escolha: MockRequestHandleScope.(HttpRequestData) -> HttpResponseData,
        listaDepois: String,
    ): Pair<CandidatosDaVagaViewModel, Rede> {
        var leitura = 0
        val rede = Rede(
            lista = { if (++leitura == 1) respond(tres, HttpStatusCode.OK, json) else respond(listaDepois, HttpStatusCode.OK, json) },
            escolha = escolha,
        )
        val vm = viewModelCom(rede)
        runBlocking {
            vm.carregar().join()
            vm.pedirEscolha(vm.candidata("c1"))
            vm.confirmarEscolha().join()
        }
        return vm to rede
    }

    @Test
    fun `200 com HTML na escolha, com o candidato ainda na lista, e falha generica e libera o botao`() {
        val (vm, rede) = escolhaIncerta({ respond("<html>ok</html>", HttpStatusCode.OK, html) }, listaDepois = tres)

        assertEquals(FalhaDaEscolha.Generica, vm.estado.value.falha)
        assertNull(vm.estado.value.escolhendo)
        assertNull(vm.estado.value.resultado)
        assertEquals(2, rede.leituras)
    }

    @Test
    fun `502 com HTML na escolha, com o candidato fora da lista, diz que o resultado e incerto`() {
        val (vm, _) = escolhaIncerta(
            { respond("<html>502 Bad Gateway</html>", HttpStatusCode.BadGateway, html) },
            listaDepois = "[${candidato("c2", "Beto")}]",
        )

        assertEquals(FalhaDaEscolha.ResultadoIncerto("Ana"), vm.estado.value.falha)
        assertNull(vm.estado.value.resultado)
        assertNull(vm.estado.value.escolhendo)
    }

    @Test
    fun `200 sem o campo obrigatorio turno_id e tratado como resposta que nao diz se valeu`() {
        val (vm, _) = escolhaIncerta(
            { respond("""{"estado":"confirmada","posicao_id":"pos-1"}""", HttpStatusCode.OK, json) },
            listaDepois = "[${candidato("c2", "Beto")}]",
        )

        assertEquals(FalhaDaEscolha.ResultadoIncerto("Ana"), vm.estado.value.falha)
    }

    @Test
    fun `erro 500 em JSON na escolha tambem confere a lista antes de dizer o que houve`() {
        val (vm, rede) = escolhaIncerta({ recusa(HttpStatusCode.InternalServerError, "erro_interno") }, listaDepois = tres)

        assertEquals(FalhaDaEscolha.Generica, vm.estado.value.falha)
        assertEquals(2, rede.leituras)
    }

    @Test
    fun `resultado incerto nao e afirmado quando a releitura tambem falha`() {
        var leitura = 0
        val rede = Rede(
            lista = { if (++leitura == 1) respond(tres, HttpStatusCode.OK, json) else throw ConnectTimeoutException("sem rede") },
            escolha = { respond("<html>x</html>", HttpStatusCode.OK, html) },
        )
        val vm = viewModelCom(rede)
        runBlocking {
            vm.carregar().join()
            vm.pedirEscolha(vm.candidata("c1"))
            vm.confirmarEscolha().join()
        }

        assertEquals(FalhaDaEscolha.Generica, vm.estado.value.falha)
        assertTrue(vm.estado.value.desatualizada)
    }
}
