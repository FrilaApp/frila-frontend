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
import org.junit.jupiter.api.Test

/**
 * Cartão An3g2Q7a: os 14 códigos do contrato que só o iOS tinha em `CodigoErroAPI`. Cada um precisa decodificar para o valor do
 * domínio (renomear um `@SerialName` faz o teste falhar), e os oito que chegam como `details` de outro código são lidos por
 * [ErroDaApi.detalhesComoCodigo], sem comparação de texto solto na tela.
 */
class CodigosDoContratoSoDoIosTest {

    /** Seis chegam como `code` do envelope de erro. */
    private val comoCode = mapOf(
        "codigo_invalido" to CodigoErroAPI.CODIGO_INVALIDO,
        "codigo_bloqueado" to CodigoErroAPI.CODIGO_BLOQUEADO,
        "fora_do_raio" to CodigoErroAPI.FORA_DO_RAIO,
        "sem_localizacao" to CodigoErroAPI.SEM_LOCALIZACAO,
        "midia_indisponivel" to CodigoErroAPI.MIDIA_INDISPONIVEL,
        "midia_invalida" to CodigoErroAPI.MIDIA_INVALIDA,
    )

    /** Oito chegam como `details`: dois de `sem_permissao` e seis de `republicacao_indisponivel`. */
    private val comoDetalhes = mapOf(
        "recurso_desligado" to CodigoErroAPI.RECURSO_DESLIGADO,
        "termos_pendentes" to CodigoErroAPI.TERMOS_PENDENTES,
        "nao_e_selecao" to CodigoErroAPI.NAO_E_SELECAO,
        "selecao_em_curso" to CodigoErroAPI.SELECAO_EM_CURSO,
        "vaga_cancelada" to CodigoErroAPI.VAGA_CANCELADA,
        "ja_comecou" to CodigoErroAPI.JA_COMECOU,
        "sem_posicoes_restantes" to CodigoErroAPI.SEM_POSICOES_RESTANTES,
        "ja_republicada" to CodigoErroAPI.JA_REPUBLICADA,
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
        for ((texto, esperado) in comoCode + comoDetalhes) {
            assertEquals(esperado, ClienteSupabase.mapearCodigo(texto, HttpStatusCode.UnprocessableEntity), texto)
            assertNotEquals(CodigoErroAPI.DESCONHECIDO, esperado, texto)
        }
    }

    @Test
    fun `o envelope de erro com cada um dos seis codes vira o valor do dominio`() = runTest {
        for ((texto, esperado) in comoCode) {
            val erro = erroDoServidor(HttpStatusCode.UnprocessableEntity, """{"code":"$texto","message":"x"}""")
            assertEquals(esperado, erro.codigo, texto)
            assertEquals(texto, erro.codigoOriginal, texto)
        }
    }

    @Test
    fun `os details de cada um dos oito viram o valor do dominio e o code segue o do envelope`() = runTest {
        for ((texto, esperado) in comoDetalhes) {
            val corpo = if (texto in setOf("recurso_desligado", "termos_pendentes")) {
                """{"code":"sem_permissao","message":"x","details":"$texto"}"""
            } else {
                """{"code":"republicacao_indisponivel","message":"x","details":"$texto"}"""
            }
            val erro = erroDoServidor(HttpStatusCode.Forbidden, corpo)
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
}
