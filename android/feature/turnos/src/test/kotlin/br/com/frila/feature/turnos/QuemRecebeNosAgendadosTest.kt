package br.com.frila.feature.turnos

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import br.com.frila.core.rede.ServicoVagas
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.network.sockets.ConnectTimeoutException
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import java.util.Collections
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Cartão QpgRwPFM (fatia "Quem recebe"): `meus_turnos` não traz `responsavel_local` (`VagaResumo` não o tem), só o `detalhe_vaga`. Decisão A
 * do Hokage: leitura extra SÓ para os agendados, em paralelo, com cache em memória por vaga na sessão, falha silenciosa e sem mexer no contrato.
 */
class QuemRecebeNosAgendadosTest {

    private val json = headersOf(HttpHeaders.ContentType, "application/json")

    private fun turno(id: String, estado: String, vagaId: String) = """
        {"id":"$id","posicao_id":"posicao-$id",
         "vaga":{"id":"$vagaId","funcao":"garçom","local":"CLS 405 Bloco C","regiao_administrativa":"Plano Piloto",
                 "inicio_em":"2026-11-01T21:00:00Z","fim_em":"2026-11-02T03:00:00Z","valor_centavos":16000},
         "contraparte":{"id":"e1","tipo":"estabelecimento","nome":"Bar do Zé",
                        "reputacao":{"positivas":1,"total":1,"turnos_considerados":1,"turnos_realizados":1}},
         "contato_visivel_ate":"2026-11-09T03:00:00Z","a_caminho_em":null,"checkin_em":null,"checkin_tipo":null,
         "checkin_distancia_m":null,"checkin_confirmado_em":null,"checkout_em":null,"checkout_distancia_m":null,
         "verificacao":"pendente","valor_acordado_centavos":16000,"pode_avaliar":false,"estado":"$estado",
         "avaliacao":null,"cancelamento":null}
    """.trimIndent()

    private fun detalhe(vagaId: String, responsavel: String) = """
        {"id":"$vagaId","estabelecimento":{"id":"e1","tipo":"estabelecimento","nome":"Bar do Zé",
          "reputacao":{"positivas":1,"total":1,"turnos_considerados":1,"turnos_realizados":1}},
         "funcao":{"id":"f1","nome":"garçom","categoria":"Salão"},"inicio_em":"2026-11-01T21:00:00Z","fim_em":"2026-11-02T03:00:00Z",
         "local":"CLS 405 Bloco C","regiao_administrativa":"Plano Piloto","ponto":{"latitude":-15.79,"longitude":-47.88},
         "valor_centavos":16000,"posicoes":1,"posicoes_abertas":0,
         "inclusos":{"inclui_refeicao":false,"inclui_transporte":false,"exige_material_proprio":false},
         "responsavel_local":"$responsavel","modo":"urgencia","estado":"publicada","oculta":false,"publicado_em":"2026-10-30T12:00:00Z"}
    """.trimIndent()

    /** Como o servidor responde ao `detalhe_vaga` de uma vaga. */
    private sealed interface Resposta {
        data class Responsavel(val nome: String) : Resposta
        data class Erro(val status: HttpStatusCode, val corpo: String) : Resposta
        data object SemRede : Resposta
    }

    private class Cenario(
        val turnos: String,
        val respostas: MutableMap<String, Resposta>,
        val portao: CompletableDeferred<Unit>? = null,
    ) {
        val leituras = Collections.synchronizedList(mutableListOf<String>())
        val listagens = java.util.concurrent.atomic.AtomicInteger(0)
    }

