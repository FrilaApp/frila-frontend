package br.com.frila.core.rede

import br.com.frila.core.dominio.modelo.CodigoErroAPI
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.get
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Cartão An3g2Q7a: os 14 códigos do contrato que só o iOS tinha em `CodigoErroAPI`. Cada um precisa decodificar para o valor do
 * domínio (renomear um `@SerialName` faz o teste falhar), e os oito que chegam como `details` de outro código são lidos por
 * [ErroDaApi.detalhesComoCodigo], sem comparação de texto solto na tela.
 */
class CodigosDoContratoSoDoIosTest {

    /** Do contrato (`android/contrato/openapi.yaml`, tabela de erros): o texto, o valor do domínio e o status HTTP da recusa. */
    private data class Caso(val texto: String, val codigo: CodigoErroAPI, val status: HttpStatusCode)

    /** Seis chegam como `code` do envelope de erro. */
    private val comoCode = listOf(
        Caso("codigo_invalido", CodigoErroAPI.CODIGO_INVALIDO, HttpStatusCode.UnprocessableEntity),
        Caso("codigo_bloqueado", CodigoErroAPI.CODIGO_BLOQUEADO, HttpStatusCode.Conflict),
        Caso("fora_do_raio", CodigoErroAPI.FORA_DO_RAIO, HttpStatusCode.UnprocessableEntity),
        Caso("sem_localizacao", CodigoErroAPI.SEM_LOCALIZACAO, HttpStatusCode.UnprocessableEntity),
        Caso("midia_indisponivel", CodigoErroAPI.MIDIA_INDISPONIVEL, HttpStatusCode.Conflict),
        Caso("midia_invalida", CodigoErroAPI.MIDIA_INVALIDA, HttpStatusCode.UnprocessableEntity),
    )

    /** Oito chegam como `details`: dois de `403 sem_permissao` e seis de `422 republicacao_indisponivel`. */
    private val comoDetalhes = listOf(
        Caso("recurso_desligado", CodigoErroAPI.RECURSO_DESLIGADO, HttpStatusCode.Forbidden),
        Caso("termos_pendentes", CodigoErroAPI.TERMOS_PENDENTES, HttpStatusCode.Forbidden),
        Caso("nao_e_selecao", CodigoErroAPI.NAO_E_SELECAO, HttpStatusCode.UnprocessableEntity),
        Caso("selecao_em_curso", CodigoErroAPI.SELECAO_EM_CURSO, HttpStatusCode.UnprocessableEntity),
        Caso("vaga_cancelada", CodigoErroAPI.VAGA_CANCELADA, HttpStatusCode.UnprocessableEntity),
        Caso("ja_comecou", CodigoErroAPI.JA_COMECOU, HttpStatusCode.UnprocessableEntity),
        Caso("sem_posicoes_restantes", CodigoErroAPI.SEM_POSICOES_RESTANTES, HttpStatusCode.UnprocessableEntity),
        Caso("ja_republicada", CodigoErroAPI.JA_REPUBLICADA, HttpStatusCode.UnprocessableEntity),
    )

    private fun erro(codigo: CodigoErroAPI, detalhes: String?) =
        ErroDaApi(codigo = codigo, codigoOriginal = "x", detalhes = detalhes, mensagemCrua = "x")

    private suspend fun erroDoServidor(status: HttpStatusCode, corpo: String): ErroDaApi {
        val cliente = ClienteSupabase(
            baseUrl = "https://frila.supabase.co",
            apiKey = "chave-teste",
            engine = MockEngine { respond(corpo, status, headersOf(HttpHeaders.ContentType, "application/json")) },
        )
        return cliente.erroDaResposta(cliente.http.get(cliente.urlRpc("qualquer")))
    }

    @Test
    fun `sao os 14 do cartao`() {
        assertEquals(14, comoCode.size + comoDetalhes.size)
    }

