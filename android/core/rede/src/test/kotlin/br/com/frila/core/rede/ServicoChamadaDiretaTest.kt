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
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** Cada RPC da contratação direta e da busca (contrato 0.2.88): caminho, método, corpo snake_case e resposta. */
class ServicoChamadaDiretaTest {

    private val casa = "11111111-1111-1111-1111-111111111111"
    private val profissional = "22222222-2222-2222-2222-222222222222"
    private val funcao = "33333333-3333-3333-3333-333333333333"
    private val chamadaId = "44444444-4444-4444-4444-444444444444"
    private val vagaId = "55555555-5555-5555-5555-555555555555"
    private val chave = "66666666-6666-6666-6666-666666666666"

    private val funcaoJson = """{"id":"$funcao","nome":"Garçom","categoria":"salao"}"""
    private val reputacaoJson =
        """{"positivas":7,"total":7,"taxa_comparecimento":1.0,"turnos_considerados":7,"turnos_realizados":7}"""
    private val servicoJson =
        """{"funcao":$funcaoJson,"unidade":"diaria","valor_centavos":15000,"horas_incluidas":8,"leva_material":"nao","especialidades":[{"id":"77777777-7777-7777-7777-777777777777","funcao_id":"$funcao","nome":"Eventos"}]}"""
    private val regiaoJson = """{"id":1,"numero":"I","nome":"Plano Piloto"}"""
    private val chamadaJson =
        """{"id":"$chamadaId","vaga_id":"$vagaId","profissional_id":"$profissional","estabelecimento_id":"$casa","estado":"aberta","recado":"Traga avental","motivo_recusa":null,"expira_em":"2026-11-17T12:00:00Z","respondida_em":null,"criada_em":"2026-11-16T20:00:00Z"}"""
    private val resumoJson =
        """{"id":"$chamadaId","vaga_id":"$vagaId","profissional_id":"$profissional","estabelecimento_id":"$casa","estado":"aberta","expira_em":"2026-11-17T12:00:00Z","criada_em":"2026-11-16T20:00:00Z","funcao":$funcaoJson,"inicio_em":"2026-11-20T22:00:00Z","fim_em":"2026-11-21T02:00:00Z","valor_centavos":18000,"outra_parte":{"id":"$casa","tipo":"estabelecimento","nome":"Bistrô Aurora","reputacao":$reputacaoJson}}"""
    private val preferenciaJson =
        """{"aceita_de_quem_ja_trabalhou":true,"pausado_ate":null,"antecedencia_minima_h":6,"aceita_de":"todos","aceita_chamadas":true,"pendencias_para_busca":["sem_regiao"]}"""

    private class Visto {
        var metodo: HttpMethod? = null
        var caminho: String? = null
        var corpo: JsonObject? = null
    }

