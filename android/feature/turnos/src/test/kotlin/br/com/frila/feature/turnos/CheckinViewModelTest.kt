package br.com.frila.feature.turnos

import br.com.frila.core.dominio.modelo.Coordenada
import br.com.frila.core.dominio.modelo.TipoVerificacaoCheckin
import br.com.frila.core.localizacao.ProvedorDeLocalizacao
import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoTurnos
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.mockk.coEvery
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

    @Test
    fun `distancia ate 200m resulta em presenca verificada (RN06)`() = runBlocking {
        val provedor = mockk<ProvedorDeLocalizacao>()
        coEvery { provedor.obterCoordenadaAtual() } returns coordenadaProxima
        val servico = servicoComResposta(resultadoJson(tipo = "geolocalizado", verificacao = "verificado", distanciaM = "111"))
        val viewModel = criarViewModel(provedor, servico)

        viewModel.fazerCheckin().join()

        assertEquals(StatusCheckin.VERIFICADO, viewModel.estado.value.status)
        val comprovante = viewModel.estado.value.comprovante
        assertNotNull(comprovante)
        assertEquals(TipoVerificacaoCheckin.GEOLOCALIZADO, comprovante!!.tipoVerificacao)
        assertTrue(comprovante.codigoAutenticacao.startsWith("CHK-"))
        assertNotNull(comprovante.coordenadasAproximadas)
    }

    @Test
    fun `distancia acima de 200m resulta em presenca manual pendente`() = runBlocking {
        val provedor = mockk<ProvedorDeLocalizacao>()
        coEvery { provedor.obterCoordenadaAtual() } returns coordenadaDistante
        val servico = servicoComResposta(resultadoJson(tipo = "manual", verificacao = "pendente", distanciaM = "1100"))
        val viewModel = criarViewModel(provedor, servico)

        viewModel.fazerCheckin().join()

        assertEquals(StatusCheckin.MANUAL_PENDENTE, viewModel.estado.value.status)
        val comprovante = viewModel.estado.value.comprovante
        assertNotNull(comprovante)
        assertEquals(TipoVerificacaoCheckin.MANUAL_PENDENTE, comprovante!!.tipoVerificacao)
        assertTrue(comprovante.codigoAutenticacao.startsWith("CHK-"))
    }

    @Test
    fun `sem GPS ou permissao, envia distancia_m nulo e vira manual pendente`() = runBlocking {
        val provedor = mockk<ProvedorDeLocalizacao>()
        coEvery { provedor.obterCoordenadaAtual() } returns null
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
    fun `erro fora_da_janela resulta em status ERRO com mensagem`() = runBlocking {
        val provedor = mockk<ProvedorDeLocalizacao>()
        coEvery { provedor.obterCoordenadaAtual() } returns coordenadaProxima
        val servico = servicoComResposta(
            json = """{"code":"fora_da_janela","message":"toque fora da janela do turno"}""",
            status = HttpStatusCode.UnprocessableEntity,
        )
        val viewModel = criarViewModel(provedor, servico)

        viewModel.fazerCheckin().join()

        assertEquals(StatusCheckin.ERRO, viewModel.estado.value.status)
        assertNotNull(viewModel.estado.value.mensagemErro)
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
}
