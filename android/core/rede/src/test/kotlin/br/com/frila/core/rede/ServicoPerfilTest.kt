package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ServicoPerfilTest {

    @Test
    fun `obterMeuPerfilProfissional chama GET rpc meu_perfil_profissional e decodifica reputacao e funcoes`() = runTest {
        var caminhoChamado: String? = null
        val engine = MockEngine { request ->
            caminhoChamado = request.url.encodedPath
            respond(
                content = """
                    {
                      "id": "11111111-1111-1111-1111-111111111111",
                      "usuario_id": "22222222-2222-2222-2222-222222222222",
                      "funcoes": [
                        {"id": "f1", "nome": "garçom", "categoria": "Salão"},
                        {"id": "f2", "nome": "cozinheiro", "categoria": "Cozinha"}
                      ],
                      "ponto_base": {"latitude": -15.7942, "longitude": -47.8822},
                      "disponibilidades": [
                        {"dia_semana": 5, "hora_inicio": "18:00", "hora_fim": "02:00"}
                      ],
                      "reputacao": {
                        "positivas": 7, "total": 7, "taxa_comparecimento": 0.95,
                        "turnos_considerados": 8, "turnos_realizados": 8
                      }
                    }
                """.trimIndent(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoPerfil(cliente)

        val perfil = servico.obterMeuPerfilProfissional()

        assertEquals("/rest/v1/rpc/meu_perfil_profissional", caminhoChamado)
        assertEquals(2, perfil.funcoes.size)
        assertEquals("garçom", perfil.funcoes.first().nome)
        assertEquals(7, perfil.reputacao.positivas)
        assertEquals(7, perfil.reputacao.total)
        assertEquals(0.95, perfil.reputacao.taxaComparecimento)
        assertEquals(-15.7942, perfil.pontoBase?.latitude)
        assertEquals(1, perfil.disponibilidades.size)
        assertEquals("18:00", perfil.disponibilidades.first().inicio)
    }

    @Test
    fun `perfil com historico zerado decodifica total zero e taxa nula`() = runTest {
        val engine = MockEngine {
            respond(
                content = """
                    {
                      "id": "11111111-1111-1111-1111-111111111111",
                      "usuario_id": "22222222-2222-2222-2222-222222222222",
                      "funcoes": [],
                      "ponto_base": null,
                      "disponibilidades": [],
                      "reputacao": {
                        "positivas": 0, "total": 0, "taxa_comparecimento": null,
                        "turnos_considerados": 0, "turnos_realizados": 0
                      }
                    }
                """.trimIndent(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoPerfil(cliente)

        val perfil = servico.obterMeuPerfilProfissional()

        assertEquals(0, perfil.reputacao.total)
        assertNull(perfil.reputacao.taxaComparecimento)
        assertTrue(perfil.funcoes.isEmpty())
        assertNull(perfil.pontoBase)
    }

    @Test
    fun `excluirConta chama POST functions v1 excluir-conta e decodifica a exclusao com 202`() = runTest {
        var caminhoChamado: String? = null
        var corpoChamado: String? = null
        val engine = MockEngine { request ->
            caminhoChamado = request.url.encodedPath
            corpoChamado = (request.body as io.ktor.http.content.TextContent).text
            respond(
                content = """
                    {
                      "perfil_removido_em": "2026-11-02T10:00:00Z",
                      "dados_apagados_ate": "2026-11-17",
                      "turnos_cancelados": 2
                    }
                """.trimIndent(),
                status = HttpStatusCode.Accepted,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoPerfil(cliente)

        val exclusao = servico.excluirConta()

        assertEquals("/functions/v1/excluir-conta", caminhoChamado)
        assertTrue(corpoChamado!!.contains("\"confirmar\":true"))
        assertEquals("2026-11-17", exclusao.dadosApagadosAte)
        assertEquals(2, exclusao.turnosCancelados)
    }

    @Test
    fun `excluirConta com administrador_unico propaga o codigo de dominio`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"administrador_unico","message":"transfira a administracao antes"}""",
                status = HttpStatusCode.Conflict,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoPerfil(cliente)

        val excecao = runCatching { servico.excluirConta() }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        assertEquals(CodigoErroAPI.ADMINISTRADOR_UNICO, (excecao as ErroDaApi).codigo)
    }
}
