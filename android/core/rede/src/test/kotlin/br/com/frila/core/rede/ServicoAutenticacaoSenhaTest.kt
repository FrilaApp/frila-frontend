package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.seguranca.ArmazenamentoDeDispositivoEmMemoria
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ServicoAutenticacaoSenhaTest {

    @Test
    fun `solicitarOtp envia create_user true e solicitarOtpRecuperacao envia create_user false`() = runTest {
        val corpos = mutableListOf<String>()
        val engine = MockEngine { request ->
            assertEquals("/auth/v1/otp", request.url.encodedPath)
            corpos += (request.body as TextContent).text
            respond("{}", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val servico = ServicoAutenticacao(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        servico.solicitarOtp("novo@exemplo.test")
        servico.solicitarOtpRecuperacao("legado@exemplo.test")

        assertEquals(2, corpos.size)
        assertTrue(corpos[0].contains("\"create_user\":true"), "esperava create_user:true, veio ${corpos[0]}")
        assertTrue(corpos[1].contains("\"create_user\":false"), "esperava create_user:false, veio ${corpos[1]}")
    }

    @Test
    fun `entrarComSenha usa autenticar-senha com plataforma android e decodifica autenticado`() = runTest {
        var caminho: String? = null
        var corpo: String? = null
        val dispositivo = ArmazenamentoDeDispositivoEmMemoria().apply {
            salvarToken("conta@exemplo.test", "tok-disp-30d")
        }
        val engine = MockEngine { request ->
            caminho = request.url.encodedPath
            corpo = (request.body as TextContent).text
            respond(
                content = """{"status":"autenticado","sessao":{"access_token":"tok-senha","refresh_token":"ref-senha","token_type":"bearer","expires_in":3600},"precisa_definir_senha":false}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoAutenticacao(
            ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine),
            dispositivo,
        )

        val resultado = servico.entrarComSenha("conta@exemplo.test", "SenhaSintetica#2026")

        assertEquals("/functions/v1/autenticar-senha", caminho)
        assertTrue(corpo!!.contains("\"plataforma\":\"android\""))
        assertTrue(corpo!!.contains("\"device_token\":\"tok-disp-30d\""))
        assertTrue(resultado is ResultadoEntradaComSenha.Autenticado)
        val autenticado = resultado as ResultadoEntradaComSenha.Autenticado
        assertEquals("tok-senha", autenticado.sessao.accessToken)
        assertEquals("ref-senha", autenticado.sessao.refreshToken)
    }

    @Test
    fun `entrarComSenha com desafio_otp e descartar_device_token remove token local`() = runTest {
        val dispositivo = ArmazenamentoDeDispositivoEmMemoria().apply {
            salvarToken("conta@exemplo.test", "tok-vencido")
        }
        val engine = MockEngine {
            respond(
                content = """{"status":"desafio_otp","desafio_id":"des-1","expira_em":"2026-11-25T15:00:00Z","descartar_device_token":true}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoAutenticacao(
            ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine),
            dispositivo,
        )

        val resultado = servico.entrarComSenha("conta@exemplo.test", "SenhaSintetica#2026")

        assertEquals(ResultadoEntradaComSenha.DesafioOtp("des-1", "2026-11-25T15:00:00Z"), resultado)
        assertEquals(null, dispositivo.obterToken("conta@exemplo.test"))
    }

    @Test
    fun `confirmarDispositivoOtp com lembrar true salva device_token e reenviar mantem desafio`() = runTest {
        val dispositivo = ArmazenamentoDeDispositivoEmMemoria()
        val caminhos = mutableListOf<String>()
        val engine = MockEngine { request ->
            caminhos += request.url.encodedPath
            when (request.url.encodedPath) {
                "/functions/v1/reenviar-dispositivo-otp" -> respond(
                    content = """{"ok":true,"desafio_id":"des-1","expira_em":"2026-11-25T15:10:00Z","reenviar_em_segundos":45}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
                "/functions/v1/confirmar-dispositivo-otp" -> respond(
                    content = """{"sessao":{"access_token":"tok-otp","refresh_token":"ref-otp","token_type":"bearer","expires_in":3600},"precisa_definir_senha":false,"device_token":"tok-30d-novo"}""",
                    status = HttpStatusCode.OK,
                    headers = headersOf(HttpHeaders.ContentType, "application/json"),
                )
                else -> error("Rota inesperada: ${request.url.encodedPath}")
            }
        }
        val servico = ServicoAutenticacao(
            ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine),
            dispositivo,
        )

        val reenvio = servico.reenviarDispositivoOtp("des-1")
        assertEquals("des-1", reenvio.desafioId)
        assertEquals(45, reenvio.reenviarEmSegundos)

        val conf = servico.confirmarDispositivoOtp(
            origem = OrigemConfirmacaoDispositivoOtp.LoginDispositivo("des-1", "conta@exemplo.test"),
            codigo = "123456",
            lembrarDispositivo = true,
        )
        assertTrue(conf.dispositivoLembrado)
        assertEquals("tok-30d-novo", dispositivo.obterToken("conta@exemplo.test"))
    }

    @Test
    fun `definirSenha usa Edge Function, revoga token quando manter false e revogarDispositivos limpa todos`() = runTest {
        val caminhos = mutableListOf<String>()
        val corpos = mutableListOf<String>()
        var authHeader: String? = null
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply {
            salvarSessao(Sessao("tok-sessao-ativa", "ref-1", "bearer", 3600))
        }
        val dispositivo = ArmazenamentoDeDispositivoEmMemoria().apply {
            salvarToken("conta@exemplo.test", "tok-30d-atual")
        }
        val engine = MockEngine { request ->
            caminhos += request.url.encodedPath
            corpos += (request.body as TextContent).text
            authHeader = request.headers[HttpHeaders.Authorization]
            when (request.url.encodedPath) {
                "/functions/v1/definir-senha" -> respond(
                    """{"ok":true,"precisa_definir_senha":false,"dispositivos_revogados":1,"sessao":null}""",
                    HttpStatusCode.OK,
                    headersOf(HttpHeaders.ContentType, "application/json"),
                )
                "/functions/v1/revogar-dispositivos" -> respond(
                    """{"ok":true,"dispositivos_revogados":2}""",
                    HttpStatusCode.OK,
                    headersOf(HttpHeaders.ContentType, "application/json"),
                )
                "/rest/v1/rpc/estado_autenticacao" -> respond(
                    """{"autenticado":true,"dispositivo_verificado":true,"precisa_definir_senha":true,"tem_conta":true}""",
                    HttpStatusCode.OK,
                    headersOf(HttpHeaders.ContentType, "application/json"),
                )
                else -> error("Rota inesperada: ${request.url.encodedPath}")
            }
        }
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            armazenamentoDeSessao = armazenamento,
            engine = engine,
        )
        val servico = ServicoAutenticacao(cliente, dispositivo)

        servico.definirSenha("NovaSenha#2026", manterDispositivoAtual = true, emailAtual = "conta@exemplo.test", refreshToken = "ref-1")
        assertEquals("/functions/v1/definir-senha", caminhos.last())
        assertEquals("Bearer tok-sessao-ativa", authHeader)
        assertTrue(corpos.last().contains("\"manter_dispositivo_atual\":true"))
        assertTrue(corpos.last().contains("\"device_token_atual\":\"tok-30d-atual\""))
        assertEquals("tok-30d-atual", dispositivo.obterToken("conta@exemplo.test"))

        servico.definirSenha("OutraSenha#2026", manterDispositivoAtual = false, emailAtual = "conta@exemplo.test")
        assertEquals(null, dispositivo.obterToken("conta@exemplo.test"))

        dispositivo.salvarToken("conta@exemplo.test", "tok-para-revogar")
        assertEquals(2, servico.revogarDispositivos())
        assertEquals(null, dispositivo.obterToken("conta@exemplo.test"))

        val estado = servico.estadoAutenticacao()
        assertTrue(estado.precisaDefinirSenha)
        assertTrue(estado.dispositivoVerificado)
    }

    @Test
    fun `mapearCodigo converte erros de senha e recovery-only do GoTrue corretamente`() = runTest {
        assertEquals(
            CodigoErroAPI.NAO_AUTENTICADO,
            ClienteSupabase.mapearCodigo("400", HttpStatusCode.BadRequest, "invalid_credentials"),
        )
        assertEquals(
            CodigoErroAPI.NAO_AUTENTICADO,
            ClienteSupabase.mapearCodigo("401", HttpStatusCode.Unauthorized, "reauthentication_needed"),
        )
        assertEquals(
            CodigoErroAPI.CAMPO_INVALIDO,
            ClienteSupabase.mapearCodigo("422", HttpStatusCode.UnprocessableEntity, "weak_password"),
        )
        assertEquals(
            CodigoErroAPI.CAMPO_INVALIDO,
            ClienteSupabase.mapearCodigo("422", HttpStatusCode.UnprocessableEntity, "same_password"),
        )
        assertEquals(
            CodigoErroAPI.NAO_ENCONTRADO,
            ClienteSupabase.mapearCodigo("422", HttpStatusCode.UnprocessableEntity, "otp_disabled"),
        )
        assertEquals(
            CodigoErroAPI.NAO_ENCONTRADO,
            ClienteSupabase.mapearCodigo("404", HttpStatusCode.NotFound, "user_not_found"),
        )
        assertEquals(
            CodigoErroAPI.LIMITE_EXCEDIDO,
            ClienteSupabase.mapearCodigo("429", HttpStatusCode.TooManyRequests, "over_email_send_rate_limit"),
        )
    }

    @Test
    fun `entrarComSenha offline falha rapido com SEM_REDE sem bater na rede`() = runTest {
        var chamadas = 0
        val engine = MockEngine {
            chamadas++
            respond("{}", HttpStatusCode.OK)
        }
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            monitorDeConectividade = MonitorDeConectividadeFalso(StatusConectividade.SEM_CONEXAO),
            engine = engine,
        )
        val servico = ServicoAutenticacao(cliente)

        val erro = runCatching { servico.entrarComSenha("conta@exemplo.test", "Senha#2026") }.exceptionOrNull()

        assertTrue(erro is ErroDaApi)
        assertEquals(CodigoErroAPI.SEM_REDE, (erro as ErroDaApi).codigo)
        assertEquals(0, chamadas)
    }
}