    private fun servico(
        visto: Visto,
        resposta: String,
        status: HttpStatusCode = HttpStatusCode.OK,
    ): ServicoChamadaDireta {
        val engine = MockEngine { request ->
            visto.metodo = request.method
            visto.caminho = request.url.encodedPath
            visto.corpo = (request.body as? TextContent)?.let {
                ClienteSupabase.jsonFrila.parseToJsonElement(it.text).jsonObject
            }
            respond(resposta, status, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        return ServicoChamadaDireta(ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine))
    }

    private suspend fun erroDe(bloco: suspend () -> Unit): ErroDaApi {
        val excecao = runCatching { bloco() }.exceptionOrNull()
        assertTrue(excecao is ErroDaApi, "esperava ErroDaApi, veio $excecao")
        return excecao as ErroDaApi
    }

    @Test
    fun `perfilPublico manda o id e decodifica o perfil rico com o nome so com inicial`() = runTest {
        val visto = Visto()
        val perfil = servico(
            visto,
            """{"id":"$profissional","tipo":"profissional","nome":"Maria S.","funcoes":["Garçom"],"reputacao":$reputacaoJson,"apresentacao":"Dez anos de salão","experiencia_faixa":"de_5_a_10_anos","cursos":["Boas práticas"],"idiomas":["portugues","ingles"],"servicos":[$servicoJson],"regioes":[$regiaoJson],"atende_todo_df":false,"no_frila_desde":"2026-03"}""",
        ).perfilPublico(profissional)

        assertEquals(HttpMethod.Post, visto.metodo)
        assertEquals("/rest/v1/rpc/perfil_publico", visto.caminho)
        assertEquals(setOf("id"), visto.corpo!!.keys)
        assertEquals(profissional, visto.corpo!!["id"]!!.jsonPrimitive.content)
        assertEquals("Maria S.", perfil.nome)
        assertEquals("de_5_a_10_anos", perfil.experienciaFaixa)
        assertEquals("diaria", perfil.servicos!!.single().unidade)
        assertEquals(15000L, perfil.servicos!!.single().valorCentavos)
        assertEquals("Eventos", perfil.servicos!!.single().especialidades!!.single().nome)
        assertEquals("Plano Piloto", perfil.regioes!!.single().nome)
        assertEquals(false, perfil.atendeTodoDf)
        assertEquals("2026-03", perfil.noFrilaDesde)
    }

    @Test
    fun `perfilPublico de perfil sem os campos novos continua decodificando como na Equipe`() = runTest {
        val perfil = servico(
            Visto(),
            """{"id":"$profissional","tipo":"profissional","nome":"Maria S.","reputacao":$reputacaoJson}""",
        ).perfilPublico(profissional)

        assertNull(perfil.servicos)
        assertNull(perfil.apresentacao)
    }

    @Test
    fun `perfilPublico de par bloqueado propaga 404 nao_encontrado`() = runTest {
        val servico = servico(
            Visto(),
            """{"code":"nao_encontrado","message":"perfil indisponivel"}""",
            HttpStatusCode.NotFound,
        )

        assertEquals(CodigoErroAPI.NAO_ENCONTRADO, erroDe { servico.perfilPublico(profissional) }.codigo)
    }

    @Test
    fun `meuPerfilDetalhado chama POST rpc meu_perfil_detalhado e decodifica servicos e preferencias`() = runTest {
        val visto = Visto()
        val perfil = servico(
            visto,
            """{"id":"$profissional","usuario_id":"88888888-8888-8888-8888-888888888888","funcoes":[$funcaoJson],"ponto_base":{"latitude":-15.79,"longitude":-47.88},"disponibilidades":[{"dia_semana":5,"hora_inicio":"18:00","hora_fim":"23:00"}],"reputacao":$reputacaoJson,"apresentacao":null,"cursos":[],"idiomas":["libras"],"servicos":[$servicoJson],"regioes":[$regiaoJson],"atende_todo_df":true,"preferencia_chamadas":$preferenciaJson}""",
        ).meuPerfilDetalhado()

        assertEquals(HttpMethod.Post, visto.metodo)
        assertEquals("/rest/v1/rpc/meu_perfil_detalhado", visto.caminho)
        assertTrue(visto.corpo!!.isEmpty())
        assertEquals(1, perfil.servicos.size)
        assertTrue(perfil.atendeTodoDf)
        assertEquals(listOf("sem_regiao"), perfil.preferenciaChamadas!!.pendenciasParaBusca)
    }

    @Test
    fun `definirServicos manda so os campos da unidade e decodifica o perfil`() = runTest {
        val visto = Visto()
        val perfil = servico(
            visto,
            """{"id":"$profissional","usuario_id":"88888888-8888-8888-8888-888888888888","funcoes":[$funcaoJson],"disponibilidades":[],"reputacao":$reputacaoJson,"cursos":[],"idiomas":[],"servicos":[$servicoJson],"regioes":[],"atende_todo_df":false}""",
        ).definirServicos(
            listOf(ServicoOferecidoDto(funcaoId = funcao, unidade = "diaria", valorCentavos = 15000, horasIncluidas = 8)),
        )

        assertEquals("/rest/v1/rpc/definir_servicos", visto.caminho)
        val enviado = visto.corpo!!["servicos"]!!.jsonArray.single().jsonObject
        assertEquals(setOf("funcao_id", "unidade", "valor_centavos", "horas_incluidas"), enviado.keys)
        assertEquals(15000, enviado["valor_centavos"]!!.jsonPrimitive.int)
        assertEquals(8, enviado["horas_incluidas"]!!.jsonPrimitive.int)
        assertEquals(1, perfil.servicos.size)
    }

    @Test
    fun `definirServicos com lista vazia manda servicos vazio para limpar`() = runTest {
        val visto = Visto()
        servico(
            visto,
            """{"id":"$profissional","usuario_id":"88888888-8888-8888-8888-888888888888","reputacao":$reputacaoJson,"cursos":[],"idiomas":[],"servicos":[],"regioes":[],"atende_todo_df":false}""",
        ).definirServicos(emptyList())

        assertEquals(0, visto.corpo!!["servicos"]!!.jsonArray.size)
    }

    @Test
    fun `definirServicos com funcao nao marcada propaga 422 com o funcao_id em details`() = runTest {
        val servico = servico(
            Visto(),
            """{"code":"funcao_nao_marcada","message":"funcao fora do perfil","details":"$funcao"}""",
            HttpStatusCode.UnprocessableEntity,
        )

        val erro = erroDe { servico.definirServicos(listOf(ServicoOferecidoDto(funcaoId = funcao, unidade = "a_combinar"))) }

        assertEquals(CodigoErroAPI.FUNCAO_NAO_MARCADA, erro.codigo)
        assertEquals(funcao, erro.detalhes)
    }

    @Test
    fun `definirPreferenciaChamadas liga com versao do texto e nao manda o que ficou de fora`() = runTest {
        val visto = Visto()
        val preferencias = servico(visto, preferenciaJson).definirPreferenciaChamadas(
            DefinirPreferenciaChamadasDto(aceitaChamadas = true, versaoTextoBusca = "busca-v1"),
        )

        assertEquals("/rest/v1/rpc/definir_preferencia_chamadas", visto.caminho)
        assertEquals(setOf("aceita_chamadas", "versao_texto_busca"), visto.corpo!!.keys)
        assertTrue(visto.corpo!!["aceita_chamadas"]!!.jsonPrimitive.boolean)
        assertEquals("busca-v1", visto.corpo!!["versao_texto_busca"]!!.jsonPrimitive.content)
        assertEquals(true, preferencias.aceitaChamadas)
        assertEquals(listOf("sem_regiao"), preferencias.pendenciasParaBusca)
        assertEquals(6, preferencias.antecedenciaMinimaH)
    }

    @Test
    fun `definirPreferenciaChamadas distingue tirar a pausa (null) de nao mexer nela`() = runTest {
        val tirar = Visto()
        servico(tirar, preferenciaJson).definirPreferenciaChamadas(DefinirPreferenciaChamadasDto(pausadoAte = JsonNull))
        assertEquals(setOf("pausado_ate"), tirar.corpo!!.keys)
        assertEquals(JsonNull, tirar.corpo!!["pausado_ate"])

        val pausar = Visto()
        servico(pausar, preferenciaJson).definirPreferenciaChamadas(
            DefinirPreferenciaChamadasDto(pausadoAte = JsonPrimitive("2026-12-01")),
        )
        assertEquals("2026-12-01", pausar.corpo!!["pausado_ate"]!!.jsonPrimitive.content)

        val nada = Visto()
        servico(nada, preferenciaJson).definirPreferenciaChamadas(DefinirPreferenciaChamadasDto(aceitaDe = "so_cnpj"))
        assertFalse(nada.corpo!!.containsKey("pausado_ate"))
    }

    @Test
    fun `definirPreferenciaChamadas ligar sem versao do texto propaga 422 campo_obrigatorio`() = runTest {
        val servico = servico(
            Visto(),
            """{"code":"campo_obrigatorio","message":"falta a versao","details":"versao_texto_busca"}""",
            HttpStatusCode.UnprocessableEntity,
        )

        val erro = erroDe { servico.definirPreferenciaChamadas(DefinirPreferenciaChamadasDto(aceitaChamadas = true)) }

        assertEquals(CodigoErroAPI.CAMPO_OBRIGATORIO, erro.codigo)
        assertEquals("versao_texto_busca", erro.detalhes)
    }

    @Test
    fun `buscarProfissionais manda POST com filtros e horario, sem os campos de fora, e decodifica a pagina`() = runTest {
        val visto = Visto()
        val pagina = servico(
            visto,
            """{"itens":[{"id":"$profissional","nome":"Maria S.","servico":$servicoJson,"regioes":[$regiaoJson],"atende_todo_df":false,"distancia_faixa":"ate_5_km","reputacao":$reputacaoJson,"disponivel_no_horario":true},{"id":"99999999-9999-9999-9999-999999999999","nome":"João P.","servico":$servicoJson,"regioes":[],"atende_todo_df":true,"distancia_faixa":"mais_de_15_km","reputacao":$reputacaoJson}],"proximo_cursor":"abc123"}""",
        ).buscarProfissionais(
            BuscarProfissionaisDto(
                estabelecimentoId = casa,
                funcaoId = funcao,
                regiaoId = 1,
                inicioEm = "2026-11-20T22:00:00Z",
                fimEm = "2026-11-21T02:00:00Z",
            ),
        )

        assertEquals(HttpMethod.Post, visto.metodo)
        assertEquals("/rest/v1/rpc/buscar_profissionais", visto.caminho)
        assertEquals(setOf("estabelecimento_id", "funcao_id", "regiao_id", "inicio_em", "fim_em"), visto.corpo!!.keys)
        assertEquals(1, visto.corpo!!["regiao_id"]!!.jsonPrimitive.int)
        assertEquals(2, pagina.itens.size)
        assertEquals("Maria S.", pagina.itens[0].nome)
        assertEquals(true, pagina.itens[0].disponivelNoHorario)
        assertNull(pagina.itens[1].disponivelNoHorario)
        assertEquals("mais_de_15_km", pagina.itens[1].distanciaFaixa)
        assertEquals("abc123", pagina.proximoCursor)
    }

    @Test
    fun `buscarProfissionais da pagina seguinte manda o cursor e ultima pagina volta sem proximo_cursor`() = runTest {
        val visto = Visto()
        val pagina = servico(visto, """{"itens":[],"proximo_cursor":null}""").buscarProfissionais(
            BuscarProfissionaisDto(estabelecimentoId = casa, funcaoId = funcao, cursor = "abc123", limite = 20),
        )

        assertEquals("abc123", visto.corpo!!["cursor"]!!.jsonPrimitive.content)
        assertEquals(20, visto.corpo!!["limite"]!!.jsonPrimitive.int)
        assertTrue(pagina.itens.isEmpty())
        assertNull(pagina.proximoCursor)
    }

    @Test
    fun `buscarProfissionais acima do limite por hora propaga 429 limite_excedido`() = runTest {
        val servico = servico(
            Visto(),
            """{"code":"limite_excedido","message":"60 buscas por hora"}""",
            HttpStatusCode.TooManyRequests,
        )

        val erro = erroDe { servico.buscarProfissionais(BuscarProfissionaisDto(estabelecimentoId = casa, funcaoId = funcao)) }

        assertEquals(CodigoErroAPI.LIMITE_EXCEDIDO, erro.codigo)
    }

    @Test
    fun `buscarProfissionais com cursor adulterado propaga 422 cursor_invalido com details`() = runTest {
        val servico = servico(
            Visto(),
            """{"code":"cursor_invalido","message":"cursor de outra busca","details":"cursor"}""",
            HttpStatusCode.UnprocessableEntity,
        )

        val erro = erroDe {
            servico.buscarProfissionais(BuscarProfissionaisDto(estabelecimentoId = casa, funcaoId = funcao, cursor = "x"))
        }

        assertEquals(CodigoErroAPI.CURSOR_INVALIDO, erro.codigo)
        assertEquals("cursor", erro.detalhes)
    }

    @Test
    fun `buscarProfissionais com recurso desligado propaga 403 sem_permissao com details recurso_desligado`() = runTest {
        val servico = servico(
            Visto(),
            """{"code":"sem_permissao","message":"busca desligada","details":"recurso_desligado"}""",
            HttpStatusCode.Forbidden,
        )

        val erro = erroDe { servico.buscarProfissionais(BuscarProfissionaisDto(estabelecimentoId = casa, funcaoId = funcao)) }

        assertEquals(CodigoErroAPI.SEM_PERMISSAO, erro.codigo)
        assertEquals("recurso_desligado", erro.detalhes)
    }

    @Test
    fun `chamarProfissional novo trabalho manda os campos da vaga com regiao_id da busca e decodifica a Chamada`() = runTest {
        val visto = Visto()
        val chamada = servico(visto, chamadaJson).chamarProfissional(
            ChamarProfissionalDto(
                chave = chave,
                profissionalId = profissional,
                estabelecimentoId = casa,
                funcaoId = funcao,
                inicioEm = "2026-11-20T22:00:00Z",
                fimEm = "2026-11-21T02:00:00Z",
                local = "SCS Quadra 2",
                regiaoAdministrativa = "Plano Piloto",
                regiaoId = 1,
                ponto = CoordenadaDto(latitude = -15.79, longitude = -47.88),
                valorCentavos = 18000,
                incluiRefeicao = true,
                incluiTransporte = false,
                exigeMaterialProprio = false,
                responsavelLocal = "Ana",
                recado = "Traga avental",
            ),
        )

        assertEquals(HttpMethod.Post, visto.metodo)
        assertEquals("/rest/v1/rpc/chamar_profissional", visto.caminho)
        val corpo = visto.corpo!!
        assertEquals(chave, corpo["chave"]!!.jsonPrimitive.content)
        assertEquals(profissional, corpo["profissional_id"]!!.jsonPrimitive.content)
        assertEquals(1, corpo["regiao_id"]!!.jsonPrimitive.int)
        assertEquals("Plano Piloto", corpo["regiao_administrativa"]!!.jsonPrimitive.content)
        assertEquals(-15.79, corpo["ponto"]!!.jsonObject["latitude"]!!.jsonPrimitive.content.toDouble())
        assertEquals(18000, corpo["valor_centavos"]!!.jsonPrimitive.int)
        assertFalse(corpo.containsKey("vaga_id"), "vaga_id e os campos da RN02 são exclusivos")
        assertFalse(corpo.containsKey("confirmo_recorrencia"))
        assertEquals(chamadaId, chamada.id)
        assertEquals("aberta", chamada.estado)
        assertNull(chamada.motivoRecusa)
    }

    @Test
    fun `chamarProfissional para a mesma vaga manda so vaga_id e nunca os campos da RN02`() = runTest {
        val visto = Visto()
        servico(visto, chamadaJson).chamarProfissional(
            ChamarProfissionalDto(chave = chave, profissionalId = profissional, estabelecimentoId = casa, vagaId = vagaId),
        )

        assertEquals(setOf("chave", "profissional_id", "estabelecimento_id", "vaga_id"), visto.corpo!!.keys)
    }

    @Test
    fun `chamarProfissional sem confirmar a recorrencia propaga 409 e reenviar manda confirmo_recorrencia`() = runTest {
        val recusa = servico(
            Visto(),
            """{"code":"recorrencia_nao_confirmada","message":"3a chamada em 7 dias"}""",
            HttpStatusCode.Conflict,
        )
        val pedido = ChamarProfissionalDto(chave = chave, profissionalId = profissional, estabelecimentoId = casa, vagaId = vagaId)

        assertEquals(CodigoErroAPI.RECORRENCIA_NAO_CONFIRMADA, erroDe { recusa.chamarProfissional(pedido) }.codigo)

        val visto = Visto()
        servico(visto, chamadaJson).chamarProfissional(pedido.copy(confirmoRecorrencia = true))
        assertTrue(visto.corpo!!["confirmo_recorrencia"]!!.jsonPrimitive.boolean)
    }

    @Test
    fun `chamarProfissional indisponivel e limite de chamadas propagam 422 com details`() = runTest {
        val pedido = ChamarProfissionalDto(chave = chave, profissionalId = profissional, estabelecimentoId = casa, vagaId = vagaId)

        val indisponivel = erroDe {
            servico(
                Visto(),
                """{"code":"profissional_indisponivel","message":"x","details":"nao_aceita_chamadas"}""",
                HttpStatusCode.UnprocessableEntity,
            ).chamarProfissional(pedido)
        }
        assertEquals(CodigoErroAPI.PROFISSIONAL_INDISPONIVEL, indisponivel.codigo)
        assertEquals("nao_aceita_chamadas", indisponivel.detalhes)

        val limite = erroDe {
            servico(
                Visto(),
                """{"code":"limite_de_chamadas","message":"x","details":"por_dia"}""",
                HttpStatusCode.UnprocessableEntity,
            ).chamarProfissional(pedido)
        }
        assertEquals(CodigoErroAPI.LIMITE_DE_CHAMADAS, limite.codigo)
        assertEquals("por_dia", limite.detalhes)
    }

    @Test
    fun `chamarProfissional com chamada aberta do par propaga 409 chamada_ja_aberta`() = runTest {
        val servico = servico(Visto(), """{"code":"chamada_ja_aberta","message":"x"}""", HttpStatusCode.Conflict)

        val erro = erroDe {
            servico.chamarProfissional(
                ChamarProfissionalDto(chave = chave, profissionalId = profissional, estabelecimentoId = casa, vagaId = vagaId),
            )
        }

        assertEquals(CodigoErroAPI.CHAMADA_JA_ABERTA, erro.codigo)
    }

    @Test
    fun `responderChamada aceitar manda a resposta sem motivo e decodifica o turno e o local liberado`() = runTest {
        val visto = Visto()
        val resultado = servico(
            visto,
            """{"chamada":{"id":"$chamadaId","vaga_id":"$vagaId","profissional_id":"$profissional","estabelecimento_id":"$casa","estado":"aceita","expira_em":"2026-11-17T12:00:00Z","respondida_em":"2026-11-16T21:00:00Z","criada_em":"2026-11-16T20:00:00Z"},"turno_id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","local":"SCS Quadra 2","ponto":{"latitude":-15.79,"longitude":-47.88},"responsavel_local":"Ana"}""",
        ).responderChamada(chamadaId, "aceitar")

        assertEquals(HttpMethod.Post, visto.metodo)
        assertEquals("/rest/v1/rpc/responder_chamada", visto.caminho)
        assertEquals(setOf("chamada_id", "resposta"), visto.corpo!!.keys)
        assertEquals("aceitar", visto.corpo!!["resposta"]!!.jsonPrimitive.content)
        assertEquals("aceita", resultado.chamada.estado)
        assertEquals("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", resultado.turnoId)
        assertEquals("SCS Quadra 2", resultado.local)
        assertEquals("Ana", resultado.responsavelLocal)
    }

    @Test
    fun `responderChamada recusar manda o motivo e a resposta traz so a chamada`() = runTest {
        val visto = Visto()
        val resultado = servico(visto, """{"chamada":$chamadaJson}""").responderChamada(chamadaId, "recusar", "agenda")

        assertEquals("recusar", visto.corpo!!["resposta"]!!.jsonPrimitive.content)
        assertEquals("agenda", visto.corpo!!["motivo_recusa"]!!.jsonPrimitive.content)
        assertNull(resultado.turnoId)
        assertNull(resultado.local)
    }

    @Test
    fun `responderChamada expirada propaga 409 chamada_indisponivel e turno sobreposto 422 inelegivel`() = runTest {
        val expirada = erroDe {
            servico(
                Visto(),
                """{"code":"chamada_indisponivel","message":"x","details":"expirada"}""",
                HttpStatusCode.Conflict,
            ).responderChamada(chamadaId, "aceitar")
        }
        assertEquals(CodigoErroAPI.CHAMADA_INDISPONIVEL, expirada.codigo)
        assertEquals("expirada", expirada.detalhes)

        val sobreposto = erroDe {
            servico(
                Visto(),
                """{"code":"inelegivel","message":"x","details":"turno_sobreposto"}""",
                HttpStatusCode.UnprocessableEntity,
            ).responderChamada(chamadaId, "aceitar")
        }
        assertEquals(CodigoErroAPI.INELEGIVEL, sobreposto.codigo)
        assertEquals("turno_sobreposto", sobreposto.detalhes)
    }

    @Test
    fun `cancelarChamada manda chamada_id e decodifica a Chamada`() = runTest {
        val visto = Visto()
        val chamada = servico(
            visto,
            chamadaJson.replace("\"estado\":\"aberta\"", "\"estado\":\"cancelada\""),
        ).cancelarChamada(chamadaId)

        assertEquals(HttpMethod.Post, visto.metodo)
        assertEquals("/rest/v1/rpc/cancelar_chamada", visto.caminho)
        assertEquals(setOf("chamada_id"), visto.corpo!!.keys)
        assertEquals("cancelada", chamada.estado)
    }

    @Test
    fun `cancelarChamada de chamada ja respondida propaga 409 chamada_indisponivel`() = runTest {
        val servico = servico(Visto(), """{"code":"chamada_indisponivel","message":"x"}""", HttpStatusCode.Conflict)

        assertEquals(CodigoErroAPI.CHAMADA_INDISPONIVEL, erroDe { servico.cancelarChamada(chamadaId) }.codigo)
    }

    @Test
    fun `minhasChamadas manda estado, cursor e limite so quando vierem e decodifica a pagina`() = runTest {
        val visto = Visto()
        val pagina = servico(visto, """{"itens":[$resumoJson],"proximo_cursor":"c2"}""").minhasChamadas(
            estado = "aberta",
            cursor = "c1",
            limite = 20,
        )

        assertEquals(HttpMethod.Post, visto.metodo)
        assertEquals("/rest/v1/rpc/minhas_chamadas", visto.caminho)
        assertEquals(setOf("estado", "cursor", "limite"), visto.corpo!!.keys)
        assertEquals("aberta", visto.corpo!!["estado"]!!.jsonPrimitive.content)
        assertEquals(chamadaId, pagina.itens.single().id)
        assertEquals("Bistrô Aurora", pagina.itens.single().outraParte.nome)
        assertEquals(18000L, pagina.itens.single().valorCentavos)
        assertEquals("c2", pagina.proximoCursor)
    }

    @Test
    fun `minhasChamadas sem filtros manda corpo vazio`() = runTest {
        val visto = Visto()
        val pagina = servico(visto, """{"itens":[],"proximo_cursor":null}""").minhasChamadas()

        assertTrue(visto.corpo!!.isEmpty())
        assertTrue(pagina.itens.isEmpty())
        assertNull(pagina.proximoCursor)
    }

    @Test
    fun `minhasChamadas com cursor de outra lista propaga 422 cursor_invalido`() = runTest {
        val servico = servico(
            Visto(),
            """{"code":"cursor_invalido","message":"x","details":"cursor"}""",
            HttpStatusCode.UnprocessableEntity,
        )

        val erro = erroDe { servico.minhasChamadas(cursor = "velho") }

        assertEquals(CodigoErroAPI.CURSOR_INVALIDO, erro.codigo)
        assertEquals("cursor", erro.detalhes)
    }

    @Test
    fun `detalheChamada manda chamada_id e antes do aceite local ponto e responsavel nao vem`() = runTest {
        val visto = Visto()
        val detalhe = servico(
            visto,
            """{"id":"$chamadaId","vaga_id":"$vagaId","profissional_id":"$profissional","estabelecimento_id":"$casa","estado":"aberta","expira_em":"2026-11-17T12:00:00Z","criada_em":"2026-11-16T20:00:00Z","funcao":$funcaoJson,"inicio_em":"2026-11-20T22:00:00Z","fim_em":"2026-11-21T02:00:00Z","valor_centavos":18000,"outra_parte":{"id":"$casa","tipo":"estabelecimento","nome":"Bistrô Aurora","reputacao":$reputacaoJson},"tipo_estabelecimento":"food_service","conta_nova":false,"regiao_administrativa":"Plano Piloto","distancia_faixa":"de_5_a_15_km","inclui_refeicao":true,"inclui_transporte":false,"exige_material_proprio":false}""",
        ).detalheChamada(chamadaId)

        assertEquals(HttpMethod.Post, visto.metodo)
        assertEquals("/rest/v1/rpc/detalhe_chamada", visto.caminho)
        assertEquals(setOf("chamada_id"), visto.corpo!!.keys)
        assertEquals("de_5_a_15_km", detalhe.distanciaFaixa)
        assertEquals("food_service", detalhe.tipoEstabelecimento)
        assertTrue(detalhe.incluiRefeicao)
        assertNull(detalhe.local)
        assertNull(detalhe.ponto)
        assertNull(detalhe.responsavelLocal)
        assertNull(detalhe.turnoId)
    }

    @Test
    fun `detalheChamada de quem nao e parte propaga 404 nao_encontrado`() = runTest {
        val servico = servico(Visto(), """{"code":"nao_encontrado","message":"x"}""", HttpStatusCode.NotFound)

        assertEquals(CodigoErroAPI.NAO_ENCONTRADO, erroDe { servico.detalheChamada(chamadaId) }.codigo)
    }

    @Test
    fun `publicarAPartirDaChamada manda vaga_id e chave, modo so quando vier, e decodifica a vaga nova`() = runTest {
        val visto = Visto()
        val publicada = servico(visto, """{"vaga_id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","posicoes":["cccccccc-cccc-cccc-cccc-cccccccccccc"]}""")
            .publicarAPartirDaChamada(vagaId, chave)

        assertEquals(HttpMethod.Post, visto.metodo)
        assertEquals("/rest/v1/rpc/publicar_a_partir_da_chamada", visto.caminho)
        assertEquals(setOf("vaga_id", "chave"), visto.corpo!!.keys)
        assertEquals("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", publicada.vagaId)
        assertEquals(1, publicada.posicoes.size)

        val comModo = Visto()
        servico(comModo, """{"vaga_id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","posicoes":[]}""")
            .publicarAPartirDaChamada(vagaId, chave, modo = "selecao")
        assertEquals("selecao", comModo.corpo!!["modo"]!!.jsonPrimitive.content)
    }

    @Test
    fun `publicarAPartirDaChamada fora da janela propaga 409 vaga_encerrada`() = runTest {
        val servico = servico(Visto(), """{"code":"vaga_encerrada","message":"x"}""", HttpStatusCode.Conflict)

        assertEquals(CodigoErroAPI.VAGA_ENCERRADA, erroDe { servico.publicarAPartirDaChamada(vagaId, chave) }.codigo)
    }

    @Test
    fun `usa o cliente atual a cada chamada depois de o gestor recriar o cliente`() = runTest {
        var caminhos = mutableListOf<String>()
        fun cliente() = ClienteSupabase(
            "https://frila.supabase.co",
            "chave-teste",
            engine = MockEngine { request ->
                caminhos += request.url.encodedPath
                respond("""{"itens":[],"proximo_cursor":null}""", HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
            },
        )
        var atual = cliente()
        val servico = ServicoChamadaDireta { atual }

        servico.minhasChamadas()
        atual = cliente()
        servico.minhasChamadas()

        assertEquals(2, caminhos.size)
    }
}
