package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.PapelMembro
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ServicoMembrosTest {

    private val estabelecimentoId = "11111111-1111-1111-1111-111111111111"
    private class Chamada {
        var metodo: HttpMethod? = null
        var caminho: String? = null
        var corpo: JsonObject? = null
    }

    private fun servico(chamada: Chamada, status: HttpStatusCode, conteudo: String): ServicoMembros {
        val engine = MockEngine { request ->
            chamada.metodo = request.method
            chamada.caminho = request.url.encodedPath
            (request.body as? TextContent)?.let {
                chamada.corpo = ClienteSupabase.jsonFrila.parseToJsonElement(it.text).jsonObject
            }
            respond(conteudo, status, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        return ServicoMembros(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
    }

    @Test
    fun `listarMeusEstabelecimentos chama GET e decodifica o papel de cada casa`() = runTest {
        val chamada = Chamada()
        val servico = servico(
            chamada, HttpStatusCode.OK,
            """
            [
              {"id": "$estabelecimentoId", "nome": "Bar da Lia", "papel": "administrador", "tipo": "food_service"},
              {"id": "22222222-2222-2222-2222-222222222222", "nome": "Buffet Sol", "papel": "operador"}
            ]
            """.trimIndent(),
        )

        val casas = servico.listarMeusEstabelecimentos()

        assertEquals(HttpMethod.Get, chamada.metodo)
        assertEquals("/rest/v1/rpc/meus_estabelecimentos", chamada.caminho)
        assertEquals(listOf(PapelMembro.ADMINISTRADOR, PapelMembro.OPERADOR), casas.map { PapelMembro.deChave(it.papel) })
        assertNull(casas[1].tipo)
        assertNull(casas[1].reputacao)
    }

    @Test
    fun `convidarMembro manda estabelecimento_id, email e papel e decodifica o token`() = runTest {
        val chamada = Chamada()
        val token = "a".repeat(64)
        val servico = servico(
            chamada, HttpStatusCode.OK,
            """
            {"convite_id": "33333333-3333-3333-3333-333333333333", "estabelecimento_id": "$estabelecimentoId",
             "email": "novo@bar.com", "papel": "operador", "token": "$token", "expira_em": "2026-11-16T12:00:00Z"}
            """.trimIndent(),
        )

        val convite = servico.convidarMembro(estabelecimentoId, "novo@bar.com", PapelMembro.OPERADOR.chave)

        assertEquals("/rest/v1/rpc/convidar_membro", chamada.caminho)
        assertEquals(setOf("estabelecimento_id", "email", "papel"), chamada.corpo!!.keys)
        assertEquals("operador", chamada.corpo!!["papel"]!!.jsonPrimitive.content)
        assertEquals(token, convite.token)
        assertEquals("2026-11-16T12:00:00Z", convite.expiraEm)
    }

    @Test
    fun `convidarMembro por operador propaga 403 sem_permissao`() = runTest {
        val servico = servico(Chamada(), HttpStatusCode.Forbidden, """{"code":"sem_permissao","message":"so administrador"}""")

        val excecao = runCatching { servico.convidarMembro(estabelecimentoId, "novo@bar.com", "operador") }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        assertEquals(CodigoErroAPI.SEM_PERMISSAO, (excecao as ErroDaApi).codigo)
    }

    @Test
    fun `aceitarConviteMembro manda so o token e decodifica membro_adicionado`() = runTest {
        val chamada = Chamada()
        val servico = servico(
            chamada, HttpStatusCode.OK,
            """{"status": "membro_adicionado", "membro_id": "44444444-4444-4444-4444-444444444444", "papel": "administrador"}""",
        )

        val membro = servico.aceitarConviteMembro("b".repeat(64))

        assertEquals("/rest/v1/rpc/aceitar_convite_membro", chamada.caminho)
        assertEquals(setOf("token"), chamada.corpo!!.keys)
        assertEquals("membro_adicionado", membro.status)
        assertEquals(PapelMembro.ADMINISTRADOR, PapelMembro.deChave(membro.papel))
        assertNull(membro.usuarioId)
    }

    @Test
    fun `aceitarConviteMembro com token vencido mapeia convite_invalido`() = runTest {
        val servico = servico(Chamada(), HttpStatusCode.UnprocessableEntity, """{"code":"convite_invalido","message":"expirado"}""")

        val excecao = runCatching { servico.aceitarConviteMembro("c".repeat(64)) }.exceptionOrNull()

        assertEquals(CodigoErroAPI.CONVITE_INVALIDO, (excecao as ErroDaApi).codigo)
    }

    @Test
    fun `removerMembro manda os dois ids e decodifica membro_removido`() = runTest {
        val chamada = Chamada()
        val servico = servico(chamada, HttpStatusCode.OK, """{"status": "membro_removido", "removido": true}""")

        val resultado = servico.removerMembro(estabelecimentoId, "55555555-5555-5555-5555-555555555555")

        assertEquals("/rest/v1/rpc/remover_membro", chamada.caminho)
        assertEquals("55555555-5555-5555-5555-555555555555", chamada.corpo!!["membro_id"]!!.jsonPrimitive.content)
        assertEquals(true, resultado.removido)
    }

    @Test
    fun `removerMembro do ultimo administrador mapeia ultimo_administrador, nao DESCONHECIDO`() = runTest {
        val servico = servico(Chamada(), HttpStatusCode.UnprocessableEntity, """{"code":"ultimo_administrador","message":"unico"}""")

        val excecao = runCatching { servico.removerMembro(estabelecimentoId, "55555555-5555-5555-5555-555555555555") }
            .exceptionOrNull()

        assertEquals(CodigoErroAPI.ULTIMO_ADMINISTRADOR, (excecao as ErroDaApi).codigo)
    }

    @Test
    fun `transferirAdministracao manda novo_admin_id e decodifica administracao_transferida`() = runTest {
        val chamada = Chamada()
        val servico = servico(
            chamada, HttpStatusCode.OK,
            """{"status": "administracao_transferida", "novo_admin_id": "66666666-6666-6666-6666-666666666666", "papel": "administrador"}""",
        )

        val resultado = servico.transferirAdministracao(estabelecimentoId, "66666666-6666-6666-6666-666666666666")

        assertEquals("/rest/v1/rpc/transferir_administracao", chamada.caminho)
        assertEquals(setOf("estabelecimento_id", "novo_admin_id"), chamada.corpo!!.keys)
        assertEquals("administracao_transferida", resultado.status)
        assertEquals("66666666-6666-6666-6666-666666666666", resultado.novoAdminId)
    }
}
