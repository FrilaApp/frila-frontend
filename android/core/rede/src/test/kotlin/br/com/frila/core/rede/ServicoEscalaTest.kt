package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/** `publicar_escala` (contrato 0.2.96, RF19): o corpo do pedido, a resposta e as recusas, com os `details` em caminho. */
class ServicoEscalaTest {

    private val casa = "11111111-1111-1111-1111-111111111111"
    private val chave = "77777777-7777-7777-7777-777777777777"
    private val evento = "88888888-8888-8888-8888-888888888888"

    private fun item(funcao: String, posicoes: Int) = ItemEscalaDto(
        funcaoId = funcao,
        inicioEm = "2026-12-12T21:00:00Z",
        fimEm = "2026-12-13T03:00:00Z",
        valorCentavos = 18000,
        posicoes = posicoes,
        incluiRefeicao = true,
        incluiTransporte = false,
        exigeMaterialProprio = false,
        responsavelLocal = "Procure a Lia na portaria",
        modo = "urgencia",
    )

    private val escala = NovaEscalaDto(
        estabelecimentoId = casa,
        evento = EventoDaEscalaDto(
            nome = "Formatura de Direito",
            data = "2026-12-12",
            local = "CLS 408, Bloco B",
            regiaoAdministrativa = "Plano Piloto",
            ponto = CoordenadaDto(-15.78, -47.93),
        ),
        vagas = listOf(item("f1", 4), item("f2", 2)),
        chave = chave,
    )

    private val resposta = """{"evento_id":"$evento","vagas":[{"vaga_id":"v1","posicoes":["a","b","c","d"]},{"vaga_id":"v2","posicoes":["e","f"]}]}"""

    @Test
    fun `publicarEscala faz POST com estabelecimento, evento, vagas e a chave unica e decodifica uma vaga por item`() = runTest {
        val visto = PedidoVisto()
        val servico = ServicoVagas(clienteDeTeste(visto, resposta))

        val publicada = servico.publicarEscala(escala)

        visto.conferirPost("publicar_escala")
        val corpo = visto.corpo!!
        assertEquals(setOf("estabelecimento_id", "evento", "vagas", "chave"), corpo.keys)
        assertEquals(casa, corpo["estabelecimento_id"]!!.jsonPrimitive.content)
        assertEquals(chave, corpo["chave"]!!.jsonPrimitive.content)
        val eventoJson = corpo["evento"]!!.jsonObject
        assertEquals(setOf("nome", "data", "local", "regiao_administrativa", "ponto"), eventoJson.keys)
        assertEquals("2026-12-12", eventoJson["data"]!!.jsonPrimitive.content)
        val vagas: JsonArray = corpo["vagas"]!!.jsonArray
        assertEquals(2, vagas.size)
        val primeira = vagas[0].jsonObject
        // Os campos de endereço e a chave não vão por item: vêm do evento e da escala.
        assertTrue("local" !in primeira.keys && "chave" !in primeira.keys && "estabelecimento_id" !in primeira.keys)
        assertEquals("f1", primeira["funcao_id"]!!.jsonPrimitive.content)
        assertEquals(4, primeira["posicoes"]!!.jsonPrimitive.content.toInt())
        assertEquals(evento, publicada.eventoId)
        assertEquals(listOf("v1", "v2"), publicada.vagas.map { it.vagaId })
        assertEquals(4, publicada.vagas[0].posicoes.size)
    }

    @Test
    fun `publicarEscala lanca o codigo de cada recusa do contrato com o caminho do campo em details`() = runTest {
        val semPermissao = Recusa(HttpStatusCode.Forbidden, "sem_permissao", CodigoErroAPI.SEM_PERMISSAO)
        conferirRecusas(
            listOf(
                Recusa(HttpStatusCode.UnprocessableEntity, "campo_obrigatorio", CodigoErroAPI.CAMPO_OBRIGATORIO, "evento.nome"),
                Recusa(HttpStatusCode.UnprocessableEntity, "campo_invalido", CodigoErroAPI.CAMPO_INVALIDO, "vagas[2].valor_centavos"),
                Recusa(HttpStatusCode.UnprocessableEntity, "campo_invalido", CodigoErroAPI.CAMPO_INVALIDO, "vagas"),
                Recusa(HttpStatusCode.UnprocessableEntity, "campo_invalido", CodigoErroAPI.CAMPO_INVALIDO, "posicoes"),
                Recusa(HttpStatusCode.UnprocessableEntity, "horario_invalido", CodigoErroAPI.HORARIO_INVALIDO, "vagas[1]"),
                Recusa(HttpStatusCode.UnprocessableEntity, "selecao_sem_antecedencia", CodigoErroAPI.SELECAO_SEM_ANTECEDENCIA, "vagas[0]"),
                Recusa(HttpStatusCode.UnprocessableEntity, "perfil_incompativel", CodigoErroAPI.PERFIL_INCOMPATIVEL),
                semPermissao,
                CONTA_SUSPENSA,
                TOKEN_VENCIDO,
            ),
        ) { cliente -> ServicoVagas(cliente).publicarEscala(escala) }
    }
}
