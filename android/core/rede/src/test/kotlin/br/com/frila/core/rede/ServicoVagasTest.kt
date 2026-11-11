package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import br.com.frila.core.dominio.modelo.Coordenada
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpMethod
import io.ktor.http.content.TextContent
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ServicoVagasTest {

    private val vagaJson = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "funcao": {"id": "22222222-2222-2222-2222-222222222222", "nome": "garçom", "categoria": "Salão"},
          "estabelecimento": {
            "id": "33333333-3333-3333-3333-333333333333",
            "tipo": "estabelecimento",
            "nome": "Bar do Zé",
            "reputacao": {"positivas": 7, "total": 7, "taxa_comparecimento": 1.0, "turnos_considerados": 7, "turnos_realizados": 7}
          },
          "inicio_em": "2026-11-01T21:00:00Z",
          "fim_em": "2026-11-02T03:00:00Z",
          "local": "SQN 108",
          "regiao_administrativa": "Asa Norte",
          "distancia_km": 4.2,
          "valor_centavos": 16000,
          "posicoes_abertas": 2,
          "inclusos": {"inclui_refeicao": true, "inclui_transporte": false, "exige_material_proprio": false},
          "modo": "selecao"
        }
    """.trimIndent()

    @Test
    fun `listarVagasAbertas chama GET rpc vagas_abertas e decodifica a lista`() = runTest {
        var caminhoChamado: String? = null
        val engine = MockEngine { request ->
            caminhoChamado = request.url.encodedPath
            respond(
                content = "[$vagaJson]",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoVagas(cliente)

        val vagas = servico.listarVagasAbertas()

        assertEquals("/rest/v1/rpc/vagas_abertas", caminhoChamado)
        assertEquals(1, vagas.size)
        assertEquals("garçom", vagas.first().funcao.nome)
        assertEquals(16_000L, vagas.first().valorCentavos)
        assertEquals(2, vagas.first().posicoesAbertas)
    }

    @Test
    fun `listarVagasAbertas sem coordenada nao envia latitude longitude nem distancia_max_km`() = runTest {
        var parametros: io.ktor.http.Parameters? = null
        val engine = MockEngine { request ->
            parametros = request.url.parameters
            respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoVagas(cliente)

        servico.listarVagasAbertas()

        assertTrue(parametros?.contains("latitude") == false)
        assertTrue(parametros?.contains("longitude") == false)
        assertTrue(parametros?.contains("distancia_max_km") == false)
    }

    @Test
    fun `listarVagasAbertas com coordenada envia latitude e longitude na URL`() = runTest {
        var parametros: io.ktor.http.Parameters? = null
        val engine = MockEngine { request ->
            parametros = request.url.parameters
            respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoVagas(cliente)

        servico.listarVagasAbertas(coordenada = Coordenada(latitude = -15.79, longitude = -47.88))

        assertEquals("-15.79", parametros?.get("latitude"))
        assertEquals("-47.88", parametros?.get("longitude"))
    }

    @Test
    fun `listarVagasAbertas com distanciaMaxKm envia distancia_max_km na URL`() = runTest {
        var parametros: io.ktor.http.Parameters? = null
        val engine = MockEngine { request ->
            parametros = request.url.parameters
            respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoVagas(cliente)

        servico.listarVagasAbertas(distanciaMaxKm = 25.0)

        assertEquals("25.0", parametros?.get("distancia_max_km"))
    }

    @Test
    fun `listarVagasAbertas com coordenada e distanciaMaxKm envia os tres parametros juntos`() = runTest {
        var parametros: io.ktor.http.Parameters? = null
        val engine = MockEngine { request ->
            parametros = request.url.parameters
            respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoVagas(cliente)

        servico.listarVagasAbertas(coordenada = Coordenada(latitude = -15.79, longitude = -47.88), distanciaMaxKm = 50.0)

        assertEquals("-15.79", parametros?.get("latitude"))
        assertEquals("-47.88", parametros?.get("longitude"))
        assertEquals("50.0", parametros?.get("distancia_max_km"))
    }

    @Test
    fun `listarVagasAbertas com conta de contratante propaga PERFIL_INCOMPATIVEL`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"perfil_incompativel","message":"conta de contratante"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoVagas(cliente)

        val excecao = runCatching { servico.listarVagasAbertas() }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        assertEquals(CodigoErroAPI.PERFIL_INCOMPATIVEL, (excecao as ErroDaApi).codigo)
    }

    @Test
    fun `lista vazia decodifica sem erro`() = runTest {
        val engine = MockEngine {
            respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoVagas(cliente)

        val vagas = servico.listarVagasAbertas()

        assertTrue(vagas.isEmpty())
    }

    @Test
    fun `candidatar chama POST rpc candidatar com vaga_id no corpo`() = runTest {
        var caminhoChamado: String? = null
        var metodoChamado: io.ktor.http.HttpMethod? = null
        val engine = MockEngine { request ->
            caminhoChamado = request.url.encodedPath
            metodoChamado = request.method
            respond(
                content = """{"estado":"pendente","candidatura_id":"6f1c2a4e-2b7d-4c5e-9a1f-3d2e1c0b9a88","posicao_id":null,"turno_id":null,"contato":null}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoVagas(cliente)

        val resultado = servico.candidatar("11111111-1111-1111-1111-111111111111")

        assertEquals("/rest/v1/rpc/candidatar", caminhoChamado)
        assertEquals(io.ktor.http.HttpMethod.Post, metodoChamado)
        assertEquals("pendente", resultado.estado)
        assertEquals("6f1c2a4e-2b7d-4c5e-9a1f-3d2e1c0b9a88", resultado.candidaturaId)
    }

    @Test
    fun `candidatar no modo urgencia decodifica turno e contato`() = runTest {
        val engine = MockEngine {
            respond(
                content = """
                    {
                      "estado": "confirmada",
                      "candidatura_id": "6f1c2a4e-2b7d-4c5e-9a1f-3d2e1c0b9a88",
                      "posicao_id": "0b8a7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d",
                      "turno_id": "9a8b7c6d-5e4f-4a3b-8c2d-1e0f0b8a7c6d",
                      "contato": {
                        "nome": "Bar do Zé",
                        "telefone": "+5561999990000",
                        "whatsapp_url": "https://wa.me/5561999990000",
                        "visivel_ate": "2026-09-27T06:00:00Z"
                      }
                    }
                """.trimIndent(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoVagas(cliente)

        val resultado = servico.candidatar("11111111-1111-1111-1111-111111111111")

        assertEquals("confirmada", resultado.estado)
        assertEquals("9a8b7c6d-5e4f-4a3b-8c2d-1e0f0b8a7c6d", resultado.turnoId)
        assertEquals("Bar do Zé", resultado.contato?.nome)
        assertEquals("+5561999990000", resultado.contato?.telefone)
    }

    @Test
    fun `candidatar com posicao_ja_preenchida propaga o codigo de dominio`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"posicao_ja_preenchida","message":"alguém chegou antes"}""",
                status = HttpStatusCode.Conflict,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoVagas(cliente)

        val excecao = runCatching { servico.candidatar("11111111-1111-1111-1111-111111111111") }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        assertEquals(CodigoErroAPI.POSICAO_JA_PREENCHIDA, (excecao as ErroDaApi).codigo)
    }

    @Test
    fun `candidatar com inelegivel propaga o codigo de dominio`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"inelegivel","message":"turno_sobreposto"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoVagas(cliente)

        val excecao = runCatching { servico.candidatar("11111111-1111-1111-1111-111111111111") }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        assertEquals(CodigoErroAPI.INELEGIVEL, (excecao as ErroDaApi).codigo)
    }

    private fun novaVaga() = NovaVagaDto(
        estabelecimentoId = "33333333-3333-3333-3333-333333333333",
        funcaoId = "22222222-2222-2222-2222-222222222222",
        inicioEm = "2026-11-20T21:00:00Z",
        fimEm = "2026-11-21T03:00:00Z",
        local = "SQN 108",
        regiaoAdministrativa = "Asa Norte",
        ponto = CoordenadaDto(-15.7942, -47.8822),
        valorCentavos = 16_000,
        posicoes = 2,
        incluiRefeicao = true,
        incluiTransporte = false,
        exigeMaterialProprio = false,
        responsavelLocal = "Lia",
        modo = "selecao",
        chave = "44444444-4444-4444-4444-444444444444",
    )

    @Test
    fun `publicarVaga faz POST com os campos do contrato e decodifica a VagaPublicada`() = runTest {
        var metodo: HttpMethod? = null
        var caminho: String? = null
        var corpo: kotlinx.serialization.json.JsonObject? = null
        val engine = MockEngine { request ->
            metodo = request.method
            caminho = request.url.encodedPath
            corpo = ClienteSupabase.jsonFrila.parseToJsonElement((request.body as TextContent).text).jsonObject
            respond(
                content = """{"vaga_id":"55555555-5555-5555-5555-555555555555","posicoes":["a","b"]}""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoVagas(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))

        val publicada = servico.publicarVaga(novaVaga())

        assertEquals(HttpMethod.Post, metodo)
        assertEquals("/rest/v1/rpc/publicar_vaga", caminho)
        assertEquals(
            setOf(
                "estabelecimento_id", "funcao_id", "inicio_em", "fim_em", "local", "regiao_administrativa", "ponto",
                "valor_centavos", "posicoes", "inclui_refeicao", "inclui_transporte", "exige_material_proprio",
                "responsavel_local", "traje", "participa_rateio", "observacoes", "modo", "alerta_antecedencia_min", "chave",
            ),
            corpo!!.keys,
        )
        assertEquals("selecao", corpo!!["modo"]!!.jsonPrimitive.content)
        assertEquals("16000", corpo!!["valor_centavos"]!!.jsonPrimitive.content)
        assertEquals("-15.7942", corpo!!["ponto"]!!.jsonObject["latitude"]!!.jsonPrimitive.content)
        assertEquals("44444444-4444-4444-4444-444444444444", corpo!!["chave"]!!.jsonPrimitive.content)
        assertEquals("55555555-5555-5555-5555-555555555555", publicada.vagaId)
        assertEquals(2, publicada.posicoes.size)
    }

    @Test
    fun `publicarVaga com selecao sem antecedencia propaga o codigo de dominio`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"selecao_sem_antecedencia","message":"menos de 24h"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoVagas(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))

        val excecao = runCatching { servico.publicarVaga(novaVaga()) }.exceptionOrNull()

        assertEquals(CodigoErroAPI.SELECAO_SEM_ANTECEDENCIA, (excecao as ErroDaApi).codigo)
    }

    @Test
    fun `listarFuncoes le o catalogo ativo da tabela funcao`() = runTest {
        var url: io.ktor.http.Url? = null
        val engine = MockEngine { request ->
            url = request.url
            respond(
                content = """[{"id":"22222222-2222-2222-2222-222222222222","nome":"garçom","categoria":"Salão"}]""",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoVagas(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))

        val funcoes = servico.listarFuncoes()

        assertEquals("/rest/v1/funcao", url!!.encodedPath)
        assertEquals("eq.true", url!!.parameters["ativo"])
        assertEquals("id,nome,categoria", url!!.parameters["select"])
        assertEquals("garçom", funcoes.single().nome)
    }

    private fun servicoQueResponde(
        status: HttpStatusCode,
        conteudo: String,
        aoReceber: (io.ktor.client.request.HttpRequestData) -> Unit = {},
    ): ServicoVagas {
        val engine = MockEngine { request ->
            aoReceber(request)
            respond(conteudo, status, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        return ServicoVagas(ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine))
    }

    @Test
    fun `candidatosDaVaga faz POST com vaga_id e decodifica candidatos em ordem, com selo da equipe e foto`() = runTest {
        var metodo: HttpMethod? = null
        var caminho: String? = null
        var corpo: kotlinx.serialization.json.JsonObject? = null
        val servico = servicoQueResponde(
            HttpStatusCode.OK,
            """
            [
              {"candidatura_id":"c1","criada_em":"2026-11-10T12:00:00Z","da_equipe":true,
               "profissional":{"id":"p1","tipo":"profissional","nome":"Ana","funcoes":["garçom","barman"],
                 "reputacao":{"positivas":9,"total":10,"taxa_comparecimento":0.95,"turnos_considerados":10,"turnos_realizados":9},
                 "foto_url":"https://frila.supabase.co/storage/foto.jpg","foto_id":"m1"}},
              {"candidatura_id":"c2","criada_em":"2026-11-10T13:00:00Z",
               "profissional":{"id":"p2","tipo":"profissional","nome":"Beto",
                 "reputacao":{"positivas":0,"total":0,"turnos_considerados":0,"turnos_realizados":0}}}
            ]
            """.trimIndent(),
        ) { request ->
            metodo = request.method
            caminho = request.url.encodedPath
            corpo = ClienteSupabase.jsonFrila.parseToJsonElement((request.body as TextContent).text).jsonObject
        }

        val candidatos = servico.candidatosDaVaga("vaga-1")

        assertEquals(HttpMethod.Post, metodo)
        assertEquals("/rest/v1/rpc/candidatos_da_vaga", caminho)
        assertEquals(setOf("vaga_id"), corpo!!.keys)
        assertEquals("vaga-1", corpo!!["vaga_id"]!!.jsonPrimitive.content)
        assertEquals(listOf("c1", "c2"), candidatos.map { it.candidaturaId })
        assertEquals(true, candidatos[0].daEquipe)
        assertEquals(false, candidatos[1].daEquipe)
        assertEquals(listOf("garçom", "barman"), candidatos[0].profissional.funcoes)
        assertEquals("https://frila.supabase.co/storage/foto.jpg", candidatos[0].profissional.fotoUrl)
        assertEquals("m1", candidatos[0].profissional.fotoId)
        assertEquals(null, candidatos[1].profissional.fotoUrl)
    }

    @Test
    fun `candidatosDaVaga de conta de profissional mapeia perfil_incompativel`() = runTest {
        val servico = servicoQueResponde(HttpStatusCode.UnprocessableEntity, """{"code":"perfil_incompativel","message":"x"}""")

        val excecao = runCatching { servico.candidatosDaVaga("vaga-1") }.exceptionOrNull()

        assertEquals(CodigoErroAPI.PERFIL_INCOMPATIVEL, (excecao as ErroDaApi).codigo)
    }

    @Test
    fun `escolherCandidato faz POST com candidatura_id e decodifica o turno, com e sem contato`() = runTest {
        var caminho: String? = null
        var corpo: kotlinx.serialization.json.JsonObject? = null
        val comContato = servicoQueResponde(
            HttpStatusCode.OK,
            """{"estado":"confirmada","posicao_id":"pos-1","turno_id":"t1","contato":{"nome":"Ana","telefone":"+5561999990000","visivel_ate":"2026-11-20T00:00:00Z"}}""",
        ) { request ->
            caminho = request.url.encodedPath
            corpo = ClienteSupabase.jsonFrila.parseToJsonElement((request.body as TextContent).text).jsonObject
        }
        val semContato = servicoQueResponde(HttpStatusCode.OK, """{"estado":"confirmada","posicao_id":"pos-1","turno_id":"t1","contato":null}""")

        val resultado = comContato.escolherCandidato("cand-1")

        assertEquals("/rest/v1/rpc/escolher_candidato", caminho)
        assertEquals(setOf("candidatura_id"), corpo!!.keys)
        assertEquals("cand-1", corpo!!["candidatura_id"]!!.jsonPrimitive.content)
        assertEquals("confirmada", resultado.estado)
        assertEquals("t1", resultado.turnoId)
        assertEquals(true, resultado.contato != null)
        assertEquals(null, semContato.escolherCandidato("cand-1").contato)
    }

    @Test
    fun `escolherCandidato propaga cada recusa do contrato com o codigo de dominio e os details`() = runTest {
        val casos = listOf(
            Triple(HttpStatusCode.Conflict, "posicao_ja_preenchida", CodigoErroAPI.POSICAO_JA_PREENCHIDA),
            Triple(HttpStatusCode.Conflict, "candidatura_indisponivel", CodigoErroAPI.CANDIDATURA_INDISPONIVEL),
            Triple(HttpStatusCode.Conflict, "vaga_encerrada", CodigoErroAPI.VAGA_ENCERRADA),
            Triple(HttpStatusCode.UnprocessableEntity, "inelegivel", CodigoErroAPI.INELEGIVEL),
            Triple(HttpStatusCode.UnprocessableEntity, "vaga_oculta", CodigoErroAPI.VAGA_OCULTA),
            Triple(HttpStatusCode.Forbidden, "sem_permissao", CodigoErroAPI.SEM_PERMISSAO),
        )
        for ((status, codigo, esperado) in casos) {
            val servico = servicoQueResponde(status, """{"code":"$codigo","message":"x","details":"turno_sobreposto"}""")

            val excecao = runCatching { servico.escolherCandidato("cand-1") }.exceptionOrNull()

            assertEquals(esperado, (excecao as ErroDaApi).codigo, codigo)
            assertEquals("turno_sobreposto", excecao.detalhes, codigo)
        }
    }

    private val painelJson = """
        {
          "estabelecimento_id": "est-1",
          "checkins_pendentes": ["turno-9"],
          "vagas": [
            {
              "vaga": {"id":"v1","funcao":"garçom","local":"SQN 108","regiao_administrativa":"Asa Norte",
                       "inicio_em":"2026-11-12T21:00:00Z","fim_em":"2026-11-13T03:00:00Z","valor_centavos":16000},
              "modo": "selecao", "estado": "publicada", "oculta": false, "alerta_vaga_vazia": true,
              "candidatos_pendentes": 2, "republicavel_em_urgencia": 1,
              "posicoes": [
                {"id":"p1","estado":"confirmada","turno_id":"t1","verificacao":"verificado","em_atraso":false,
                 "a_caminho_em":"2026-11-12T19:00:00Z","checkin_em":"2026-11-12T21:02:00Z","checkin_tipo":"codigo",
                 "checkin_confirmado_em":"2026-11-12T21:03:00Z",
                 "profissional":{"id":"pr1","tipo":"profissional","nome":"Ana",
                   "reputacao":{"positivas":1,"total":1,"turnos_considerados":1,"turnos_realizados":1}}},
                {"id":"p2","estado":"aberta","profissional":null,"turno_id":null,"verificacao":null,"em_atraso":false,"a_caminho_em":null},
                {"id":"p3","estado":"cancelada","profissional":null,"turno_id":null,"verificacao":null,"em_atraso":false,"a_caminho_em":null,
                 "cancelamento":{"causa":"profissional","falta":true,"motivo":"Imprevisto","cancelada_em":"2026-11-12T10:00:00Z"}}
              ]
            }
          ]
        }
    """.trimIndent()

    @Test
    fun `painelEstabelecimento faz POST com estabelecimento_id e a janela em UTC, e decodifica o painel inteiro`() = runTest {
        var caminho: String? = null
        var metodo: HttpMethod? = null
        var corpo: kotlinx.serialization.json.JsonObject? = null
        val servico = servicoQueResponde(HttpStatusCode.OK, painelJson) { request ->
            caminho = request.url.encodedPath
            metodo = request.method
            corpo = ClienteSupabase.jsonFrila.parseToJsonElement((request.body as TextContent).text).jsonObject
        }

        val painel = servico.painelEstabelecimento(
            "est-1",
            java.time.Instant.parse("2025-11-10T15:00:00.123Z"),
            java.time.Instant.parse("2027-11-10T15:00:00Z"),
        ).getOrThrow()

        assertEquals(HttpMethod.Post, metodo)
        assertEquals("/rest/v1/rpc/painel_estabelecimento", caminho)
        assertEquals(setOf("estabelecimento_id", "de", "ate"), corpo!!.keys)
        assertEquals("est-1", corpo!!["estabelecimento_id"]!!.jsonPrimitive.content)
        assertEquals("2025-11-10T15:00:00Z", corpo!!["de"]!!.jsonPrimitive.content)
        assertEquals("2027-11-10T15:00:00Z", corpo!!["ate"]!!.jsonPrimitive.content)
        assertEquals(listOf("turno-9"), painel.checkinsPendentes)
        val vaga = painel.vagas.single()
        assertEquals("garçom", vaga.vaga.funcao)
        assertEquals("selecao", vaga.modo)
        assertEquals(true, vaga.alertaVagaVazia)
        assertEquals(2, vaga.candidatosPendentes)
        assertEquals(1, vaga.republicavelEmUrgencia)
        assertEquals(listOf("confirmada", "aberta", "cancelada"), vaga.posicoes.map { it.estado })
        assertEquals("Ana", vaga.posicoes[0].profissional?.nome)
        assertEquals("codigo", vaga.posicoes[0].checkinTipo)
        assertEquals(null, vaga.posicoes[1].profissional)
        assertEquals(true, vaga.posicoes[2].cancelamento?.falta)
        assertEquals("profissional", vaga.posicoes[2].cancelamento?.causa)
    }

    @Test
    fun `painel de uma casa sem vagas decodifica lista vazia`() = runTest {
        val servico = servicoQueResponde(HttpStatusCode.OK, """{"estabelecimento_id":"est-1","vagas":[],"checkins_pendentes":[]}""")

        val painel = servico.painelEstabelecimento("est-1", java.time.Instant.EPOCH, java.time.Instant.EPOCH).getOrThrow()

        assertEquals(true, painel.vagas.isEmpty())
    }

    @Test
    fun `painelEstabelecimento devolve falha com ErroDaApi para 403, sem lancar`() = runTest {
        val servico = servicoQueResponde(HttpStatusCode.Forbidden, """{"code":"sem_permissao","message":"x"}""")

        val resultado = servico.painelEstabelecimento("est-1", java.time.Instant.EPOCH, java.time.Instant.EPOCH)

        assertEquals(true, resultado.isFailure)
        assertEquals(CodigoErroAPI.SEM_PERMISSAO, (resultado.exceptionOrNull() as ErroDaApi).codigo)
    }

    @Test
    fun `painelEstabelecimento devolve falha quando o corpo nao e JSON, sem lancar`() = runTest {
        val servico = servicoQueResponde(HttpStatusCode.OK, "<html>gateway</html>")

        val resultado = servico.painelEstabelecimento("est-1", java.time.Instant.EPOCH, java.time.Instant.EPOCH)

        assertEquals(true, resultado.isFailure)
        assertEquals(false, resultado.exceptionOrNull() is ErroDaApi)
    }
}
