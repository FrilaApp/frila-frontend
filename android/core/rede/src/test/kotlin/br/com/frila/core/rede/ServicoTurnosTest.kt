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

class ServicoTurnosTest {

    private val turnoJson = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "posicao_id": "33333333-3333-3333-3333-333333333333",
          "vaga": {
            "id": "22222222-2222-2222-2222-222222222222",
            "funcao": "garçom",
            "local": "CLS 405 Bloco C",
            "regiao_administrativa": "Plano Piloto",
            "inicio_em": "2026-11-01T21:00:00Z",
            "fim_em": "2026-11-02T03:00:00Z",
            "valor_centavos": 16000
          },
          "contraparte": {
            "id": "e1",
            "tipo": "estabelecimento",
            "nome": "Bar do Zé",
            "reputacao": {
              "positivas": 7,
              "total": 7,
              "turnos_considerados": 7,
              "turnos_realizados": 7
            }
          },
          "contato_visivel_ate": "2026-11-09T03:00:00Z",
          "a_caminho_em": null,
          "checkin_em": null,
          "checkin_tipo": null,
          "checkin_distancia_m": null,
          "checkin_confirmado_em": null,
          "checkout_em": null,
          "checkout_distancia_m": null,
          "verificacao": "pendente",
          "valor_acordado_centavos": 16000,
          "pode_avaliar": false,
          "estado": "confirmada",
          "avaliacao": null,
          "cancelamento": null
        }
    """.trimIndent()

    @Test
    fun `listarMeusTurnos chama GET rpc meus_turnos e decodifica a lista`() = runTest {
        var caminhoChamado: String? = null
        val engine = MockEngine { request ->
            caminhoChamado = request.url.encodedPath
            respond(
                content = "[$turnoJson]",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoTurnos(cliente)

        val turnos = servico.listarMeusTurnos()

        assertEquals("/rest/v1/rpc/meus_turnos", caminhoChamado)
        assertEquals(1, turnos.size)
        assertEquals("confirmada", turnos.first().estado)
        assertEquals("garçom", turnos.first().vaga.funcao)
        assertEquals(16000L, turnos.first().valorAcordadoCentavos)
        assertEquals("11111111-1111-1111-1111-111111111111", turnos.first().id)
    }

    @Test
    fun `turno cancelado (RN12) continua na lista, nao e filtrado pelo servico`() = runTest {
        val jsonCancelado = """
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "posicao_id": "33333333-3333-3333-3333-333333333333",
              "vaga": {
                "id": "22222222-2222-2222-2222-222222222222",
                "funcao": "garçom",
                "local": "CLS 405 Bloco C",
                "regiao_administrativa": "Plano Piloto",
                "inicio_em": "2026-11-01T21:00:00Z",
                "fim_em": "2026-11-02T03:00:00Z",
                "valor_centavos": 16000
              },
              "contraparte": {
                "id": "e1",
                "tipo": "estabelecimento",
                "nome": "Bar do Zé",
                "reputacao": {
                  "positivas": 7,
                  "total": 7,
                  "turnos_considerados": 7,
                  "turnos_realizados": 7
                }
              },
              "contato_visivel_ate": "2026-11-09T03:00:00Z",
              "a_caminho_em": null,
              "checkin_em": null,
              "checkin_tipo": null,
              "checkin_distancia_m": null,
              "checkin_confirmado_em": null,
              "checkout_em": null,
              "checkout_distancia_m": null,
              "verificacao": "pendente",
              "valor_acordado_centavos": 16000,
              "pode_avaliar": false,
              "estado": "cancelada",
              "avaliacao": null,
              "cancelamento": {
                "causa": "estabelecimento",
                "falta": false,
                "cancelada_em": "2026-11-01T15:00:00Z"
              }
            }
        """.trimIndent()
        val engine = MockEngine {
            respond(
                content = "[$jsonCancelado]",
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoTurnos(cliente)

        val turnos = servico.listarMeusTurnos()

        assertEquals(1, turnos.size)
        assertEquals("cancelada", turnos.first().estado)
        assertEquals("estabelecimento", turnos.first().cancelamento?.causa)
        assertEquals(false, turnos.first().cancelamento?.falta)
    }

    @Test
    fun `checkin e avaliacao nulos decodificam sem erro quando ausentes`() = runTest {
        val engine = MockEngine {
            respond(content = "[$turnoJson]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoTurnos(cliente)

        val turno = servico.listarMeusTurnos().first()

        assertNull(turno.checkinEm)
        assertNull(turno.avaliacao)
        assertNull(turno.cancelamento)
    }

    @Test
    fun `lista vazia decodifica sem erro`() = runTest {
        val engine = MockEngine {
            respond(content = "[]", status = HttpStatusCode.OK, headers = headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoTurnos(cliente)

        assertTrue(servico.listarMeusTurnos().isEmpty())
    }

    @Test
    fun `fazerCheckin chama POST rpc fazer_checkin com o corpo certo e decodifica sucesso geolocalizado`() = runTest {
        var caminhoChamado: String? = null
        var corpoChamado: String? = null
        val engine = MockEngine { request ->
            caminhoChamado = request.url.encodedPath
            corpoChamado = (request.body as io.ktor.http.content.TextContent).text
            respond(
                content = """
                    {
                      "turno_id": "11111111-1111-1111-1111-111111111111",
                      "tipo": "geolocalizado",
                      "verificacao": "verificado",
                      "registrado_em": "2026-11-01T21:05:00Z",
                      "distancia_m": 42
                    }
                """.trimIndent(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoTurnos(cliente)

        val resultado = servico.fazerCheckin(
            turnoId = "11111111-1111-1111-1111-111111111111",
            distanciaMetros = 42,
            registradoEm = "2026-11-01T21:05:00Z",
        )

        assertEquals("/rest/v1/rpc/fazer_checkin", caminhoChamado)
        assertTrue(corpoChamado!!.contains("\"distancia_m\":42"))
        assertEquals("geolocalizado", resultado.tipo)
        assertEquals("verificado", resultado.verificacao)
        assertEquals(42, resultado.distanciaM)
    }

    @Test
    fun `fazerCheckin sem localizacao decodifica sucesso manual pendente`() = runTest {
        var corpoChamado: String? = null
        val engine = MockEngine { request ->
            corpoChamado = (request.body as io.ktor.http.content.TextContent).text
            respond(
                content = """
                    {
                      "turno_id": "11111111-1111-1111-1111-111111111111",
                      "tipo": "manual",
                      "verificacao": "pendente",
                      "registrado_em": "2026-11-01T21:05:00Z",
                      "distancia_m": null
                    }
                """.trimIndent(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoTurnos(cliente)

        val resultado = servico.fazerCheckin(
            turnoId = "11111111-1111-1111-1111-111111111111",
            distanciaMetros = null,
            registradoEm = "2026-11-01T21:05:00Z",
        )

        assertTrue(corpoChamado!!.contains("\"distancia_m\":null"))
        assertEquals("manual", resultado.tipo)
        assertEquals("pendente", resultado.verificacao)
        assertNull(resultado.distanciaM)
    }

    @Test
    fun `fazerCheckin fora da janela propaga o codigo de dominio`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"fora_da_janela","message":"toque fora da janela do turno"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoTurnos(cliente)

        val excecao = runCatching {
            servico.fazerCheckin(
                turnoId = "11111111-1111-1111-1111-111111111111",
                distanciaMetros = 10,
                registradoEm = "2026-11-01T21:05:00Z",
            )
        }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        assertEquals(CodigoErroAPI.FORA_DA_JANELA, (excecao as ErroDaApi).codigo)
    }

    @Test
    fun `avaliarTurno chama POST rpc avaliar com o corpo certo e decodifica a avaliacao`() = runTest {
        var caminhoChamado: String? = null
        var corpoChamado: String? = null
        val engine = MockEngine { request ->
            caminhoChamado = request.url.encodedPath
            corpoChamado = (request.body as io.ktor.http.content.TextContent).text
            respond(
                content = """
                    {
                      "turno_id": "11111111-1111-1111-1111-111111111111",
                      "resposta": true,
                      "criada_em": "2026-11-02T04:00:00Z"
                    }
                """.trimIndent(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoTurnos(cliente)

        val avaliacao = servico.avaliarTurno(turnoId = "11111111-1111-1111-1111-111111111111", resposta = true)

        assertEquals("/rest/v1/rpc/avaliar", caminhoChamado)
        assertTrue(corpoChamado!!.contains("\"resposta\":true"))
        assertEquals("11111111-1111-1111-1111-111111111111", avaliacao.turnoId)
        assertEquals(true, avaliacao.resposta)
    }

    @Test
    fun `avaliarTurno com avaliacao_indisponivel propaga o codigo de dominio`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"avaliacao_indisponivel","message":"antes_do_fim"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoTurnos(cliente)

        val excecao = runCatching {
            servico.avaliarTurno(turnoId = "11111111-1111-1111-1111-111111111111", resposta = true)
        }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        assertEquals(CodigoErroAPI.AVALIACAO_INDISPONIVEL, (excecao as ErroDaApi).codigo)
    }

    @Test
    fun `avaliarTurno com avaliacao_ja_registrada propaga o codigo de dominio`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"avaliacao_ja_registrada","message":"resposta diferente da ja gravada"}""",
                status = HttpStatusCode.Conflict,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val cliente = ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine)
        val servico = ServicoTurnos(cliente)

        val excecao = runCatching {
            servico.avaliarTurno(turnoId = "11111111-1111-1111-1111-111111111111", resposta = false)
        }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        assertEquals(CodigoErroAPI.AVALIACAO_JA_REGISTRADA, (excecao as ErroDaApi).codigo)
    }

    @Test
    fun `cancelarPosicao envia posicao e motivo e decodifica falta verdadeira`() = runTest {
        var caminhoChamado: String? = null
        var corpoChamado: String? = null
        val engine = MockEngine { request ->
            caminhoChamado = request.url.encodedPath
            corpoChamado = (request.body as io.ktor.http.content.TextContent).text
            respond(
                content = """
                    {
                      "posicao_id": "33333333-3333-3333-3333-333333333333",
                      "falta": true,
                      "reaberta": true,
                      "nova_posicao_id": "44444444-4444-4444-4444-444444444444"
                    }
                """.trimIndent(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoTurnos(
            ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine),
        )

        val resultado = servico.cancelarPosicao(
            posicaoId = "33333333-3333-3333-3333-333333333333",
            motivo = "Problema de saúde",
        )

        assertEquals("/rest/v1/rpc/cancelar_posicao", caminhoChamado)
        assertTrue(corpoChamado!!.contains("\"posicao_id\":\"33333333-3333-3333-3333-333333333333\""))
        assertTrue(corpoChamado!!.contains("\"motivo\":\"Problema de saúde\""))
        assertTrue(resultado.falta)
        assertTrue(resultado.reaberta)
        assertEquals("44444444-4444-4444-4444-444444444444", resultado.novaPosicaoId)
    }

    @Test
    fun `cancelarPosicao decodifica cancelamento sem falta`() = runTest {
        val engine = MockEngine {
            respond(
                content = """
                    {
                      "posicao_id": "33333333-3333-3333-3333-333333333333",
                      "falta": false,
                      "reaberta": false,
                      "nova_posicao_id": null
                    }
                """.trimIndent(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoTurnos(
            ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine),
        )

        val resultado = servico.cancelarPosicao("33333333-3333-3333-3333-333333333333", "Imprevisto pessoal")

        assertEquals(false, resultado.falta)
        assertEquals(false, resultado.reaberta)
        assertNull(resultado.novaPosicaoId)
    }

    @Test
    fun `cancelarPosicao 409 propaga posicao nao cancelavel`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"posicao_nao_cancelavel","message":"turno em andamento"}""",
                status = HttpStatusCode.Conflict,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoTurnos(
            ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine),
        )

        val excecao = runCatching { servico.cancelarPosicao("p1", "Problema de saúde") }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        assertEquals(CodigoErroAPI.POSICAO_NAO_CANCELAVEL, (excecao as ErroDaApi).codigo)
    }

    @Test
    fun `cancelarPosicao 422 propaga campo invalido`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"campo_invalido","message":"motivo recusado","details":"motivo"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoTurnos(
            ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine),
        )

        val excecao = runCatching { servico.cancelarPosicao("p1", "motivo bloqueado") }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        assertEquals(CodigoErroAPI.CAMPO_INVALIDO, (excecao as ErroDaApi).codigo)
        assertEquals("motivo", excecao.detalhes)
    }

    @Test
    fun `abrirSuporte chama POST rpc abrir_suporte com o corpo certo e decodifica o protocolo`() = runTest {
        var caminhoChamado: String? = null
        var corpoChamado: String? = null
        val engine = MockEngine { request ->
            caminhoChamado = request.url.encodedPath
            corpoChamado = (request.body as io.ktor.http.content.TextContent).text
            respond(
                content = """
                    {
                      "ocorrencia_id": "6f1c2a4e-2b7d-4c5e-9a1f-3d2e1c0b9a88",
                      "tipo": "suporte",
                      "criada_em": "2026-10-08T14:00:00Z",
                      "prazo_resposta_ate": "2026-10-15"
                    }
                """.trimIndent(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoTurnos(
            ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine),
        )

        val protocolo = servico.abrirSuporte(turnoId = "t-1", categoria = "seguranca", chave = "chave-1")

        assertEquals("/rest/v1/rpc/abrir_suporte", caminhoChamado)
        assertTrue(corpoChamado!!.contains("\"turno_id\":\"t-1\""))
        assertTrue(corpoChamado!!.contains("\"categoria\":\"seguranca\""))
        assertTrue(corpoChamado!!.contains("\"chave\":\"chave-1\""))
        assertEquals("6f1c2a4e-2b7d-4c5e-9a1f-3d2e1c0b9a88", protocolo.ocorrenciaId)
        assertEquals("suporte", protocolo.tipo)
    }

    @Test
    fun `abrirSuporte com campo_invalido propaga o codigo de dominio`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"campo_invalido","message":"categoria fora do enum","details":"categoria"}""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoTurnos(
            ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine),
        )

        val excecao = runCatching {
            servico.abrirSuporte(turnoId = "t-1", categoria = "invalida", chave = "chave-1")
        }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        assertEquals(CodigoErroAPI.CAMPO_INVALIDO, (excecao as ErroDaApi).codigo)
        assertEquals("categoria", excecao.detalhes)
    }

    @Test
    fun `abrirSuporte com limite_excedido propaga o codigo de dominio`() = runTest {
        val engine = MockEngine {
            respond(
                content = """{"code":"limite_excedido","message":"maximo de chamados diarios atingido"}""",
                status = HttpStatusCode.TooManyRequests,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val servico = ServicoTurnos(
            ClienteSupabase(baseUrl = "https://frila.supabase.co", apiKey = "chave-teste", engine = engine),
        )

        val excecao = runCatching {
            servico.abrirSuporte(turnoId = "t-1", categoria = "outro", chave = "chave-1")
        }.exceptionOrNull()

        assertTrue(excecao is ErroDaApi)
        assertEquals(CodigoErroAPI.LIMITE_EXCEDIDO, (excecao as ErroDaApi).codigo)
    }
}