    @Test
    fun `cada code do contrato decodifica para o valor do dominio`() {
        for ((texto, esperado, status) in comoCode + comoDetalhes) {
            assertEquals(esperado, ClienteSupabase.mapearCodigo(texto, status), texto)
            assertNotEquals(CodigoErroAPI.DESCONHECIDO, esperado, texto)
        }
    }

    @Test
    fun `o envelope de erro com cada um dos seis codes vira o valor do dominio`() = runTest {
        for ((texto, esperado, status) in comoCode) {
            val erro = erroDoServidor(status, """{"code":"$texto","message":"x"}""")
            assertEquals(esperado, erro.codigo, texto)
            assertEquals(texto, erro.codigoOriginal, texto)
        }
    }

    @Test
    fun `os details de cada um dos oito viram o valor do dominio e o code segue o do envelope`() = runTest {
        for ((texto, esperado, status) in comoDetalhes) {
            val corpo = if (texto in setOf("recurso_desligado", "termos_pendentes")) {
                """{"code":"sem_permissao","message":"x","details":"$texto"}"""
            } else {
                """{"code":"republicacao_indisponivel","message":"x","details":"$texto"}"""
            }
            val erro = erroDoServidor(status, corpo)
            assertEquals(esperado, erro.detalhesComoCodigo, texto)
            assertEquals(
                if (texto in setOf("recurso_desligado", "termos_pendentes")) CodigoErroAPI.SEM_PERMISSAO else CodigoErroAPI.REPUBLICACAO_INDISPONIVEL,
                erro.codigo,
                texto,
            )
        }
    }

    @Test
    fun `details que nao e um valor do dominio nao vira codigo`() {
        assertNull(erro(CodigoErroAPI.CODIGO_BLOQUEADO, "temporario").detalhesComoCodigo)
        assertNull(erro(CodigoErroAPI.CODIGO_BLOQUEADO, "encerrado").detalhesComoCodigo)
        assertNull(erro(CodigoErroAPI.CAMPO_INVALIDO, "pausado_ate").detalhesComoCodigo)
        assertNull(erro(CodigoErroAPI.CAMPO_INVALIDO, null).detalhesComoCodigo)
        assertNull(erro(CodigoErroAPI.CAMPO_INVALIDO, "").detalhesComoCodigo)
        assertNull(erro(CodigoErroAPI.CAMPO_INVALIDO, "desconhecido").detalhesComoCodigo)
        assertNull(erro(CodigoErroAPI.CAMPO_INVALIDO, "com \"aspas\" e \\ barra").detalhesComoCodigo)
    }

    @Test
    fun `details que ja eram codigos continuam valendo, como conta_suspensa`() {
        assertEquals(CodigoErroAPI.CONTA_SUSPENSA, erro(CodigoErroAPI.SEM_PERMISSAO, "conta_suspensa").detalhesComoCodigo)
    }

    @Test
    fun `o status de cada fixture e o da tabela de erros do contrato`() {
        // O teste roda no diretório do módulo (`android/core/rede`): o contrato fica em `android/contrato`.
        val contrato = java.io.File("../../contrato/openapi.yaml")
        assertTrue(contrato.isFile, "contrato não encontrado em ${contrato.absolutePath}")
        val linhas = contrato.readLines().filter { it.trimStart().startsWith("|") }
        fun existe(status: HttpStatusCode, celula: String) =
            linhas.any { it.replace(" ", "").startsWith("|${status.value}|`$celula`") }

        for ((texto, _, status) in comoCode) {
            assertTrue(existe(status, texto), "o contrato não tem a linha `${status.value} $texto`")
        }
        for ((texto, _, status) in comoDetalhes) {
            val pai = if (texto in setOf("recurso_desligado", "termos_pendentes")) "sem_permissao" else "republicacao_indisponivel"
            val ok = if (pai == "sem_permissao") existe(status, "sem_permissao`+`$texto") else existe(status, pai)
            assertTrue(ok, "o contrato não tem a linha `${status.value} $pai` para $texto")
        }
    }
}
