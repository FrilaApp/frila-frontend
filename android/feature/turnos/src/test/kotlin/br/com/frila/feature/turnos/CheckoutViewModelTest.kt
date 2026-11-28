package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.localizacao.LeituraDeLocalizacao
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.EventoDeTelemetria
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import java.time.Instant
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** L1-4: o check-out do profissional (`fazer_checkout`), no mesmo controlador do check-in do turno. */
class CheckoutViewModelTest {

    private val turnoId = "11111111-1111-1111-1111-111111111111"
    private val vaga = Coordenada(latitude = -15.7942, longitude = -47.8822)
    private val aUns111Metros = Coordenada(latitude = -15.7932, longitude = -47.8822)
    private val agora = Instant.parse("2026-11-02T03:10:00Z")
    private val registroJson =
        """{"turno_id":"$turnoId","tipo":"geolocalizado","verificacao":"verificado","registrado_em":"2026-11-02T03:10:00Z","distancia_m":111}"""

    private class Rede(val resposta: () -> Pair<HttpStatusCode, String>) {
        val corpos = mutableListOf<kotlinx.serialization.json.JsonObject>()
        val caminhos = mutableListOf<String>()
    }

    private fun viewModel(
        rede: Rede,
        provedor: ProvedorDeLocalizacao,
        antesDeResponder: suspend () -> Unit = {},
        registrarEvento: (EventoDeTelemetria, String?, String?) -> Unit = { _, _, _ -> },
    ): CheckinViewModel {
        val engine = MockEngine { request ->
            rede.caminhos += request.url.encodedPath
            rede.corpos += ClienteSupabase.jsonFrila.parseToJsonElement((request.body as TextContent).text).jsonObject
            antesDeResponder()
            val (status, corpo) = rede.resposta()
            respond(corpo, status, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        return CheckinViewModel(
            turnoId = turnoId,
            coordenadaDaVaga = vaga,
            servicoTurnos = ServicoTurnos(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine)),
            provedorDeLocalizacao = provedor,
            instanteAtual = { agora },
            registrarEvento = registrarEvento,
            escopo = CoroutineScope(Dispatchers.Default),
        )
    }

    private fun provedor(
        permissao: Boolean = true,
        gps: Boolean = true,
        leitura: LeituraDeLocalizacao? = LeituraDeLocalizacao(aUns111Metros, precisaoMetros = 10f, simulada = false),
    ): ProvedorDeLocalizacao {
        val p = mockk<ProvedorDeLocalizacao>()
        every { p.temPermissaoDeLocalizacao() } returns permissao
        every { p.isGpsAtivado() } returns gps
        coEvery { p.lerParaCheckin() } returns leitura
        return p
    }

    @Test
    fun `telemetria registra tentativa checkin e checkout sem repetir conclusoes`() = runBlocking {
        val eventos = mutableListOf<Triple<EventoDeTelemetria, String?, String?>>()
        val vm = viewModel(Rede { HttpStatusCode.OK to registroJson }, provedor(),
            registrarEvento = { evento, vaga, turno -> eventos += Triple(evento, vaga, turno) })
        vm.fazerCheckin().join()
        vm.fazerCheckin().join()
        vm.fazerCheckout().join()
        vm.fazerCheckout().join()
        assertEquals(listOf(EventoDeTelemetria.CHECKIN_TENTADO, EventoDeTelemetria.CHECKIN_CONCLUIDO,
            EventoDeTelemetria.CHECKIN_TENTADO, EventoDeTelemetria.CHECKOUT_CONCLUIDO), eventos.map { it.first })
        assertTrue(eventos.all { it.second == null && it.third == turnoId })
    }

    @Test
    fun `telemetria de checkin recusado so registra tentativa`() = runBlocking {
        val eventos = mutableListOf<EventoDeTelemetria>()
        val vm = viewModel(Rede { HttpStatusCode.UnprocessableEntity to """{"code":"fora_da_janela","message":"sintetico"}""" }, provedor(),
            registrarEvento = { evento, _, _ -> eventos += evento })
        vm.fazerCheckin().join()
        vm.fazerCheckout().join()
        assertEquals(listOf(EventoDeTelemetria.CHECKIN_TENTADO), eventos)
    }

    @Test
    fun `fazer check-out manda so a distancia e a hora do toque e fica feito`() = runBlocking {
        val rede = Rede { HttpStatusCode.OK to registroJson }
        val vm = viewModel(rede, provedor())

        vm.fazerCheckout().join()

        assertEquals(listOf("/rest/v1/rpc/fazer_checkout"), rede.caminhos)
        assertEquals(setOf("turno_id", "distancia_m", "registrado_em"), rede.corpos.single().keys)
        assertEquals("111", rede.corpos.single()["distancia_m"]!!.jsonPrimitive.content)
        assertEquals("2026-11-02T03:10:00Z", rede.corpos.single()["registrado_em"]!!.jsonPrimitive.content)
        assertEquals(StatusCheckout.FEITO, vm.estado.value.checkout)
        assertNull(vm.estado.value.mensagemErroCheckout)
    }

    @Test
    fun `o check-out nao mexe no estado do check-in`() = runBlocking {
        val vm = viewModel(Rede { HttpStatusCode.OK to registroJson }, provedor())

        vm.fazerCheckout().join()

        assertEquals(StatusCheckin.OCIOSO, vm.estado.value.status)
        assertNull(vm.estado.value.comprovante)
        assertNull(vm.estado.value.dialogoDefensivo)
        assertTrue(!vm.estado.value.pedirPermissao)
    }

    @Test
    fun `sem permissao o check-out segue com distancia nula e sem pedir nada`() = runBlocking {
        val rede = Rede { HttpStatusCode.OK to registroJson }
        val vm = viewModel(rede, provedor(permissao = false))

        vm.fazerCheckout().join()

        assertTrue(rede.corpos.single()["distancia_m"] is JsonNull)
        assertEquals(StatusCheckout.FEITO, vm.estado.value.checkout)
        assertTrue(!vm.estado.value.pedirPermissao)
        assertNull(vm.estado.value.dialogoDefensivo)
    }

    @Test
    fun `GPS desligado ou leitura imprecisa seguem com distancia nula`() = runBlocking {
        val gps = Rede { HttpStatusCode.OK to registroJson }
        viewModel(gps, provedor(gps = false)).fazerCheckout().join()
        val imprecisa = Rede { HttpStatusCode.OK to registroJson }
        val ruim = LeituraDeLocalizacao(aUns111Metros, precisaoMetros = 250f, simulada = false)
        viewModel(imprecisa, provedor(leitura = ruim)).fazerCheckout().join()

        assertTrue(gps.corpos.single()["distancia_m"] is JsonNull)
        assertTrue(imprecisa.corpos.single()["distancia_m"] is JsonNull)
    }

    @Test
    fun `cada recusa do servidor vira uma mensagem e deixa tentar de novo`() = runBlocking {
        val casos = listOf(
            Triple(HttpStatusCode.Conflict, "checkin_pendente", TextosCheckoutECodigo.CHECKOUT_SEM_CHECKIN),
            Triple(HttpStatusCode.UnprocessableEntity, "fora_da_janela", TextosCheckoutECodigo.CHECKOUT_FORA_DA_JANELA),
            Triple(HttpStatusCode.UnprocessableEntity, "registro_no_futuro", TextosCheckoutECodigo.CHECKOUT_HORARIO_ERRADO),
            Triple(HttpStatusCode.NotFound, "nao_encontrado", TextosCheckoutECodigo.CHECKOUT_NAO_ENCONTRADO),
            // rclJTMOK: 401 e 403 com o texto do iOS (MensagemDoErroAPI.texto), não mais o "Tente de novo".
            Triple(HttpStatusCode.Unauthorized, "nao_autenticado", "Sua sessão expirou. Entre novamente para continuar."),
            Triple(HttpStatusCode.Forbidden, "sem_permissao", "Sua conta não pode realizar esta ação."),
        )
        for ((status, codigo, mensagem) in casos) {
            val vm = viewModel(Rede { status to """{"code":"$codigo","message":"x"}""" }, provedor())

            vm.fazerCheckout().join()

            assertEquals(StatusCheckout.ERRO, vm.estado.value.checkout, codigo)
            assertEquals(mensagem, vm.estado.value.mensagemErroCheckout, codigo)
        }
    }

    @Test
    fun `resposta que nao e JSON vira erro generico, sem derrubar nem prender o botao`() = runBlocking {
        val vm = viewModel(Rede { HttpStatusCode.OK to "<html>gateway</html>" }, provedor())

        vm.fazerCheckout().join()

        assertEquals(StatusCheckout.ERRO, vm.estado.value.checkout)
        assertEquals(TextosCheckoutECodigo.CHECKOUT_ERRO_PADRAO, vm.estado.value.mensagemErroCheckout)
    }

    @Test
    fun `depois de um erro, tentar de novo funciona e limpa a mensagem`() = runBlocking {
        var chamadas = 0
        val rede = Rede {
            chamadas++
            if (chamadas == 1) HttpStatusCode.UnprocessableEntity to """{"code":"fora_da_janela","message":"x"}"""
            else HttpStatusCode.OK to registroJson
        }
        val vm = viewModel(rede, provedor())
        vm.fazerCheckout().join()

        vm.fazerCheckout().join()

        assertEquals(StatusCheckout.FEITO, vm.estado.value.checkout)
        assertNull(vm.estado.value.mensagemErroCheckout)
        assertEquals(2, rede.caminhos.size)
    }

    @Test
    fun `dois toques seguidos enviam um check-out so`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        val rede = Rede { HttpStatusCode.OK to registroJson }
        val vm = viewModel(rede, provedor(), antesDeResponder = { liberar.await() })

        val primeiro = vm.fazerCheckout()
        kotlinx.coroutines.withTimeout(5_000) { while (vm.estado.value.checkout != StatusCheckout.REGISTRANDO) kotlinx.coroutines.yield() }
        val segundo = vm.fazerCheckout()
        liberar.complete(Unit)
        primeiro.join()
        segundo.join()

        assertEquals(1, rede.caminhos.size)
        assertEquals(StatusCheckout.FEITO, vm.estado.value.checkout)
    }
}
