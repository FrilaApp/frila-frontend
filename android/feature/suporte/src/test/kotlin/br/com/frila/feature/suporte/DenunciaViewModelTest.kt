package br.com.frila.feature.suporte

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.MotivoDenuncia
import br.com.frila.core.dominio.modelo.TipoDeAlvo
import br.com.frila.core.rede.BloqueioDto
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.DenunciarDto
import br.com.frila.core.rede.ErroDaApi
import br.com.frila.core.rede.ProtocoloDto
import br.com.frila.core.rede.ServicoConfianca
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class DenunciaViewModelTest {

    private val alvoId = "11111111-1111-1111-1111-111111111111"
    private val relatoOk = "Relato com mais de dez caracteres."

    private val protocolo = ProtocoloDto(
        ocorrenciaId = "6f1c2a4e-1111-2222-3333-444455556666",
        tipo = "denuncia",
        criadaEm = "2026-11-10T12:00:00Z",
        prazoRespostaAte = "2026-11-17",
    )
    private val bloqueio = BloqueioDto("estabelecimento", alvoId, "2026-11-10T12:00:00Z")

    private fun erro(codigo: CodigoErroAPI, detalhes: String? = null) =
        ErroDaApi(codigo = codigo, codigoOriginal = codigo.name.lowercase(), detalhes = detalhes, mensagemCrua = "x")

    private class Fabrica {
        var contador = 0
        val corpos = mutableListOf<DenunciarDto>()
    }

    private fun viewModel(
        fabrica: Fabrica = Fabrica(),
        turnoId: String? = null,
        chamadaId: String? = null,
        bloquear: suspend (String, String) -> BloqueioDto = { _, _ -> bloqueio },
        denunciar: suspend (DenunciarDto) -> ProtocoloDto = { protocolo },
    ) = DenunciaViewModel(
        alvoTipo = TipoDeAlvo.ESTABELECIMENTO,
        alvoId = alvoId,
        denunciar = { corpo -> fabrica.corpos += corpo; denunciar(corpo) },
        bloquear = bloquear,
        turnoId = turnoId,
        chamadaId = chamadaId,
        gerarChave = { "chave-${++fabrica.contador}" },
        escopo = CoroutineScope(Dispatchers.Unconfined),
    )

    @Test
    fun `relato com menos de 10 caracteres nao sai e mostra o minimo`() = runBlocking {
        val fabrica = Fabrica()
        val vm = viewModel(fabrica)
        vm.editarRelato("curto")
        assertFalse(vm.estado.value.podeEnviar)

        vm.enviarDenuncia().join()

        assertTrue(fabrica.corpos.isEmpty())
        assertEquals(TextosSuporte.RELATO_MINIMO, vm.estado.value.erroDenuncia)
    }

    @Test
    fun `espacos nao contam para o minimo e o relato sai aparado`() = runBlocking {
        val fabrica = Fabrica()
        val vm = viewModel(fabrica)
        vm.editarRelato("   123456789   ")
        assertFalse(vm.estado.value.relatoValido)

        vm.editarRelato("  $relatoOk  ")
        vm.enviarDenuncia().join()

        assertEquals(relatoOk, fabrica.corpos.single().relato)
    }

    @Test
    fun `envia alvo, motivo, turno e chamada e guarda o protocolo`() = runBlocking {
        val fabrica = Fabrica()
        val vm = viewModel(fabrica, turnoId = "turno-1", chamadaId = "chamada-1")
        vm.escolherMotivo(MotivoDenuncia.RISCO_SEGURANCA)
        vm.editarRelato(relatoOk)

        vm.enviarDenuncia().join()

        val corpo = fabrica.corpos.single()
        assertEquals("estabelecimento", corpo.alvoTipo)
        assertEquals(alvoId, corpo.alvoId)
        assertEquals("risco_seguranca", corpo.motivo)
        assertEquals("turno-1", corpo.turnoId)
        assertEquals("chamada-1", corpo.chamadaId)
        assertEquals(protocolo, vm.estado.value.protocolo)
        assertFalse(vm.estado.value.enviando)
    }

    @Test
    fun `sem associacao, turno e chamada vao nulos`() = runBlocking {
        val fabrica = Fabrica()
        val vm = viewModel(fabrica)
        vm.editarRelato(relatoOk)

        vm.enviarDenuncia().join()

        assertNull(fabrica.corpos.single().turnoId)
        assertNull(fabrica.corpos.single().chamadaId)
    }

    @Test
    fun `reenviar o mesmo conteudo depois de falha reutiliza a chave, editar gera outra`() = runBlocking {
        val fabrica = Fabrica()
        var falhar = true
        val vm = viewModel(fabrica, denunciar = { if (falhar) throw erro(CodigoErroAPI.SEM_REDE) else protocolo })
        vm.editarRelato(relatoOk)

        vm.enviarDenuncia().join()
        vm.enviarDenuncia().join()
        assertEquals(TextosSuporte.ERRO_SEM_REDE, vm.estado.value.erroDenuncia)
        vm.editarRelato("$relatoOk Mais um detalhe.")
        vm.enviarDenuncia().join()
        falhar = false
        vm.enviarDenuncia().join()

        assertEquals(listOf("chave-1", "chave-1", "chave-2", "chave-2"), fabrica.corpos.map { it.chave })
    }

    @Test
    fun `trocar o motivo tambem gera outra chave`() = runBlocking {
        val fabrica = Fabrica()
        val vm = viewModel(fabrica, denunciar = { throw erro(CodigoErroAPI.SEM_REDE) })
        vm.editarRelato(relatoOk)
        vm.enviarDenuncia().join()
        vm.escolherMotivo(MotivoDenuncia.OUTRO)
        vm.enviarDenuncia().join()

        assertNotEquals(fabrica.corpos[0].chave, fabrica.corpos[1].chave)
    }

    @Test
    fun `segundo toque durante o envio e depois do protocolo nao abre outra denuncia`() = runBlocking {
        val liberar = CompletableDeferred<Unit>()
        val fabrica = Fabrica()
        val vm = viewModel(fabrica, denunciar = { liberar.await(); protocolo })
        vm.editarRelato(relatoOk)

        val primeiro = vm.enviarDenuncia()
        assertTrue(vm.estado.value.enviando)
        val segundo = vm.enviarDenuncia()
        liberar.complete(Unit)
        withTimeout(5_000) { primeiro.join(); segundo.join() }
        vm.enviarDenuncia().join()

        assertEquals(1, fabrica.corpos.size)
    }

    @Test
    fun `mapeia os erros da API para mensagens e libera a tela`() = runBlocking {
        val casos = listOf(
            erro(CodigoErroAPI.SEM_REDE) to TextosSuporte.ERRO_SEM_REDE,
            erro(CodigoErroAPI.CAMPO_INVALIDO, "relato") to TextosSuporte.RELATO_MINIMO,
            erro(CodigoErroAPI.CAMPO_OBRIGATORIO, "relato") to TextosSuporte.RELATO_MINIMO,
            erro(CodigoErroAPI.CAMPO_INVALIDO, "chamada_id") to TextosSuporte.ERRO_DADOS,
            erro(CodigoErroAPI.NAO_ENCONTRADO) to TextosSuporte.INDISPONIVEL,
            erro(CodigoErroAPI.CONTA_SUSPENSA) to TextosSuporte.ERRO_GENERICO,
        )
        casos.forEach { (falha, mensagem) ->
            val vm = viewModel(denunciar = { throw falha })
            vm.editarRelato(relatoOk)
            vm.enviarDenuncia().join()
            assertEquals(mensagem, vm.estado.value.erroDenuncia, "${falha.codigo} ${falha.detalhes}")
            assertFalse(vm.estado.value.enviando)
            assertNull(vm.estado.value.protocolo)
        }
    }

    @Test
    fun `excecao que nao e ErroDaApi nao deixa a tela travada em enviando`() = runBlocking {
        val vm = viewModel(denunciar = { throw IllegalStateException("html do gateway") })
        vm.editarRelato(relatoOk)

        vm.enviarDenuncia().join()

        assertFalse(vm.estado.value.enviando)
        assertEquals(TextosSuporte.ERRO_GENERICO, vm.estado.value.erroDenuncia)
    }

    @Test
    fun `bloqueio so acontece depois do dialogo e cancelar nao chama a API`() = runBlocking {
        var chamadas = 0
        val vm = viewModel(bloquear = { _, _ -> chamadas++; bloqueio })

        vm.abrirDialogoBloqueio()
        assertTrue(vm.estado.value.dialogoBloqueioAberto)
        assertEquals(0, chamadas)
        vm.cancelarBloqueio()

        assertFalse(vm.estado.value.dialogoBloqueioAberto)
        assertFalse(vm.estado.value.bloqueado)
        assertEquals(0, chamadas)
    }

    @Test
    fun `confirmar bloqueia o par certo uma vez e nao repete`() = runBlocking {
        val chamadas = mutableListOf<Pair<String, String>>()
        val vm = viewModel(bloquear = { tipo, id -> chamadas += tipo to id; bloqueio })

        vm.abrirDialogoBloqueio()
        vm.confirmarBloqueio().join()
        vm.confirmarBloqueio().join()
        vm.abrirDialogoBloqueio()

        assertEquals(listOf("estabelecimento" to alvoId), chamadas)
        assertTrue(vm.estado.value.bloqueado)
        assertFalse(vm.estado.value.dialogoBloqueioAberto)
    }

    @Test
    fun `falha no bloqueio mostra o erro, nao marca bloqueado e permite tentar de novo`() = runBlocking {
        var falhar = true
        val vm = viewModel(bloquear = { _, _ -> if (falhar) throw erro(CodigoErroAPI.SEM_REDE) else bloqueio })

        vm.abrirDialogoBloqueio()
        vm.confirmarBloqueio().join()

        assertEquals(TextosSuporte.ERRO_SEM_REDE, vm.estado.value.erroBloqueio)
        assertFalse(vm.estado.value.bloqueado)
        assertFalse(vm.estado.value.bloqueando)

        falhar = false
        vm.abrirDialogoBloqueio()
        assertNull(vm.estado.value.erroBloqueio)
        vm.confirmarBloqueio().join()
        assertTrue(vm.estado.value.bloqueado)
    }

    @Test
    fun `protocolo curto e prazo seguem as regras do contrato`() {
        assertEquals("6F1C2A4E", protocolo.protocoloCurto)
        assertEquals("17/11/2026", formatarPrazo("2026-11-17"))
        assertEquals("17/11/2026", formatarPrazo("2026-11-17T12:00:00Z"))
        assertEquals("amanhã", formatarPrazo("amanhã"))
    }

    @Test
    fun `contra o ServicoConfianca real o corpo sai no formato do contrato`() = runBlocking {
        var corpoDenuncia: kotlinx.serialization.json.JsonObject? = null
        var corpoBloqueio: kotlinx.serialization.json.JsonObject? = null
        val engine = MockEngine { request ->
            val json = ClienteSupabase.jsonFrila.parseToJsonElement((request.body as TextContent).text).jsonObject
            if (request.url.encodedPath.endsWith("/denunciar")) {
                corpoDenuncia = json
                respond(
                    """{"ocorrencia_id":"6f1c2a4e-1111-2222-3333-444455556666","tipo":"denuncia","criada_em":"2026-11-10T12:00:00Z","prazo_resposta_ate":"2026-11-17"}""",
                    HttpStatusCode.OK,
                    headersOf(HttpHeaders.ContentType, "application/json"),
                )
            } else {
                corpoBloqueio = json
                respond(
                    """{"alvo_tipo":"estabelecimento","alvo_id":"$alvoId","criado_em":"2026-11-10T12:00:00Z"}""",
                    HttpStatusCode.OK,
                    headersOf(HttpHeaders.ContentType, "application/json"),
                )
            }
        }
        val servico = ServicoConfianca(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
        val vm = DenunciaViewModel(
            alvoTipo = TipoDeAlvo.ESTABELECIMENTO,
            alvoId = alvoId,
            denunciar = servico::denunciar,
            bloquear = servico::bloquear,
            chamadaId = "33333333-3333-3333-3333-333333333333",
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
        vm.editarRelato(relatoOk)

        vm.enviarDenuncia().join()
        vm.abrirDialogoBloqueio()
        vm.confirmarBloqueio().join()

        assertEquals("33333333-3333-3333-3333-333333333333", corpoDenuncia!!["chamada_id"]!!.jsonPrimitive.content)
        assertEquals(JsonNull, corpoDenuncia!!["turno_id"])
        assertEquals("assedio", corpoDenuncia!!["motivo"]!!.jsonPrimitive.content)
        assertEquals(36, corpoDenuncia!!["chave"]!!.jsonPrimitive.content.length)
        assertEquals(setOf("alvo_tipo", "alvo_id"), corpoBloqueio!!.keys)
        assertEquals("6F1C2A4E", vm.estado.value.protocolo!!.protocoloCurto)
        assertTrue(vm.estado.value.bloqueado)
    }

    private fun viewModelComServicoReal(engine: MockEngine) = ServicoConfianca(
        ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine),
    ).let { servico ->
        DenunciaViewModel(
            alvoTipo = TipoDeAlvo.ESTABELECIMENTO,
            alvoId = alvoId,
            denunciar = servico::denunciar,
            bloquear = servico::bloquear,
            gerarChave = { "chave-1" },
            escopo = CoroutineScope(Dispatchers.Unconfined),
        )
    }

    private val html = headersOf(HttpHeaders.ContentType, "text/html")

    @Test
    fun `bloqueio com resposta nao JSON cai no catch generico, libera a tela e deixa tentar de novo`() = runBlocking {
        var gateway = true
        val vm = viewModelComServicoReal(MockEngine {
            if (gateway) respond("<html>502 Bad Gateway</html>", HttpStatusCode.OK, html)
            else respond("""{"alvo_tipo":"estabelecimento","alvo_id":"$alvoId","criado_em":"2026-11-10T12:00:00Z"}""", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        })

        vm.abrirDialogoBloqueio()
        vm.confirmarBloqueio().join()

        assertEquals(TextosSuporte.ERRO_GENERICO, vm.estado.value.erroBloqueio)
        assertFalse(vm.estado.value.bloqueando)
        assertFalse(vm.estado.value.bloqueado)

        gateway = false
        vm.abrirDialogoBloqueio()
        vm.confirmarBloqueio().join()
        assertTrue(vm.estado.value.bloqueado)
        assertNull(vm.estado.value.erroBloqueio)
    }

    @Test
    fun `bloqueio com erro 502 em HTML tambem cai no catch generico`() = runBlocking {
        val vm = viewModelComServicoReal(MockEngine { respond("<html>502</html>", HttpStatusCode.BadGateway, html) })

        vm.abrirDialogoBloqueio()
        vm.confirmarBloqueio().join()

        assertEquals(TextosSuporte.ERRO_GENERICO, vm.estado.value.erroBloqueio)
        assertFalse(vm.estado.value.bloqueando)
    }

    @Test
    fun `denuncia com resposta nao JSON cai no catch generico e a mesma chave serve na nova tentativa`() = runBlocking {
        val chaves = mutableListOf<String>()
        var gateway = true
        val vm = viewModelComServicoReal(MockEngine { request ->
            chaves += ClienteSupabase.jsonFrila.parseToJsonElement((request.body as TextContent).text).jsonObject["chave"]!!.jsonPrimitive.content
            if (gateway) respond("<html>502</html>", HttpStatusCode.OK, html)
            else respond(
                """{"ocorrencia_id":"6f1c2a4e-1111-2222-3333-444455556666","tipo":"denuncia","criada_em":"2026-11-10T12:00:00Z","prazo_resposta_ate":"2026-11-17"}""",
                HttpStatusCode.OK,
                headersOf(HttpHeaders.ContentType, "application/json"),
            )
        })
        vm.editarRelato(relatoOk)

        vm.enviarDenuncia().join()
        assertEquals(TextosSuporte.ERRO_GENERICO, vm.estado.value.erroDenuncia)
        assertFalse(vm.estado.value.enviando)

        gateway = false
        vm.enviarDenuncia().join()

        assertNotNull(vm.estado.value.protocolo)
        assertEquals(listOf("chave-1", "chave-1"), chaves)
    }
}
