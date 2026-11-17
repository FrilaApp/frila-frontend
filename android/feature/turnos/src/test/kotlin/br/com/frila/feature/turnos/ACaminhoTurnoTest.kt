package br.com.frila.feature.turnos

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.network.sockets.ConnectTimeoutException
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** "Estou a caminho" do profissional (US14, RF12; L2-1): a regra da janela e o envio de `avisar_a_caminho`. */
class ACaminhoTurnoTest {

    private val inicio = Instant.parse("2026-11-01T21:00:00Z")
    private val json = headersOf(HttpHeaders.ContentType, "application/json")

    private fun turnoJson(id: String = "t1", estado: String = "confirmada", aCaminhoEm: String? = null, checkinEm: String? = null) = """
        {
          "id": "$id", "posicao_id": "posicao-$id",
          "vaga": {"id": "vaga-$id", "funcao": "garçom", "local": "CLS 405 Bloco C", "regiao_administrativa": "Plano Piloto",
                   "inicio_em": "2026-11-01T21:00:00Z", "fim_em": "2026-11-02T03:00:00Z", "valor_centavos": 16000},
          "contraparte": {"id": "e1", "tipo": "estabelecimento", "nome": "Bar do Zé",
                          "reputacao": {"positivas": 1, "total": 1, "turnos_considerados": 1, "turnos_realizados": 1}},
          "a_caminho_em": ${aCaminhoEm?.let { "\"$it\"" } ?: "null"},
          "checkin_em": ${checkinEm?.let { "\"$it\"" } ?: "null"},
          "checkin_tipo": null, "checkin_distancia_m": null, "checkin_confirmado_em": null,
          "checkout_em": null, "checkout_distancia_m": null,
          "verificacao": "pendente", "valor_acordado_centavos": 16000, "pode_avaliar": false,
          "estado": "$estado", "avaliacao": null, "cancelamento": null
        }
    """.trimIndent()

    private class Pedido(val caminho: String, val corpo: String)

