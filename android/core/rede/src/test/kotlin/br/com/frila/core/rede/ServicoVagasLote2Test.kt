package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.http.HttpStatusCode
import java.time.Instant
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Lote 2 (L2-0): `cancelar_vaga`, `republicar_vaga`, `republicar_posicoes_restantes`, `detalhe_vaga`,
 * `retirar_candidatura` e `minhas_candidaturas`. Pedido, resposta e as recusas do contrato 0.2.95.
 */
class ServicoVagasLote2Test {

    private val vaga = "22222222-2222-2222-2222-222222222222"
    private val vagaNova = "55555555-5555-5555-5555-555555555555"
    private val candidatura = "66666666-6666-6666-6666-666666666666"
    private val chave = "77777777-7777-7777-7777-777777777777"
    private val turno = "11111111-1111-1111-1111-111111111111"

    private val semPermissao = Recusa(HttpStatusCode.Forbidden, "sem_permissao", CodigoErroAPI.SEM_PERMISSAO)
    private val naoEncontrado = Recusa(HttpStatusCode.NotFound, "nao_encontrado", CodigoErroAPI.NAO_ENCONTRADO)
    private val perfilIncompativel = Recusa(HttpStatusCode.UnprocessableEntity, "perfil_incompativel", CodigoErroAPI.PERFIL_INCOMPATIVEL)
    private val vagaOculta = Recusa(HttpStatusCode.UnprocessableEntity, "vaga_oculta", CodigoErroAPI.VAGA_OCULTA)

    private val vagaPublicadaJson = """{"vaga_id":"$vagaNova","posicoes":["p1","p2"]}"""

    private val vagaResumoJson = """
        {"id":"$vaga","funcao":"Garçom","local":"CLS 405 Bloco C","regiao_administrativa":"Plano Piloto",
         "inicio_em":"2026-12-01T21:00:00Z","fim_em":"2026-12-02T03:00:00Z","valor_centavos":16000,"ponto":null,
         "origem":"publicacao","vaga_origem_id":null}
    """.trimIndent()

    private val vagaObrigatoriosJson = """
        "id":"$vaga",
        "estabelecimento":{"id":"e1","tipo":"estabelecimento","nome":"Bar do Zé",
          "reputacao":{"positivas":7,"total":8,"turnos_considerados":8,"turnos_realizados":8}},
        "funcao":{"id":"f1","nome":"Garçom","categoria":"salao"},
        "inicio_em":"2026-12-01T21:00:00Z","fim_em":"2026-12-02T03:00:00Z",
        "local":"CLS 405 Bloco C","regiao_administrativa":"Plano Piloto",
        "ponto":{"latitude":-15.81,"longitude":-47.89},
        "valor_centavos":16000,"posicoes":3,"posicoes_abertas":2,
        "inclusos":{"inclui_refeicao":true,"inclui_transporte":false,"exige_material_proprio":false},
        "responsavel_local":"Procure a gerente no balcão",
        "modo":"selecao","estado":"publicada","oculta":false,"publicado_em":"2026-11-17T12:00:00Z"
    """.trimIndent()

    // ---- cancelar_vaga ----

    @Test
    fun `cancelarVaga faz POST com vaga_id e motivo e decodifica a vaga cancelada`() = runTest {
        val visto = PedidoVisto()
        val servico = ServicoVagas(clienteDeTeste(visto, """{"vaga_id":"$vaga","estado":"cancelada","posicoes_canceladas":3}"""))

        val resultado = servico.cancelarVaga(vaga, "O evento foi adiado")

        visto.conferirPost("cancelar_vaga")
        assertEquals(setOf("vaga_id", "motivo"), visto.corpo!!.keys)
        assertEquals(vaga, visto.corpo!!["vaga_id"]!!.jsonPrimitive.content)
        assertEquals("O evento foi adiado", visto.corpo!!["motivo"]!!.jsonPrimitive.content)
        assertEquals(vaga, resultado.vagaId)
        assertEquals("cancelada", resultado.estado)
        assertEquals(3, resultado.posicoesCanceladas)
    }

