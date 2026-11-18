package br.com.frila.feature.chamadas.casa

import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.time.Instant
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Decisão do O2, paridade com o #905 do iOS: a busca guarda UM trabalho por serviço e horário buscados. O 1º envio de cada par abre a folha e cria a
 * vaga; depois, todo reenvio desse par repete o trabalho guardado, sem folha nova e sem 2ª vaga. Outro serviço ou outro horário é outro trabalho.
 * Chamar espera a página seguinte em voo (MENOR 4).
 */
class BuscaUmTrabalhoPorServicoEHorarioTest {

    private val casa = "11111111-1111-1111-1111-111111111111"
    private val garcom = "33333333-3333-3333-3333-333333333333"
    private val bartender = "44444444-4444-4444-4444-444444444444"
    private val sexta = HorarioDaBusca(Instant.parse("2026-11-20T22:00:00Z"), Instant.parse("2026-11-21T02:00:00Z"))
    private val sabado = HorarioDaBusca(Instant.parse("2026-11-21T22:00:00Z"), Instant.parse("2026-11-22T02:00:00Z"))
    private val json = headersOf(HttpHeaders.ContentType, "application/json")

    private fun cartao(id: String) =
        """{"id":"$id","nome":"Pessoa $id","servico":{"funcao":{"id":"$garcom","nome":"Garçom","categoria":"salao"},"unidade":"diaria","valor_centavos":15000,"horas_incluidas":8},"regioes":[],"atende_todo_df":true,"distancia_faixa":"ate_5_km","reputacao":{"positivas":3,"total":4,"turnos_considerados":4,"turnos_realizados":4}}"""

    private fun pagina(ids: List<String>, proximo: String? = null) =
        """{"itens":[${ids.joinToString(",") { cartao(it) }}],"proximo_cursor":${proximo?.let { "\"$it\"" } ?: "null"}}"""

    private fun trabalho(horario: HorarioDaBusca, valor: Long = 18000, funcao: String = garcom) = TrabalhoDaChamada(
        funcaoId = funcao,
        inicio = horario.inicio,
        fim = horario.fim,
        local = "SCS Quadra 2",
        regiaoAdministrativa = "Plano Piloto",
        ponto = br.com.frila.core.rede.CoordenadaDto(-15.79, -47.88),
        valorCentavos = valor,
        responsavelLocal = "Bistrô Ipê",
    )

    /** O servidor falso: pedido com o trabalho completo cria a vaga "vaga-N"; pedido com `vaga_id` entra nela. */
    private fun rede(): RedeDeTeste = RedeDeTeste().apply {
        ok("buscar_profissionais", pagina(listOf("p1", "p2", "p3", "p4")))
        var vagas = 0
        val porHorario = mutableMapOf<String, String>()
        rota("chamar_profissional") { pedido ->
            val vaga = pedido.corpo["vaga_id"]?.jsonPrimitive?.content
                ?: porHorario.getOrPut(pedido.corpo["inicio_em"]!!.jsonPrimitive.content) { "vaga-${++vagas}" }
            respond(
                """{"id":"c-${pedido.corpo["profissional_id"]!!.jsonPrimitive.content}","vaga_id":"$vaga","profissional_id":"${pedido.corpo["profissional_id"]!!.jsonPrimitive.content}","estabelecimento_id":"$casa","estado":"aberta","expira_em":"2026-11-17T12:00:00Z","criada_em":"2026-11-16T15:00:00Z"}""",
                HttpStatusCode.OK,
                json,
            )
        }
    }

