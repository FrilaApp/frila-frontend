package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.dominio.modelo.TipoVerificacaoCheckin
import br.com.frila.core.localizacao.LeituraDeLocalizacao
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.network.sockets.ConnectTimeoutException
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Mesma ressalva de `MockEngine` + escopo próprio documentada em `MeusTurnosViewModelTest` e em
 * `br.com.frila.feature.entrada.entrada.EntradaViewModel`: o teste espera o `Job` com `.join()`.
 */
class CheckinViewModelTest {

    private val turnoId = "11111111-1111-1111-1111-111111111111"
    private val coordenadaDaVaga = Coordenada(latitude = -15.7942, longitude = -47.8822)
    // ~111 m ao norte da vaga: dentro do limite de 200 m (RN06).
    private val coordenadaProxima = Coordenada(latitude = -15.7932, longitude = -47.8822)
    // ~1,1 km ao norte da vaga: fora do limite de 200 m.
    private val coordenadaDistante = Coordenada(latitude = -15.7842, longitude = -47.8822)

    private fun servicoComResposta(json: String, status: HttpStatusCode = HttpStatusCode.OK): ServicoTurnos {
        val engine = MockEngine { respond(content = json, status = status, headers = headersOf(HttpHeaders.ContentType, "application/json")) }
        return ServicoTurnos(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))
    }

    private fun resultadoJson(tipo: String, verificacao: String, distanciaM: String = "null") = """
        {
          "turno_id": "$turnoId",
          "tipo": "$tipo",
          "verificacao": "$verificacao",
          "registrado_em": "2026-11-01T21:05:00Z",
          "distancia_m": $distanciaM
        }
    """.trimIndent()

    private fun criarViewModel(
        provedorDeLocalizacao: ProvedorDeLocalizacao,
        servicoTurnos: ServicoTurnos,
    ): CheckinViewModel = CheckinViewModel(
        turnoId = turnoId,
        coordenadaDaVaga = coordenadaDaVaga,
        servicoTurnos = servicoTurnos,
        provedorDeLocalizacao = provedorDeLocalizacao,
        escopo = CoroutineScope(Dispatchers.Default),
    )

    /** Cenário padrão: permissão concedida e GPS ativo — testes defensivos stubam explicitamente. */
    private fun provedorComPermissaoEGps(coordenada: Coordenada?, precisaoMetros: Float = 10f): ProvedorDeLocalizacao {
        val provedor = mockk<ProvedorDeLocalizacao>()
        every { provedor.temPermissaoDeLocalizacao() } returns true
        every { provedor.isGpsAtivado() } returns true
        coEvery { provedor.lerParaCheckin() } returns coordenada?.let {
            LeituraDeLocalizacao(coordenada = it, precisaoMetros = precisaoMetros, simulada = false)
        }
        return provedor
    }

    @Test
    fun `distancia ate 200m resulta em presenca verificada (RN06)`() = runBlocking {
        val provedor = provedorComPermissaoEGps(coordenadaProxima)
        val servico = servicoComResposta(resultadoJson(tipo = "geolocalizado", verificacao = "verificado", distanciaM = "111"))
        val viewModel = criarViewModel(provedor, servico)

        viewModel.fazerCheckin().join()

        assertEquals(StatusCheckin.VERIFICADO, viewModel.estado.value.status)
        val comprovante = viewModel.estado.value.comprovante
        assertNotNull(comprovante)
        assertEquals(TipoVerificacaoCheckin.GEOLOCALIZADO, comprovante!!.tipoVerificacao)
        assertTrue(comprovante.codigoAutenticacao.startsWith("CHK-"))
    }

    /** A posição do toque só serve para medir a distância: não fica no comprovante nem sai no texto que a pessoa compartilha. */
    @Test
    fun `o comprovante do check-in geolocalizado nao guarda nem compartilha a posicao`() = runBlocking {
        val provedor = provedorComPermissaoEGps(coordenadaProxima)
        val servico = servicoComResposta(resultadoJson(tipo = "geolocalizado", verificacao = "verificado", distanciaM = "111"))
        val viewModel = criarViewModel(provedor, servico)

        viewModel.fazerCheckin().join()

        val comprovante = viewModel.estado.value.comprovante!!
        assertEquals(TipoVerificacaoCheckin.GEOLOCALIZADO, comprovante.tipoVerificacao)
        val compartilhado = comprovante.textoCompartilhamento()
        assertTrue("Localização" !in compartilhado, compartilhado)
        assertTrue(!Regex("""-?\d{1,3}\.\d{2,}""").containsMatchIn(compartilhado), compartilhado)
    }

    @Test
    fun `distancia acima de 200m resulta em presenca manual pendente`() = runBlocking {
        val provedor = provedorComPermissaoEGps(coordenadaDistante)
        val servico = servicoComResposta(resultadoJson(tipo = "manual", verificacao = "pendente", distanciaM = "1100"))
        val viewModel = criarViewModel(provedor, servico)

        viewModel.fazerCheckin().join()

        assertEquals(StatusCheckin.MANUAL_PENDENTE, viewModel.estado.value.status)
        val comprovante = viewModel.estado.value.comprovante
        assertNotNull(comprovante)
        assertEquals(TipoVerificacaoCheckin.MANUAL_PENDENTE, comprovante!!.tipoVerificacao)
        assertTrue(comprovante.codigoAutenticacao.startsWith("CHK-"))
    }

    /**
     * Igual ao iOS (`RegraDePresenca.precisaoHorizontalMaximaMetros` e a etapa `.semGPS(.imprecisa)`): leitura com erro acima de
     * 100 m não prova presença. Nada sai sozinho: a tela diz o motivo e a pessoa escolhe tentar de novo ou o check-in manual.
     */
    @Test
    fun `leitura com precisao pior que 100 m mostra o motivo e nao envia nada ate a pessoa escolher`() = runBlocking {
        val provedor = mockk<ProvedorDeLocalizacao>()
        every { provedor.temPermissaoDeLocalizacao() } returns true
        every { provedor.isGpsAtivado() } returns true
        coEvery { provedor.lerParaCheckin() } returnsMany listOf(
            LeituraDeLocalizacao(coordenadaProxima, precisaoMetros = 150f, simulada = false),
            LeituraDeLocalizacao(coordenadaProxima, precisaoMetros = 20f, simulada = false),
        )
        val corpos = mutableListOf<String>()
        val viewModel = criarViewModel(provedor, servicoQueGrava(corpos, resultadoJson("geolocalizado", "verificado", distanciaM = "111")))

        viewModel.fazerCheckin().join()

        assertEquals(DialogoDefensivoLocalizacao.LEITURA_IMPRECISA, viewModel.estado.value.dialogoDefensivo)
        assertEquals(StatusCheckin.OCIOSO, viewModel.estado.value.status)
        assertTrue(corpos.isEmpty())

        // "Tentar de novo": fecha o aviso, lê de novo e, com a leitura boa, manda a distância.
        viewModel.fazerCheckin().join()
        assertEquals(null, viewModel.estado.value.dialogoDefensivo)
        assertTrue(Regex("\"distancia_m\":\\d+").containsMatchIn(corpos.single()))
    }

    @Test
    fun `leitura imprecisa e Continuar manual manda distancia_m nulo e fica manual pendente`() = runBlocking {
        val provedor = provedorComPermissaoEGps(coordenadaProxima, precisaoMetros = 150f)
        val corpos = mutableListOf<String>()
        val viewModel = criarViewModel(provedor, servicoQueGrava(corpos))
        viewModel.fazerCheckin().join()
        assertEquals(DialogoDefensivoLocalizacao.LEITURA_IMPRECISA, viewModel.estado.value.dialogoDefensivo)

        viewModel.prosseguirCheckinManual().join()

        assertTrue(corpos.single().contains("\"distancia_m\":null"))
        assertEquals(StatusCheckin.MANUAL_PENDENTE, viewModel.estado.value.status)
    }

    @Test
    fun `leitura com precisao de exatamente 100 m vale e manda a distancia`() = runBlocking {
        val provedor = provedorComPermissaoEGps(coordenadaProxima, precisaoMetros = 100f)
        var corpoRecebido: String? = null
        val engine = MockEngine { request ->
            corpoRecebido = (request.body as io.ktor.http.content.TextContent).text
            respond(
                content = resultadoJson(tipo = "geolocalizado", verificacao = "verificado", distanciaM = "111"),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoTurnos(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))
        val viewModel = criarViewModel(provedor, servico)

        viewModel.fazerCheckin().join()

        assertTrue(Regex("\"distancia_m\":\\d+").containsMatchIn(corpoRecebido!!))
        assertEquals(StatusCheckin.VERIFICADO, viewModel.estado.value.status)
    }

    @Test
    fun `com permissao e GPS mas sem fix (timeout), envia distancia_m nulo e vira manual pendente`() = runBlocking {
        val provedor = provedorComPermissaoEGps(coordenada = null)
        var corpoRecebido: String? = null
        val engine = MockEngine { request ->
            corpoRecebido = (request.body as io.ktor.http.content.TextContent).text
            respond(
                content = resultadoJson(tipo = "manual", verificacao = "pendente"),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoTurnos(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))
        val viewModel = criarViewModel(provedor, servico)

        viewModel.fazerCheckin().join()

        assertTrue(corpoRecebido!!.contains("\"distancia_m\":null"))
        assertEquals(StatusCheckin.MANUAL_PENDENTE, viewModel.estado.value.status)
    }

    @Test
    fun `erro fora_da_janela resulta em status ERRO com o texto proprio da janela`() = runBlocking {
        val provedor = provedorComPermissaoEGps(coordenadaProxima)
        val servico = servicoComResposta(
            json = """{"code":"fora_da_janela","message":"toque fora da janela do turno"}""",
            status = HttpStatusCode.UnprocessableEntity,
        )
        val viewModel = criarViewModel(provedor, servico)

        viewModel.fazerCheckin().join()

        assertEquals(StatusCheckin.ERRO, viewModel.estado.value.status)
        assertEquals("Fora do horário permitido para check-in deste turno.", viewModel.estado.value.mensagemErro)
    }

    // ---- 409 vaga_encerrada no check-in (cartão kcQICUG0): só teste, o mapeamento já existe ----

    private val textoDaPosicaoEncerrada = "Esta posição foi encerrada."

    @Test
    fun `409 vaga_encerrada no check-in com localizacao mostra que a posicao foi encerrada, e nao a mensagem generica`() = runBlocking {
        // O contrato (fazer_checkin): posição cancelada é `409 vaga_encerrada` com `details: posicao_cancelada`.
        for (detalhes in listOf("posicao_cancelada", null)) {
            val servico = servicoComResposta(
                json = """{"code":"vaga_encerrada","message":"x","details":${detalhes?.let { "\"$it\"" }}}""",
                status = HttpStatusCode.Conflict,
            )
            val viewModel = criarViewModel(provedorComPermissaoEGps(coordenadaProxima), servico)

            viewModel.fazerCheckin().join()

            assertEquals(StatusCheckin.ERRO, viewModel.estado.value.status, "$detalhes")
            assertEquals(textoDaPosicaoEncerrada, viewModel.estado.value.mensagemErro, "$detalhes")
            assertEquals(null, viewModel.estado.value.comprovante, "$detalhes")
        }
    }

    @Test
    fun `409 vaga_encerrada no check-in manual sem GPS mostra a mesma mensagem`() = runBlocking {
        val servico = servicoComResposta(
            json = """{"code":"vaga_encerrada","message":"x","details":"posicao_cancelada"}""",
            status = HttpStatusCode.Conflict,
        )
        val viewModel = criarViewModel(provedorComPermissaoEGps(coordenadaProxima), servico)

        viewModel.prosseguirCheckinManual().join()

        assertEquals(StatusCheckin.ERRO, viewModel.estado.value.status)
        assertEquals(textoDaPosicaoEncerrada, viewModel.estado.value.mensagemErro)
    }

    @Test
    fun `status comeca OCIOSO antes do toque`() {
        val provedor = mockk<ProvedorDeLocalizacao>()
        val servico = servicoComResposta(resultadoJson(tipo = "manual", verificacao = "pendente"))
        val viewModel = criarViewModel(provedor, servico)

        assertEquals(StatusCheckin.OCIOSO, viewModel.estado.value.status)
    }

    @Test
    fun `calcularDistanciaMetros e nulo quando falta qualquer uma das coordenadas`() {
        assertEquals(null, CheckinViewModel.calcularDistanciaMetros(null, coordenadaDaVaga))
        assertEquals(null, CheckinViewModel.calcularDistanciaMetros(coordenadaProxima, null))
    }

    /** Conta cada `fazer_checkin` e só responde depois de [liberar]: o primeiro toque fica em voo enquanto o segundo chega. */
    private fun servicoQueSegura(chamadas: java.util.concurrent.atomic.AtomicInteger, liberar: kotlinx.coroutines.CompletableDeferred<Unit>): ServicoTurnos {
        val engine = MockEngine {
            chamadas.incrementAndGet()
            liberar.await()
            respond(
                content = resultadoJson(tipo = "geolocalizado", verificacao = "verificado", distanciaM = "111"),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        return ServicoTurnos(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))
    }

    @Test
    fun `toque duplo no check-in manda um so fazer_checkin`() = runBlocking {
        val chamadas = java.util.concurrent.atomic.AtomicInteger()
        val liberar = kotlinx.coroutines.CompletableDeferred<Unit>()
        val viewModel = criarViewModel(provedorComPermissaoEGps(coordenadaProxima), servicoQueSegura(chamadas, liberar))

        val primeiro = viewModel.fazerCheckin()
        val segundo = viewModel.fazerCheckin()
        // Dá tempo de um segundo pedido, se houvesse, chegar ao servidor antes de liberar o primeiro.
        kotlinx.coroutines.delay(300)
        liberar.complete(Unit)
        primeiro.join()
        segundo.join()

        assertEquals(1, chamadas.get())
        assertEquals(StatusCheckin.VERIFICADO, viewModel.estado.value.status)
    }

    @Test
    fun `toque duplo em seguir sem GPS manda um so fazer_checkin`() = runBlocking {
        val chamadas = java.util.concurrent.atomic.AtomicInteger()
        val liberar = kotlinx.coroutines.CompletableDeferred<Unit>()
        val viewModel = criarViewModel(provedorComPermissaoEGps(coordenadaProxima), servicoQueSegura(chamadas, liberar))

        val primeiro = viewModel.prosseguirCheckinManual()
        val segundo = viewModel.prosseguirCheckinManual()
        kotlinx.coroutines.delay(300)
        liberar.complete(Unit)
        primeiro.join()
        segundo.join()

        assertEquals(1, chamadas.get())
    }

    @Test
    fun `resposta 200 ilegivel no check-in nao deixa o botao preso em registrando`() = runBlocking {
        var chamadas = 0
        val engine = MockEngine {
            chamadas++
            respond(content = "<html>gateway</html>", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val servico = ServicoTurnos(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))
        val viewModel = CheckinViewModel(
            turnoId = turnoId,
            coordenadaDaVaga = coordenadaDaVaga,
            servicoTurnos = servico,
            provedorDeLocalizacao = provedorComPermissaoEGps(coordenadaProxima),
            escopo = CoroutineScope(kotlinx.coroutines.SupervisorJob() + Dispatchers.Default),
        )

        viewModel.fazerCheckin().join()
        val depoisDoPrimeiro = viewModel.estado.value.status
        viewModel.fazerCheckin().join()

        assertEquals(StatusCheckin.ERRO, depoisDoPrimeiro)
        assertEquals(2, chamadas, "o segundo toque tem de poder tentar de novo")
    }

    @Test
    fun `resposta 200 ilegivel em seguir sem GPS tambem vira erro e deixa tentar de novo`() = runBlocking {
        var chamadas = 0
        val engine = MockEngine {
            chamadas++
            respond(content = "<html>gateway</html>", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val servico = ServicoTurnos(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))
        val viewModel = CheckinViewModel(
            turnoId = turnoId,
            coordenadaDaVaga = coordenadaDaVaga,
            servicoTurnos = servico,
            provedorDeLocalizacao = provedorComPermissaoEGps(coordenadaProxima),
            escopo = CoroutineScope(kotlinx.coroutines.SupervisorJob() + Dispatchers.Default),
        )

        viewModel.prosseguirCheckinManual().join()
        val depoisDoPrimeiro = viewModel.estado.value.status
        viewModel.prosseguirCheckinManual().join()

        assertEquals(StatusCheckin.ERRO, depoisDoPrimeiro)
        assertEquals(2, chamadas, "o segundo toque tem de poder tentar de novo")
    }

    /** Grava o corpo de cada `fazer_checkin` e responde com [resposta]. */
    private fun servicoQueGrava(corpos: MutableList<String>, resposta: String = resultadoJson(tipo = "manual", verificacao = "pendente")): ServicoTurnos {
        val engine = MockEngine { request ->
            corpos += (request.body as io.ktor.http.content.TextContent).text
            respond(content = resposta, status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
        }
        return ServicoTurnos(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))
    }

    @Test
    fun `sem permissao, o 1o toque pede a permissao do sistema, sem dialogo e sem chamar a API (C0-7)`() = runBlocking {
        val provedor = mockk<ProvedorDeLocalizacao>()
        every { provedor.temPermissaoDeLocalizacao() } returns false
        val corpos = mutableListOf<String>()
        val viewModel = criarViewModel(provedor, servicoQueGrava(corpos))

        viewModel.fazerCheckin().join()

        assertTrue(viewModel.estado.value.pedirPermissao)
        assertEquals(null, viewModel.estado.value.dialogoDefensivo)
        assertEquals(StatusCheckin.OCIOSO, viewModel.estado.value.status)
        assertTrue(corpos.isEmpty(), "a API não deveria ser chamada antes da resposta da permissão")
        // A tela abre o pedido do sistema uma vez só.
        viewModel.pedidoDePermissaoAberto()
        assertTrue(!viewModel.estado.value.pedirPermissao)
    }

    @Test
    fun `recusada a permissao do sistema, aparece o dialogo que leva as Configuracoes e a API nao e chamada (RN06, RN22)`() = runBlocking {
        val provedor = mockk<ProvedorDeLocalizacao>()
        every { provedor.temPermissaoDeLocalizacao() } returns false
        val corpos = mutableListOf<String>()
        val viewModel = criarViewModel(provedor, servicoQueGrava(corpos))
        viewModel.fazerCheckin().join()

        viewModel.respostaDaPermissao(concedida = false).join()

        assertEquals(DialogoDefensivoLocalizacao.PERMISSAO_NEGADA, viewModel.estado.value.dialogoDefensivo)
        assertTrue(!viewModel.estado.value.pedirPermissao)
        assertEquals(StatusCheckin.OCIOSO, viewModel.estado.value.status)
        assertTrue(corpos.isEmpty(), "a API não deveria ser chamada sem permissão de localização")

        // Depois da recusa, o próximo toque já mostra o diálogo, sem pedir de novo ao sistema.
        viewModel.dispensarDialogoDefensivo()
        viewModel.fazerCheckin().join()
        assertEquals(DialogoDefensivoLocalizacao.PERMISSAO_NEGADA, viewModel.estado.value.dialogoDefensivo)
        assertTrue(!viewModel.estado.value.pedirPermissao)
    }

    @Test
    fun `concedida a permissao do sistema, o check-in segue pelo GPS e manda a distancia (C0-7)`() = runBlocking {
        val provedor = mockk<ProvedorDeLocalizacao>()
        every { provedor.temPermissaoDeLocalizacao() } returnsMany listOf(false, true)
        every { provedor.isGpsAtivado() } returns true
        coEvery { provedor.lerParaCheckin() } returns LeituraDeLocalizacao(coordenadaProxima, precisaoMetros = 10f, simulada = false)
        val corpos = mutableListOf<String>()
        val viewModel = criarViewModel(provedor, servicoQueGrava(corpos, resultadoJson("geolocalizado", "verificado", distanciaM = "111")))
        viewModel.fazerCheckin().join()
        assertTrue(viewModel.estado.value.pedirPermissao)

        viewModel.respostaDaPermissao(concedida = true).join()

        assertEquals(1, corpos.size)
        assertTrue(Regex("\"distancia_m\":\\d+").containsMatchIn(corpos.single()))
        assertEquals(StatusCheckin.VERIFICADO, viewModel.estado.value.status)
        assertEquals(null, viewModel.estado.value.dialogoDefensivo)
    }

    @Test
    fun `com o ponto da vaga e leitura a ate 200 m, o corpo de fazer_checkin leva distancia_m com numero (C0-7)`() = runBlocking {
        val provedor = provedorComPermissaoEGps(coordenadaProxima)
        val corpos = mutableListOf<String>()
        val viewModel = criarViewModel(provedor, servicoQueGrava(corpos, resultadoJson("geolocalizado", "verificado", distanciaM = "111")))

        viewModel.fazerCheckin().join()

        val distancia = Regex("\"distancia_m\":(\\d+)").find(corpos.single())?.groupValues?.get(1)?.toInt()
        assertNotNull(distancia)
        assertTrue(distancia!! <= CheckinViewModel.LIMITE_METROS)
    }

    @Test
    fun `com permissao mas GPS desligado, exibe dialogo GPS_DESLIGADO e nao chama a API (RN06, RN22)`() = runBlocking {
        val provedor = mockk<ProvedorDeLocalizacao>()
        every { provedor.temPermissaoDeLocalizacao() } returns true
        every { provedor.isGpsAtivado() } returns false
        var apiChamada = false
        val engine = MockEngine {
            apiChamada = true
            respond(content = resultadoJson(tipo = "manual", verificacao = "pendente"), status = HttpStatusCode.OK)
        }
        val servico = ServicoTurnos(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))
        val viewModel = criarViewModel(provedor, servico)

        viewModel.fazerCheckin().join()

        assertEquals(DialogoDefensivoLocalizacao.GPS_DESLIGADO, viewModel.estado.value.dialogoDefensivo)
        assertEquals(StatusCheckin.OCIOSO, viewModel.estado.value.status)
        assertTrue(!apiChamada, "a API não deveria ser chamada com GPS desligado")
    }

    @Test
    fun `prosseguirCheckinManual limpa o dialogo e envia distancia_m nulo, resultando em MANUAL_PENDENTE`() = runBlocking {
        val provedor = mockk<ProvedorDeLocalizacao>()
        every { provedor.temPermissaoDeLocalizacao() } returns false
        var corpoRecebido: String? = null
        val engine = MockEngine { request ->
            corpoRecebido = (request.body as io.ktor.http.content.TextContent).text
            respond(
                content = resultadoJson(tipo = "manual", verificacao = "pendente"),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoTurnos(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))
        val viewModel = criarViewModel(provedor, servico)
        viewModel.fazerCheckin().join()
        viewModel.respostaDaPermissao(concedida = false).join()
        assertEquals(DialogoDefensivoLocalizacao.PERMISSAO_NEGADA, viewModel.estado.value.dialogoDefensivo)

        viewModel.prosseguirCheckinManual().join()

        assertEquals(null, viewModel.estado.value.dialogoDefensivo)
        assertEquals(StatusCheckin.MANUAL_PENDENTE, viewModel.estado.value.status)
        assertTrue(corpoRecebido!!.contains("\"distancia_m\":null"))
    }

    @Test
    fun `dispensarDialogoDefensivo limpa o dialogo e volta o status para OCIOSO`() = runBlocking {
        val provedor = mockk<ProvedorDeLocalizacao>()
        every { provedor.temPermissaoDeLocalizacao() } returns false
        val servico = servicoComResposta(resultadoJson(tipo = "manual", verificacao = "pendente"))
        val viewModel = criarViewModel(provedor, servico)
        viewModel.fazerCheckin().join()
        viewModel.respostaDaPermissao(concedida = false).join()
        assertEquals(DialogoDefensivoLocalizacao.PERMISSAO_NEGADA, viewModel.estado.value.dialogoDefensivo)

        viewModel.dispensarDialogoDefensivo()

        assertEquals(null, viewModel.estado.value.dialogoDefensivo)
        assertEquals(StatusCheckin.OCIOSO, viewModel.estado.value.status)
    }

    @Test
    fun `resultado com tipo manual e verificacao verificado mapeia para MANUAL_CONFIRMADO e status VERIFICADO`() = runBlocking {
        val provedor = provedorComPermissaoEGps(coordenadaDistante)
        val servico = servicoComResposta(resultadoJson(tipo = "manual", verificacao = "verificado", distanciaM = "500"))
        val viewModel = criarViewModel(provedor, servico)

        viewModel.fazerCheckin().join()

        assertEquals(StatusCheckin.VERIFICADO, viewModel.estado.value.status)
        val comprovante = viewModel.estado.value.comprovante
        assertNotNull(comprovante)
        assertEquals(TipoVerificacaoCheckin.MANUAL_CONFIRMADO, comprovante!!.tipoVerificacao)
    }

    @Test
    fun `resultado com verificacao desconhecida cai no estado conservador NAO_VERIFICADO sem quebrar`() = runBlocking {
        val provedor = provedorComPermissaoEGps(coordenadaDistante)
        val servico = servicoComResposta(resultadoJson(tipo = "manual", verificacao = "em_auditoria_futura"))
        val viewModel = criarViewModel(provedor, servico)

        viewModel.fazerCheckin().join()

        assertEquals(StatusCheckin.OCIOSO, viewModel.estado.value.status)
        val comprovante = viewModel.estado.value.comprovante
        assertNotNull(comprovante)
        assertEquals(TipoVerificacaoCheckin.NAO_VERIFICADO, comprovante!!.tipoVerificacao)
    }


    // ---- 422 registro_no_futuro e sem rede no check-in (cartão Gk6JX2wW, 104): só teste, o mapeamento já existe ----

    @Test
    fun `422 registro_no_futuro no check-in pede para ajustar o horario do aparelho`() = runBlocking {
        val servico = servicoComResposta(
            json = """{"code":"registro_no_futuro","message":"x","details":null}""",
            status = HttpStatusCode.UnprocessableEntity,
        )
        val viewModel = criarViewModel(provedorComPermissaoEGps(coordenadaProxima), servico)

        viewModel.fazerCheckin().join()

        assertEquals(StatusCheckin.ERRO, viewModel.estado.value.status)
        assertEquals("O horário do aparelho está incorreto. Ajuste e tente de novo.", viewModel.estado.value.mensagemErro)
    }

    @Test
    fun `check-in sem rede mostra a mensagem de sem conexao`() = runBlocking {
        // O cliente converte a falha de conexão em ErroDaApi(SEM_REDE) (ClienteSupabase, HttpResponseValidator).
        val engine = MockEngine { throw ConnectTimeoutException("sem rede") }
        val servico = ServicoTurnos(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))
        val viewModel = criarViewModel(provedorComPermissaoEGps(coordenadaProxima), servico)

        viewModel.fazerCheckin().join()

        assertEquals(StatusCheckin.ERRO, viewModel.estado.value.status)
        assertEquals("Sem conexão. Verifique sua internet e tente de novo.", viewModel.estado.value.mensagemErro)
    }

    // ---- 401, 403 e 404 no check-in (cartão rclJTMOK): o mesmo texto do iOS (MensagemDoErroAPI.texto) ----

    private val recusasDeSessaoEAcesso = listOf(
        Triple(HttpStatusCode.Unauthorized, "nao_autenticado", "Sua sessão expirou. Entre novamente para continuar."),
        Triple(HttpStatusCode.Forbidden, "sem_permissao", "Sua conta não pode realizar esta ação."),
        Triple(HttpStatusCode.NotFound, "nao_encontrado", "Não encontramos este turno."),
    )

    @Test
    fun `401, 403 e 404 no check-in com localizacao dizem o motivo, e nao o tente de novo`() = runBlocking {
        for ((status, codigo, mensagem) in recusasDeSessaoEAcesso) {
            val servico = servicoComResposta(json = """{"code":"$codigo","message":"x"}""", status = status)
            val viewModel = criarViewModel(provedorComPermissaoEGps(coordenadaProxima), servico)

            viewModel.fazerCheckin().join()

            assertEquals(StatusCheckin.ERRO, viewModel.estado.value.status, codigo)
            assertEquals(mensagem, viewModel.estado.value.mensagemErro, codigo)
        }
    }

    @Test
    fun `401, 403 e 404 no check-in manual sem GPS dizem o mesmo motivo`() = runBlocking {
        for ((status, codigo, mensagem) in recusasDeSessaoEAcesso) {
            val servico = servicoComResposta(json = """{"code":"$codigo","message":"x"}""", status = status)
            val viewModel = criarViewModel(provedorComPermissaoEGps(coordenadaProxima), servico)

            viewModel.prosseguirCheckinManual().join()

            assertEquals(StatusCheckin.ERRO, viewModel.estado.value.status, codigo)
            assertEquals(mensagem, viewModel.estado.value.mensagemErro, codigo)
        }
    }
}