    @Test
    fun `cancelarVaga lanca o codigo de cada recusa do contrato`() = runTest {
        conferirRecusas(
            listOf(
                Recusa(HttpStatusCode.Conflict, "vaga_encerrada", CodigoErroAPI.VAGA_ENCERRADA),
                Recusa(HttpStatusCode.UnprocessableEntity, "campo_obrigatorio", CodigoErroAPI.CAMPO_OBRIGATORIO, "motivo"),
                Recusa(HttpStatusCode.UnprocessableEntity, "campo_invalido", CodigoErroAPI.CAMPO_INVALIDO, "motivo"),
                naoEncontrado,
                perfilIncompativel,
                CONTA_SUSPENSA,
                TOKEN_VENCIDO,
            ),
        ) { ServicoVagas(it).cancelarVaga(vaga, "ok") }
    }

    // ---- republicar_vaga ----

    @Test
    fun `republicarVaga faz POST com a origem, o horario novo em UTC ate o segundo e a chave`() = runTest {
        val visto = PedidoVisto()
        val servico = ServicoVagas(clienteDeTeste(visto, vagaPublicadaJson))

        val resultado = servico.republicarVaga(
            vagaId = vaga,
            inicio = Instant.parse("2026-12-01T21:00:00.987Z"),
            fim = Instant.parse("2026-12-02T03:00:00.123Z"),
            chave = chave,
        )

        visto.conferirPost("republicar_vaga")
        assertEquals(setOf("vaga_id", "inicio_em", "fim_em", "chave"), visto.corpo!!.keys)
        assertEquals(vaga, visto.corpo!!["vaga_id"]!!.jsonPrimitive.content)
        assertEquals("2026-12-01T21:00:00Z", visto.corpo!!["inicio_em"]!!.jsonPrimitive.content)
        assertEquals("2026-12-02T03:00:00Z", visto.corpo!!["fim_em"]!!.jsonPrimitive.content)
        assertEquals(chave, visto.corpo!!["chave"]!!.jsonPrimitive.content)
        assertEquals(vagaNova, resultado.vagaId)
        assertEquals(listOf("p1", "p2"), resultado.posicoes)
    }

    @Test
    fun `republicarVaga lanca o codigo de cada recusa do contrato`() = runTest {
        conferirRecusas(
            listOf(
                Recusa(HttpStatusCode.UnprocessableEntity, "horario_invalido", CodigoErroAPI.HORARIO_INVALIDO),
                Recusa(HttpStatusCode.UnprocessableEntity, "selecao_sem_antecedencia", CodigoErroAPI.SELECAO_SEM_ANTECEDENCIA),
                Recusa(HttpStatusCode.UnprocessableEntity, "campo_invalido", CodigoErroAPI.CAMPO_INVALIDO, "inicio_em"),
                vagaOculta,
                perfilIncompativel,
                naoEncontrado,
                semPermissao,
                CONTA_SUSPENSA,
                TOKEN_VENCIDO,
            ),
        ) { ServicoVagas(it).republicarVaga(vaga, Instant.parse("2026-12-01T21:00:00Z"), Instant.parse("2026-12-02T03:00:00Z"), chave) }
    }

    // ---- republicar_posicoes_restantes ----

    @Test
    fun `republicarPosicoesRestantes faz POST so com a origem e a chave e decodifica a vaga nova`() = runTest {
        val visto = PedidoVisto()
        val servico = ServicoVagas(clienteDeTeste(visto, vagaPublicadaJson))

        val resultado = servico.republicarPosicoesRestantes(vaga, chave)

        visto.conferirPost("republicar_posicoes_restantes")
        assertEquals(setOf("vaga_id", "chave"), visto.corpo!!.keys)
        assertEquals(vaga, visto.corpo!!["vaga_id"]!!.jsonPrimitive.content)
        assertEquals(chave, visto.corpo!!["chave"]!!.jsonPrimitive.content)
        assertEquals(vagaNova, resultado.vagaId)
        assertEquals(2, resultado.posicoes.size)
    }

