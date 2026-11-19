package br.com.frila.feature.perfil

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class EnderecosOficiaisConviteTest {

    private val token = "ab".repeat(32)

    @Test
    fun `o link do convite e a origem da web mais convite e o token no fragmento`() {
        assertEquals("https://frilabr.com/app/convite#$token", EnderecosOficiais.padrao.linkDoConvite(token))
    }

    @Test
    fun `a origem vem da configuracao, nao de um dominio fixo`() {
        val homologacao = EnderecosOficiais(origemDaWeb = "https://homolog.exemplo.org/app")
        assertEquals("https://homolog.exemplo.org/app/convite#$token", homologacao.linkDoConvite(token))
    }
}