    private fun viewModel(c: Cenario, comCache: Boolean = true): Pair<MeusTurnosViewModel, QuemRecebeDasVagas?> {
        val engine = MockEngine { request ->
            val caminho = request.url.encodedPath
            when {
                caminho.endsWith("/meus_turnos") -> {
                    c.listagens.incrementAndGet()
                    respond(c.turnos, HttpStatusCode.OK, json)
                }
                caminho.endsWith("/detalhe_vaga") -> {
                    val vagaId = Json.parseToJsonElement((request.body as TextContent).text).jsonObject["vaga_id"]!!.jsonPrimitive.content
                    c.leituras += vagaId
                    c.portao?.await()
                    when (val r = c.respostas[vagaId] ?: Resposta.Erro(HttpStatusCode.NotFound, """{"code":"nao_encontrado","message":"x"}""")) {
                        is Resposta.Responsavel -> respond(detalhe(vagaId, r.nome), HttpStatusCode.OK, json)
                        is Resposta.Erro -> respond(r.corpo, r.status, json)
                        Resposta.SemRede -> throw ConnectTimeoutException("sem rede")
                    }
                }
                else -> respond("{}", HttpStatusCode.NotFound, json)
            }
        }
        val cliente = ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine)
        val vagas = ServicoVagas(cliente)
        val cache = if (comCache) QuemRecebeDasVagas { id -> vagas.detalheVaga(id).responsavelLocal } else null
        val vm = MeusTurnosViewModel(ServicoTurnos(cliente), escopo = CoroutineScope(Dispatchers.Default), quemRecebeDasVagas = cache)
        return vm to cache
    }

    /** O cenário típico: 3 turnos agendados e 4 no histórico (2 cumpridos, 2 cancelados). */
    private fun cenarioTipico(portao: CompletableDeferred<Unit>? = null) = Cenario(
        turnos = "[" + listOf(
            turno("t1", "confirmada", "v1"), turno("t2", "confirmada", "v2"), turno("t3", "confirmada", "v3"),
            turno("h1", "cumprida", "vh1"), turno("h2", "cumprida", "vh2"), turno("h3", "cancelada", "vh3"), turno("h4", "cancelada", "vh4"),
        ).joinToString(",") + "]",
        respostas = mutableMapOf(
            "v1" to Resposta.Responsavel("Carlos Silva"), "v2" to Resposta.Responsavel("Ana Lima"), "v3" to Resposta.Responsavel("Rui Costa"),
            "vh1" to Resposta.Responsavel("NAO-DEVIA-LER"), "vh2" to Resposta.Responsavel("NAO-DEVIA-LER"),
            "vh3" to Resposta.Responsavel("NAO-DEVIA-LER"), "vh4" to Resposta.Responsavel("NAO-DEVIA-LER"),
        ),
        portao = portao,
    )

    private fun MeusTurnosViewModel.quemRecebeDosAgendados() = estado.value.agendados.associate { it.vagaId to it.quemRecebe }

    @Test
    fun `carregar le o detalhe so das vagas agendadas, uma vez cada, e nada do historico`() = runBlocking {
        val c = cenarioTipico()
        val (vm, _) = viewModel(c)

        vm.carregar().join()

        assertEquals(setOf("v1", "v2", "v3"), c.leituras.toSet())
        assertEquals(3, c.leituras.size, "uma leitura por vaga agendada: ${c.leituras}")
        assertEquals(mapOf("v1" to "Carlos Silva", "v2" to "Ana Lima", "v3" to "Rui Costa"), vm.quemRecebeDosAgendados())
        assertTrue(vm.estado.value.historicoCompleto.all { it.quemRecebe == null }, "o historico nao tem o dado")
        assertEquals(4, vm.estado.value.historicoCompleto.size)
    }

    @Test
    fun `a atualizacao automatica e o puxar para atualizar nao leem de novo, e o responsavel nao some da lista`() = runBlocking {
        val c = cenarioTipico()
        val (vm, _) = viewModel(c)
        vm.carregar().join()
        assertEquals(3, c.leituras.size)

        repeat(3) { vm.atualizarSemPiscar().join() }
        vm.atualizar().join()
        vm.carregar().join()

        assertEquals(6, c.listagens.get(), "a lista foi lida 6 vezes (carregar, 3 automaticas, puxar para atualizar, carregar)")
        assertEquals(3, c.leituras.size, "mas o detalhe das vagas continuou lido só 3 vezes: ${c.leituras}")
        assertEquals(mapOf("v1" to "Carlos Silva", "v2" to "Ana Lima", "v3" to "Rui Costa"), vm.quemRecebeDosAgendados())
    }

    @Test
    fun `a lista aparece antes de o detalhe chegar, e o responsavel entra depois`() = runBlocking {
        val portao = CompletableDeferred<Unit>()
        val c = cenarioTipico(portao)
        val (vm, _) = viewModel(c)

        val job = vm.carregar()
        withTimeout(5_000) { while (vm.estado.value.status != StatusMeusTurnos.SUCESSO) kotlinx.coroutines.delay(10) }

        assertEquals(3, vm.estado.value.agendados.size, "a lista ja esta na tela")
        assertTrue(vm.estado.value.agendados.all { it.quemRecebe == null }, "com o detalhe ainda em voo")
        portao.complete(Unit)
        job.join()
        assertEquals("Carlos Silva", vm.estado.value.agendados.first { it.vagaId == "v1" }.quemRecebe)
    }

    @Test
    fun `404 da vaga direta e falha silenciosa, sem erro na tela, sem responsavel, e sem ler de novo`() = runBlocking {
        val c = cenarioTipico()
        c.respostas["v2"] = Resposta.Erro(HttpStatusCode.NotFound, """{"code":"nao_encontrado","message":"x"}""")
        val (vm, _) = viewModel(c)

        vm.carregar().join()
        vm.atualizarSemPiscar().join()
        vm.atualizar().join()

        assertEquals(StatusMeusTurnos.SUCESSO, vm.estado.value.status)
        assertNull(vm.estado.value.mensagemErro)
        assertNull(vm.estado.value.agendados.first { it.vagaId == "v2" }.quemRecebe)
        assertEquals("Carlos Silva", vm.estado.value.agendados.first { it.vagaId == "v1" }.quemRecebe)
        assertEquals(1, c.leituras.count { it == "v2" }, "o 404 e definitivo: guardado, nao repete a cada releitura: ${c.leituras}")
    }

    @Test
    fun `falha de rede e silenciosa e NAO fica guardada, a proxima releitura tenta de novo`() = runBlocking {
        val c = cenarioTipico()
        c.respostas["v1"] = Resposta.SemRede
        val (vm, _) = viewModel(c)

        vm.carregar().join()

        assertEquals(StatusMeusTurnos.SUCESSO, vm.estado.value.status)
        assertNull(vm.estado.value.agendados.first { it.vagaId == "v1" }.quemRecebe)

        c.respostas["v1"] = Resposta.Responsavel("Carlos Silva") // a rede voltou
        vm.atualizarSemPiscar().join()

        assertEquals("Carlos Silva", vm.estado.value.agendados.first { it.vagaId == "v1" }.quemRecebe)
        assertEquals(2, c.leituras.count { it == "v1" })
        assertEquals(1, c.leituras.count { it == "v2" }, "as outras ja estavam guardadas")
    }

    @Test
    fun `responsavel em branco conta como sem responsavel (o cartao usa o nome da casa)`() = runBlocking {
        val c = cenarioTipico()
        c.respostas["v3"] = Resposta.Responsavel("   ")
        val (vm, _) = viewModel(c)

        vm.carregar().join()

        assertNull(vm.estado.value.agendados.first { it.vagaId == "v3" }.quemRecebe)
        vm.atualizarSemPiscar().join()
        assertEquals(1, c.leituras.count { it == "v3" })
    }

    @Test
    fun `duas releituras ao mesmo tempo leem cada vaga uma vez so`() = runBlocking {
        val portao = CompletableDeferred<Unit>()
        val c = cenarioTipico(portao)
        val (vm, _) = viewModel(c)

        val a = vm.carregar()
        withTimeout(5_000) { while (vm.estado.value.status != StatusMeusTurnos.SUCESSO) kotlinx.coroutines.delay(10) }
        val b = vm.atualizarSemPiscar() // chega com o detalhe da primeira ainda em voo
        withTimeout(5_000) { while (c.listagens.get() < 2) kotlinx.coroutines.delay(10) }
        kotlinx.coroutines.delay(100)
        portao.complete(Unit)
        a.join()
        b.join()

        assertEquals(3, c.leituras.size, "uma leitura por vaga, mesmo com duas releituras em voo: ${c.leituras}")
    }

    @Test
    fun `limpar o cache (logout ou troca de conta) faz a proxima carga ler de novo`() = runBlocking {
        val c = cenarioTipico()
        val (vm, cache) = viewModel(c)
        vm.carregar().join()
        assertEquals(3, c.leituras.size)

        cache!!.limpar()
        vm.atualizarSemPiscar().join()

        assertEquals(6, c.leituras.size, "depois de limpar, as 3 vagas sao lidas de novo: ${c.leituras}")
    }

    @Test
    fun `sem o cache injetado nada e lido e a lista segue como sempre`() = runBlocking {
        val c = cenarioTipico()
        val (vm, _) = viewModel(c, comCache = false)

        vm.carregar().join()

        assertEquals(0, c.leituras.size)
        assertEquals(3, vm.estado.value.agendados.size)
        assertTrue(vm.estado.value.agendados.all { it.quemRecebe == null })
    }

    @Test
    fun `uma leitura em voo quando a sessao termina nao guarda o dado da conta que saiu`() = runBlocking {
        val portao = CompletableDeferred<Unit>()
        val cache = QuemRecebeDasVagas { portao.await(); "Carlos Silva" }
        val leitura = async(Dispatchers.Default) { cache.de("v1") }
        kotlinx.coroutines.delay(100) // a leitura já está em voo

        cache.limpar() // logout, troca de conta ou sessão expirada
        portao.complete(Unit)
        leitura.await()

        assertNull(cache.noCache("v1"), "o resultado de antes do logout não pode ficar guardado para a próxima conta")
    }

    @Test
    fun `a releitura nao faz o responsavel piscar, nenhuma emissao do estado volta a ter o agendado sem ele`() = runBlocking {
        val c = cenarioTipico()
        val (vm, _) = viewModel(c)
        vm.carregar().join()
        val vistos = Collections.synchronizedList(mutableListOf<List<String?>>())
        val coleta = launch(Dispatchers.Unconfined) { vm.estado.collect { vistos += it.agendados.map { item -> item.quemRecebe } } }

        repeat(3) { vm.atualizarSemPiscar().join() }
        vm.atualizar().join()
        coleta.cancel()

        assertTrue(vistos.isNotEmpty())
        assertTrue(vistos.all { linha -> linha.all { it != null } }, "o responsavel ja conhecido nao some entre uma leitura e outra: $vistos")
    }
}