    @Test
    fun `republicarPosicoesRestantes lanca republicacao_indisponivel com cada motivo em details e as outras recusas`() = runTest {
        val motivos = listOf("nao_e_selecao", "selecao_em_curso", "vaga_cancelada", "ja_comecou", "sem_posicoes_restantes", "ja_republicada")
        conferirRecusas(
            motivos.map {
                Recusa(HttpStatusCode.UnprocessableEntity, "republicacao_indisponivel", CodigoErroAPI.REPUBLICACAO_INDISPONIVEL, it)
            } + listOf(vagaOculta, perfilIncompativel, naoEncontrado, semPermissao, CONTA_SUSPENSA, TOKEN_VENCIDO),
        ) { ServicoVagas(it).republicarPosicoesRestantes(vaga, chave) }
    }

    // ---- detalhe_vaga ----

    @Test
    fun `detalheVaga faz POST com vaga_id no corpo e decodifica a vaga inteira`() = runTest {
        val visto = PedidoVisto()
        val json = """
            {$vagaObrigatoriosJson,
             "distancia_km":4.2,"traje":"Camisa preta","participa_rateio":true,"observacoes":"Chegar 15 min antes",
             "origem":"publicacao","vaga_origem_id":null,"campo_novo_do_servidor":1}
        """.trimIndent()
        val servico = ServicoVagas(clienteDeTeste(visto, json))

        val detalhe = servico.detalheVaga(vaga)

        visto.conferirPost("detalhe_vaga")
        assertEquals(setOf("vaga_id"), visto.corpo!!.keys)
        assertEquals(vaga, visto.corpo!!["vaga_id"]!!.jsonPrimitive.content)
        assertEquals(vaga, detalhe.id)
        assertEquals("Bar do Zé", detalhe.estabelecimento.nome)
        assertEquals("Garçom", detalhe.funcao.nome)
        assertEquals("2026-12-01T21:00:00Z", detalhe.inicioEm)
        assertEquals(-15.81, detalhe.ponto.latitude)
        assertEquals(4.2, detalhe.distanciaKm)
        assertEquals(16000L, detalhe.valorCentavos)
        assertEquals(3, detalhe.posicoes)
        assertEquals(2, detalhe.posicoesAbertas)
        assertTrue(detalhe.inclusos.incluiRefeicao)
        assertEquals("Procure a gerente no balcão", detalhe.responsavelLocal)
        assertEquals("Camisa preta", detalhe.traje)
        assertEquals(true, detalhe.participaRateio)
        assertEquals("selecao", detalhe.modo)
        assertEquals("publicada", detalhe.estado)
        assertFalse(detalhe.oculta)
        assertEquals("2026-11-17T12:00:00Z", detalhe.publicadoEm)
        assertEquals("publicacao", detalhe.origem)
        assertNull(detalhe.vagaOrigemId)
    }

    @Test
    fun `detalheVaga so com os campos obrigatorios do contrato decodifica com os opcionais nulos`() = runTest {
        val servico = ServicoVagas(clienteDeTeste(PedidoVisto(), "{$vagaObrigatoriosJson}"))

        val detalhe = servico.detalheVaga(vaga)

        assertNull(detalhe.distanciaKm)
        assertNull(detalhe.traje)
        assertNull(detalhe.participaRateio)
        assertNull(detalhe.observacoes)
        assertNull(detalhe.origem)
        assertNull(detalhe.vagaOrigemId)
    }

    @Test
    fun `detalheVaga lanca o codigo de cada recusa do contrato`() = runTest {
        conferirRecusas(listOf(naoEncontrado, perfilIncompativel, CONTA_SUSPENSA, TOKEN_VENCIDO)) { ServicoVagas(it).detalheVaga(vaga) }
    }

