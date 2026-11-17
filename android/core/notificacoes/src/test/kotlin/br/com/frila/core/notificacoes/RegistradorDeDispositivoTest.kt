package br.com.frila.core.notificacoes

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoDispositivo
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlin.time.Duration.Companion.seconds
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * C0-10: o aparelho se registra ao abrir o app com sessão e logo depois de entrar (não só quando o FCM troca o token),
 * mandando `versao_app` (0.2.56), e guarda o `vinculo_id` devolvido (RN15).
 */
class RegistradorDeDispositivoTest {

    private val sessao = Sessao(accessToken = "access", refreshToken = "refresh", tokenType = "bearer", expiresIn = 3600, vinculoId = null)

    private class Servidor {
        val corpos = mutableListOf<String>()
        val servico = ServicoDispositivo(
            ClienteSupabase(
                baseUrl = "https://frila.supabase.co",
                apiKey = "chave-teste",
                engine = MockEngine { request ->
                    corpos += (request.body as io.ktor.http.content.TextContent).text
                    respond(
                        content = """{"plataforma":"android","atualizado_em":"2026-10-22T10:00:00Z","vinculo_id":"vinculo-novo"}""",
                        status = HttpStatusCode.OK,
                        headers = headersOf(HttpHeaders.ContentType, "application/json"),
                    )
                },
            ),
        )
    }

    @Test
    fun `com sessao e token, registra com versao_app e guarda o vinculo_id`() = runTest {
        val servidor = Servidor()
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessao) }
        val registrador = RegistradorDeDispositivo(servidor.servico, armazenamento, versaoApp = "1.2.0") {
            "token-fcm-de-teste-com-mais-de-20-chars"
        }

        registrador.registrar()

        assertEquals(1, servidor.corpos.size)
        assertTrue(servidor.corpos.first().contains("\"versao_app\":\"1.2.0\""))
        assertTrue(servidor.corpos.first().contains("token-fcm-de-teste-com-mais-de-20-chars"))
        assertEquals("vinculo-novo", armazenamento.obterSessao()?.vinculoId)
    }

    @Test
    fun `sem sessao, nao chama o servidor (o registro exige quem entrou)`() = runTest {
        val servidor = Servidor()
        val registrador = RegistradorDeDispositivo(servidor.servico, ArmazenamentoDeSessaoEmMemoria(), versaoApp = "1.2.0") {
            "token-fcm-de-teste-com-mais-de-20-chars"
        }

        registrador.registrar()

        assertTrue(servidor.corpos.isEmpty())
    }

    @Test
    fun `sem token do FCM (nulo ou erro), nao chama o servidor e nao lanca`() = runTest {
        val servidor = Servidor()
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessao) }

        RegistradorDeDispositivo(servidor.servico, armazenamento, versaoApp = "1.2.0") { null }.registrar()
        RegistradorDeDispositivo(servidor.servico, armazenamento, versaoApp = "1.2.0") { error("sem Play Services") }.registrar()

        assertTrue(servidor.corpos.isEmpty())
    }

    @Test
    fun `token novo do FCM (onNewToken) tambem manda versao_app`() = runTest {
        val servidor = Servidor()
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessao) }
        val registrador = RegistradorDeDispositivo(servidor.servico, armazenamento, versaoApp = "1.2.0") { null }

        registrador.registrarComToken("token-fcm-novo-de-teste-com-20-chars")

        assertEquals(1, servidor.corpos.size)
        assertTrue(servidor.corpos.first().contains("\"versao_app\":\"1.2.0\""))
        assertEquals("vinculo-novo", armazenamento.obterSessao()?.vinculoId)
    }
    @Test
    fun `em segundo plano, a falha do servidor vira log sem dado pessoal e nada lanca`() = runTest {
        val falhas = mutableListOf<String>()
        val servico = ServicoDispositivo(
            ClienteSupabase(
                baseUrl = "https://frila.supabase.co",
                apiKey = "chave-teste",
                engine = MockEngine { respond(content = "erro", status = HttpStatusCode.InternalServerError) },
            ),
        )
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessao) }
        val registrador = RegistradorDeDispositivo(
            servico, armazenamento, versaoApp = "1.2.0", escopo = backgroundScope, registrarFalha = { falhas += it },
        ) { "token-fcm-de-teste-com-mais-de-20-chars" }

        registrador.registrarEmSegundoPlano().join()

        assertEquals(1, falhas.size)
        assertTrue(falhas.none { it.contains("token-fcm") || it.contains("access") }, "o log não leva token nem sessão")
    }

    @Test
    fun `em segundo plano, token que nao chega no prazo vira log e o registro desiste`() = runTest {
        val falhas = mutableListOf<String>()
        val servidor = Servidor()
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply { salvarSessao(sessao) }
        val registrador = RegistradorDeDispositivo(
            servidor.servico, armazenamento, versaoApp = "1.2.0", escopo = backgroundScope, prazo = 15.seconds,
            registrarFalha = { falhas += it },
        ) {
            delay(60_000)
            "token-fcm-de-teste-com-mais-de-20-chars"
        }

        registrador.registrarEmSegundoPlano().join()

        assertEquals(1, falhas.size)
        assertTrue(servidor.corpos.isEmpty())
    }
}
