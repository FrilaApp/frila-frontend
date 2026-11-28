package br.com.frila.feature.chamadas.casa

import br.com.frila.core.rede.ChamadaResumoDto
import io.ktor.client.engine.mock.respond
import io.ktor.client.network.sockets.ConnectTimeoutException
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonPrimitive
import java.time.Instant
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class AcompanharChamadasViewModelTest {

    private val casa = "11111111-1111-1111-1111-111111111111"
    private val vaga = "55555555-5555-5555-5555-555555555555"
    private val outraVaga = "99999999-9999-9999-9999-999999999999"
    private val garcom = "33333333-3333-3333-3333-333333333333"
    private val novaVaga = "88888888-8888-8888-8888-888888888888"

    private val reputacao = """{"positivas":7,"total":7,"turnos_considerados":7,"turnos_realizados":7}"""

    private fun resumo(id: String, vagaId: String, estado: String, motivo: String? = null, respondidaEm: String? = null) =
        """{"id":"$id","vaga_id":"$vagaId","profissional_id":"22222222-2222-2222-2222-222222222222","estabelecimento_id":"$casa","estado":"$estado","motivo_recusa":${motivo?.let { "\"$it\"" } ?: "null"},"expira_em":"2026-11-17T12:00:00Z","respondida_em":${respondidaEm?.let { "\"$it\"" } ?: "null"},"criada_em":"2026-11-16T15:00:00Z","funcao":{"id":"$garcom","nome":"Garçom","categoria":"salao"},"inicio_em":"2026-11-20T22:00:00Z","fim_em":"2026-11-21T02:00:00Z","valor_centavos":18000,"outra_parte":{"id":"22222222-2222-2222-2222-222222222222","tipo":"profissional","nome":"Maria S.","reputacao":$reputacao}}"""

    private fun pagina(vararg itens: String, proximo: String? = null) =
        """{"itens":[${itens.joinToString(",")}],"proximo_cursor":${proximo?.let { "\"$it\"" } ?: "null"}}"""

    private fun chamadaCancelada(id: String) =
        """{"id":"$id","vaga_id":"$vaga","profissional_id":"22222222-2222-2222-2222-222222222222","estabelecimento_id":"$casa","estado":"cancelada","expira_em":"2026-11-17T12:00:00Z","criada_em":"2026-11-16T15:00:00Z"}"""

    /** Antes do início do turno dos fixtures (`2026-11-20T22:00:00Z`): o relógio de verdade já passou dele. */
    private val antesDoInicio = Instant.parse("2026-11-17T10:00:00Z")

    private fun viewModelCom(rede: RedeDeTeste, prazoMs: Long = 5_000, agora: Instant = antesDoInicio): AcompanharChamadasViewModel {
        var contador = 0
        return AcompanharChamadasViewModel(
            vagaId = vaga,
            listar = rede.chamadas::minhasChamadas,
            cancelarChamada = rede.chamadas::cancelarChamada,
            publicarAPartirDaChamada = rede.chamadas::publicarAPartirDaChamada,
            novaChave = { "chave-${++contador}" },
            prazoMs = prazoMs,
            relogio = { agora },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
    }

    private val idA = "a0000000-0000-0000-0000-000000000001"
    private val idB = "a0000000-0000-0000-0000-000000000002"

    @Test
    fun `carregar fica so com as chamadas desta vaga e segue o cursor ate o fim`() = runBlocking {
        val rede = RedeDeTeste()
        val paginas = ArrayDeque(
            listOf(
                pagina(resumo(idA, vaga, "aberta"), resumo("x1", outraVaga, "aceita"), proximo = "c1"),
                pagina(resumo(idB, vaga, "recusada", motivo = "valor"), resumo("x2", outraVaga, "aberta")),
            ),
        )
        rede.rota("minhas_chamadas") { respond(paginas.removeFirst(), HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) }
        val vm = viewModelCom(rede)

        vm.carregar().join()

        assertEquals(listOf(idA, idB), vm.estado.value.chamadas.map { it.id })
        assertFalse(vm.estado.value.carregando)
        val pedidos = rede.doNome("minhas_chamadas")
        assertEquals(2, pedidos.size)
        assertFalse("cursor" in pedidos[0].corpo)
        assertEquals("c1", pedidos[1].corpo["cursor"]!!.jsonPrimitive.content)
        assertEquals("20", pedidos[1].corpo["limite"]!!.jsonPrimitive.content)
    }

    @Test
    fun `os estados ganham o rotulo do iOS e o motivo da recusa o texto, nunca o codigo`() {
        val tela = EstadoAcompanharChamadas()
        assertEquals("Aguardando resposta", tela.rotuloDoEstado("aberta"))
        assertEquals("Aceita", tela.rotuloDoEstado("aceita"))
        assertEquals("Recusada", tela.rotuloDoEstado("recusada"))
        assertEquals("Expirada", tela.rotuloDoEstado("expirada"))
        assertEquals("Cancelada", tela.rotuloDoEstado("cancelada"))
        assertEquals("Encerrada", tela.rotuloDoEstado("encerrada"))
        assertEquals("Conflito de agenda", textoDoMotivoDeRecusa("agenda"))
        assertEquals("Distância ou transporte", textoDoMotivoDeRecusa("distancia"))
        assertEquals("Valor proposto", textoDoMotivoDeRecusa("valor"))
        assertEquals("Tipo de serviço", textoDoMotivoDeRecusa("tipo_de_servico"))
        assertEquals("Outro motivo", textoDoMotivoDeRecusa("outro"))
    }

    @Test
    fun `falha ao carregar fica como falha da carga, e nao como erro de acao, e tentar novamente recupera`() = runBlocking {
        var offline = true
        val rede = RedeDeTeste().apply {
            rota("minhas_chamadas") {
                if (offline) throw ConnectTimeoutException("sem rota", null)
                respond(pagina(resumo(idA, vaga, "aberta")), HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            }
        }
        val vm = viewModelCom(rede)

        vm.carregar().join()
        assertEquals(TextosChamadaCasa.ERRO, vm.estado.value.falhaAoCarregar)
        assertNull(vm.estado.value.erro)
        assertFalse(vm.estado.value.carregando)

        offline = false
        vm.carregar().join()
        assertNull(vm.estado.value.falhaAoCarregar)
        assertNull(vm.estado.value.erro)
        assertEquals(1, vm.estado.value.chamadas.size)
    }

    @Test
    fun `chave chamada_direta desligada no servidor mostra o texto de desligado`() = runBlocking {
        val rede = RedeDeTeste().apply { recusa("minhas_chamadas", HttpStatusCode.Forbidden, "sem_permissao", "recurso_desligado") }
        val vm = viewModelCom(rede)

        vm.carregar().join()

        assertEquals(TextosChamadaCasa.DESLIGADO, vm.estado.value.falhaAoCarregar)
        assertNull(vm.estado.value.erro)
    }

    @Test
    fun `prazo estourado ao carregar vira erro sem prender em carregando`() = runBlocking {
        val rede = RedeDeTeste().apply {
            rota("minhas_chamadas") { delay(10_000); respond(pagina(), HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) }
        }
        val vm = viewModelCom(rede, prazoMs = 100)

        vm.carregar().join()

        assertEquals(TextosChamadaCasa.ERRO, vm.estado.value.falhaAoCarregar)
        assertNull(vm.estado.value.erro)
        assertFalse(vm.estado.value.carregando)
    }

    @Test
    fun `cancelar com sucesso e a releitura falhando mostra o sucesso, guarda a lista e marca so a falha da carga`() = runBlocking {
        val rede = RedeDeTeste()
        var cancelada = false
        rede.rota("minhas_chamadas") {
            if (cancelada) throw ConnectTimeoutException("sem rota", null)
            respond(pagina(resumo(idA, vaga, "aberta")), HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        rede.rota("cancelar_chamada") {
            cancelada = true
            respond(chamadaCancelada(idA), HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.cancelar(idA).join()

        assertEquals(TextosChamadaCasa.CHAMADA_CANCELADA_SUCESSO, vm.estado.value.sucesso)
        assertNull(vm.estado.value.erro)
        assertEquals(TextosChamadaCasa.ERRO, vm.estado.value.falhaAoCarregar)
        assertEquals(1, vm.estado.value.chamadas.size)
    }

    @Test
    fun `cancelar uma chamada aberta chama o RPC, relê a lista e mostra o sucesso`() = runBlocking {
        val rede = RedeDeTeste()
        var cancelada = false
        rede.rota("minhas_chamadas") {
            val estado = if (cancelada) "cancelada" else "aberta"
            respond(pagina(resumo(idA, vaga, estado)), HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        rede.rota("cancelar_chamada") {
            cancelada = true
            respond(chamadaCancelada(idA), HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.cancelar(idA).join()

        assertEquals(idA, rede.doNome("cancelar_chamada").single().corpo["chamada_id"]!!.jsonPrimitive.content)
        assertEquals("cancelada", vm.estado.value.chamadas.single().estado)
        assertEquals(TextosChamadaCasa.CHAMADA_CANCELADA_SUCESSO, vm.estado.value.sucesso)
        assertNull(vm.estado.value.erro)
        assertFalse(vm.estado.value.acaoEmVoo)
    }

    @Test
    fun `cancelar so vale para chamada aberta da lista`() = runBlocking {
        val rede = RedeDeTeste()
        rede.ok("minhas_chamadas", pagina(resumo(idA, vaga, "aceita"), resumo(idB, vaga, "recusada")))
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.cancelar(idA).join()
        vm.cancelar(idB).join()
        vm.cancelar("nao-esta-na-lista").join()

        assertTrue(rede.doNome("cancelar_chamada").isEmpty())
    }

    @Test
    fun `cancelar uma chamada ja respondida explica e relê a lista`() = runBlocking {
        val rede = RedeDeTeste()
        rede.ok("minhas_chamadas", pagina(resumo(idA, vaga, "aberta")))
        rede.recusa("cancelar_chamada", HttpStatusCode.Conflict, "chamada_indisponivel")
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.cancelar(idA).join()

        assertEquals(TextosChamadaCasa.CHAMADA_JA_RESPONDIDA, vm.estado.value.erro)
        assertNull(vm.estado.value.sucesso)
        assertFalse(vm.estado.value.acaoEmVoo)
        assertEquals(2, rede.doNome("minhas_chamadas").size)
    }

    @Test
    fun `outro erro ao cancelar mostra a mensagem generica e solta a acao`() = runBlocking {
        val rede = RedeDeTeste()
        rede.ok("minhas_chamadas", pagina(resumo(idA, vaga, "aberta")))
        rede.recusa("cancelar_chamada", HttpStatusCode.Forbidden, "sem_permissao")
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.cancelar(idA).join()

        assertEquals(TextosChamadaCasa.ERRO, vm.estado.value.erro)
        assertFalse(vm.estado.value.acaoEmVoo)
    }

    @Test
    fun `publicar para todos so aparece quando nenhuma chamada foi aceita e nenhuma segue aberta`() = runBlocking {
        val casos = mapOf(
            "todas recusadas, expiradas ou canceladas" to (listOf("recusada", "expirada", "cancelada", "encerrada") to true),
            "uma aberta" to (listOf("recusada", "aberta") to false),
            "uma aceita" to (listOf("recusada", "aceita") to false),
            "so aceita" to (listOf("aceita") to false),
        )
        for ((nome, caso) in casos) {
            val (estados, esperado) = caso
            val rede = RedeDeTeste()
            rede.ok("minhas_chamadas", pagina(*estados.mapIndexed { i, e -> resumo("a000000$i", vaga, e) }.toTypedArray()))
            val vm = viewModelCom(rede)
            vm.carregar().join()
            assertEquals(esperado, vm.estado.value.podePublicarParaTodos, nome)
        }
        val vazio = RedeDeTeste().apply { ok("minhas_chamadas", pagina()) }
        val vm = viewModelCom(vazio)
        vm.carregar().join()
        assertFalse(vm.estado.value.podePublicarParaTodos)
    }

    @Test
    fun `publicar para todos manda a vaga, a chave e o modo urgencia e guarda a vaga aberta`() = runBlocking {
        val rede = RedeDeTeste()
        rede.ok("minhas_chamadas", pagina(resumo(idA, vaga, "recusada")))
        rede.ok("publicar_a_partir_da_chamada", """{"vaga_id":"$novaVaga","posicoes":["p1"]}""")
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.publicarParaTodos().join()

        val corpo = rede.doNome("publicar_a_partir_da_chamada").single().corpo
        assertEquals(vaga, corpo["vaga_id"]!!.jsonPrimitive.content)
        assertEquals("chave-1", corpo["chave"]!!.jsonPrimitive.content)
        assertEquals("urgencia", corpo["modo"]!!.jsonPrimitive.content)
        assertEquals(novaVaga, vm.estado.value.vagaPublicadaId)
        assertEquals(TextosChamadaCasa.VAGA_PUBLICADA_SUCESSO, vm.estado.value.sucesso)
        // Depois de publicar, o botão some: não existe uma segunda vaga.
        assertFalse(vm.estado.value.podePublicarParaTodos)
        vm.publicarParaTodos().join()
        assertEquals(1, rede.doNome("publicar_a_partir_da_chamada").size)
    }

    @Test
    fun `publicar para todos sem a condicao nao chama nada`() = runBlocking {
        val rede = RedeDeTeste()
        rede.ok("minhas_chamadas", pagina(resumo(idA, vaga, "aberta")))
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.publicarParaTodos().join()

        assertTrue(rede.doNome("publicar_a_partir_da_chamada").isEmpty())
    }

    @Test
    fun `sem rede ao publicar mantem a chave, e o toque seguinte reenvia a mesma`() = runBlocking {
        var offline = true
        val rede = RedeDeTeste()
        rede.ok("minhas_chamadas", pagina(resumo(idA, vaga, "expirada")))
        rede.rota("publicar_a_partir_da_chamada") {
            if (offline) throw ConnectTimeoutException("sem rota", null)
            respond("""{"vaga_id":"$novaVaga","posicoes":["p1"]}""", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.publicarParaTodos().join()
        assertEquals(TextosChamadaCasa.ERRO, vm.estado.value.erro)
        assertFalse(vm.estado.value.acaoEmVoo)
        assertNull(vm.estado.value.vagaPublicadaId)

        offline = false
        vm.publicarParaTodos().join()

        val chaves = rede.doNome("publicar_a_partir_da_chamada").map { it.corpo["chave"]!!.jsonPrimitive.content }
        assertEquals(listOf("chave-1", "chave-1"), chaves)
        assertEquals(novaVaga, vm.estado.value.vagaPublicadaId)
    }

    @Test
    fun `recusa do servidor ao publicar solta a acao e a proxima tentativa leva chave nova`() = runBlocking {
        val rede = RedeDeTeste()
        rede.ok("minhas_chamadas", pagina(resumo(idA, vaga, "recusada")))
        // `403 sem_permissao`: quem toca deixou de ser membro da casa (publicar_a_partir_da_chamada, privado.eh_membro).
        rede.recusa("publicar_a_partir_da_chamada", HttpStatusCode.Forbidden, "sem_permissao")
        val vm = viewModelCom(rede)
        vm.carregar().join()

        vm.publicarParaTodos().join()
        assertEquals(TextosChamadaCasa.ERRO, vm.estado.value.erro)
        assertFalse(vm.estado.value.acaoEmVoo)

        vm.publicarParaTodos().join()
        val chaves = rede.doNome("publicar_a_partir_da_chamada").map { it.corpo["chave"]!!.jsonPrimitive.content }
        assertEquals(listOf("chave-1", "chave-2"), chaves)
    }

    /**
     * `publicar_a_partir_da_chamada` (frila-backend `origin/develop`, `20261117190000_residuos_ordem_de_travas.sql`)
     * responde `409 vaga_encerrada` com a vaga direta cancelada, encerrada ou preenchida, ou fora da janela (RN35).
     */
    @Test
    fun `409 vaga_encerrada ao publicar explica, esconde o botao e rele a lista`() = runBlocking {
        val rede = RedeDeTeste()
        rede.ok("minhas_chamadas", pagina(resumo(idA, vaga, "recusada", respondidaEm = "2026-11-16T18:00:00Z")))
        rede.recusa("publicar_a_partir_da_chamada", HttpStatusCode.Conflict, "vaga_encerrada")
        val vm = viewModelCom(rede)
        vm.carregar().join()
        assertTrue(vm.estado.value.podePublicarParaTodos)

        vm.publicarParaTodos().join()

        assertEquals(TextosChamadaCasa.VAGA_ENCERRADA_AO_PUBLICAR, vm.estado.value.erro)
        assertFalse(vm.estado.value.podePublicarParaTodos)
        assertFalse(vm.estado.value.acaoEmVoo)
        assertEquals(2, rede.doNome("minhas_chamadas").size, "a lista é relida depois da recusa")
        vm.publicarParaTodos().join()
        assertEquals(1, rede.doNome("publicar_a_partir_da_chamada").size, "com a vaga encerrada não há segundo pedido")
    }

    @Test
    fun `o botao some quando a lista ja mostra a vaga encerrada`() = runBlocking {
        fun pode(vararg itens: String, agora: Instant = antesDoInicio): Boolean = runBlocking {
            val rede = RedeDeTeste().apply { ok("minhas_chamadas", pagina(*itens)) }
            val vm = viewModelCom(rede, agora = agora)
            vm.carregar().join()
            vm.estado.value.podePublicarParaTodos
        }
        // expirar_chamadas encerra a vaga direta quando a última chamada aberta expira.
        assertFalse(
            pode(resumo(idA, vaga, "recusada", respondidaEm = "2026-11-16T18:00:00Z"), resumo(idB, vaga, "expirada", respondidaEm = "2026-11-17T12:00:00Z")),
            "a última a fechar expirou",
        )
        // Recusa e cancelamento não encerram a vaga: se a última a fechar foi recusada, ainda dá para publicar.
        assertTrue(
            pode(resumo(idA, vaga, "expirada", respondidaEm = "2026-11-16T18:00:00Z"), resumo(idB, vaga, "recusada", respondidaEm = "2026-11-17T09:00:00Z")),
            "a última a fechar foi recusada",
        )
        // O turno já começou: fora da janela de conversão.
        assertFalse(pode(resumo(idA, vaga, "recusada", respondidaEm = "2026-11-16T18:00:00Z"), agora = Instant.parse("2026-11-20T22:00:00Z")), "o turno começou")
        assertTrue(pode(resumo(idA, vaga, "recusada", respondidaEm = "2026-11-16T18:00:00Z"), agora = Instant.parse("2026-11-20T21:59:00Z")), "falta um minuto")
        // Sem `respondida_em` não dá para saber quem fechou por último: o botão fica, e o 409 cuida do resto.
        assertTrue(pode(resumo(idA, vaga, "expirada")), "sem respondida_em")
    }

    @Test
    fun `vagaJaEncerrada devolve false enquanto houver chamada aberta mesmo com outra expirada respondida`() {
        val expirada = Json.decodeFromString<ChamadaResumoDto>(resumo(idA, vaga, "expirada", respondidaEm = "2026-11-17T12:00:00Z"))
        val aberta = Json.decodeFromString<ChamadaResumoDto>(resumo(idB, vaga, "aberta"))

        assertFalse(vagaJaEncerrada(listOf(expirada, aberta), antesDoInicio))
    }

    @Test
    fun `chamada expirada com outra aberta nao marca vaga encerrada e deixa publicar quando a aberta e recusada`() = runBlocking {
        val rede = RedeDeTeste()
        val leituras = ArrayDeque(
            listOf(
                pagina(resumo(idA, vaga, "expirada", respondidaEm = "2026-11-17T12:00:00Z"), resumo(idB, vaga, "aberta")),
                pagina(
                    resumo(idA, vaga, "expirada", respondidaEm = "2026-11-17T12:00:00Z"),
                    resumo(idB, vaga, "recusada", motivo = "agenda", respondidaEm = "2026-11-17T12:05:00Z"),
                ),
            ),
        )
        rede.rota("minhas_chamadas") { respond(leituras.removeFirst(), HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) }
        val vm = viewModelCom(rede)

        vm.carregar().join()
        assertFalse(vm.estado.value.vagaEncerrada)
        assertFalse(vm.estado.value.podePublicarParaTodos)

        vm.carregar().join()
        assertFalse(vm.estado.value.vagaEncerrada)
        assertTrue(vm.estado.value.podePublicarParaTodos)
    }

    @Test
    fun `vaga encerrada pela lista volta a aceitar publicacao quando uma leitura seguinte mostra a vaga viva`() = runBlocking {
        val rede = RedeDeTeste()
        val leituras = ArrayDeque(
            listOf(
                pagina(resumo(idA, vaga, "expirada", respondidaEm = "2026-11-17T12:00:00Z")),
                pagina(resumo(idA, vaga, "expirada", respondidaEm = "2026-11-17T12:00:00Z"), resumo(idB, vaga, "aberta")),
                pagina(
                    resumo(idA, vaga, "expirada", respondidaEm = "2026-11-17T12:00:00Z"),
                    resumo(idB, vaga, "recusada", respondidaEm = "2026-11-17T12:10:00Z"),
                ),
            ),
        )
        rede.rota("minhas_chamadas") { respond(leituras.removeFirst(), HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json")) }
        val vm = viewModelCom(rede)

        vm.carregar().join()
        assertTrue(vm.estado.value.vagaEncerrada)
        assertFalse(vm.estado.value.podePublicarParaTodos)

        vm.carregar().join()
        assertFalse(vm.estado.value.vagaEncerrada)
        assertFalse(vm.estado.value.podePublicarParaTodos)

        vm.carregar().join()
        assertFalse(vm.estado.value.vagaEncerrada)
        assertTrue(vm.estado.value.podePublicarParaTodos)
    }

    @Test
    fun `409 vaga_encerrada ao publicar segue escondendo o botao mesmo apos recarregar a lista`() = runBlocking {
        val rede = RedeDeTeste()
        rede.ok("minhas_chamadas", pagina(resumo(idA, vaga, "recusada", respondidaEm = "2026-11-16T18:00:00Z")))
        rede.recusa("publicar_a_partir_da_chamada", HttpStatusCode.Conflict, "vaga_encerrada")
        val vm = viewModelCom(rede)
        vm.carregar().join()
        assertTrue(vm.estado.value.podePublicarParaTodos)

        vm.publicarParaTodos().join()
        assertTrue(vm.estado.value.vagaEncerrada)
        assertFalse(vm.estado.value.podePublicarParaTodos)

        vm.carregar().join()
        assertTrue(vm.estado.value.vagaEncerrada)
        assertFalse(vm.estado.value.podePublicarParaTodos)
    }
}
