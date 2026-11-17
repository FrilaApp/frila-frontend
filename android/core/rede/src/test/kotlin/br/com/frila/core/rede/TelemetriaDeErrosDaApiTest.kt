package br.com.frila.core.rede

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.get
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** L1-7d: cada resposta de erro da API avisa a telemetria de falhas com só código, rota e duração (como o `TelemetriaCrashlytics` do iOS). */
class TelemetriaDeErrosDaApiTest {

    private class Avisos {
        val itens = mutableListOf<Triple<String, String, Long>>()
        val registro = RegistroDeErroDaApi { codigo, rpc, duracao -> itens += Triple(codigo, rpc, duracao) }
    }

    private fun cliente(status: HttpStatusCode, corpo: String, avisos: RegistroDeErroDaApi?) = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-teste",
        engine = MockEngine { respond(corpo, status, headersOf(HttpHeaders.ContentType, "application/json")) },
        registroDeErros = avisos,
    )

    private suspend fun chamar(c: ClienteSupabase, caminho: String): Result<String> =
        runCatching { c.corpoOuErro<String>(c.http.get(c.urlCompleta(caminho))) }

    @Test
    fun `erro da API avisa com o codigo, so o nome da rota e a duracao`() = runTest {
        val avisos = Avisos()
        val c = cliente(HttpStatusCode.Forbidden, """{"code":"sem_permissao","message":"x"}""", avisos.registro)
        val resultado = chamar(c, "/rest/v1/rpc/minha_conta?email=maria@exemplo.com&token=SEGREDO")
        assertTrue(resultado.exceptionOrNull() is ErroDaApi)
        val (codigo, rpc, duracao) = avisos.itens.single()
        assertEquals("sem_permissao", codigo)
        assertEquals("minha_conta", rpc)
        assertTrue(duracao >= 0)
        assertTrue(avisos.itens.toString().let { !it.contains("maria") && !it.contains("SEGREDO") && !it.contains("frila.supabase.co") })
    }

    @Test
    fun `leitura de tabela avisa com o nome da tabela`() = runTest {
        val avisos = Avisos()
        chamar(cliente(HttpStatusCode.BadRequest, """{"code":"campo_invalido","message":"x"}""", avisos.registro), "/rest/v1/regiao_administrativa")
        assertEquals("regiao_administrativa", avisos.itens.single().second)
    }

    @Test
    fun `codigo ou rota fora do formato nao passam, viram desconhecido e outro`() = runTest {
        val avisos = Avisos()
        chamar(cliente(HttpStatusCode.BadRequest, """{"code":"a@b.com","message":"x"}""", avisos.registro), "/rest/v1/rpc/Nome Com Espaço")
        assertEquals("desconhecido" to "outro", avisos.itens.single().let { it.first to it.second })
    }

    @Test
    fun `resposta de sucesso nao avisa nada`() = runTest {
        val avisos = Avisos()
        chamar(cliente(HttpStatusCode.OK, "\"ok\"", avisos.registro), "/rest/v1/rpc/minha_conta")
        assertTrue(avisos.itens.isEmpty())
    }

    @Test
    fun `quem recebe o aviso e nao deve poder derrubar a chamada`() = runTest {
        val c = cliente(HttpStatusCode.Forbidden, """{"code":"sem_permissao","message":"x"}""") { _, _, _ -> error("telemetria quebrou") }
        val erro = chamar(c, "/rest/v1/rpc/minha_conta").exceptionOrNull()
        assertTrue(erro is ErroDaApi, erro.toString())
    }

    @Test
    fun `sem registro o comportamento e o de sempre`() = runTest {
        val erro = chamar(cliente(HttpStatusCode.Forbidden, """{"code":"sem_permissao","message":"x"}""", null), "/rest/v1/rpc/minha_conta").exceptionOrNull()
        assertEquals("sem_permissao", (erro as ErroDaApi).codigoOriginal)
    }
}
