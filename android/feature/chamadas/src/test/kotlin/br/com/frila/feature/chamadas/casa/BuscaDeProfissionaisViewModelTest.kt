package br.com.frila.feature.chamadas.casa

import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class BuscaDeProfissionaisViewModelTest {

    private val casa = "11111111-1111-1111-1111-111111111111"
    private val garcom = "33333333-3333-3333-3333-333333333333"
    private val inicio = Instant.parse("2026-11-20T22:00:00Z")
    private val fim = Instant.parse("2026-11-21T02:00:00Z")
    private val json = headersOf(HttpHeaders.ContentType, "application/json")

    private fun cartao(id: String, disponivel: Boolean? = null) =
        """{"id":"$id","nome":"Pessoa $id","servico":{"funcao":{"id":"$garcom","nome":"Garçom","categoria":"salao"},"unidade":"diaria","valor_centavos":15000,"horas_incluidas":8},"regioes":[],"atende_todo_df":true,"distancia_faixa":"ate_5_km","reputacao":{"positivas":3,"total":4,"turnos_considerados":4,"turnos_realizados":4}${disponivel?.let { ",\"disponivel_no_horario\":$it" } ?: ""}}"""

    private fun pagina(ids: List<String>, proximo: String? = null, disponivel: Boolean? = null) =
        """{"itens":[${ids.joinToString(",") { cartao(it, disponivel) }}],"proximo_cursor":${proximo?.let { "\"$it\"" } ?: "null"}}"""

    private fun ids(prefixo: String, de: Int, ate: Int) = (de..ate).map { "$prefixo-$it" }

    private val chamadaJson =
        """{"id":"c1","vaga_id":"v1","profissional_id":"p","estabelecimento_id":"$casa","estado":"aberta","expira_em":"2026-11-17T12:00:00Z","criada_em":"2026-11-16T15:00:00Z"}"""

    private val trabalho = TrabalhoDaChamada(
        funcaoId = garcom,
        inicio = inicio,
        fim = fim,
        local = "SCS Quadra 2",
        regiaoAdministrativa = "Plano Piloto",
        ponto = br.com.frila.core.rede.CoordenadaDto(-15.79, -47.88),
        valorCentavos = 18000,
        responsavelLocal = "Bistrô Ipê",
    )

    private fun viewModelCom(rede: RedeDeTeste, recurso: Boolean = true, prazoMs: Long = 5_000): BuscaDeProfissionaisViewModel {
        var contador = 0
        return BuscaDeProfissionaisViewModel(
            estabelecimentoId = casa,
            recursoHabilitado = { recurso },
            buscarProfissionais = rede.chamadas::buscarProfissionais,
            chamarProfissional = rede.chamadas::chamarProfissional,
            aceitarTermos = rede.chamadas::aceitarTermos,
            minhasChamadas = { estado, cursor -> rede.chamadas.minhasChamadas(estado = estado, cursor = cursor) },
            detalheChamada = rede.chamadas::detalheChamada,
            novaChave = { "chave-${++contador}" },
            prazoMs = prazoMs,
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
    }

    private fun BuscaDeProfissionaisViewModel.comFiltros(regiao: Int? = null, horario: HorarioDaBusca? = null) = apply {
        definirFuncao(garcom)
        definirRegiao(regiao)
        definirHorario(horario)
    }

    @Test
    fun `buscar manda os filtros no corpo e mostra os resultados na ordem do servidor, com o selo dele`() = runBlocking {
        val rede = RedeDeTeste().apply {
            // A reputação de "z" é a melhor, mas o app não reordena (D2): vale a ordem que o servidor mandou.
            ok("buscar_profissionais", pagina(listOf("z", "a", "m"), disponivel = true))
        }
        val vm = viewModelCom(rede).comFiltros(regiao = 7, horario = HorarioDaBusca(inicio, fim))

        vm.buscar().join()

        val corpo = rede.doNome("buscar_profissionais").single().corpo
        assertEquals(casa, corpo["estabelecimento_id"]!!.jsonPrimitive.content)
        assertEquals(garcom, corpo["funcao_id"]!!.jsonPrimitive.content)
        assertEquals(7, corpo["regiao_id"]!!.jsonPrimitive.int)
        assertEquals("2026-11-20T22:00:00Z", corpo["inicio_em"]!!.jsonPrimitive.content)
        assertEquals("2026-11-21T02:00:00Z", corpo["fim_em"]!!.jsonPrimitive.content)
        assertEquals(20, corpo["limite"]!!.jsonPrimitive.int)
        assertFalse("cursor" in corpo)
        val tela = vm.estado.value
        assertEquals(EstadoDaBusca.Resultados, tela.estado)
        assertEquals(listOf("z", "a", "m"), tela.resultados.map { it.id })
        assertTrue(tela.resultados.all { it.disponivelNoHorario == true })
        assertNull(tela.rascunhoParaPublicarParaTodos)
    }

    @Test
    fun `sem regiao nem horario o corpo leva so o servico`() = runBlocking {
        val rede = RedeDeTeste().apply { ok("buscar_profissionais", pagina(listOf("a"))) }
        val vm = viewModelCom(rede).comFiltros()

        vm.buscar().join()

        val corpo = rede.doNome("buscar_profissionais").single().corpo
        assertEquals(setOf("estabelecimento_id", "funcao_id", "limite"), corpo.keys)
    }

    @Test
    fun `sem servico, ou com termino antes do inicio, a busca nem sai`() = runBlocking {
        val rede = RedeDeTeste().apply { ok("buscar_profissionais", pagina(listOf("a"))) }
        val vm = viewModelCom(rede)

        assertFalse(vm.estado.value.podeBuscar)
        vm.buscar().join()
        vm.definirFuncao(garcom)
        vm.definirHorario(HorarioDaBusca(inicio = fim, fim = inicio))
        assertFalse(vm.estado.value.podeBuscar)
        vm.buscar().join()

        assertTrue(rede.pedidos.isEmpty())
        assertEquals(EstadoDaBusca.Ocioso, vm.estado.value.estado)
    }

    @Test
    fun `busca vazia oferece publicar para todos ja preenchido com os filtros`() = runBlocking {
        val rede = RedeDeTeste().apply { ok("buscar_profissionais", pagina(emptyList())) }
        val horario = HorarioDaBusca(inicio, fim)
        val vm = viewModelCom(rede).comFiltros(regiao = 7, horario = horario)

        vm.buscar().join()

        assertEquals(EstadoDaBusca.Vazio, vm.estado.value.estado)
        assertEquals(
            RascunhoDeVagaDaBusca(estabelecimentoId = casa, funcaoId = garcom, regiaoId = 7, horario = horario),
            vm.estado.value.rascunhoParaPublicarParaTodos,
        )
    }

    @Test
    fun `paginas de 20 por cursor ate o fim, sem repetir quem ja veio`() = runBlocking {
        val rede = RedeDeTeste()
        val cursores = mutableListOf<String?>()
        rede.rota("buscar_profissionais") { pedido ->
            val cursor = pedido.corpo["cursor"]?.jsonPrimitive?.content
            cursores += cursor
            val corpo = when (cursor) {
                null -> pagina(ids("p", 1, 20), proximo = "c2")
                "c2" -> pagina(ids("p", 18, 37), proximo = null) // 18 a 20 repetidos
                else -> error("cursor inesperado $cursor")
            }
            respond(corpo, HttpStatusCode.OK, json)
        }
        val vm = viewModelCom(rede).comFiltros()

        vm.buscar().join()
        assertTrue(vm.estado.value.temMais)
        assertEquals(20, vm.estado.value.resultados.size)

        vm.carregarMais().join()

        assertEquals(listOf(null, "c2"), cursores)
        assertEquals(37, vm.estado.value.resultados.size)
        assertEquals(vm.estado.value.resultados.map { it.id }.distinct(), vm.estado.value.resultados.map { it.id })
        assertFalse(vm.estado.value.temMais)
        assertFalse(vm.estado.value.carregandoMais)
        // No fim, carregar mais não faz outro pedido.
        vm.carregarMais().join()
        assertEquals(2, rede.doNome("buscar_profissionais").size)
    }

    @Test
    fun `para em 200 resultados mesmo com cursor, e o ultimo pedido so pede o que falta`() = runBlocking {
        val rede = RedeDeTeste()
        val limites = mutableListOf<Int>()
        var numero = 0
        rede.rota("buscar_profissionais") { pedido ->
            limites += pedido.corpo["limite"]!!.jsonPrimitive.int
            val ate = ++numero * 20
            respond(pagina(ids("p", ate - 19, ate), proximo = "c$numero"), HttpStatusCode.OK, json)
        }
        val vm = viewModelCom(rede).comFiltros()

        vm.buscar().join()
        repeat(9) { vm.carregarMais().join() }

        assertEquals(200, vm.estado.value.resultados.size)
        assertFalse(vm.estado.value.temMais)
        vm.carregarMais().join()
        assertEquals(10, rede.doNome("buscar_profissionais").size)
        assertTrue(limites.all { it == 20 })
    }

    @Test
    fun `o servidor mandar mais que o teto na ultima pagina nao passa de 200`() = runBlocking {
        val rede = RedeDeTeste()
        var numero = 0
        rede.rota("buscar_profissionais") {
            numero++
            val corpo = if (numero < 10) pagina(ids("p", numero * 20 - 19, numero * 20), proximo = "c$numero")
            else pagina(ids("q", 1, 25), proximo = "c10")
            respond(corpo, HttpStatusCode.OK, json)
        }
        val vm = viewModelCom(rede).comFiltros()

        vm.buscar().join()
        repeat(9) { vm.carregarMais().join() }

        assertEquals(200, vm.estado.value.resultados.size)
        assertFalse(vm.estado.value.temMais)
    }

    @Test
    fun `429 na primeira pagina vira a mensagem de limite de buscas`() = runBlocking {
        val rede = RedeDeTeste().apply { recusa("buscar_profissionais", HttpStatusCode.TooManyRequests, "limite_excedido") }
        val vm = viewModelCom(rede).comFiltros()

        vm.buscar().join()

        assertEquals(EstadoDaBusca.Erro(TextosChamadaCasa.BUSCA_LIMITE_DE_BUSCAS), vm.estado.value.estado)
        assertTrue(vm.estado.value.resultados.isEmpty())
        assertTrue(vm.estado.value.podeBuscar)
    }

    @Test
    fun `chave busca_profissionais desligada no app deixa a busca indisponivel sem chamar a rede`() = runBlocking {
        val rede = RedeDeTeste()
        val vm = viewModelCom(rede, recurso = false).comFiltros()

        vm.buscar().join()

        assertEquals(EstadoDaBusca.Indisponivel, vm.estado.value.estado)
        assertTrue(rede.pedidos.isEmpty())
    }

    @Test
    fun `recurso_desligado vindo do servidor tambem deixa a busca indisponivel`() = runBlocking {
        val rede = RedeDeTeste().apply { recusa("buscar_profissionais", HttpStatusCode.Forbidden, "sem_permissao", "recurso_desligado") }
        val vm = viewModelCom(rede).comFiltros()

        vm.buscar().join()

        assertEquals(EstadoDaBusca.Indisponivel, vm.estado.value.estado)
    }

    @Test
    fun `outros erros viram a mensagem de buscar agora, e falha de carregar mais mantem a lista`() = runBlocking {
        val rede = RedeDeTeste().apply { recusa("buscar_profissionais", HttpStatusCode.InternalServerError, "erro_interno") }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        assertEquals(EstadoDaBusca.Erro(TextosChamadaCasa.BUSCA_ERRO), vm.estado.value.estado)

        var segunda = false
        rede.rota("buscar_profissionais") {
            if (!segunda) { segunda = true; respond(pagina(ids("p", 1, 20), proximo = "c2"), HttpStatusCode.OK, json) }
            else respond("""{"code":"erro_interno","message":"x"}""", HttpStatusCode.InternalServerError, json)
        }
        vm.buscar().join()
        vm.carregarMais().join()

        assertEquals(EstadoDaBusca.Resultados, vm.estado.value.estado)
        assertEquals(20, vm.estado.value.resultados.size)
        assertEquals(TextosChamadaCasa.BUSCA_ERRO_AO_CARREGAR_MAIS, vm.estado.value.erroAoCarregarMais)
        assertTrue(vm.estado.value.temMais)
        assertFalse(vm.estado.value.carregandoMais)
    }

    @Test
    fun `cursor_invalido ao carregar mais refaz a busca do comeco com os mesmos filtros`() = runBlocking {
        val rede = RedeDeTeste()
        var chamadas = 0
        rede.rota("buscar_profissionais") { pedido ->
            chamadas++
            when {
                pedido.corpo["cursor"] != null ->
                    respond("""{"code":"cursor_invalido","message":"x"}""", HttpStatusCode.UnprocessableEntity, json)
                chamadas == 1 -> respond(pagina(ids("p", 1, 20), proximo = "velho"), HttpStatusCode.OK, json)
                else -> respond(pagina(ids("n", 1, 5)), HttpStatusCode.OK, json)
            }
        }
        val vm = viewModelCom(rede).comFiltros(regiao = 3)
        vm.buscar().join()

        vm.carregarMais().join()

        val pedidos = rede.doNome("buscar_profissionais")
        assertEquals(3, pedidos.size)
        assertFalse("cursor" in pedidos[2].corpo)
        assertEquals(3, pedidos[2].corpo["regiao_id"]!!.jsonPrimitive.int)
        assertEquals(ids("n", 1, 5), vm.estado.value.resultados.map { it.id })
        assertEquals(EstadoDaBusca.Resultados, vm.estado.value.estado)
        assertNull(vm.estado.value.erroAoCarregarMais)
    }

    @Test
    fun `429 ao carregar mais troca a busca pela mensagem de limite`() = runBlocking {
        val rede = RedeDeTeste()
        var primeira = true
        rede.rota("buscar_profissionais") {
            if (primeira) { primeira = false; respond(pagina(ids("p", 1, 20), proximo = "c2"), HttpStatusCode.OK, json) }
            else respond("""{"code":"limite_excedido","message":"x"}""", HttpStatusCode.TooManyRequests, json)
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()

        vm.carregarMais().join()

        assertEquals(EstadoDaBusca.Erro(TextosChamadaCasa.BUSCA_LIMITE_DE_BUSCAS), vm.estado.value.estado)
        assertFalse(vm.estado.value.carregandoMais)
    }

    @Test
    fun `ate 3 selecionados, o 4o nao entra e liga o aviso, e desmarcar abre vaga`() = runBlocking {
        val rede = RedeDeTeste().apply { ok("buscar_profissionais", pagina(ids("p", 1, 5))) }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()

        assertTrue(vm.alternarSelecao("p-1"))
        assertTrue(vm.alternarSelecao("p-2"))
        assertTrue(vm.alternarSelecao("p-3"))
        assertFalse(vm.alternarSelecao("p-4"))
        assertEquals(TextosChamadaCasa.BUSCA_LIMITE_DE_SELECAO, vm.estado.value.avisoDeLimiteDeSelecao)
        assertEquals(listOf("p-1", "p-2", "p-3"), vm.estado.value.selecionados)

        assertTrue(vm.alternarSelecao("p-2"))
        assertNull(vm.estado.value.avisoDeLimiteDeSelecao)
        assertTrue(vm.alternarSelecao("p-4"))
        assertEquals(listOf("p-1", "p-3", "p-4"), vm.estado.value.selecionados)
        assertTrue(vm.estado.value.estaSelecionado("p-4"))

        vm.alternarSelecao("p-5")
        vm.dispensarAvisoDeLimite()
        assertNull(vm.estado.value.avisoDeLimiteDeSelecao)
        // Quem não está na lista não entra.
        assertFalse(vm.alternarSelecao("desconhecido"))
    }

    @Test
    fun `nova busca zera a selecao e o que ja foi chamado`() = runBlocking {
        val rede = RedeDeTeste().apply {
            ok("buscar_profissionais", pagina(ids("p", 1, 3)))
            ok("chamar_profissional", chamadaJson)
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        vm.alternarSelecao("p-1")
        vm.chamar(trabalho).join()
        assertEquals(1, vm.estado.value.resultadosDaChamada.size)

        vm.buscar().join()

        assertTrue(vm.estado.value.selecionados.isEmpty())
        assertTrue(vm.estado.value.resultadosDaChamada.isEmpty())
    }

    @Test
    fun `chamar manda o trabalho na 1a chamada e so o vaga_id dela nas outras, cada uma com a sua chave`() = runBlocking {
        val rede = RedeDeTeste().apply {
            ok("buscar_profissionais", pagina(ids("p", 1, 5)))
            ok("chamar_profissional", chamadaJson)
        }
        val vm = viewModelCom(rede).comFiltros(regiao = 7)
        vm.buscar().join()
        listOf("p-1", "p-3", "p-5").forEach(vm::alternarSelecao)

        vm.chamar(trabalho, recado = "Traga avental").join()

        val pedidos = rede.doNome("chamar_profissional")
        assertEquals(listOf("p-1", "p-3", "p-5"), pedidos.map { it.corpo["profissional_id"]!!.jsonPrimitive.content })
        assertEquals(listOf("chave-1", "chave-2", "chave-3"), pedidos.map { it.corpo["chave"]!!.jsonPrimitive.content })
        assertTrue(pedidos.all { it.corpo["recado"]!!.jsonPrimitive.content == "Traga avental" })
        assertTrue(pedidos.all { it.corpo["estabelecimento_id"]!!.jsonPrimitive.content == casa })
        // A 1ª leva o trabalho inteiro e o regiao_id da busca, sem vaga_id.
        val primeira = pedidos.first().corpo
        assertEquals(7, primeira["regiao_id"]!!.jsonPrimitive.int)
        assertEquals("18000", primeira["valor_centavos"]!!.jsonPrimitive.content)
        assertFalse("vaga_id" in primeira)
        // A 2ª e a 3ª levam só o vaga_id da resposta da 1ª (a vaga guarda a região), nunca os dois.
        pedidos.drop(1).forEach {
            assertEquals("v1", it.corpo["vaga_id"]!!.jsonPrimitive.content)
            assertEquals(setOf("chave", "profissional_id", "estabelecimento_id", "vaga_id", "recado"), it.corpo.keys)
        }
        assertTrue(vm.estado.value.resultadosDaChamada.values.all { it is ResultadoDaChamadaDaBusca.Enviada })
        assertFalse(vm.estado.value.enviando)
        assertFalse(vm.estado.value.mostrarJ7)

        // Quem já tem chamada enviada não é chamado de novo.
        vm.chamar(trabalho).join()
        assertEquals(3, rede.doNome("chamar_profissional").size)
    }

    /** Responde cada chamada com a vaga `vaga-<n>` (uma por pedido que cria vaga, isto é, sem vaga_id). */
    private fun RedeDeTeste.respondeComVagaPropria(falhas: Set<String> = emptySet()) {
        var vagas = 0
        rota("chamar_profissional") { pedido ->
            val id = pedido.corpo["profissional_id"]!!.jsonPrimitive.content
            when {
                id in falhas -> respond("""{"code":"profissional_indisponivel","message":"x"}""", HttpStatusCode.UnprocessableEntity, json)
                "vaga_id" in pedido.corpo -> respond(chamadaJson.replace("\"v1\"", "\"${pedido.corpo["vaga_id"]!!.jsonPrimitive.content}\""), HttpStatusCode.OK, json)
                else -> respond(chamadaJson.replace("\"v1\"", "\"vaga-${++vagas}\""), HttpStatusCode.OK, json)
            }
        }
    }

    @Test
    fun `3 selecionados geram 1 pedido com o trabalho e 2 com o vaga_id da resposta, e nunca criam 3 vagas`() = runBlocking {
        val rede = RedeDeTeste().apply {
            ok("buscar_profissionais", pagina(ids("p", 1, 3)))
            respondeComVagaPropria()
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2", "p-3").forEach(vm::alternarSelecao)

        vm.chamar(trabalho).join()

        val pedidos = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals(3, pedidos.size)
        assertEquals(1, pedidos.count { "valor_centavos" in it })
        assertEquals(listOf("vaga-1", "vaga-1"), pedidos.drop(1).map { it["vaga_id"]!!.jsonPrimitive.content })
        assertTrue(pedidos.drop(1).none { "valor_centavos" in it || "funcao_id" in it || "regiao_id" in it })
        assertEquals(3, pedidos.map { it["chave"]!!.jsonPrimitive.content }.toSet().size)
    }

    @Test
    fun `se a 1a falhar, a proxima que der certo vira a 1a e as outras vao pelo vaga_id dela`() = runBlocking {
        val rede = RedeDeTeste().apply {
            ok("buscar_profissionais", pagina(ids("p", 1, 3)))
            respondeComVagaPropria(falhas = setOf("p-1"))
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2", "p-3").forEach(vm::alternarSelecao)

        vm.chamar(trabalho).join()

        val pedidos = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals(listOf("p-1", "p-2", "p-3"), pedidos.map { it["profissional_id"]!!.jsonPrimitive.content })
        // p-1 tentou criar a vaga e foi recusada; p-2 criou; p-3 foi pelo vaga_id de p-2.
        assertTrue("valor_centavos" in pedidos[0])
        assertTrue("valor_centavos" in pedidos[1])
        assertFalse("vaga_id" in pedidos[1])
        assertEquals("vaga-1", pedidos[2]["vaga_id"]!!.jsonPrimitive.content)
        assertFalse("valor_centavos" in pedidos[2])
        assertTrue(vm.estado.value.resultadosDaChamada["p-1"] is ResultadoDaChamadaDaBusca.Erro)
    }

    @Test
    fun `J7 da 1a, quem estava pendente reenvia pelo vaga_id da vaga que outro criou, com a mesma chave`() = runBlocking {
        val rede = RedeDeTeste().apply { ok("buscar_profissionais", pagina(ids("p", 1, 2))) }
        var confirmado = false
        rede.rota("chamar_profissional") { pedido ->
            val id = pedido.corpo["profissional_id"]!!.jsonPrimitive.content
            if (id == "p-1" && !confirmado) respond("""{"code":"recorrencia_nao_confirmada","message":"x"}""", HttpStatusCode.Conflict, json)
            else respond(chamadaJson.replace("\"v1\"", "\"vaga-9\""), HttpStatusCode.OK, json)
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2").forEach(vm::alternarSelecao)

        vm.chamar(trabalho).join()
        confirmado = true
        vm.chamar(trabalho, confirmoRecorrencia = true).join()

        val pedidos = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals(3, pedidos.size)
        assertTrue("valor_centavos" in pedidos[1], "p-2 virou a 1ª")
        val reenvio = pedidos[2]
        assertEquals("p-1", reenvio["profissional_id"]!!.jsonPrimitive.content)
        assertEquals("chave-1", reenvio["chave"]!!.jsonPrimitive.content)
        assertEquals("vaga-9", reenvio["vaga_id"]!!.jsonPrimitive.content)
        assertFalse("valor_centavos" in reenvio)
        assertTrue(reenvio["confirmo_recorrencia"]!!.jsonPrimitive.boolean)
    }

    // --- Aceite dos Termos 1.1 (contrato 0.2.90) -----------------------------------------------------------

    /** A busca responde `termos_pendentes` na 1ª vez e a página na seguinte (como o servidor depois do aceite). */
    private fun RedeDeTeste.buscaQueExigeOAceite(depoisDoAceite: String = pagina(listOf("a", "b"))) {
        rota("buscar_profissionais") {
            if (doNome("aceitar_termos").isEmpty()) {
                respond("""{"code":"sem_permissao","message":"x","details":"termos_pendentes"}""", HttpStatusCode.Forbidden, json)
            } else {
                respond(depoisDoAceite, HttpStatusCode.OK, json)
            }
        }
    }

    @Test
    fun `termos_pendentes na busca vira o estado de aceite, sem lista e com a busca bloqueada`() = runBlocking {
        val rede = RedeDeTeste().apply { buscaQueExigeOAceite() }
        val vm = viewModelCom(rede).comFiltros()

        vm.buscar().join()

        val tela = vm.estado.value
        assertEquals(EstadoDaBusca.TermosPendentes(), tela.estado)
        assertTrue(tela.resultados.isEmpty())
        assertFalse(tela.podeBuscar)
        vm.buscar().join()
        assertEquals(1, rede.doNome("buscar_profissionais").size)
    }

    @Test
    fun `aceitar chama aceitar_termos com a versao exigida e repete a busca com os mesmos filtros`() = runBlocking {
        val rede = RedeDeTeste().apply {
            buscaQueExigeOAceite()
            ok("aceitar_termos", """{"termos_versao":"2026-11-16","aceito_em":"2026-11-16T20:00:00Z"}""")
        }
        val vm = viewModelCom(rede).comFiltros(regiao = 7, horario = HorarioDaBusca(inicio, fim))
        vm.buscar().join()

        vm.aceitarTermosEBuscar().join()

        val aceite = rede.doNome("aceitar_termos").single().corpo
        assertEquals(BuscaDeProfissionaisViewModel.TERMOS_VERSAO_EXIGIDA, aceite["termos_versao"]!!.jsonPrimitive.content)
        assertEquals("2026-11-16", aceite["termos_versao"]!!.jsonPrimitive.content)
        val buscas = rede.doNome("buscar_profissionais")
        assertEquals(2, buscas.size)
        assertEquals(buscas[0].corpo, buscas[1].corpo)
        assertEquals(7, buscas[1].corpo["regiao_id"]!!.jsonPrimitive.int)
        val tela = vm.estado.value
        assertEquals(EstadoDaBusca.Resultados, tela.estado)
        assertEquals(listOf("a", "b"), tela.resultados.map { it.id })
    }

    @Test
    fun `erro no aceite mostra a mensagem e a busca continua bloqueada, sem repetir a busca`() = runBlocking {
        val rede = RedeDeTeste().apply {
            buscaQueExigeOAceite()
            recusa("aceitar_termos", HttpStatusCode.InternalServerError, "desconhecido")
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()

        vm.aceitarTermosEBuscar().join()

        val tela = vm.estado.value
        assertEquals(EstadoDaBusca.TermosPendentes(erro = TextosChamadaCasa.BUSCA_TERMOS_ERRO), tela.estado)
        assertFalse(tela.podeBuscar)
        assertEquals(1, rede.doNome("buscar_profissionais").size)
    }

    @Test
    fun `depois de um erro no aceite tocar de novo tenta outra vez e libera a busca`() = runBlocking {
        val rede = RedeDeTeste().apply {
            buscaQueExigeOAceite()
            recusa("aceitar_termos", HttpStatusCode.InternalServerError, "desconhecido")
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        vm.aceitarTermosEBuscar().join()
        rede.ok("aceitar_termos", """{"termos_versao":"2026-11-16","aceito_em":"2026-11-16T20:00:00Z"}""")

        vm.aceitarTermosEBuscar().join()

        assertEquals(2, rede.doNome("aceitar_termos").size)
        assertEquals(EstadoDaBusca.Resultados, vm.estado.value.estado)
    }

    @Test
    fun `aceite que estoura o prazo vira erro de aceite e a busca fica bloqueada`() = runBlocking {
        val rede = RedeDeTeste().apply {
            buscaQueExigeOAceite()
            rota("aceitar_termos") { kotlinx.coroutines.delay(5_000); respond("{}", HttpStatusCode.OK, json) }
        }
        val vm = viewModelCom(rede, prazoMs = 50).comFiltros()
        vm.buscar().join()

        vm.aceitarTermosEBuscar().join()

        assertEquals(EstadoDaBusca.TermosPendentes(erro = TextosChamadaCasa.BUSCA_TERMOS_ERRO), vm.estado.value.estado)
        assertEquals(1, rede.doNome("buscar_profissionais").size)
    }

    @Test
    fun `aceitar sem a busca ter sido barrada por termos nao chama nada`() = runBlocking {
        val rede = RedeDeTeste().apply { ok("buscar_profissionais", pagina(listOf("a"))) }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()

        vm.aceitarTermosEBuscar().join()

        assertTrue(rede.doNome("aceitar_termos").isEmpty())
        assertEquals(EstadoDaBusca.Resultados, vm.estado.value.estado)
    }

    @Test
    fun `se o servidor ainda pede os Termos depois do aceite volta ao estado de aceite sem laco`() = runBlocking {
        val rede = RedeDeTeste().apply {
            recusa("buscar_profissionais", HttpStatusCode.Forbidden, "sem_permissao", "termos_pendentes")
            ok("aceitar_termos", """{"termos_versao":"2026-11-16","aceito_em":"2026-11-16T20:00:00Z"}""")
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()

        vm.aceitarTermosEBuscar().join()

        assertEquals(EstadoDaBusca.TermosPendentes(), vm.estado.value.estado)
        assertEquals(2, rede.doNome("buscar_profissionais").size)
        assertEquals(1, rede.doNome("aceitar_termos").size)
    }

    // --- Catálogos dos filtros ---------------------------------------------------------------------------

    private val garcomDto = br.com.frila.core.rede.FuncaoDto(garcom, "Garçom", "salao")
    private val regiaoDto = br.com.frila.core.rede.RegiaoAdministrativaDto(1, "I", "Plano Piloto")
    private val casaDto = br.com.frila.core.rede.MeuEstabelecimentoDto(
        id = casa, nome = "Bistrô Ipê", tipo = "restaurante", endereco = "SCS Quadra 2", regiaoAdministrativa = "Plano Piloto",
        ponto = br.com.frila.core.rede.CoordenadaDto(-15.79, -47.88), papel = "administrador",
    )

    private fun comCatalogos(
        recurso: suspend () -> Boolean = { true },
        funcoes: suspend () -> List<br.com.frila.core.rede.FuncaoDto> = { listOf(garcomDto) },
        regioes: suspend () -> List<br.com.frila.core.rede.RegiaoAdministrativaDto> = { listOf(regiaoDto) },
        buscarCasa: suspend (String) -> br.com.frila.core.rede.MeuEstabelecimentoDto = { casaDto },
        prazoMs: Long = 5_000,
    ) = BuscaDeProfissionaisViewModel(
        estabelecimentoId = casa,
        recursoHabilitado = recurso,
        buscarProfissionais = { error("não deveria buscar") },
        chamarProfissional = { error("não deveria chamar") },
        minhasChamadas = { _, _ -> error("não deveria ler") },
        detalheChamada = { error("não deveria ler") },
        prazoMs = prazoMs,
        listarFuncoes = funcoes,
        listarRegioes = regioes,
        buscarCasa = buscarCasa,
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `carregarCatalogos traz funcoes, regioes e a casa`() = runBlocking {
        val vm = comCatalogos()

        vm.carregarCatalogos().join()

        val tela = vm.estado.value
        assertEquals(listOf(garcomDto), tela.funcoes)
        assertEquals(listOf(regiaoDto), tela.regioes)
        assertEquals(casaDto, tela.casa)
        assertFalse(tela.carregandoCatalogos)
        assertFalse(tela.falhaDeCatalogos)
    }

    @Test
    fun `carregarCatalogos com a chave desligada deixa a busca indisponivel sem pedir catalogos`() = runBlocking {
        var pediu = false
        val vm = comCatalogos(recurso = { false }, funcoes = { pediu = true; emptyList() })

        vm.carregarCatalogos().join()

        assertEquals(EstadoDaBusca.Indisponivel, vm.estado.value.estado)
        assertFalse(pediu)
        assertFalse(vm.estado.value.carregandoCatalogos)
    }

    @Test
    fun `sem as regioes a busca segue so sem o filtro, e falha das funcoes oferece tentar de novo`() = runBlocking {
        val semRegioes = comCatalogos(regioes = { throw IllegalStateException("sem rede") })
        semRegioes.carregarCatalogos().join()
        assertEquals(listOf(garcomDto), semRegioes.estado.value.funcoes)
        assertTrue(semRegioes.estado.value.regioes.isEmpty())
        assertFalse(semRegioes.estado.value.falhaDeCatalogos)

        var falhar = true
        val vm = comCatalogos(funcoes = { if (falhar) throw IllegalStateException("sem rede") else listOf(garcomDto) })
        vm.carregarCatalogos().join()
        assertTrue(vm.estado.value.falhaDeCatalogos)
        assertFalse(vm.estado.value.carregandoCatalogos)
        falhar = false
        vm.carregarCatalogos().join()
        assertFalse(vm.estado.value.falhaDeCatalogos)
        assertEquals(listOf(garcomDto), vm.estado.value.funcoes)
    }

    @Test
    fun `catalogos com recurso_desligado do servidor ficam indisponiveis, e o prazo estourado vira falha`() = runBlocking {
        val desligado = comCatalogos(
            funcoes = { throw br.com.frila.core.rede.ErroDaApi(br.com.frila.core.dominio.modelo.CodigoErroAPI.SEM_PERMISSAO, "sem_permissao", "recurso_desligado", "x") },
        )
        desligado.carregarCatalogos().join()
        assertEquals(EstadoDaBusca.Indisponivel, desligado.estado.value.estado)

        val lento = comCatalogos(funcoes = { kotlinx.coroutines.delay(5_000); emptyList() }, prazoMs = 20)
        lento.carregarCatalogos().join()
        assertTrue(lento.estado.value.falhaDeCatalogos)
    }

    @Test
    fun `1a incerta por prazo estourado nao promove ninguem, e o reenvio repete a chave dela e so depois os outros vao pelo vaga_id`() = runBlocking {
        val rede = RedeDeTeste().apply { ok("buscar_profissionais", pagina(ids("p", 1, 3))) }
        var atrasar = true
        rede.rota("chamar_profissional") { pedido ->
            val id = pedido.corpo["profissional_id"]!!.jsonPrimitive.content
            when {
                id == "p-1" && atrasar -> { kotlinx.coroutines.delay(5_000); respond(chamadaJson, HttpStatusCode.OK, json) }
                "vaga_id" in pedido.corpo -> respond(chamadaJson.replace("\"v1\"", "\"${pedido.corpo["vaga_id"]!!.jsonPrimitive.content}\""), HttpStatusCode.OK, json)
                else -> respond(chamadaJson.replace("\"v1\"", "\"vaga-p1\""), HttpStatusCode.OK, json)
            }
        }
        val vm = viewModelCom(rede, prazoMs = 100).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2", "p-3").forEach(vm::alternarSelecao)

        vm.chamar(trabalho).join()

        // Só o pedido do p-1 saiu; nenhum de p-2/p-3 foi com o trabalho.
        val primeiros = rede.doNome("chamar_profissional")
        assertEquals(listOf("p-1"), primeiros.map { it.corpo["profissional_id"]!!.jsonPrimitive.content })
        val tela = vm.estado.value
        assertEquals(ResultadoDaChamadaDaBusca.Erro(TextosChamadaCasa.ERRO, incerto = true), tela.resultadosDaChamada["p-1"])
        assertEquals(ResultadoDaChamadaDaBusca.NaoEnviada, tela.resultadosDaChamada["p-2"])
        assertEquals(ResultadoDaChamadaDaBusca.NaoEnviada, tela.resultadosDaChamada["p-3"])
        assertFalse(tela.enviando)
        assertTrue(tela.podeReenviar)

        atrasar = false
        vm.chamar(trabalho).join()

        val pedidos = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals(4, pedidos.size)
        assertEquals(listOf("p-1", "p-1", "p-2", "p-3"), pedidos.map { it["profissional_id"]!!.jsonPrimitive.content })
        // O reenvio do p-1 repete a MESMA chave e o trabalho; os outros vão pelo vaga_id que a resposta trouxe.
        assertEquals(pedidos[0]["chave"], pedidos[1]["chave"])
        assertTrue("valor_centavos" in pedidos[1])
        assertEquals(listOf("vaga-p1", "vaga-p1"), pedidos.drop(2).map { it["vaga_id"]!!.jsonPrimitive.content })
        assertTrue(pedidos.drop(2).none { "valor_centavos" in it })
        assertTrue(vm.estado.value.resultadosDaChamada.values.all { it is ResultadoDaChamadaDaBusca.Enviada })
        assertFalse(vm.estado.value.podeReenviar)
    }

    @Test
    fun `1a com resposta ilegivel tambem para o laco, mas recusa definitiva promove o proximo`() = runBlocking {
        val rede = RedeDeTeste().apply { ok("buscar_profissionais", pagina(ids("p", 1, 3))) }
        rede.rota("chamar_profissional") { pedido ->
            when (pedido.corpo["profissional_id"]!!.jsonPrimitive.content) {
                "p-1" -> respond("isto nao e json", HttpStatusCode.OK, json)
                else -> respond(chamadaJson, HttpStatusCode.OK, json)
            }
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2", "p-3").forEach(vm::alternarSelecao)

        vm.chamar(trabalho).join()

        assertEquals(1, rede.doNome("chamar_profissional").size)
        assertEquals(ResultadoDaChamadaDaBusca.NaoEnviada, vm.estado.value.resultadosDaChamada["p-3"])

        // Já a recusa DEFINITIVA do servidor (4xx com código) continua promovendo o próximo (teste do "1a falhar").
        val definitiva = RedeDeTeste().apply {
            ok("buscar_profissionais", pagina(ids("p", 1, 2)))
            respondeComVagaPropria(falhas = setOf("p-1"))
        }
        val vm2 = viewModelCom(definitiva).comFiltros()
        vm2.buscar().join()
        listOf("p-1", "p-2").forEach(vm2::alternarSelecao)
        vm2.chamar(trabalho).join()
        assertEquals(2, definitiva.doNome("chamar_profissional").size)
        assertFalse(vm2.estado.value.podeReenviar)
    }

    @Test
    fun `1a recusada e a 2a incerta, o reenvio manda a 2a primeiro com a mesma chave para nao criar duas vagas`() = runBlocking {
        val rede = RedeDeTeste().apply { ok("buscar_profissionais", pagina(ids("p", 1, 3))) }
        var atrasar = true
        rede.rota("chamar_profissional") { pedido ->
            val id = pedido.corpo["profissional_id"]!!.jsonPrimitive.content
            when {
                id == "p-1" -> respond("""{"code":"profissional_indisponivel","message":"x"}""", HttpStatusCode.UnprocessableEntity, json)
                id == "p-2" && atrasar -> { kotlinx.coroutines.delay(5_000); respond(chamadaJson, HttpStatusCode.OK, json) }
                "vaga_id" in pedido.corpo -> respond(chamadaJson, HttpStatusCode.OK, json)
                else -> respond(chamadaJson, HttpStatusCode.OK, json)
            }
        }
        val vm = viewModelCom(rede, prazoMs = 100).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2", "p-3").forEach(vm::alternarSelecao)
        vm.chamar(trabalho).join()
        assertEquals(listOf("p-1", "p-2"), rede.doNome("chamar_profissional").map { it.corpo["profissional_id"]!!.jsonPrimitive.content })
        val chaveDoP2 = rede.doNome("chamar_profissional")[1].corpo["chave"]

        atrasar = false
        vm.chamar(trabalho).join()

        val reenvio = rede.doNome("chamar_profissional").drop(2).map { it.corpo }
        // O p-2 (incerto, levando o trabalho) vai antes do p-1 (recusado antes), com a mesma chave.
        assertEquals("p-2", reenvio.first()["profissional_id"]!!.jsonPrimitive.content)
        assertEquals(chaveDoP2, reenvio.first()["chave"])
        assertTrue("valor_centavos" in reenvio.first())
        assertTrue(reenvio.drop(1).all { "vaga_id" in it && "valor_centavos" !in it })
    }

    @Test
    fun `p-1 com J7 e p-2 incerto levando o trabalho, o Confirmar fica bloqueado ate o reenvio resolver a vaga, e entao o p-1 vai pelo vaga_id`() = runBlocking {
        val rede = RedeDeTeste().apply { ok("buscar_profissionais", pagina(ids("p", 1, 3))) }
        var atrasar = true
        rede.rota("chamar_profissional") { pedido ->
            val id = pedido.corpo["profissional_id"]!!.jsonPrimitive.content
            when {
                id == "p-1" && "confirmo_recorrencia" !in pedido.corpo ->
                    respond("""{"code":"recorrencia_nao_confirmada","message":"x"}""", HttpStatusCode.Conflict, json)
                id == "p-2" && atrasar -> { kotlinx.coroutines.delay(5_000); respond(chamadaJson, HttpStatusCode.OK, json) }
                "vaga_id" in pedido.corpo -> respond(chamadaJson.replace("\"v1\"", "\"${pedido.corpo["vaga_id"]!!.jsonPrimitive.content}\""), HttpStatusCode.OK, json)
                else -> respond(chamadaJson.replace("\"v1\"", "\"vaga-p2\""), HttpStatusCode.OK, json)
            }
        }
        val vm = viewModelCom(rede, prazoMs = 100).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2", "p-3").forEach(vm::alternarSelecao)

        vm.chamar(trabalho).join()

        // p-1 recebeu J7 (nada criado); p-2 levou o trabalho e ficou incerto; p-3 nem saiu.
        var tela = vm.estado.value
        assertEquals(ResultadoDaChamadaDaBusca.PedeConfirmacaoDeRecorrencia, tela.resultadosDaChamada["p-1"])
        assertEquals(ResultadoDaChamadaDaBusca.Erro(TextosChamadaCasa.ERRO, incerto = true), tela.resultadosDaChamada["p-2"])
        assertEquals(ResultadoDaChamadaDaBusca.NaoEnviada, tela.resultadosDaChamada["p-3"])
        assertTrue(tela.mostrarJ7)
        assertTrue(tela.podeReenviar)
        assertEquals(listOf("p-1", "p-2"), rede.doNome("chamar_profissional").map { it.corpo["profissional_id"]!!.jsonPrimitive.content })

        // Confirmar o J7 agora mandaria o p-1 com o trabalho completo e poderia criar a 2ª vaga: não sai nada.
        vm.chamar(trabalho, confirmoRecorrencia = true).join()
        assertEquals(2, rede.doNome("chamar_profissional").size)
        assertTrue(vm.estado.value.podeReenviar)

        // O reenvio resolve a vaga do p-2 (mesma chave); o p-1 e o p-3 vão pelo vaga_id, nunca com o trabalho.
        atrasar = false
        vm.chamar(trabalho).join()
        tela = vm.estado.value
        assertFalse(tela.podeReenviar)
        assertTrue(tela.resultadosDaChamada["p-2"] is ResultadoDaChamadaDaBusca.Enviada)
        assertTrue(tela.resultadosDaChamada["p-3"] is ResultadoDaChamadaDaBusca.Enviada)
        assertTrue(tela.mostrarJ7)

        vm.chamar(trabalho, confirmoRecorrencia = true).join()

        val pedidos = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals(listOf("p-1", "p-2", "p-2", "p-1", "p-3", "p-1"), pedidos.map { it["profissional_id"]!!.jsonPrimitive.content })
        assertEquals(pedidos[1]["chave"], pedidos[2]["chave"])
        // Só o p-1 do começo e o p-2 levaram o trabalho; todo o resto foi pelo vaga_id da vaga do p-2.
        assertEquals(listOf(0, 1, 2), pedidos.withIndex().filter { "valor_centavos" in it.value }.map { it.index })
        pedidos.drop(3).forEach { assertEquals("vaga-p2", it["vaga_id"]!!.jsonPrimitive.content) }
        val confirmado = pedidos.last()
        assertEquals("chave-1", confirmado["chave"]!!.jsonPrimitive.content)
        assertTrue(confirmado["confirmo_recorrencia"]!!.jsonPrimitive.boolean)
        assertTrue(vm.estado.value.resultadosDaChamada["p-1"] is ResultadoDaChamadaDaBusca.Enviada)
        assertFalse(vm.estado.value.mostrarJ7)
    }

    @Test
    fun `p-1 de J7 que virou nao enviado volta pelo vaga_id quando a vaga ja existe, nunca com o trabalho`() = runBlocking {
        val rede = RedeDeTeste().apply { ok("buscar_profissionais", pagina(ids("p", 1, 3))) }
        var atrasar = true
        rede.rota("chamar_profissional") { pedido ->
            val id = pedido.corpo["profissional_id"]!!.jsonPrimitive.content
            when {
                id == "p-1" && "confirmo_recorrencia" !in pedido.corpo ->
                    respond("""{"code":"recorrencia_nao_confirmada","message":"x"}""", HttpStatusCode.Conflict, json)
                id == "p-2" && atrasar -> { kotlinx.coroutines.delay(5_000); respond(chamadaJson, HttpStatusCode.OK, json) }
                "vaga_id" in pedido.corpo -> respond(chamadaJson.replace("\"v1\"", "\"${pedido.corpo["vaga_id"]!!.jsonPrimitive.content}\""), HttpStatusCode.OK, json)
                else -> respond(chamadaJson.replace("\"v1\"", "\"vaga-p2\""), HttpStatusCode.OK, json)
            }
        }
        val vm = viewModelCom(rede, prazoMs = 100).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2", "p-3").forEach(vm::alternarSelecao)

        vm.chamar(trabalho).join() // p-1 J7, p-2 incerto, p-3 nem saiu
        vm.chamar(trabalho).join() // o reenvio do p-2 estoura de novo: o laço para antes do p-1, que vira NaoEnviada
        assertEquals(ResultadoDaChamadaDaBusca.NaoEnviada, vm.estado.value.resultadosDaChamada["p-1"])
        assertEquals(listOf("p-1", "p-2", "p-2"), rede.doNome("chamar_profissional").map { it.corpo["profissional_id"]!!.jsonPrimitive.content })

        atrasar = false
        vm.chamar(trabalho).join() // agora a vaga do p-2 existe

        val depois = rede.doNome("chamar_profissional").drop(3).map { it.corpo }
        assertEquals(listOf("p-2", "p-1", "p-3"), depois.map { it["profissional_id"]!!.jsonPrimitive.content })
        val p1 = depois[1]
        assertEquals("vaga-p2", p1["vaga_id"]!!.jsonPrimitive.content)
        assertFalse("valor_centavos" in p1 || "funcao_id" in p1)
        assertEquals("chave-1", p1["chave"]!!.jsonPrimitive.content)
        // Em todo o fluxo só o p-1 inicial e o p-2 (duas vezes, mesma chave) levaram o trabalho.
        val comTrabalho = rede.doNome("chamar_profissional").map { it.corpo }.filter { "valor_centavos" in it }
        assertEquals(listOf("p-1", "p-2", "p-2", "p-2"), comTrabalho.map { it["profissional_id"]!!.jsonPrimitive.content })
    }

    // --- Envio incerto trava a seleção e a busca; vaga por trabalho vale entre buscas -----------------------

    /** p-1 estoura o prazo (incerto) enquanto [atrasar]; as vagas nascem como `vaga-<profissional>` e quem vai por vaga_id a devolve. */
    private fun RedeDeTeste.respondeComP1Atrasado(atrasar: () -> Boolean) {
        rota("chamar_profissional") { pedido ->
            val id = pedido.corpo["profissional_id"]!!.jsonPrimitive.content
            when {
                id == "p-1" && atrasar() -> { kotlinx.coroutines.delay(5_000); respond(chamadaJson, HttpStatusCode.OK, json) }
                "vaga_id" in pedido.corpo -> respond(chamadaJson.replace("\"v1\"", "\"${pedido.corpo["vaga_id"]!!.jsonPrimitive.content}\""), HttpStatusCode.OK, json)
                else -> respond(chamadaJson.replace("\"v1\"", "\"vaga-$id\""), HttpStatusCode.OK, json)
            }
        }
    }

    @Test
    fun `com envio incerto pendente nao da para desmarcar nem trocar a selecao, e outro trabalho nao sai`() = runBlocking {
        val rede = RedeDeTeste().apply { ok("buscar_profissionais", pagina(ids("p", 1, 5))) }
        rede.respondeComP1Atrasado { true }
        val vm = viewModelCom(rede, prazoMs = 100).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2").forEach(vm::alternarSelecao)
        vm.chamar(trabalho).join()
        assertTrue(vm.estado.value.temEnvioPendente)
        assertTrue(vm.estado.value.selecaoTravada)

        assertFalse(vm.alternarSelecao("p-1"), "desmarcar o incerto")
        assertFalse(vm.alternarSelecao("p-2"), "desmarcar o que nem saiu")
        assertFalse(vm.alternarSelecao("p-3"), "trocar por outro")
        assertEquals(listOf("p-1", "p-2"), vm.estado.value.selecionados)

        // Outro trabalho também fica de fora: abriria outra vaga para quem pode já ter chamada. Pela regra do #905 (um trabalho por serviço e
        // horário) o que sai é o REENVIO do trabalho guardado, com a mesma chave, e nunca o outro valor.
        vm.chamar(trabalho.copy(valorCentavos = 25000)).join()
        val pedidos = rede.doNome("chamar_profissional").map { it.corpo }
        assertTrue(pedidos.none { it["valor_centavos"]?.jsonPrimitive?.content == "25000" }, "o outro valor nunca sai")
        assertEquals(pedidos[0]["chave"], pedidos[1]["chave"])
    }

    @Test
    fun `com envio incerto pendente a busca fica bloqueada, e o reenvio pelo ViewModel segue com a mesma chave`() = runBlocking {
        val rede = RedeDeTeste().apply { ok("buscar_profissionais", pagina(ids("p", 1, 3))) }
        var atrasar = true
        rede.respondeComP1Atrasado { atrasar }
        val vm = viewModelCom(rede, prazoMs = 100).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2").forEach(vm::alternarSelecao)
        vm.chamar(trabalho).join()

        assertFalse(vm.estado.value.podeBuscar)
        vm.buscar().join()
        assertEquals(1, rede.doNome("buscar_profissionais").size)
        assertEquals(listOf("p-1", "p-2"), vm.estado.value.selecionados)
        assertTrue(vm.estado.value.temEnvioPendente)

        // "Tentar de novo" sem passar o trabalho (a folha pode ter fechado): o ViewModel guardou o último envio.
        atrasar = false
        vm.reenviar().join()

        val pedidos = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals(listOf("p-1", "p-1", "p-2"), pedidos.map { it["profissional_id"]!!.jsonPrimitive.content })
        assertEquals(pedidos[0]["chave"], pedidos[1]["chave"])
        assertEquals("vaga-p-1", pedidos[2]["vaga_id"]!!.jsonPrimitive.content)
        assertFalse(vm.estado.value.temEnvioPendente)
        assertTrue(vm.estado.value.podeBuscar)
    }

    /** Página 1 com cursor; a próxima responde [aoCarregarMais] depois de [demoraMs] (para o carregarMais ficar em voo). */
    private fun RedeDeTeste.buscaComCarregarMaisLento(demoraMs: Long, aoCarregarMais: suspend io.ktor.client.engine.mock.MockRequestHandleScope.() -> io.ktor.client.request.HttpResponseData) {
        var buscas = 0
        rota("buscar_profissionais") { pedido ->
            buscas++
            when {
                pedido.corpo["cursor"] != null -> { kotlinx.coroutines.delay(demoraMs); aoCarregarMais() }
                buscas == 1 -> respond(pagina(ids("p", 1, 20), proximo = "velho"), HttpStatusCode.OK, json)
                // A página nova não traz mais o p-1 (o incerto): ele continua na lista por estar selecionado.
                else -> respond(pagina(ids("n", 1, 5)), HttpStatusCode.OK, json)
            }
        }
    }

    @Test
    fun `carregarMais em voo que da cursor_invalido refaz a pagina sem apagar a selecao, e o Chamar espera a pagina`() = runBlocking {
        val rede = RedeDeTeste()
        rede.buscaComCarregarMaisLento(200) { respond("""{"code":"cursor_invalido","message":"x"}""", HttpStatusCode.UnprocessableEntity, json) }
        var atrasar = true
        rede.respondeComP1Atrasado { atrasar }
        val vm = viewModelCom(rede, prazoMs = 500).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2").forEach(vm::alternarSelecao)

        // MENOR 4 do #807 (decisão do O2): com a página seguinte em voo o Chamar espera. Antes, o pedido saía durante o "carregar mais" e o
        // `cursor_invalido` refazia a lista e a seleção por cima dele. Agora o refazer do cursor não encontra pedido nenhum em voo.
        val mais = vm.carregarMais()
        vm.chamar(trabalho).join()
        mais.join()
        assertTrue(rede.doNome("chamar_profissional").isEmpty(), "nada sai com a página em voo")

        val tela = vm.estado.value
        assertEquals(ids("n", 1, 5) + listOf("p-1", "p-2"), tela.resultados.map { it.id })
        assertEquals(listOf("p-1", "p-2"), tela.selecionados)
        assertEquals(EstadoDaBusca.Resultados, tela.estado)
        assertTrue(tela.podeChamar, "refeita a página, o Chamar volta")
    }

    @Test
    fun `com envio pendente o carregarMais nao sai, e o reenvio segue possivel`() = runBlocking {
        val rede = RedeDeTeste()
        rede.buscaComCarregarMaisLento(200) { respond("""{"code":"limite_excedido","message":"x"}""", HttpStatusCode.TooManyRequests, json) }
        var atrasar = true
        rede.respondeComP1Atrasado { atrasar }
        val vm = viewModelCom(rede, prazoMs = 500).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2").forEach(vm::alternarSelecao)

        // MENOR 4 do #807: com a página em voo o Chamar espera, então o pedido sai antes do "carregar mais" (que, com envio incerto, nem sai).
        vm.chamar(trabalho).join()
        val mais = vm.carregarMais()
        mais.join()

        // O envio pendente continua ao alcance, e o "carregar mais" não saiu por causa dele.
        var tela = vm.estado.value
        assertTrue(tela.podeReenviar)
        assertTrue(tela.podeChamar)
        val buscasAntes = rede.doNome("buscar_profissionais").size
        vm.carregarMais().join() // bloqueado: nada sai com envio pendente
        assertEquals(buscasAntes, rede.doNome("buscar_profissionais").size)

        atrasar = false
        vm.reenviar().join()

        val pedidos = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals(listOf("p-1", "p-1", "p-2"), pedidos.map { it["profissional_id"]!!.jsonPrimitive.content })
        assertEquals(pedidos[0]["chave"], pedidos[1]["chave"])
        assertEquals("vaga-p-1", pedidos[2]["vaga_id"]!!.jsonPrimitive.content)
        tela = vm.estado.value
        assertFalse(tela.temEnvioPendente)
        assertTrue(tela.resultadosDaChamada.values.all { it is ResultadoDaChamadaDaBusca.Enviada })
    }

    @Test
    fun `com envio pendente em Resultados o carregarMais fica bloqueado`() = runBlocking {
        val rede = RedeDeTeste()
        rede.buscaComCarregarMaisLento(0) { respond(pagina(ids("m", 1, 5)), HttpStatusCode.OK, json) }
        rede.respondeComP1Atrasado { true }
        val vm = viewModelCom(rede, prazoMs = 100).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2").forEach(vm::alternarSelecao)
        vm.chamar(trabalho).join()
        assertTrue(vm.estado.value.temEnvioPendente)
        val buscasAntes = rede.doNome("buscar_profissionais").size

        vm.carregarMais().join()

        assertEquals(buscasAntes, rede.doNome("buscar_profissionais").size)
        assertEquals(20, vm.estado.value.resultados.size)
    }

    @Test
    fun `nova busca com o mesmo trabalho entra na vaga que ja existe pelo vaga_id, e outro trabalho na mesma busca nao abre 2a vaga`() = runBlocking {
        val rede = RedeDeTeste().apply { ok("buscar_profissionais", pagina(ids("p", 1, 5))) }
        rede.respondeComP1Atrasado { false }
        val vm = viewModelCom(rede).comFiltros(regiao = 7)
        vm.buscar().join()
        vm.alternarSelecao("p-1")
        vm.chamar(trabalho).join()
        assertEquals("vaga-p-1", (vm.estado.value.resultadosDaChamada["p-1"] as ResultadoDaChamadaDaBusca.Enviada).chamada.vagaId)

        // Nova busca (a seleção e os resultados da chamada zeram), mesmo trabalho: vai pelo vaga_id da vaga existente.
        vm.buscar().join()
        vm.alternarSelecao("p-2")
        vm.chamar(trabalho).join()
        var pedidos = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals("p-2", pedidos.last()["profissional_id"]!!.jsonPrimitive.content)
        assertEquals("vaga-p-1", pedidos.last()["vaga_id"]!!.jsonPrimitive.content)
        assertFalse("valor_centavos" in pedidos.last())

        // O trabalho mudou (outro valor) na MESMA busca (serviço e horário): pela regra do #905 vale o trabalho guardado, nunca uma 2ª vaga.
        vm.buscar().join()
        vm.alternarSelecao("p-3")
        vm.chamar(trabalho.copy(valorCentavos = 25000)).join()
        pedidos = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals("p-3", pedidos.last()["profissional_id"]!!.jsonPrimitive.content)
        assertEquals("vaga-p-1", pedidos.last()["vaga_id"]!!.jsonPrimitive.content)
        assertFalse("valor_centavos" in pedidos.last())
        // A região da busca também faz parte do trabalho: outra região não entra na vaga da primeira.
        vm.definirRegiao(8)
        vm.buscar().join()
        vm.alternarSelecao("p-4")
        vm.chamar(trabalho).join()
        assertFalse("vaga_id" in rede.doNome("chamar_profissional").last().corpo)
    }

    @Test
    fun `chamar sem selecao, ou sem resultados, nao faz nada`() = runBlocking {
        val rede = RedeDeTeste().apply { ok("buscar_profissionais", pagina(emptyList())) }
        val vm = viewModelCom(rede).comFiltros()

        vm.chamar(trabalho).join()
        vm.buscar().join()
        vm.chamar(trabalho).join()

        assertTrue(rede.doNome("chamar_profissional").isEmpty())
        assertFalse(vm.estado.value.podeChamar)
    }

    @Test
    fun `J7 de um dos selecionados pede a confirmacao e o reenvio vale so para ele, com a mesma chave`() = runBlocking {
        val rede = RedeDeTeste().apply { ok("buscar_profissionais", pagina(ids("p", 1, 3))) }
        var confirmado = false
        rede.rota("chamar_profissional") { pedido ->
            val id = pedido.corpo["profissional_id"]!!.jsonPrimitive.content
            if (id == "p-2" && !confirmado) respond("""{"code":"recorrencia_nao_confirmada","message":"x"}""", HttpStatusCode.Conflict, json)
            else respond(chamadaJson, HttpStatusCode.OK, json)
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2", "p-3").forEach(vm::alternarSelecao)

        vm.chamar(trabalho).join()

        assertTrue(vm.estado.value.mostrarJ7)
        assertEquals(ResultadoDaChamadaDaBusca.PedeConfirmacaoDeRecorrencia, vm.estado.value.resultadosDaChamada["p-2"])
        assertTrue(vm.estado.value.resultadosDaChamada["p-1"] is ResultadoDaChamadaDaBusca.Enviada)
        assertTrue(vm.estado.value.resultadosDaChamada["p-3"] is ResultadoDaChamadaDaBusca.Enviada)
        assertFalse(vm.estado.value.enviando)

        confirmado = true
        vm.chamar(trabalho, confirmoRecorrencia = true).join()

        val pedidos = rede.doNome("chamar_profissional")
        assertEquals(4, pedidos.size)
        val reenvio = pedidos.last().corpo
        assertEquals("p-2", reenvio["profissional_id"]!!.jsonPrimitive.content)
        assertEquals("chave-2", reenvio["chave"]!!.jsonPrimitive.content)
        assertTrue(reenvio["confirmo_recorrencia"]!!.jsonPrimitive.boolean)
        assertTrue(vm.estado.value.resultadosDaChamada["p-2"] is ResultadoDaChamadaDaBusca.Enviada)
        assertFalse(vm.estado.value.mostrarJ7)
    }

    @Test
    fun `confirmo_recorrencia sem a recusa J7 nao envia nada`() = runBlocking {
        val rede = RedeDeTeste().apply {
            ok("buscar_profissionais", pagina(ids("p", 1, 2)))
            ok("chamar_profissional", chamadaJson)
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        vm.alternarSelecao("p-1")

        vm.chamar(trabalho, confirmoRecorrencia = true).join()

        assertTrue(rede.doNome("chamar_profissional").isEmpty())
    }

    @Test
    fun `a recusa de um nao impede os outros, e cada resultado ganha a mensagem do iOS`() = runBlocking {
        val rede = RedeDeTeste().apply { ok("buscar_profissionais", pagina(ids("p", 1, 3))) }
        rede.rota("chamar_profissional") { pedido ->
            when (pedido.corpo["profissional_id"]!!.jsonPrimitive.content) {
                "p-1" -> respond("""{"code":"chamada_ja_aberta","message":"x"}""", HttpStatusCode.Conflict, json)
                "p-2" -> respond("""{"code":"profissional_indisponivel","message":"x","details":"pausado"}""", HttpStatusCode.UnprocessableEntity, json)
                else -> respond(chamadaJson, HttpStatusCode.OK, json)
            }
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2", "p-3").forEach(vm::alternarSelecao)

        vm.chamar(trabalho).join()

        val resultados = vm.estado.value.resultadosDaChamada
        assertEquals(ResultadoDaChamadaDaBusca.Erro(TextosChamadaCasa.JA_ABERTA), resultados["p-1"])
        assertEquals(ResultadoDaChamadaDaBusca.Erro(TextosChamadaCasa.INDISPONIVEL), resultados["p-2"])
        assertNotNull((resultados["p-3"] as ResultadoDaChamadaDaBusca.Enviada).chamada)
        assertFalse(vm.estado.value.enviando)
        assertFalse(vm.estado.value.mostrarJ7)
    }

    // --- Trabalho já aberto (409 trabalho_ja_aberto, contrato 0.2.95) ------------------------------------------

    private val vagaAberta = "7c1f0c1e-5b0a-4a53-9d1e-2f6c8f0a4b11"

    /**
     * A casa já tem o trabalho aberto em [aberta] (0.2.95): o pedido pelo trabalho, ou pelo `vaga_id` de outra vaga, recebe
     * `409 trabalho_ja_aberto` com [detalhes] em `details` (por padrão, a própria [aberta]); pelo `vaga_id` dela, entra.
     */
    private fun RedeDeTeste.comTrabalhoAberto(aberta: String, detalhes: String? = aberta) {
        rota("chamar_profissional") { pedido ->
            if (pedido.corpo["vaga_id"]?.jsonPrimitive?.content == aberta) {
                respond(chamadaJson.replace("\"v1\"", "\"$aberta\""), HttpStatusCode.OK, json)
            } else {
                val details = detalhes?.let { "\"$it\"" } ?: "null"
                respond("""{"code":"trabalho_ja_aberto","message":"trabalho_ja_aberto","details":$details,"hint":null}""", HttpStatusCode.Conflict, json)
            }
        }
        comTermosDaVaga(aberta)
    }

    /**
     * 0.2.95: a vaga aberta [vaga] em `minhas_chamadas` (o valor) e no `detalhe_chamada` (os inclusos). Por padrão, os
     * mesmos termos do `trabalho` dos testes, e o 409 segue direto.
     */
    private fun RedeDeTeste.comTermosDaVaga(
        vaga: String,
        valorCentavos: Long = trabalho.valorCentavos,
        refeicao: Boolean = false,
        transporte: Boolean = false,
        material: Boolean = false,
    ) {
        val base = chamadaAberta(vaga, valorCentavos)
        ok("minhas_chamadas", """{"itens":[{$base}],"proximo_cursor":null}""")
        ok(
            "detalhe_chamada",
            """{$base,"regiao_administrativa":"Plano Piloto","inclui_refeicao":$refeicao,"inclui_transporte":$transporte,"exige_material_proprio":$material}""",
        )
    }

    /** O item `aberta` de `minhas_chamadas` da vaga [vaga] (sem as chaves de fora), que o `detalhe_chamada` completa. */
    private fun chamadaAberta(vaga: String, valorCentavos: Long) =
        """"id":"chamada-$vaga","vaga_id":"$vaga","profissional_id":"p-9","estabelecimento_id":"$casa","estado":"aberta",""" +
            """"expira_em":"2026-11-17T12:00:00Z","criada_em":"2026-11-16T15:00:00Z","funcao":{"id":"$garcom","nome":"Garçom","categoria":"salao"},""" +
            """"inicio_em":"2026-11-20T22:00:00Z","fim_em":"2026-11-21T02:00:00Z","valor_centavos":$valorCentavos,""" +
            """"outra_parte":{"id":"p-9","tipo":"profissional","nome":"Pessoa 9","reputacao":{"positivas":0,"total":0,"turnos_considerados":0,"turnos_realizados":0}}"""

    /**
     * 0.2.95 (head final cc40db7): `minhas_chamadas` em duas páginas. A 1ª traz só a chamada de [naPrimeira] e o cursor
     * "c2"; a 2ª (pedida com ele) traz só a de [naSegunda], sem cursor. Os termos são os do `trabalho` dos testes.
     */
    private fun RedeDeTeste.comChamadasEmDuasPaginas(naPrimeira: String, naSegunda: String) {
        rota("minhas_chamadas") { pedido ->
            val segunda = pedido.corpo["cursor"]?.jsonPrimitive?.content == "c2"
            val vaga = if (segunda) naSegunda else naPrimeira
            val cursor = if (segunda) "null" else "\"c2\""
            respond("""{"itens":[{${chamadaAberta(vaga, trabalho.valorCentavos)}}],"proximo_cursor":$cursor}""", HttpStatusCode.OK, json)
        }
    }

    private fun trabalhoJaAberto(vaga: String) =
        """{"code":"trabalho_ja_aberto","message":"trabalho_ja_aberto","details":"$vaga","hint":null}"""

    private fun vagaDoResultado(tela: EstadoBusca, id: String): String? =
        (tela.resultadosDaChamada[id] as? ResultadoDaChamadaDaBusca.Enviada)?.chamada?.vagaId

    @Test
    fun `409 trabalho_ja_aberto, quem levou o trabalho vai de novo pelo vaga_id de details com chave nova e fica enviada, e os outros e a nova busca entram direto nela`() = runBlocking {
        val rede = RedeDeTeste().apply {
            ok("buscar_profissionais", pagina(ids("p", 1, 4)))
            comTrabalhoAberto(vagaAberta)
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2", "p-3").forEach(vm::alternarSelecao)

        vm.chamar(trabalho).join()

        val pedidos = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals(listOf("p-1", "p-1", "p-2", "p-3"), pedidos.map { it["profissional_id"]!!.jsonPrimitive.content })
        // Só o primeiro leva o trabalho; depois do 409 todos vão pela vaga aberta, cada um com a sua chave.
        assertEquals(listOf(true, false, false, false), pedidos.map { "valor_centavos" in it })
        assertEquals(listOf(null, vagaAberta, vagaAberta, vagaAberta), pedidos.map { it["vaga_id"]?.jsonPrimitive?.content })
        assertEquals(4, pedidos.map { it["chave"]!!.jsonPrimitive.content }.toSet().size)
        val tela = vm.estado.value
        assertEquals(listOf(vagaAberta, vagaAberta, vagaAberta), listOf("p-1", "p-2", "p-3").map { vagaDoResultado(tela, it) })
        assertFalse(tela.temEnvioPendente)

        // A vaga que o 409 apontou ficou como a do trabalho: a nova busca entra direto nela.
        vm.buscar().join()
        vm.alternarSelecao("p-4")
        vm.chamar(trabalho).join()
        val depois = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals(5, depois.size)
        assertEquals("p-4", depois.last()["profissional_id"]!!.jsonPrimitive.content)
        assertEquals(vagaAberta, depois.last()["vaga_id"]?.jsonPrimitive?.content)
        assertEquals(vagaAberta, vagaDoResultado(vm.estado.value, "p-4"))
    }

    @Test
    fun `409 trabalho_ja_aberto sem vaga_id em details vira o erro generico, sem pedido pelo vaga_id e sem travar`() = runBlocking {
        for (detalhes in listOf(null, "nao-e-uuid")) {
            val rede = RedeDeTeste().apply {
                ok("buscar_profissionais", pagina(ids("p", 1, 2)))
                comTrabalhoAberto(vagaAberta, detalhes = detalhes)
            }
            val vm = viewModelCom(rede).comFiltros()
            vm.buscar().join()
            listOf("p-1", "p-2").forEach(vm::alternarSelecao)

            vm.chamar(trabalho).join()

            val pedidos = rede.doNome("chamar_profissional").map { it.corpo }
            // Recusa definitiva: o 2º vira o 1º e recebe o mesmo 409; ninguém vai pelo vaga_id.
            assertEquals(listOf("p-1", "p-2"), pedidos.map { it["profissional_id"]!!.jsonPrimitive.content }, "details=$detalhes")
            assertTrue(pedidos.none { "vaga_id" in it }, "details=$detalhes")
            val tela = vm.estado.value
            assertEquals(ResultadoDaChamadaDaBusca.Erro(TextosChamadaCasa.ERRO), tela.resultadosDaChamada["p-1"], "details=$detalhes")
            assertEquals(ResultadoDaChamadaDaBusca.Erro(TextosChamadaCasa.ERRO), tela.resultadosDaChamada["p-2"], "details=$detalhes")
            assertFalse(tela.temEnvioPendente, "details=$detalhes")
        }
    }

    @Test
    fun `409 trabalho_ja_aberto no pedido pelo vaga_id troca a vaga do trabalho pela de details, e o proximo entra direto nela`() = runBlocking {
        val rede = RedeDeTeste().apply {
            ok("buscar_profissionais", pagina(ids("p", 1, 3)))
            respondeComVagaPropria()
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        vm.alternarSelecao("p-1")
        vm.chamar(trabalho).join()
        assertEquals("vaga-1", vagaDoResultado(vm.estado.value, "p-1"))
        // Outra vaga direta do mesmo trabalho passou a ter a chamada aberta (por exemplo, de outro aparelho).
        rede.comTrabalhoAberto(vagaAberta)
        vm.buscar().join()
        listOf("p-2", "p-3").forEach(vm::alternarSelecao)

        vm.chamar(trabalho).join()

        val pedidos = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals(listOf("p-1", "p-2", "p-2", "p-3"), pedidos.map { it["profissional_id"]!!.jsonPrimitive.content })
        assertEquals(listOf(null, "vaga-1", vagaAberta, vagaAberta), pedidos.map { it["vaga_id"]?.jsonPrimitive?.content })
        assertEquals(listOf(vagaAberta, vagaAberta), listOf("p-2", "p-3").map { vagaDoResultado(vm.estado.value, it) })
    }

    @Test
    fun `409 trabalho_ja_aberto tambem no pedido pelo vaga_id nao insiste, vira o erro generico e o proximo entra na vaga`() = runBlocking {
        val rede = RedeDeTeste().apply {
            ok("buscar_profissionais", pagina(ids("p", 1, 2)))
            comTermosDaVaga(vagaAberta) // os mesmos termos do trabalho: segue direto
        }
        rede.rota("chamar_profissional") { pedido ->
            val vaga = pedido.corpo["vaga_id"]?.jsonPrimitive?.content
            if (pedido.corpo["profissional_id"]!!.jsonPrimitive.content == "p-1" || vaga == null) {
                respond("""{"code":"trabalho_ja_aberto","message":"x","details":"$vagaAberta","hint":null}""", HttpStatusCode.Conflict, json)
            } else {
                respond(chamadaJson.replace("\"v1\"", "\"$vaga\""), HttpStatusCode.OK, json)
            }
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2").forEach(vm::alternarSelecao)

        vm.chamar(trabalho).join()

        val pedidos = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals(listOf("p-1", "p-1", "p-2"), pedidos.map { it["profissional_id"]!!.jsonPrimitive.content })
        assertEquals(listOf(null, vagaAberta, vagaAberta), pedidos.map { it["vaga_id"]?.jsonPrimitive?.content })
        val tela = vm.estado.value
        assertEquals(ResultadoDaChamadaDaBusca.Erro(TextosChamadaCasa.ERRO), tela.resultadosDaChamada["p-1"])
        assertEquals(vagaAberta, vagaDoResultado(tela, "p-2"))
        assertFalse(tela.temEnvioPendente)
    }

    // --- Termos da vaga aberta diferentes dos digitados (0.2.95, head 15026bc do #265) ------------------------

    @Test
    fun `409 com valor ou inclusos diferentes nao sai pelo vaga_id, e quem levou o trabalho e os proximos esperam a confirmacao`() = runBlocking {
        val rede = RedeDeTeste().apply {
            ok("buscar_profissionais", pagina(ids("p", 1, 3)))
            comTrabalhoAberto(vagaAberta)
            comTermosDaVaga(vagaAberta, valorCentavos = 25000, refeicao = true)
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2", "p-3").forEach(vm::alternarSelecao)

        vm.chamar(trabalho).join()

        // Só o 1º saiu, pelo trabalho, e recebeu o 409; ninguém foi pelo vaga_id.
        val pedidos = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals(listOf("p-1"), pedidos.map { it["profissional_id"]!!.jsonPrimitive.content })
        val termos = TermosDaVagaAberta(vagaAberta, 25000, incluiRefeicao = true, incluiTransporte = false, exigeMaterialProprio = false)
        val tela = vm.estado.value
        assertEquals(termos, tela.termosParaConfirmar)
        val esperando = ResultadoDaChamadaDaBusca.PedeConfirmacaoDosTermos(termos)
        assertEquals(listOf(esperando, esperando, esperando), listOf("p-1", "p-2", "p-3").map { tela.resultadosDaChamada[it] })
        assertFalse(tela.podeChamar)
        // Chamar de novo sem confirmar também não manda nada.
        vm.chamar(trabalho).join()
        assertEquals(1, rede.doNome("chamar_profissional").size)
    }

    @Test
    fun `confirmar os termos da vaga aberta manda um pedido so pelo vaga_id, com chave nova, e a pessoa fica enviada`() = runBlocking {
        val rede = RedeDeTeste().apply {
            ok("buscar_profissionais", pagina(ids("p", 1, 1)))
            comTrabalhoAberto(vagaAberta)
            comTermosDaVaga(vagaAberta, valorCentavos = 25000)
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        vm.alternarSelecao("p-1")
        vm.chamar(trabalho).join()
        val antes = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals(1, antes.size)

        vm.confirmarTermosDaVagaAberta().join()

        val depois = rede.doNome("chamar_profissional").map { it.corpo }.drop(antes.size)
        assertEquals(listOf(vagaAberta), depois.map { it["vaga_id"]?.jsonPrimitive?.content })
        assertTrue(depois.none { "valor_centavos" in it })
        assertTrue(depois.none { pedido -> antes.any { it["chave"] == pedido["chave"] } })
        assertEquals(vagaAberta, vagaDoResultado(vm.estado.value, "p-1"))
        assertNull(vm.estado.value.termosParaConfirmar)
    }

    @Test
    fun `cancelar os termos da vaga aberta nao manda nada, e quem esperava volta a ficar sem resultado`() = runBlocking {
        val rede = RedeDeTeste().apply {
            ok("buscar_profissionais", pagina(ids("p", 1, 2)))
            comTrabalhoAberto(vagaAberta)
            comTermosDaVaga(vagaAberta, refeicao = true)
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2").forEach(vm::alternarSelecao)
        vm.chamar(trabalho).join()
        val antes = rede.doNome("chamar_profissional").size

        vm.cancelarTermosDaVagaAberta()

        assertEquals(antes, rede.doNome("chamar_profissional").size)
        val tela = vm.estado.value
        assertNull(tela.termosParaConfirmar)
        assertTrue(tela.resultadosDaChamada.isEmpty())
        assertTrue(tela.podeChamar)
    }

    @Test
    fun `409 com a leitura dos termos falhando vira o erro generico, e nada sai pelo vaga_id`() = runBlocking {
        val rede = RedeDeTeste().apply {
            ok("buscar_profissionais", pagina(ids("p", 1, 1)))
            comTrabalhoAberto(vagaAberta)
            recusa("minhas_chamadas", HttpStatusCode.InternalServerError, "erro_interno")
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        vm.alternarSelecao("p-1")

        vm.chamar(trabalho).join()

        val pedidos = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals(1, pedidos.size)
        assertTrue(pedidos.none { "vaga_id" in it })
        assertEquals(ResultadoDaChamadaDaBusca.Erro(TextosChamadaCasa.ERRO), vm.estado.value.resultadosDaChamada["p-1"])
        assertNull(vm.estado.value.termosParaConfirmar)
        assertFalse(vm.estado.value.temEnvioPendente)
    }

    @Test
    fun `a linha dos termos traz o valor da vaga e os inclusos dela, como no iOS`() {
        val termos = TermosDaVagaAberta(vagaAberta, 15000, incluiRefeicao = true, incluiTransporte = false, exigeMaterialProprio = true)
        assertEquals("R$\u00A0150,00, Refeição inclusa, sem transporte, Exige material próprio", linhaDosTermos(termos))
        assertEquals(
            "Esta chamada vai com os termos da vaga já aberta: R$\u00A0150,00, Refeição inclusa, sem transporte, Exige material próprio",
            TextosChamadaCasa.buscaTermosDaVagaAberta(linhaDosTermos(termos)),
        )
    }

    // --- minhas_chamadas em mais de uma página (0.2.95, head final cc40db7) e os cenários da revisão do #808 ----------

    @Test
    fun `409 com a chamada da vaga aberta so na 2a pagina de minhas_chamadas segue o cursor, acha, compara e vai pelo vaga_id`() = runBlocking {
        val rede = RedeDeTeste().apply {
            ok("buscar_profissionais", pagina(ids("p", 1, 1)))
            comTrabalhoAberto(vagaAberta)
            comChamadasEmDuasPaginas(naPrimeira = "vaga-outra", naSegunda = vagaAberta)
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        vm.alternarSelecao("p-1")

        vm.chamar(trabalho).join()

        val leituras = rede.doNome("minhas_chamadas")
        assertEquals(2, leituras.size)
        assertEquals("c2", leituras.last().corpo["cursor"]?.jsonPrimitive?.content)
        val pedidos = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals(listOf(null, vagaAberta), pedidos.map { it["vaga_id"]?.jsonPrimitive?.content })
        assertEquals(vagaAberta, vagaDoResultado(vm.estado.value, "p-1"))
        assertNull(vm.estado.value.termosParaConfirmar)
    }

    @Test
    fun `409 sem a chamada da vaga aberta em nenhuma pagina de minhas_chamadas le todas, nao repete pelo vaga_id e vira o erro generico`() = runBlocking {
        val rede = RedeDeTeste().apply {
            ok("buscar_profissionais", pagina(ids("p", 1, 1)))
            comTrabalhoAberto(vagaAberta)
            comChamadasEmDuasPaginas(naPrimeira = "vaga-outra-1", naSegunda = "vaga-outra-2")
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        vm.alternarSelecao("p-1")

        vm.chamar(trabalho).join()

        assertEquals(2, rede.doNome("minhas_chamadas").size)
        val pedidos = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals(1, pedidos.size)
        assertTrue(pedidos.none { "vaga_id" in it })
        assertEquals(ResultadoDaChamadaDaBusca.Erro(TextosChamadaCasa.ERRO), vm.estado.value.resultadosDaChamada["p-1"])
        assertNull(vm.estado.value.termosParaConfirmar)
        assertFalse(vm.estado.value.temEnvioPendente)
    }

    @Test
    fun `confirmar com tres esperando manda um pedido por pessoa, todos pelo vaga_id, com chaves novas e distintas`() = runBlocking {
        val rede = RedeDeTeste().apply {
            ok("buscar_profissionais", pagina(ids("p", 1, 3)))
            comTrabalhoAberto(vagaAberta)
            comTermosDaVaga(vagaAberta, valorCentavos = 25000)
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2", "p-3").forEach(vm::alternarSelecao)
        vm.chamar(trabalho).join()
        val antes = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals(1, antes.size)

        vm.confirmarTermosDaVagaAberta().join()

        val depois = rede.doNome("chamar_profissional").map { it.corpo }.drop(1)
        assertEquals(listOf("p-1", "p-2", "p-3"), depois.map { it["profissional_id"]!!.jsonPrimitive.content })
        assertTrue(depois.all { it["vaga_id"]?.jsonPrimitive?.content == vagaAberta && "valor_centavos" !in it })
        val chaves = depois.map { it["chave"]!!.jsonPrimitive.content }
        assertEquals(3, chaves.toSet().size)
        assertFalse(antes[0]["chave"]!!.jsonPrimitive.content in chaves)
        assertEquals(listOf(vagaAberta, vagaAberta, vagaAberta), listOf("p-1", "p-2", "p-3").map { vagaDoResultado(vm.estado.value, it) })
    }

    @Test
    fun `409 com os mesmos termos e o pedido pelo vaga_id incerto nao para a rodada, e o reenvio repete a mesma chave`() = runBlocking {
        val rede = RedeDeTeste().apply {
            ok("buscar_profissionais", pagina(ids("p", 1, 2)))
            comTermosDaVaga(vagaAberta)
        }
        var perdeu = false
        rede.rota("chamar_profissional") { pedido ->
            val vaga = pedido.corpo["vaga_id"]?.jsonPrimitive?.content
            when {
                vaga != vagaAberta -> respond(trabalhoJaAberto(vagaAberta), HttpStatusCode.Conflict, json)
                pedido.corpo["profissional_id"]!!.jsonPrimitive.content == "p-1" && !perdeu -> {
                    perdeu = true
                    respond("isto nao e json", HttpStatusCode.OK, json)
                }
                else -> respond(chamadaJson.replace("\"v1\"", "\"$vagaAberta\""), HttpStatusCode.OK, json)
            }
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        listOf("p-1", "p-2").forEach(vm::alternarSelecao)

        vm.chamar(trabalho).join()

        val pedidos = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals(listOf("p-1", "p-1", "p-2"), pedidos.map { it["profissional_id"]!!.jsonPrimitive.content })
        assertEquals(listOf(null, vagaAberta, vagaAberta), pedidos.map { it["vaga_id"]?.jsonPrimitive?.content })
        assertFalse(pedidos[0]["chave"] == pedidos[1]["chave"])
        val tela = vm.estado.value
        assertEquals(true, (tela.resultadosDaChamada["p-1"] as? ResultadoDaChamadaDaBusca.Erro)?.incerto)
        assertEquals(vagaAberta, vagaDoResultado(tela, "p-2"))
        assertTrue(tela.podeReenviar)

        vm.reenviar().join()

        val depois = rede.doNome("chamar_profissional").map { it.corpo }
        assertEquals(4, depois.size)
        assertEquals("p-1", depois[3]["profissional_id"]!!.jsonPrimitive.content)
        assertEquals(vagaAberta, depois[3]["vaga_id"]?.jsonPrimitive?.content)
        assertEquals(depois[1]["chave"], depois[3]["chave"])
        assertEquals(vagaAberta, vagaDoResultado(vm.estado.value, "p-1"))
        assertEquals(1, depois.count { "valor_centavos" in it })
    }

    /**
     * Quem espera o J7 (p-1) fica atrás de quem recebe o 409 com termos diferentes (p-2): outro aparelho abriu o mesmo
     * trabalho entre duas rodadas. Devolve a rede e a busca com os termos pendentes, depois do reenvio.
     */
    private suspend fun j7AtrasDosTermosDiferentes(): Pair<RedeDeTeste, BuscaDeProfissionaisViewModel> {
        val rede = RedeDeTeste().apply { ok("buscar_profissionais", pagina(ids("p", 1, 2))) }
        var aberta: String? = null
        rede.rota("chamar_profissional") { pedido ->
            val vaga = pedido.corpo["vaga_id"]?.jsonPrimitive?.content
            val confirmou = pedido.corpo["confirmo_recorrencia"]?.jsonPrimitive?.boolean == true
            when {
                aberta != null && vaga != aberta -> respond(trabalhoJaAberto(aberta!!), HttpStatusCode.Conflict, json)
                pedido.corpo["profissional_id"]!!.jsonPrimitive.content == "p-1" && !confirmou ->
                    respond("""{"code":"recorrencia_nao_confirmada","message":"x"}""", HttpStatusCode.Conflict, json)
                else -> respond(chamadaJson.replace("\"v1\"", "\"${vaga ?: "v1"}\""), HttpStatusCode.OK, json)
            }
        }
        val vm = viewModelCom(rede).comFiltros()
        vm.buscar().join()
        vm.alternarSelecao("p-1")
        vm.chamar(trabalho).join()
        assertTrue(vm.estado.value.mostrarJ7)
        // A seleção muda: o p-2 entra antes de quem espera o J7.
        listOf("p-1", "p-2", "p-1").forEach(vm::alternarSelecao)
        assertEquals(listOf("p-2", "p-1"), vm.estado.value.selecionados)
        aberta = vagaAberta
        rede.comTermosDaVaga(vagaAberta, valorCentavos = 25000, refeicao = true)
        vm.reenviar().join()
        return rede to vm
    }

    @Test
    fun `J7 atras dos termos diferentes, os termos vem primeiro, o J7 nao manda nada e so volta depois de confirmar os termos`() = runBlocking {
        val (rede, vm) = j7AtrasDosTermosDiferentes()
        var tela = vm.estado.value
        assertNotNull(tela.termosParaConfirmar)
        assertFalse(tela.mostrarJ7)
        assertEquals(ResultadoDaChamadaDaBusca.PedeConfirmacaoDeRecorrencia, tela.resultadosDaChamada["p-1"])
        val naRodada = rede.doNome("chamar_profissional").size

        // Com os termos pendentes, a confirmação do J7 não manda nada.
        vm.chamar(trabalho, confirmoRecorrencia = true).join()
        assertEquals(naRodada, rede.doNome("chamar_profissional").size)

        // Confirmar os termos: os dois saem pela vaga aberta; quem tinha J7 vai sem a confirmação e o servidor pede de novo.
        vm.confirmarTermosDaVagaAberta().join()
        val depois = rede.doNome("chamar_profissional").map { it.corpo }.drop(naRodada)
        assertTrue(depois.all { it["vaga_id"]?.jsonPrimitive?.content == vagaAberta && "valor_centavos" !in it })
        tela = vm.estado.value
        assertEquals(vagaAberta, vagaDoResultado(tela, "p-2"))
        assertEquals(ResultadoDaChamadaDaBusca.PedeConfirmacaoDeRecorrencia, tela.resultadosDaChamada["p-1"])
        assertTrue(tela.mostrarJ7)
        assertNull(tela.termosParaConfirmar)

        // Agora o J7 confirmado sai, pela vaga aberta.
        vm.chamar(trabalho, confirmoRecorrencia = true).join()
        val ultimo = rede.doNome("chamar_profissional").last().corpo
        assertEquals("p-1", ultimo["profissional_id"]!!.jsonPrimitive.content)
        assertEquals(vagaAberta, ultimo["vaga_id"]?.jsonPrimitive?.content)
        assertTrue(ultimo["confirmo_recorrencia"]!!.jsonPrimitive.boolean)
        assertEquals(vagaAberta, vagaDoResultado(vm.estado.value, "p-1"))
    }

    @Test
    fun `J7 atras dos termos diferentes, cancelar os termos nao manda nada e religa o J7`() = runBlocking {
        val (rede, vm) = j7AtrasDosTermosDiferentes()
        val naRodada = rede.doNome("chamar_profissional").size

        vm.cancelarTermosDaVagaAberta()

        val tela = vm.estado.value
        assertEquals(naRodada, rede.doNome("chamar_profissional").size)
        assertNull(tela.termosParaConfirmar)
        assertTrue(tela.mostrarJ7)
        assertEquals(ResultadoDaChamadaDaBusca.PedeConfirmacaoDeRecorrencia, tela.resultadosDaChamada["p-1"])
    }
}
