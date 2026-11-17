package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.seguranca.ArmazenamentoDeSessaoEmMemoria
import br.com.frila.core.seguranca.Sessao
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.content.TextContent
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ServicoContaTest {

    private fun servico(corpo: String, status: HttpStatusCode, aoChamar: (String, HttpMethod) -> Unit = { _, _ -> }): ServicoConta {
        val engine = MockEngine { request ->
            aoChamar(request.url.encodedPath, request.method)
            respond(corpo, status, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        return ServicoConta(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))
    }

    @Test
    fun `minhaConta chama GET rpc minha_conta e le o perfil da conta`() = runTest {
        var caminho: String? = null
        var metodo: HttpMethod? = null
        val servico = servico(
            """{"id":"u1","perfil":"contratante","nome":"Casa Teste","telefone":"61999990000","email":"c@exemplo.com","nascimento":"1990-01-01","estado":"ativa","campo_novo":1}""",
            HttpStatusCode.OK,
        ) { c, m -> caminho = c; metodo = m }

        val conta = servico.minhaConta()

        assertEquals("/rest/v1/rpc/minha_conta", caminho)
        assertEquals(HttpMethod.Get, metodo)
        assertEquals("contratante", conta.perfil)
        assertEquals("u1", conta.id)
    }

    @Test
    fun `minhaConta sem conta no servidor lanca nao_encontrado`() = runTest {
        val servico = servico("""{"code":"nao_encontrado","message":"sem conta","details":null}""", HttpStatusCode.NotFound)

        val erro = assertThrows(ErroDaApi::class.java) { kotlinx.coroutines.runBlocking { servico.minhaConta() } }

        assertEquals(CodigoErroAPI.NAO_ENCONTRADO, erro.codigo)
    }

    private val corpoUsuario =
        """{"id":"u1","perfil":"profissional","nome":"Ana Souza","telefone":"+5511987654321","email":"ana@exemplo.com","nascimento":"2000-06-15","estado":"ativa"}"""

    private val dadosDeCadastro = CriarContaDto(
        perfil = "profissional",
        nome = "Ana Souza",
        telefone = "+5511987654321",
        nascimento = "2000-06-15",
        termosVersao = "2026-11-16",
    )

    @Test
    fun `criarConta chama POST rpc criar_conta com o corpo do cadastro e le a conta`() = runTest {
        var caminho: String? = null
        var metodo: HttpMethod? = null
        var corpo: String? = null
        var tipoDeConteudo: String? = null
        val engine = MockEngine { request ->
            caminho = request.url.encodedPath
            metodo = request.method
            corpo = (request.body as TextContent).text
            tipoDeConteudo = request.body.contentType?.toString()
            respond(corpoUsuario, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val servico = ServicoConta(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))

        val conta = servico.criarConta(dadosDeCadastro)

        assertEquals("/rest/v1/rpc/criar_conta", caminho)
        assertEquals(HttpMethod.Post, metodo)
        assertTrue(tipoDeConteudo!!.startsWith("application/json"))
        assertEquals(
            """{"perfil":"profissional","nome":"Ana Souza","telefone":"+5511987654321","nascimento":"2000-06-15","termos_versao":"2026-11-16"}""",
            corpo,
        )
        assertFalse(corpo!!.contains("sinal_idade"), "sinal_idade nulo precisa ficar fora do JSON")
        assertEquals("u1", conta.id)
        assertEquals("profissional", conta.perfil)
        assertEquals("ativa", conta.estado)
    }

    @Test
    fun `criarConta envia sinal_idade quando informado`() = runTest {
        var corpo: String? = null
        val engine = MockEngine { request ->
            corpo = (request.body as TextContent).text
            respond(corpoUsuario, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val servico = ServicoConta(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))

        servico.criarConta(dadosDeCadastro.copy(sinalIdade = "dezoito_ou_mais"))

        assertTrue(corpo!!.contains(""""sinal_idade":"dezoito_ou_mais""""))
    }

    @Test
    fun `criarConta e autenticado com o Bearer da sessao e o apikey`() = runTest {
        var cabecalhos: Map<String, List<String>>? = null
        val engine = MockEngine { request ->
            cabecalhos = request.headers.entries().associate { it.key.lowercase() to it.value }
            respond(corpoUsuario, HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val armazenamento = ArmazenamentoDeSessaoEmMemoria().apply {
            salvarSessao(Sessao(accessToken = "jwt-sintetico-123", refreshToken = "refresh-sintetico", tokenType = "bearer", expiresIn = 3_600L))
        }
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            armazenamentoDeSessao = armazenamento,
            engine = engine,
        )

        ServicoConta(cliente).criarConta(dadosDeCadastro)

        assertEquals(listOf("Bearer jwt-sintetico-123"), cabecalhos!!["authorization"])
        assertEquals(listOf("chave-teste"), cabecalhos!!["apikey"])
    }

    @Test
    fun `criarConta com 422 menor_de_idade lanca ErroDaApi com o codigo`() = runTest {
        val servico = servico("""{"code":"menor_de_idade","message":"menor","details":"nascimento"}""", HttpStatusCode.UnprocessableEntity)

        val erro = assertThrows(ErroDaApi::class.java) { kotlinx.coroutines.runBlocking { servico.criarConta(dadosDeCadastro) } }

        assertEquals(CodigoErroAPI.MENOR_DE_IDADE, erro.codigo)
        assertEquals("nascimento", erro.detalhes)
    }

    @Test
    fun `criarConta com 422 campo_invalido expoe o campo em detalhes`() = runTest {
        val servico = servico("""{"code":"campo_invalido","message":"nome","details":"nome"}""", HttpStatusCode.UnprocessableEntity)

        val erro = assertThrows(ErroDaApi::class.java) { kotlinx.coroutines.runBlocking { servico.criarConta(dadosDeCadastro) } }

        assertEquals(CodigoErroAPI.CAMPO_INVALIDO, erro.codigo)
        assertEquals("nome", erro.detalhes)
    }

    @Test
    fun `criarConta com 409 conta_existente lanca ErroDaApi com o codigo`() = runTest {
        val servico = servico("""{"code":"conta_existente","message":"ja existe","details":null}""", HttpStatusCode.Conflict)

        val erro = assertThrows(ErroDaApi::class.java) { kotlinx.coroutines.runBlocking { servico.criarConta(dadosDeCadastro) } }

        assertEquals(CodigoErroAPI.CONTA_EXISTENTE, erro.codigo)
    }
}
