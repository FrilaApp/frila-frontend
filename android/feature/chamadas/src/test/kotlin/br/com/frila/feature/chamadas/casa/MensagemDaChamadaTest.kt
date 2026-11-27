package br.com.frila.feature.chamadas.casa

import br.com.frila.core.rede.ErroDaApi
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows

/**
 * A mensagem de cada recusa de `chamar_profissional`, a mesma do iOS (`ChamadaDiretaViewModel.mensagem`). O erro sai do envelope
 * que o servidor manda, lido pelo cliente de verdade (`RedeDeTeste`), e não de um `ErroDaApi` montado à mão.
 */
class MensagemDaChamadaTest {

    private fun mensagemPara(status: HttpStatusCode, codigo: String, detalhes: String? = null): String = runBlocking {
        val rede = RedeDeTeste().apply { recusa("minhas_chamadas", status, codigo, detalhes) }
        mensagemDaChamada(assertThrows<ErroDaApi> { runBlocking { rede.chamadas.minhasChamadas() } })
    }

    @Test
    fun `valor zero ou negativo na vaga direta nova pede para conferir o valor (contrato 0_2_116)`() {
        assertEquals(TextosChamadaCasa.VALOR_INVALIDO, mensagemPara(HttpStatusCode.UnprocessableEntity, "campo_invalido", "valor_centavos"))
    }

    @Test
    fun `outro campo invalido continua com a mensagem generica`() {
        assertEquals(TextosChamadaCasa.ERRO, mensagemPara(HttpStatusCode.UnprocessableEntity, "campo_invalido", "regiao_id"))
        assertEquals(TextosChamadaCasa.ERRO, mensagemPara(HttpStatusCode.UnprocessableEntity, "campo_invalido"))
    }

    @Test
    fun `recurso desligado vale nas duas formas que o servidor manda`() {
        assertEquals(TextosChamadaCasa.DESLIGADO, mensagemPara(HttpStatusCode.Forbidden, "recurso_desligado"))
        assertEquals(TextosChamadaCasa.DESLIGADO, mensagemPara(HttpStatusCode.Forbidden, "sem_permissao", "recurso_desligado"))
    }

    @Test
    fun `as recusas que ja tinham texto continuam com ele`() {
        assertEquals(TextosChamadaCasa.JA_ABERTA, mensagemPara(HttpStatusCode.Conflict, "chamada_ja_aberta"))
        assertEquals(TextosChamadaCasa.INDISPONIVEL, mensagemPara(HttpStatusCode.UnprocessableEntity, "profissional_indisponivel", "agenda_cheia"))
        assertEquals(TextosChamadaCasa.INDISPONIVEL, mensagemPara(HttpStatusCode.Conflict, "chamada_indisponivel"))
        assertEquals(TextosChamadaCasa.INDISPONIVEL, mensagemPara(HttpStatusCode.NotFound, "nao_encontrado"))
        assertEquals(TextosChamadaCasa.LIMITE, mensagemPara(HttpStatusCode.TooManyRequests, "limite_de_chamadas"))
        assertEquals(TextosChamadaCasa.ERRO, mensagemPara(HttpStatusCode.Forbidden, "sem_permissao"))
    }
}
