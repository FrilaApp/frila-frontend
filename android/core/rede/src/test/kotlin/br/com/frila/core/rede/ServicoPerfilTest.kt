package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
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

    // MARK: - L1-0a: criar_perfil_profissional

    @Test
    fun `criarPerfilProfissional envia POST rpc criar_perfil_profissional com o corpo do contrato e decodifica o perfil`() = runTest {
        var caminhoChamado: String? = null
        var metodoChamado: HttpMethod? = null
        var corpoChamado: String? = null
        val engine = MockEngine { request ->
            caminhoChamado = request.url.encodedPath
            metodoChamado = request.method
            corpoChamado = (request.body as? TextContent)?.text
            respond(
                content = """
                    {
                      "id": "11111111-1111-1111-1111-111111111111",
                      "usuario_id": "22222222-2222-2222-2222-222222222222",
                      "funcoes": [
                        {"id": "f1111111-1111-1111-1111-111111111111", "nome": "Garçom", "categoria": "Salão"}
                      ],
                      "ponto_base": {"latitude": -15.7942, "longitude": -47.8822},
                      "disponibilidades": [
                        {"dia_semana": 1, "hora_inicio": "08:00", "hora_fim": "16:00"}
                      ],
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

        val dados = DadosDoPerfilProfissionalDto(
            funcoes = listOf("f1111111-1111-1111-1111-111111111111"),
            pontoBase = CoordenadaDto(latitude = -15.7942, longitude = -47.8822),
            disponibilidades = listOf(
                JanelaDeDisponibilidadeDto(diaSemana = 1, inicio = "08:00", fim = "16:00")
            ),
        )

        val perfil = servico.criarPerfilProfissional(dados)

        assertEquals("/rest/v1/rpc/criar_perfil_profissional", caminhoChamado)
        assertEquals(HttpMethod.Post, metodoChamado)
        assertTrue(corpoChamado!!.contains("\"funcoes\":[\"f1111111-1111-1111-1111-111111111111\"]"))
        assertTrue(corpoChamado!!.contains("\"latitude\":-15.7942"))
        assertTrue(corpoChamado!!.contains("\"longitude\":-47.8822"))
        assertTrue(corpoChamado!!.contains("\"dia_semana\":1"))
        assertTrue(corpoChamado!!.contains("\"hora_inicio\":\"08:00\""))
        assertTrue(corpoChamado!!.contains("\"hora_fim\":\"16:00\""))
        assertEquals("11111111-1111-1111-1111-111111111111", perfil.id)
        assertEquals("Garçom", perfil.funcoes.first().nome)
    }

    @Test
    fun `criarPerfilProfissional com 401 propaga NAO_AUTENTICADO`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"nao_autenticado","message":"nao autenticado"}""",
                status = HttpStatusCode.Unauthorized,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
        val dados = DadosDoPerfilProfissionalDto(listOf("f1"), CoordenadaDto(0.0, 0.0), emptyList())

        val erro = runCatching { servico.criarPerfilProfissional(dados) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.NAO_AUTENTICADO, erro.codigo)
    }

    @Test
    fun `criarPerfilProfissional com 403 conta_suspensa propaga CONTA_SUSPENSA`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"conta_suspensa","message":"conta suspensa"}""",
                status = HttpStatusCode.Forbidden,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
        val dados = DadosDoPerfilProfissionalDto(listOf("f1"), CoordenadaDto(0.0, 0.0), emptyList())

        val erro = runCatching { servico.criarPerfilProfissional(dados) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.CONTA_SUSPENSA, erro.codigo)
    }

    @Test
    fun `criarPerfilProfissional com 409 perfil_ja_existe propaga PERFIL_JA_EXISTE`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"perfil_ja_existe","message":"perfil ja existe"}""",
                status = HttpStatusCode.Conflict,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
        val dados = DadosDoPerfilProfissionalDto(listOf("f1"), CoordenadaDto(0.0, 0.0), emptyList())

        val erro = runCatching { servico.criarPerfilProfissional(dados) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.PERFIL_JA_EXISTE, erro.codigo)
    }

    @Test
    fun `criarPerfilProfissional com 422 perfil_incompativel propaga PERFIL_INCOMPATIVEL`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"perfil_incompativel","message":"conta de contratante"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
        val dados = DadosDoPerfilProfissionalDto(listOf("f1"), CoordenadaDto(0.0, 0.0), emptyList())

        val erro = runCatching { servico.criarPerfilProfissional(dados) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.PERFIL_INCOMPATIVEL, erro.codigo)
    }

    @Test
    fun `criarPerfilProfissional com 422 campo_invalido propaga CAMPO_INVALIDO e details`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"campo_invalido","message":"funcao invalida","details":"funcoes"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
        val dados = DadosDoPerfilProfissionalDto(listOf("f1"), CoordenadaDto(0.0, 0.0), emptyList())

        val erro = runCatching { servico.criarPerfilProfissional(dados) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.CAMPO_INVALIDO, erro.codigo)
        assertEquals("funcoes", erro.detalhes)
    }

    // MARK: - L1-0a: atualizar_perfil_profissional

    @Test
    fun `atualizarPerfilProfissional envia POST rpc atualizar_perfil_profissional omitindo campos nao informados e decodifica o perfil`() = runTest {
        var caminhoChamado: String? = null
        var metodoChamado: HttpMethod? = null
        var corpoChamado: String? = null
        val engine = MockEngine { request ->
            caminhoChamado = request.url.encodedPath
            metodoChamado = request.method
            corpoChamado = (request.body as? TextContent)?.text
            respond(
                content = """
                    {
                      "id": "11111111-1111-1111-1111-111111111111",
                      "usuario_id": "22222222-2222-2222-2222-222222222222",
                      "funcoes": [
                        {"id": "f2222222-2222-2222-2222-222222222222", "nome": "Cozinheiro", "categoria": "Cozinha"}
                      ],
                      "ponto_base": {"latitude": -15.7942, "longitude": -47.8822},
                      "disponibilidades": [],
                      "reputacao": {
                        "positivas": 3, "total": 3, "taxa_comparecimento": 1.0,
                        "turnos_considerados": 3, "turnos_realizados": 3
                      }
                    }
                """.trimIndent(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val alteracao = AlteracaoDoPerfilProfissionalDto(
            funcoes = listOf("f2222222-2222-2222-2222-222222222222"),
        )

        val perfil = servico.atualizarPerfilProfissional(alteracao)

        assertEquals("/rest/v1/rpc/atualizar_perfil_profissional", caminhoChamado)
        assertEquals(HttpMethod.Post, metodoChamado)
        assertTrue(corpoChamado!!.contains("\"funcoes\":[\"f2222222-2222-2222-2222-222222222222\"]"))
        assertFalse(corpoChamado!!.contains("ponto_base"))
        assertFalse(corpoChamado!!.contains("disponibilidades"))
        assertEquals("Cozinheiro", perfil.funcoes.first().nome)
    }

    @Test
    fun `atualizarPerfilProfissional com 401 propaga NAO_AUTENTICADO`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"nao_autenticado","message":"nao autenticado"}""",
                status = HttpStatusCode.Unauthorized,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val erro = runCatching { servico.atualizarPerfilProfissional(AlteracaoDoPerfilProfissionalDto(funcoes = listOf("f1"))) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.NAO_AUTENTICADO, erro.codigo)
    }

    @Test
    fun `atualizarPerfilProfissional com 403 conta_suspensa propaga CONTA_SUSPENSA`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"conta_suspensa","message":"conta suspensa"}""",
                status = HttpStatusCode.Forbidden,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val erro = runCatching { servico.atualizarPerfilProfissional(AlteracaoDoPerfilProfissionalDto(funcoes = listOf("f1"))) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.CONTA_SUSPENSA, erro.codigo)
    }

    @Test
    fun `atualizarPerfilProfissional com 404 nao_encontrado propaga NAO_ENCONTRADO`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"nao_encontrado","message":"perfil nao encontrado"}""",
                status = HttpStatusCode.NotFound,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val erro = runCatching { servico.atualizarPerfilProfissional(AlteracaoDoPerfilProfissionalDto(funcoes = listOf("f1"))) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.NAO_ENCONTRADO, erro.codigo)
    }

    @Test
    fun `atualizarPerfilProfissional com 422 campo_obrigatorio propaga CAMPO_OBRIGATORIO e details`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"campo_obrigatorio","message":"nenhum campo informado","details":"nenhum_campo"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val erro = runCatching { servico.atualizarPerfilProfissional(AlteracaoDoPerfilProfissionalDto()) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.CAMPO_OBRIGATORIO, erro.codigo)
        assertEquals("nenhum_campo", erro.detalhes)
    }

    @Test
    fun `atualizarPerfilProfissional com 422 campo_invalido propaga CAMPO_INVALIDO e details`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"campo_invalido","message":"funcoes vazias","details":"funcoes"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val erro = runCatching { servico.atualizarPerfilProfissional(AlteracaoDoPerfilProfissionalDto(funcoes = emptyList())) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.CAMPO_INVALIDO, erro.codigo)
        assertEquals("funcoes", erro.detalhes)
    }

    // MARK: - L1-0a: atualizar_apresentacao_profissional

    @Test
    fun `atualizarApresentacaoProfissional envia POST rpc atualizar_apresentacao_profissional com campos ricos e decodifica o perfil detalhado`() = runTest {
        var caminhoChamado: String? = null
        var metodoChamado: HttpMethod? = null
        var corpoChamado: String? = null
        val engine = MockEngine { request ->
            caminhoChamado = request.url.encodedPath
            metodoChamado = request.method
            corpoChamado = (request.body as? TextContent)?.text
            respond(
                content = """
                    {
                      "id": "11111111-1111-1111-1111-111111111111",
                      "usuario_id": "22222222-2222-2222-2222-222222222222",
                      "funcoes": [
                        {"id": "f1", "nome": "Garçom", "categoria": "Salão"}
                      ],
                      "ponto_base": {"latitude": -15.7942, "longitude": -47.8822},
                      "disponibilidades": [],
                      "reputacao": {
                        "positivas": 1, "total": 1, "taxa_comparecimento": 1.0,
                        "turnos_considerados": 1, "turnos_realizados": 1
                      },
                      "apresentacao": "Garçom experiente",
                      "onde_trabalhei": "Bar do Lago",
                      "experiencia_faixa": "de_3_a_5_anos",
                      "cursos": ["Curso A"],
                      "idiomas": ["portugues"],
                      "servicos": [],
                      "regioes": [],
                      "atende_todo_df": false
                    }
                """.trimIndent(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val apresentacao = ApresentacaoDoProfissionalDto(
            apresentacao = JsonPrimitive("Garçom experiente"),
            ondeTrabalhei = JsonPrimitive("Bar do Lago"),
            experienciaFaixa = JsonPrimitive("de_3_a_5_anos"),
            cursos = listOf("Curso A"),
            idiomas = listOf("portugues"),
        )

        val perfil = servico.atualizarApresentacaoProfissional(apresentacao)

        assertEquals("/rest/v1/rpc/atualizar_apresentacao_profissional", caminhoChamado)
        assertEquals(HttpMethod.Post, metodoChamado)
        assertTrue(corpoChamado!!.contains("\"apresentacao\":\"Garçom experiente\""))
        assertTrue(corpoChamado!!.contains("\"onde_trabalhei\":\"Bar do Lago\""))
        assertTrue(corpoChamado!!.contains("\"experiencia_faixa\":\"de_3_a_5_anos\""))
        assertTrue(corpoChamado!!.contains("\"cursos\":[\"Curso A\"]"))
        assertTrue(corpoChamado!!.contains("\"idiomas\":[\"portugues\"]"))
        assertEquals("Garçom experiente", perfil.apresentacao)
        assertEquals("Bar do Lago", perfil.ondeTrabalhei)
        assertEquals("de_3_a_5_anos", perfil.experienciaFaixa)
    }

    @Test
    fun `atualizarApresentacaoProfissional com JsonNull limpa o campo e o omitido nao vai no corpo`() = runTest {
        var corpo: kotlinx.serialization.json.JsonObject? = null
        val engine = MockEngine { request ->
            corpo = ClienteSupabase.jsonFrila.parseToJsonElement((request.body as TextContent).text).jsonObject
            respond(
                content = """
                    {"id":"11111111-1111-1111-1111-111111111111","usuario_id":"22222222-2222-2222-2222-222222222222","funcoes":[],
                     "ponto_base":null,"disponibilidades":[],
                     "reputacao":{"positivas":0,"total":0,"turnos_considerados":0,"turnos_realizados":0},
                     "apresentacao":null,"onde_trabalhei":null,"experiencia_faixa":null,"cursos":[],"idiomas":[],
                     "servicos":[],"regioes":[],"atende_todo_df":false}
                """.trimIndent(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        servico.atualizarApresentacaoProfissional(
            ApresentacaoDoProfissionalDto(apresentacao = JsonNull, experienciaFaixa = JsonNull, cursos = emptyList()),
        )

        assertEquals(setOf("apresentacao", "experiencia_faixa", "cursos"), corpo!!.keys)
        assertEquals(JsonNull, corpo!!["apresentacao"])
        assertEquals(JsonNull, corpo!!["experiencia_faixa"])
        assertEquals("[]", corpo!!["cursos"].toString())
    }

    @Test
    fun `atualizarApresentacaoProfissional com 401 propaga NAO_AUTENTICADO`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"nao_autenticado","message":"nao autenticado"}""",
                status = HttpStatusCode.Unauthorized,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val erro = runCatching { servico.atualizarApresentacaoProfissional(ApresentacaoDoProfissionalDto(apresentacao = JsonPrimitive("teste"))) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.NAO_AUTENTICADO, erro.codigo)
    }

    @Test
    fun `atualizarApresentacaoProfissional com 403 sem_permissao recurso_desligado propaga SEM_PERMISSAO e details`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"sem_permissao","message":"recurso desligado","details":"recurso_desligado"}""",
                status = HttpStatusCode.Forbidden,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val erro = runCatching { servico.atualizarApresentacaoProfissional(ApresentacaoDoProfissionalDto(apresentacao = JsonPrimitive("teste"))) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.SEM_PERMISSAO, erro.codigo)
        assertEquals("recurso_desligado", erro.detalhes)
    }

    @Test
    fun `atualizarApresentacaoProfissional com 403 conta_suspensa propaga CONTA_SUSPENSA`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"conta_suspensa","message":"conta suspensa"}""",
                status = HttpStatusCode.Forbidden,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val erro = runCatching { servico.atualizarApresentacaoProfissional(ApresentacaoDoProfissionalDto(apresentacao = JsonPrimitive("teste"))) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.CONTA_SUSPENSA, erro.codigo)
    }

    @Test
    fun `atualizarApresentacaoProfissional com 404 nao_encontrado propaga NAO_ENCONTRADO`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"nao_encontrado","message":"perfil nao encontrado"}""",
                status = HttpStatusCode.NotFound,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val erro = runCatching { servico.atualizarApresentacaoProfissional(ApresentacaoDoProfissionalDto(apresentacao = JsonPrimitive("teste"))) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.NAO_ENCONTRADO, erro.codigo)
    }

    @Test
    fun `atualizarApresentacaoProfissional com 422 campo_obrigatorio propaga CAMPO_OBRIGATORIO e details`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"campo_obrigatorio","message":"nenhum campo informado","details":"nenhum_campo"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val erro = runCatching { servico.atualizarApresentacaoProfissional(ApresentacaoDoProfissionalDto()) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.CAMPO_OBRIGATORIO, erro.codigo)
        assertEquals("nenhum_campo", erro.detalhes)
    }

    @Test
    fun `atualizarApresentacaoProfissional com 422 campo_invalido propaga CAMPO_INVALIDO e details`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"campo_invalido","message":"texto com telefone","details":"apresentacao"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val erro = runCatching { servico.atualizarApresentacaoProfissional(ApresentacaoDoProfissionalDto(apresentacao = JsonPrimitive("99999-9999"))) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.CAMPO_INVALIDO, erro.codigo)
        assertEquals("apresentacao", erro.detalhes)
    }

    @Test
    fun `atualizarApresentacaoProfissional com 422 perfil_incompativel propaga PERFIL_INCOMPATIVEL`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"perfil_incompativel","message":"conta de contratante"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val erro = runCatching { servico.atualizarApresentacaoProfissional(ApresentacaoDoProfissionalDto(apresentacao = JsonPrimitive("teste"))) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.PERFIL_INCOMPATIVEL, erro.codigo)
    }

    // MARK: - L1-0a: definir_regioes_atendidas

    @Test
    fun `definirRegioesAtendidas envia POST rpc definir_regioes_atendidas com regioes e atende_todo_df e decodifica o perfil detalhado`() = runTest {
        var caminhoChamado: String? = null
        var metodoChamado: HttpMethod? = null
        var corpoChamado: String? = null
        val engine = MockEngine { request ->
            caminhoChamado = request.url.encodedPath
            metodoChamado = request.method
            corpoChamado = (request.body as? TextContent)?.text
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
                      },
                      "apresentacao": null,
                      "onde_trabalhei": null,
                      "experiencia_faixa": null,
                      "cursos": [],
                      "idiomas": [],
                      "servicos": [],
                      "regioes": [
                        {"id": 1, "nome": "Plano Piloto", "sigla": "PP", "ativo": true},
                        {"id": 3, "nome": "Taguatinga", "sigla": "TAG", "ativo": true}
                      ],
                      "atende_todo_df": false
                    }
                """.trimIndent(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val dados = DefinirRegioesAtendidasDto(
            regioes = listOf(1, 3),
            atendeTodoDf = false,
        )

        val perfil = servico.definirRegioesAtendidas(dados)

        assertEquals("/rest/v1/rpc/definir_regioes_atendidas", caminhoChamado)
        assertEquals(HttpMethod.Post, metodoChamado)
        assertTrue(corpoChamado!!.contains("\"regioes\":[1,3]"))
        assertTrue(corpoChamado!!.contains("\"atende_todo_df\":false"))
        assertEquals(2, perfil.regioes.size)
        assertEquals("Plano Piloto", perfil.regioes.first().nome)
        assertFalse(perfil.atendeTodoDf)
    }

    @Test
    fun `definirRegioesAtendidas com 401 propaga NAO_AUTENTICADO`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"nao_autenticado","message":"nao autenticado"}""",
                status = HttpStatusCode.Unauthorized,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val erro = runCatching { servico.definirRegioesAtendidas(DefinirRegioesAtendidasDto(listOf(1), false)) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.NAO_AUTENTICADO, erro.codigo)
    }

    @Test
    fun `definirRegioesAtendidas com 403 sem_permissao recurso_desligado propaga SEM_PERMISSAO e details`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"sem_permissao","message":"recurso desligado","details":"recurso_desligado"}""",
                status = HttpStatusCode.Forbidden,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val erro = runCatching { servico.definirRegioesAtendidas(DefinirRegioesAtendidasDto(listOf(1), false)) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.SEM_PERMISSAO, erro.codigo)
        assertEquals("recurso_desligado", erro.detalhes)
    }

    @Test
    fun `definirRegioesAtendidas com 403 conta_suspensa propaga CONTA_SUSPENSA`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"conta_suspensa","message":"conta suspensa"}""",
                status = HttpStatusCode.Forbidden,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val erro = runCatching { servico.definirRegioesAtendidas(DefinirRegioesAtendidasDto(listOf(1), false)) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.CONTA_SUSPENSA, erro.codigo)
    }

    @Test
    fun `definirRegioesAtendidas com 404 nao_encontrado propaga NAO_ENCONTRADO`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"nao_encontrado","message":"perfil nao encontrado"}""",
                status = HttpStatusCode.NotFound,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val erro = runCatching { servico.definirRegioesAtendidas(DefinirRegioesAtendidasDto(listOf(1), false)) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.NAO_ENCONTRADO, erro.codigo)
    }

    @Test
    fun `definirRegioesAtendidas com 422 campo_invalido propaga CAMPO_INVALIDO e details`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"campo_invalido","message":"regiao inexistente","details":"regioes"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoPerfil(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))

        val erro = runCatching { servico.definirRegioesAtendidas(DefinirRegioesAtendidasDto(listOf(999), false)) }.exceptionOrNull() as ErroDaApi
        assertEquals(CodigoErroAPI.CAMPO_INVALIDO, erro.codigo)
        assertEquals("regioes", erro.detalhes)
    }
}