    // ---- retirar_candidatura ----

    @Test
    fun `retirarCandidatura faz POST so com candidatura_id e decodifica a candidatura retirada`() = runTest {
        val visto = PedidoVisto()
        val servico = ServicoVagas(
            clienteDeTeste(visto, """{"id":"$candidatura","vaga":$vagaResumoJson,"estado":"retirada","criada_em":"2026-11-16T10:00:00Z","turno_id":null}"""),
        )

        val retirada = servico.retirarCandidatura(candidatura)

        visto.conferirPost("retirar_candidatura")
        assertEquals(setOf("candidatura_id"), visto.corpo!!.keys)
        assertEquals(candidatura, visto.corpo!!["candidatura_id"]!!.jsonPrimitive.content)
        assertEquals(candidatura, retirada.id)
        assertEquals("retirada", retirada.estado)
        assertEquals(vaga, retirada.vaga.id)
        assertNull(retirada.turnoId)
    }

    @Test
    fun `retirarCandidatura lanca o codigo de cada recusa do contrato`() = runTest {
        conferirRecusas(
            listOf(
                Recusa(HttpStatusCode.Conflict, "candidatura_indisponivel", CodigoErroAPI.CANDIDATURA_INDISPONIVEL),
                Recusa(HttpStatusCode.UnprocessableEntity, "campo_obrigatorio", CodigoErroAPI.CAMPO_OBRIGATORIO, "candidatura_id"),
                perfilIncompativel,
                naoEncontrado,
                CONTA_SUSPENSA,
                TOKEN_VENCIDO,
            ),
        ) { ServicoVagas(it).retirarCandidatura(candidatura) }
    }

    // ---- minhas_candidaturas ----

    @Test
    fun `minhasCandidaturas sem filtro faz POST com corpo vazio e decodifica a aceita com turno e a pendente sem`() = runTest {
        val visto = PedidoVisto()
        val json = """
            [{"id":"$candidatura","vaga":$vagaResumoJson,"estado":"aceita","criada_em":"2026-11-16T10:00:00Z","turno_id":"$turno"},
             {"id":"c2","vaga":$vagaResumoJson,"estado":"pendente","criada_em":"2026-11-15T10:00:00Z"}]
        """.trimIndent()
        val servico = ServicoVagas(clienteDeTeste(visto, json))

        val candidaturas = servico.minhasCandidaturas()

        visto.conferirPost("minhas_candidaturas")
        assertTrue(visto.corpo!!.isEmpty(), "sem filtro, estado não vai no corpo: ${visto.corpo}")
        assertEquals(2, candidaturas.size)
        assertEquals("aceita", candidaturas[0].estado)
        assertEquals(turno, candidaturas[0].turnoId)
        assertEquals("Garçom", candidaturas[0].vaga.funcao)
        assertEquals("pendente", candidaturas[1].estado)
        assertNull(candidaturas[1].turnoId)
    }

    @Test
    fun `minhasCandidaturas com filtro manda estado no corpo e lista vazia decodifica`() = runTest {
        val visto = PedidoVisto()
        val servico = ServicoVagas(clienteDeTeste(visto, "[]"))

        val candidaturas = servico.minhasCandidaturas(estado = "pendente")

        visto.conferirPost("minhas_candidaturas")
        assertEquals(setOf("estado"), visto.corpo!!.keys)
        assertEquals("pendente", visto.corpo!!["estado"]!!.jsonPrimitive.content)
        assertTrue(candidaturas.isEmpty())
    }

    @Test
    fun `minhasCandidaturas lanca o codigo de cada recusa do contrato`() = runTest {
        conferirRecusas(listOf(perfilIncompativel, CONTA_SUSPENSA, TOKEN_VENCIDO)) { ServicoVagas(it).minhasCandidaturas() }
    }
}
