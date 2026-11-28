package br.com.frila.feature.chamadas.profissional

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.ServicoChamadaDireta
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.client.request.HttpResponseData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject

/** Fixtures do contrato 0.2.88 para os testes do lado do profissional. Só dado sintético. */
internal object Fixtures {
    const val FUNCAO = "11111111-1111-1111-1111-111111111111"
    const val FUNCAO_BARMAN = "12121212-1212-1212-1212-121212121212"
    const val PROFISSIONAL = "22222222-2222-2222-2222-222222222222"
    const val CASA = "33333333-3333-3333-3333-333333333333"
    const val CHAMADA = "44444444-4444-4444-4444-444444444444"
    const val VAGA = "55555555-5555-5555-5555-555555555555"
    const val TURNO = "66666666-6666-6666-6666-666666666666"
    const val ESPECIALIDADE = "77777777-7777-7777-7777-777777777777"

    val funcaoJson = """{"id":"$FUNCAO","nome":"Garçom","categoria":"salao"}"""
    val barmanJson = """{"id":"$FUNCAO_BARMAN","nome":"Barman","categoria":"bar"}"""
    val reputacaoJson = """{"positivas":7,"total":7,"turnos_considerados":7,"turnos_realizados":7}"""

    fun preferenciaJson(
        aceitaChamadas: Boolean = false,
        pausadoAte: String? = null,
        antecedencia: Int = 6,
        aceitaDe: String = "todos",
        aceitaDeQuemJaTrabalhou: Boolean = true,
        pendencias: List<String> = emptyList(),
    ) = """{"aceita_de_quem_ja_trabalhou":$aceitaDeQuemJaTrabalhou,"pausado_ate":${pausadoAte?.let { "\"$it\"" }},"antecedencia_minima_h":$antecedencia,"aceita_de":"$aceitaDe","aceita_chamadas":$aceitaChamadas,"pendencias_para_busca":[${pendencias.joinToString(",") { "\"$it\"" }}]}"""

    fun perfilDetalhadoJson(
        funcoes: List<String> = listOf(funcaoJson),
        servicos: List<String> = emptyList(),
        preferencia: String? = preferenciaJson(),
    ) = """{"id":"$PROFISSIONAL","usuario_id":"88888888-8888-8888-8888-888888888888","funcoes":[${funcoes.joinToString(",")}],"disponibilidades":[],"reputacao":$reputacaoJson,"cursos":[],"idiomas":[],"servicos":[${servicos.joinToString(",")}],"regioes":[],"atende_todo_df":false${preferencia?.let { ",\"preferencia_chamadas\":$it" } ?: ""}}"""

    val servicoDiariaJson =
        """{"funcao":$funcaoJson,"unidade":"diaria","valor_centavos":15000,"horas_incluidas":8,"leva_material":"nao","inclui":"Avental","especialidades":[{"id":"$ESPECIALIDADE","funcao_id":"$FUNCAO","nome":"Eventos"}]}"""

    fun especialidadesJson(funcaoId: String = FUNCAO) =
        """[{"id":"$ESPECIALIDADE","funcao_id":"$funcaoId","nome":"Eventos","ativo":true},{"id":"99999999-9999-9999-9999-999999999999","funcao_id":"$funcaoId","nome":"Casamentos","ativo":true},{"id":"aaaaaaaa-0000-0000-0000-000000000000","funcao_id":"$funcaoId","nome":"Antiga","ativo":false}]"""

    fun detalheChamadaJson(
        estado: String = "aberta",
        expiraEm: String = "2026-11-17T12:00:00Z",
        contaNova: Boolean = false,
        recado: String? = "Traga avental",
        turnoId: String? = null,
        local: String? = null,
        responsavelLocal: String? = null,
    ) = """{"id":"$CHAMADA","vaga_id":"$VAGA","profissional_id":"$PROFISSIONAL","estabelecimento_id":"$CASA","estado":"$estado","recado":${recado?.let { "\"$it\"" }},"expira_em":"$expiraEm","criada_em":"2026-11-16T20:00:00Z","funcao":$funcaoJson,"inicio_em":"2026-11-20T22:00:00Z","fim_em":"2026-11-21T02:00:00Z","valor_centavos":18000,"outra_parte":{"id":"$CASA","tipo":"estabelecimento","nome":"Bistrô Aurora","reputacao":$reputacaoJson},"tipo_estabelecimento":"food_service","conta_nova":$contaNova,"regiao_administrativa":"Plano Piloto","distancia_faixa":"de_5_a_15_km","inclui_refeicao":true,"inclui_transporte":false,"exige_material_proprio":false${turnoId?.let { ",\"turno_id\":\"$it\"" } ?: ""}${local?.let { ",\"local\":\"$it\"" } ?: ""}${responsavelLocal?.let { ",\"responsavel_local\":\"$it\"" } ?: ""}}"""

    fun resultadoJson(estado: String) =
        """{"chamada":{"id":"$CHAMADA","vaga_id":"$VAGA","profissional_id":"$PROFISSIONAL","estabelecimento_id":"$CASA","estado":"$estado","expira_em":"2026-11-17T12:00:00Z","respondida_em":"2026-11-16T21:00:00Z","criada_em":"2026-11-16T20:00:00Z"}${if (estado == "aceita") ",\"turno_id\":\"$TURNO\",\"local\":\"SCS Quadra 2\",\"ponto\":{\"latitude\":-15.79,\"longitude\":-47.88},\"responsavel_local\":\"Ana\"" else ""}}"""

    fun erro(codigo: String, detalhes: String? = null) =
        """{"code":"$codigo","message":"x","details":${detalhes?.let { "\"$it\"" }}}"""
}

internal class Pedido(val caminho: String, val metodo: String, val consulta: String, val corpo: JsonObject?)

/**
 * Um backend de mentira por caminho: cada `rota` devolve uma resposta, e [pedidos] guarda o que o app mandou
 * (para o teste provar o corpo do contrato, não só o resultado).
 */
internal class RedeDeTeste(private val rotas: MutableMap<String, suspend MockRequestHandleScope.() -> HttpResponseData> = mutableMapOf()) {
    val pedidos = mutableListOf<Pedido>()
    private val json = headersOf(HttpHeaders.ContentType, "application/json")

    fun ok(sufixo: String, corpo: String) {
        rotas[sufixo] = { respond(corpo, HttpStatusCode.OK, json) }
    }

    fun recusa(sufixo: String, status: HttpStatusCode, corpo: String) {
        rotas[sufixo] = { respond(corpo, status, json) }
    }

    fun resposta(sufixo: String, bloco: suspend MockRequestHandleScope.() -> HttpResponseData) {
        rotas[sufixo] = bloco
    }

    fun doCaminho(sufixo: String) = pedidos.filter { it.caminho.endsWith(sufixo) }

    val servico: ServicoChamadaDireta by lazy { ServicoChamadaDireta(cliente) }

    val cliente: ClienteSupabase by lazy {
        val engine = MockEngine { request: HttpRequestData ->
            val corpo = (request.body as? TextContent)?.text
                ?.let { ClienteSupabase.jsonFrila.parseToJsonElement(it).jsonObject }
            pedidos += Pedido(request.url.encodedPath, request.method.value, request.url.encodedQuery, corpo)
            val rota = rotas.entries.firstOrNull { request.url.encodedPath.endsWith(it.key) }?.value
            rota?.invoke(this) ?: respond("""{"code":"nao_encontrado","message":"sem rota"}""", HttpStatusCode.NotFound, json)
        }
        ClienteSupabase("https://frila.supabase.co", "chave-teste", engine = engine)
    }
}