    private fun viewModelCom(rede: RedeDeTeste): BuscaDeProfissionaisViewModel {
        var contador = 0
        return BuscaDeProfissionaisViewModel(
            estabelecimentoId = casa,
            recursoHabilitado = { true },
            buscarProfissionais = rede.chamadas::buscarProfissionais,
            chamarProfissional = rede.chamadas::chamarProfissional,
            aceitarTermos = rede.chamadas::aceitarTermos,
            minhasChamadas = { estado, cursor -> rede.chamadas.minhasChamadas(estado = estado, cursor = cursor) },
            detalheChamada = rede.chamadas::detalheChamada,
            novaChave = { "chave-${++contador}" },
            prazoMs = 5_000,
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
    }

    private suspend fun BuscaDeProfissionaisViewModel.buscarPara(funcao: String, horario: HorarioDaBusca?) {
        definirFuncao(funcao)
        definirHorario(horario)
        buscar().join()
    }

    private fun RedeDeTeste.chamadas() = doNome("chamar_profissional")

    @Test
    fun `a 2a chamada da mesma busca leva o trabalho guardado, nunca um trabalho novo`() = runBlocking {
        val rede = rede()
        val vm = viewModelCom(rede)
        vm.buscarPara(garcom, sexta)
        vm.alternarSelecao("p1")
        vm.chamar(trabalho(sexta, valor = 18000)).join()
        vm.alternarSelecao("p2")
        // A folha entregou um trabalho diferente (outro valor): para a mesma busca vale o guardado.
        vm.chamar(trabalho(sexta, valor = 99900)).join()

        val segunda = rede.chamadas()[1].corpo
        assertEquals("vaga-1", segunda["vaga_id"]!!.jsonPrimitive.content)
        assertFalse("valor_centavos" in segunda, "a 2ª pessoa entra na vaga guardada, sem trabalho completo")
        assertEquals(setOf("vaga-1"), rede.chamadas().map { it.corpo["vaga_id"]?.jsonPrimitive?.content ?: "vaga-1" }.toSet())
    }

    @Test
    fun `o estado mostra o trabalho enviado da busca feita, e outro horario comeca sem envio`() = runBlocking {
        val rede = rede()
        val vm = viewModelCom(rede)
        vm.buscarPara(garcom, sexta)
        assertNull(vm.estado.value.trabalhoEnviadoDaBusca)
        vm.alternarSelecao("p1")
        vm.chamar(trabalho(sexta)).join()
        assertEquals(trabalho(sexta), vm.estado.value.trabalhoEnviadoDaBusca)

        vm.buscarPara(garcom, sabado)
        assertNull(vm.estado.value.trabalhoEnviadoDaBusca, "outro horário é outro trabalho: abre a folha")
        vm.buscarPara(garcom, sexta)
        assertEquals(trabalho(sexta), vm.estado.value.trabalhoEnviadoDaBusca, "voltar ao mesmo horário volta ao trabalho guardado")
    }

    @Test
    fun `outro horario abre a sua vaga e voltar ao horario antigo entra na vaga antiga`() = runBlocking {
        val rede = rede()
        val vm = viewModelCom(rede)
        vm.buscarPara(garcom, sexta)
        vm.alternarSelecao("p1")
        vm.chamar(trabalho(sexta)).join()

        vm.buscarPara(garcom, sabado)
        vm.alternarSelecao("p2")
        vm.chamar(trabalho(sabado)).join()
        assertEquals("2026-11-21T22:00:00Z", rede.chamadas()[1].corpo["inicio_em"]!!.jsonPrimitive.content)

        vm.buscarPara(garcom, sexta)
        vm.alternarSelecao("p3")
        vm.chamar(trabalho(sexta, valor = 77700)).join()
        val terceira = rede.chamadas()[2].corpo
        assertEquals("vaga-1", terceira["vaga_id"]!!.jsonPrimitive.content)
        assertFalse("valor_centavos" in terceira)
    }

    @Test
    fun `o 1o envio so sai com um trabalho do servico da busca`() = runBlocking {
        val rede = rede()
        val vm = viewModelCom(rede)
        vm.buscarPara(garcom, sexta)
        vm.alternarSelecao("p1")
        vm.chamar(trabalho(sexta, funcao = bartender)).join()
        assertTrue(rede.chamadas().isEmpty(), "um trabalho de outro serviço não abre vaga por esta lista")
        assertNull(vm.estado.value.trabalhoEnviadoDaBusca)
    }

    @Test
    fun `chamar espera a pagina seguinte em voo`() = runBlocking {
        val rede = rede()
        val liberar = CompletableDeferred<Unit>()
        rede.rota("buscar_profissionais") { pedido ->
            if ("cursor" in pedido.corpo) {
                liberar.await()
                respond(pagina(listOf("p5")), HttpStatusCode.OK, json)
            } else {
                respond(pagina(listOf("p1", "p2"), proximo = "c2"), HttpStatusCode.OK, json)
            }
        }
        val vm = viewModelCom(rede)
        vm.buscarPara(garcom, sexta)
        vm.alternarSelecao("p1")
        assertTrue(vm.estado.value.podeChamar)

        val carregando = vm.carregarMais()
        assertTrue(vm.estado.value.carregandoMais)
        assertFalse(vm.estado.value.podeChamar, "com a página em voo o Chamar fica desligado")
        vm.chamar(trabalho(sexta)).join()
        assertTrue(rede.chamadas().isEmpty())

        liberar.complete(Unit)
        withTimeout(5_000) { carregando.join() }
        assertTrue(vm.estado.value.podeChamar)
    }
    @Test
    fun `repro Codex - recusa definitiva antes de criar vaga permite corrigir o recado`() = runBlocking {
        val rede = rede()
        rede.rota("chamar_profissional") { pedido ->
            if (pedido.corpo["recado"]?.jsonPrimitive?.content == "recado recusado") {
                respond("""{"code":"campo_invalido","message":"recado recusado","details":"recado"}""", HttpStatusCode.UnprocessableEntity, json)
            } else {
                respond("""{"id":"c1","vaga_id":"vaga-1","profissional_id":"p1","estabelecimento_id":"$casa","estado":"aberta","expira_em":"2026-11-17T12:00:00Z","criada_em":"2026-11-16T15:00:00Z"}""", HttpStatusCode.OK, json)
            }
        }
        val vm = viewModelCom(rede)
        vm.buscarPara(garcom, sexta)
        vm.alternarSelecao("p1")
        vm.chamar(trabalho(sexta), "recado recusado").join()
        assertFalse(vm.estado.value.temEnvioPendente)
        assertNull(vm.estado.value.trabalhoEnviadoDaBusca, "sem vaga nem pendência a folha volta a abrir")
        vm.chamar(trabalho(sexta), "recado corrigido").join()
        val segunda = rede.chamadas().last().corpo
        assertEquals("18000", segunda["valor_centavos"]?.jsonPrimitive?.content, "a correção envia o trabalho completo")
        assertFalse("vaga_id" in segunda)
        val recados = rede.chamadas().map { it.corpo["recado"]?.jsonPrimitive?.content }
        println("REPRO CODEX recados enviados: $recados; resultado: ${vm.estado.value.resultadosDaChamada["p1"]}")
        assertEquals("recado corrigido", recados.last(), "recusa definitiva sem vaga deve aceitar a correção")
    }

    @Test
    fun `envio incerto e nao enviados preservam o trabalho e a mesma chave no reenvio`() = runBlocking {
        val rede = rede()
        rede.rota("chamar_profissional") { throw java.io.IOException("sem rede") }
        val vm = viewModelCom(rede)
        vm.buscarPara(garcom, sexta)
        vm.alternarSelecao("p1")
        vm.alternarSelecao("p2")
        vm.chamar(trabalho(sexta), "original").join()
        assertTrue((vm.estado.value.resultadosDaChamada["p1"] as ResultadoDaChamadaDaBusca.Erro).incerto)
        assertEquals(ResultadoDaChamadaDaBusca.NaoEnviada, vm.estado.value.resultadosDaChamada["p2"])
        assertEquals(trabalho(sexta), vm.estado.value.trabalhoEnviadoDaBusca)
        val primeiro = rede.chamadas().single().corpo
        vm.chamar(trabalho(sexta, valor = 99900), "alterado").join()
        assertEquals(primeiro, rede.chamadas().last().corpo)
        rede.recusa("chamar_profissional", HttpStatusCode.UnprocessableEntity, "campo_invalido")
        vm.chamar(trabalho(sexta, valor = 99900), "alterado").join()
        assertTrue(vm.estado.value.resultadosDaChamada.values.all { it is ResultadoDaChamadaDaBusca.Erro && !it.incerto })
        assertEquals(trabalho(sexta), vm.estado.value.trabalhoEnviadoDaBusca, "reenvio nunca apaga o guardado")
        vm.chamar(trabalho(sexta, valor = 99900), "alterado").join()
        assertEquals("original", rede.chamadas().last().corpo["recado"]?.jsonPrimitive?.content)
        assertEquals("18000", rede.chamadas().last().corpo["valor_centavos"]?.jsonPrimitive?.content)
    }

    @Test
    fun `uma enviada e uma recusada mantem a vaga e o recado guardados`() = runBlocking {
        val rede = rede()
        val vm = viewModelCom(rede)
        vm.buscarPara(garcom, sexta)
        vm.alternarSelecao("p1")
        vm.alternarSelecao("p2")
        // A primeira resposta cria a vaga; a segunda é recusada definitivamente.
        rede.rota("chamar_profissional") { pedido ->
            if (pedido.corpo["profissional_id"]?.jsonPrimitive?.content == "p2") {
                respond("""{"code":"campo_invalido","message":"recusado"}""", HttpStatusCode.UnprocessableEntity, json)
            } else {
                respond("""{"id":"c1","vaga_id":"vaga-1","profissional_id":"p1","estabelecimento_id":"$casa","estado":"aberta","expira_em":"2026-11-17T12:00:00Z","criada_em":"2026-11-16T15:00:00Z"}""", HttpStatusCode.OK, json)
            }
        }
        vm.chamar(trabalho(sexta), "original").join()
        assertTrue(vm.estado.value.resultadosDaChamada["p1"] is ResultadoDaChamadaDaBusca.Enviada)
        assertFalse((vm.estado.value.resultadosDaChamada["p2"] as ResultadoDaChamadaDaBusca.Erro).incerto)
        assertEquals(trabalho(sexta), vm.estado.value.trabalhoEnviadoDaBusca)
        // Um reenvio só com recusas também nunca apaga o guardado da rodada anterior.
        vm.chamar(trabalho(sexta, valor = 99900), "alterado").join()
        assertEquals(trabalho(sexta), vm.estado.value.trabalhoEnviadoDaBusca)
        val reenvio = rede.chamadas().last().corpo
        assertEquals("vaga-1", reenvio["vaga_id"]?.jsonPrimitive?.content)
        assertEquals("original", reenvio["recado"]?.jsonPrimitive?.content)
        assertFalse("valor_centavos" in reenvio)
    }

    @Test
    fun `J7 preserva o trabalho e o recado ate a confirmacao`() = runBlocking {
        val rede = rede()
        rede.recusa("chamar_profissional", HttpStatusCode.Conflict, "recorrencia_nao_confirmada")
        val vm = viewModelCom(rede)
        vm.buscarPara(garcom, sexta)
        vm.alternarSelecao("p1")
        vm.chamar(trabalho(sexta), "original").join()
        assertEquals(ResultadoDaChamadaDaBusca.PedeConfirmacaoDeRecorrencia, vm.estado.value.resultadosDaChamada["p1"])
        assertEquals(trabalho(sexta), vm.estado.value.trabalhoEnviadoDaBusca)
        vm.chamar(trabalho(sexta, valor = 99900), "alterado", confirmoRecorrencia = true).join()
        val reenvio = rede.chamadas().last().corpo
        assertEquals("18000", reenvio["valor_centavos"]?.jsonPrimitive?.content)
        assertEquals("original", reenvio["recado"]?.jsonPrimitive?.content)
        assertEquals("true", reenvio["confirmo_recorrencia"]?.jsonPrimitive?.content)
    }

    @Test
    fun `409 com termos diferentes preserva o trabalho ate a casa confirmar`() = runBlocking {
        val rede = rede()
        rede.recusa("chamar_profissional", HttpStatusCode.Conflict, "trabalho_ja_aberto", "55555555-5555-4555-8555-555555555555")
        val base = """"id":"c1","vaga_id":"55555555-5555-4555-8555-555555555555","profissional_id":"p1","estabelecimento_id":"$casa","estado":"aberta","expira_em":"2026-11-17T12:00:00Z","criada_em":"2026-11-16T15:00:00Z","funcao":{"id":"$garcom","nome":"Garçom","categoria":"salao"},"inicio_em":"2026-11-20T22:00:00Z","fim_em":"2026-11-21T02:00:00Z","valor_centavos":25000,"outra_parte":{"id":"p1","tipo":"profissional","nome":"Pessoa","reputacao":{"positivas":0,"total":0,"turnos_considerados":0,"turnos_realizados":0}}"""
        rede.ok("minhas_chamadas", """{"itens":[{$base}],"proximo_cursor":null}""")
        rede.ok("detalhe_chamada", """{$base,"regiao_administrativa":"Plano Piloto","inclui_refeicao":false,"inclui_transporte":false,"exige_material_proprio":false}""")
        val vm = viewModelCom(rede)
        vm.buscarPara(garcom, sexta)
        vm.alternarSelecao("p1")
        vm.alternarSelecao("p2")
        vm.chamar(trabalho(sexta), "original").join()
        assertTrue(vm.estado.value.resultadosDaChamada.values.all { it is ResultadoDaChamadaDaBusca.PedeConfirmacaoDosTermos })
        assertEquals(trabalho(sexta), vm.estado.value.trabalhoEnviadoDaBusca)
        vm.chamar(trabalho(sexta, valor = 99900), "alterado").join()
        assertEquals(1, rede.chamadas().size, "nada sai antes da confirmação")
        vm.confirmarTermosDaVagaAberta().join()
        assertEquals("55555555-5555-4555-8555-555555555555", rede.chamadas().last().corpo["vaga_id"]?.jsonPrimitive?.content)
        assertEquals("original", rede.chamadas().last().corpo["recado"]?.jsonPrimitive?.content)
    }

    @Test
    fun `um unico incerto no primeiro envio preserva o trabalho sem NaoEnviada`() = runBlocking {
        val rede = rede()
        rede.rota("chamar_profissional") { throw java.io.IOException("sem rede") }
        val vm = viewModelCom(rede)
        vm.buscarPara(garcom, sexta)
        vm.alternarSelecao("p1")
        vm.chamar(trabalho(sexta), "original").join()

        assertEquals(setOf("p1"), vm.estado.value.resultadosDaChamada.keys)
        assertTrue((vm.estado.value.resultadosDaChamada["p1"] as ResultadoDaChamadaDaBusca.Erro).incerto)
        assertEquals(trabalho(sexta), vm.estado.value.trabalhoEnviadoDaBusca, "o único incerto mantém o guardado mesmo sem NaoEnviada")
        val primeiro = rede.chamadas().single().corpo
        vm.chamar(trabalho(sexta, valor = 99900), "alterado").join()
        assertEquals(2, rede.chamadas().size)
        assertEquals(primeiro, rede.chamadas().last().corpo, "o reenvio preserva trabalho, recado e chave")
    }

    @Test
    fun `409 com termos iguais e recusa pelo vaga_id preserva o trabalho conhecido`() = runBlocking {
        val rede = rede()
        val vaga = "55555555-5555-4555-8555-555555555555"
        val base = """"id":"c1","vaga_id":"$vaga","profissional_id":"p1","estabelecimento_id":"$casa","estado":"aberta","expira_em":"2026-11-17T12:00:00Z","criada_em":"2026-11-16T15:00:00Z","funcao":{"id":"$garcom","nome":"Garçom","categoria":"salao"},"inicio_em":"2026-11-20T22:00:00Z","fim_em":"2026-11-21T02:00:00Z","valor_centavos":18000,"outra_parte":{"id":"p1","tipo":"profissional","nome":"Pessoa","reputacao":{"positivas":0,"total":0,"turnos_considerados":0,"turnos_realizados":0}}"""
        rede.ok("minhas_chamadas", """{"itens":[{$base}],"proximo_cursor":null}""")
        rede.ok("detalhe_chamada", """{$base,"regiao_administrativa":"Plano Piloto","inclui_refeicao":false,"inclui_transporte":false,"exige_material_proprio":false}""")
        rede.rota("chamar_profissional") { pedido ->
            if ("vaga_id" !in pedido.corpo) {
                respond("""{"code":"trabalho_ja_aberto","message":"x","details":"$vaga"}""", HttpStatusCode.Conflict, json)
            } else {
                respond("""{"code":"campo_invalido","message":"recusado"}""", HttpStatusCode.UnprocessableEntity, json)
            }
        }
        val vm = viewModelCom(rede)
        vm.buscarPara(garcom, sexta)
        vm.alternarSelecao("p1")
        vm.chamar(trabalho(sexta), "original").join()

        assertEquals(2, rede.chamadas().size, "o 409 com termos iguais repete pela vaga conhecida")
        assertTrue("valor_centavos" in rede.chamadas().first().corpo)
        assertEquals(vaga, rede.chamadas().last().corpo["vaga_id"]?.jsonPrimitive?.content)
        assertEquals(setOf("p1"), vm.estado.value.resultadosDaChamada.keys)
        assertFalse((vm.estado.value.resultadosDaChamada["p1"] as ResultadoDaChamadaDaBusca.Erro).incerto)
        assertNull(vm.estado.value.termosParaConfirmar)
        assertEquals(trabalho(sexta), vm.estado.value.trabalhoEnviadoDaBusca, "a vaga identificada mantém o guardado mesmo após recusa definitiva")

        vm.chamar(trabalho(sexta, valor = 99900), "alterado").join()
        assertEquals(3, rede.chamadas().size)
        val reenvio = rede.chamadas().last().corpo
        assertEquals(vaga, reenvio["vaga_id"]?.jsonPrimitive?.content)
        assertEquals("original", reenvio["recado"]?.jsonPrimitive?.content)
        assertFalse("valor_centavos" in reenvio, "não abre outro trabalho após identificar a vaga")
    }

}