    private fun viewModelCom(
        agora: Instant,
        pedidos: MutableList<Pedido> = mutableListOf(),
        turno: String = turnoJson(),
        aoAvisar: suspend () -> io.ktor.client.engine.mock.MockRequestHandleScope.() -> io.ktor.client.request.HttpResponseData,
    ): MeusTurnosViewModel {
        val engine = MockEngine { request ->
            val caminho = request.url.encodedPath
            pedidos += Pedido(caminho, (request.body as? TextContent)?.text.orEmpty())
            if (caminho.endsWith("/avisar_a_caminho")) aoAvisar()() else respond("[$turno]", HttpStatusCode.OK, json)
        }
        val cliente = ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine)
        return MeusTurnosViewModel(ServicoTurnos(cliente), Clock.fixed(agora, ZoneOffset.UTC), CoroutineScope(Dispatchers.Default))
    }

    private fun respostaOk(em: String = "2026-11-01T20:30:00Z"): suspend () -> io.ktor.client.engine.mock.MockRequestHandleScope.() -> io.ktor.client.request.HttpResponseData = {
        { respond("""{"turno_id":"t1","a_caminho_em":"$em"}""", HttpStatusCode.OK, json) }
    }

    private fun recusa(status: HttpStatusCode, codigo: String, detalhes: String? = null): suspend () -> io.ktor.client.engine.mock.MockRequestHandleScope.() -> io.ktor.client.request.HttpResponseData = {
        { respond("""{"code":"$codigo","message":"x","details":${detalhes?.let { "\"$it\"" } ?: "null"}}""", status, json) }
    }

    private fun item(estado: String = "confirmada", aCaminhoEm: Instant? = null, comCheckin: Boolean = false) =
        ItemTurno(
            turnoId = "t1", posicaoId = "p1", inicio = inicio, funcaoNome = "garçom", estabelecimentoNome = "Bar do Zé",
            dataHorarioFormatado = "01/11 18:00", valorFormatado = "R$ 160,00", estado = estado, aCaminhoEm = aCaminhoEm,
            comprovante = if (comCheckin) br.com.frila.core.dominio.modelo.GeradorComprovanteCheckin.gerar(
                "t1", inicio, br.com.frila.core.dominio.modelo.TipoVerificacaoCheckin.GEOLOCALIZADO,
            ) else null,
        )

    // ---- a regra da janela: de 3 h antes até 15 min depois do início, confirmado, sem check-in e sem aviso ----

    @Test
    fun `a janela vai de 3 horas antes ate 15 minutos depois do inicio, com as bordas dentro`() {
        assertFalse(podeAvisarACaminho(item(), inicio.minusSeconds(3 * 3600 + 1)))
        assertTrue(podeAvisarACaminho(item(), inicio.minusSeconds(3 * 3600)))
        assertTrue(podeAvisarACaminho(item(), inicio))
        assertTrue(podeAvisarACaminho(item(), inicio.plusSeconds(15 * 60)))
        assertFalse(podeAvisarACaminho(item(), inicio.plusSeconds(15 * 60 + 1)))
    }

    @Test
    fun `nao pode avisar quem ja avisou, ja fez check-in ou tem turno que nao esta confirmado`() {
        val dentro = inicio.minusSeconds(3600)
        assertFalse(podeAvisarACaminho(item(aCaminhoEm = dentro), dentro))
        assertFalse(podeAvisarACaminho(item(comCheckin = true), dentro))
        assertFalse(podeAvisarACaminho(item(estado = "cancelada"), dentro))
        assertFalse(podeAvisarACaminho(item(estado = "cumprida"), dentro))
    }

    // ---- o mapeamento ----

    @Test
    fun `carregar leva o a_caminho_em do servidor para o item do turno`() = runBlocking {
        val vm = viewModelCom(inicio, turno = turnoJson(aCaminhoEm = "2026-11-01T20:10:00Z")) { respostaOk()() }

        vm.carregar().join()

        assertEquals(Instant.parse("2026-11-01T20:10:00Z"), vm.estado.value.agendados.single().aCaminhoEm)
    }

    // ---- o envio ----

    @Test
    fun `avisar manda POST avisar_a_caminho com o id do turno e marca o turno como avisado`() = runBlocking {
        val pedidos = mutableListOf<Pedido>()
        val vm = viewModelCom(inicio.minusSeconds(1800), pedidos, aoAvisar = respostaOk("2026-11-01T20:30:00Z"))
        vm.carregar().join()

        vm.avisarACaminho(vm.estado.value.agendados.single())!!.join()

        val envio = pedidos.single { it.caminho.endsWith("/avisar_a_caminho") }
        assertEquals("/rest/v1/rpc/avisar_a_caminho", envio.caminho)
        assertEquals("""{"turno_id":"t1"}""", envio.corpo.replace(" ", ""))
        assertEquals(Instant.parse("2026-11-01T20:30:00Z"), vm.estado.value.agendados.single().aCaminhoEm)
        assertNull(vm.estado.value.avisandoACaminho)
        assertNull(vm.estado.value.erroACaminho)
    }

    @Test
    fun `o horario do aviso vindo com deslocamento de zero horas e lido certo e marca o turno como avisado`() = runBlocking {
        val vm = viewModelCom(inicio.minusSeconds(1800), aoAvisar = respostaOk("2026-11-01T20:30:00+00:00"))
        vm.carregar().join()

        vm.avisarACaminho(vm.estado.value.agendados.single())!!.join()

        assertEquals(Instant.parse("2026-11-01T20:30:00Z"), vm.estado.value.agendados.single().aCaminhoEm)
        assertNull(vm.estado.value.erroACaminho)
        assertFalse(podeAvisarACaminho(vm.estado.value.agendados.single(), inicio.minusSeconds(1800)))
    }

    @Test
    fun `depois de avisado, outro toque nao dispara outro pedido`() = runBlocking {
        val pedidos = mutableListOf<Pedido>()
        val vm = viewModelCom(inicio.minusSeconds(1800), pedidos, aoAvisar = respostaOk())
        vm.carregar().join()
        vm.avisarACaminho(vm.estado.value.agendados.single())!!.join()

        val segundo = vm.avisarACaminho(vm.estado.value.agendados.single())

        assertNull(segundo)
        assertEquals(1, pedidos.count { it.caminho.endsWith("/avisar_a_caminho") })
    }

    @Test
    fun `fora da janela nao envia nada`() = runBlocking {
        val pedidos = mutableListOf<Pedido>()
        val vm = viewModelCom(inicio.minusSeconds(4 * 3600), pedidos, aoAvisar = respostaOk())
        vm.carregar().join()

        assertNull(vm.avisarACaminho(vm.estado.value.agendados.single()))

        assertEquals(0, pedidos.count { it.caminho.endsWith("/avisar_a_caminho") })
    }

    @Test
    fun `um envio por vez - o segundo toque com o primeiro em voo nao dispara outro pedido`() = runBlocking {
        val pedidos = mutableListOf<Pedido>()
        val solta = CompletableDeferred<Unit>()
        val vm = viewModelCom(inicio.minusSeconds(1800), pedidos) { solta.await(); respostaOk()() }
        vm.carregar().join()
        val turno = vm.estado.value.agendados.single()

        val primeiro = vm.avisarACaminho(turno)!!
        assertEquals("t1", vm.estado.value.avisandoACaminho)
        assertNull(vm.avisarACaminho(turno))
        solta.complete(Unit)
        primeiro.join()

        assertEquals(1, pedidos.count { it.caminho.endsWith("/avisar_a_caminho") })
        assertNull(vm.estado.value.avisandoACaminho)
    }

    private fun recusaEsperada(aoAvisar: suspend () -> io.ktor.client.engine.mock.MockRequestHandleScope.() -> io.ktor.client.request.HttpResponseData, texto: String) = runBlocking {
        val vm = viewModelCom(inicio.minusSeconds(1800), aoAvisar = aoAvisar)
        vm.carregar().join()
        val turno = vm.estado.value.agendados.single()

        vm.avisarACaminho(turno)!!.join()

        assertEquals("t1", vm.estado.value.erroACaminho?.turnoId)
        assertEquals(texto, vm.estado.value.erroACaminho?.mensagem)
        assertNull(vm.estado.value.avisandoACaminho)
        assertNull(vm.estado.value.agendados.single().aCaminhoEm)
        // Nenhuma falha trava o botão: dá para tentar de novo.
        assertNotNull(vm.avisarACaminho(turno))
    }

    @Test
    fun `422 fora da janela vira o texto da janela`() =
        recusaEsperada(recusa(HttpStatusCode.UnprocessableEntity, "a_caminho_fora_da_janela"), TextosACaminho.ERRO_FORA_DA_JANELA)

    @Test
    fun `403 conta suspensa vira o texto da suspensao`() =
        recusaEsperada(recusa(HttpStatusCode.Forbidden, "sem_permissao", "conta_suspensa"), TextosACaminho.ERRO_CONTA_SUSPENSA)

    @Test
    fun `403 de quem nao e o profissional do turno e 422 de campo obrigatorio viram o texto generico`() {
        recusaEsperada(recusa(HttpStatusCode.Forbidden, "sem_permissao"), TextosACaminho.ERRO_GENERICO)
        recusaEsperada(recusa(HttpStatusCode.UnprocessableEntity, "campo_obrigatorio", "turno_id"), TextosACaminho.ERRO_GENERICO)
    }

    @Test
    fun `sem rede vira o texto de conexao`() =
        recusaEsperada({ throw ConnectTimeoutException("sem rota", null) }, TextosACaminho.ERRO_SEM_REDE)

    @Test
    fun `resposta ilegivel de gateway vira o texto generico, sem o corpo cru`() =
        recusaEsperada(
            { { respond("<html>502</html>", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "text/html")) } },
            TextosACaminho.ERRO_GENERICO,
        )

    @Test
    fun `um aviso que deu certo limpa o erro anterior`() = runBlocking {
        var offline = true
        val vm = viewModelCom(inicio.minusSeconds(1800)) { if (offline) throw ConnectTimeoutException("sem rota", null) else respostaOk()() }
        vm.carregar().join()
        val turno = vm.estado.value.agendados.single()
        vm.avisarACaminho(turno)!!.join()
        assertEquals(TextosACaminho.ERRO_SEM_REDE, vm.estado.value.erroACaminho?.mensagem)

        offline = false
        vm.avisarACaminho(turno)!!.join()

        assertNull(vm.estado.value.erroACaminho)
        assertNotNull(vm.estado.value.agendados.single().aCaminhoEm)
    }
}
