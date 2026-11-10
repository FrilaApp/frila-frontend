package br.com.frila.core.dominio.modelo

import kotlinx.serialization.json.Json
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class PapelMembroTest {

    @Test
    fun `so o administrador gerencia a equipe`() {
        assertTrue(PapelMembro.ADMINISTRADOR.podeGerenciarEquipe)
        assertFalse(PapelMembro.OPERADOR.podeGerenciarEquipe)
    }

    @Test
    fun `chave de fio e a do contrato e serializa igual`() {
        assertEquals("\"administrador\"", Json.encodeToString(PapelMembro.serializer(), PapelMembro.ADMINISTRADOR))
        assertEquals(PapelMembro.OPERADOR, Json.decodeFromString(PapelMembro.serializer(), "\"operador\""))
        PapelMembro.entries.forEach { assertEquals(it, PapelMembro.deChave(it.chave)) }
    }

    @Test
    fun `papel desconhecido nao vira operador nem administrador`() {
        assertNull(PapelMembro.deChave("gerente"))
        assertNull(PapelMembro.deChave(null))
    }

    @Test
    fun `chaves de denuncia batem com os enums MotivoDenuncia e TipoDeAlvo do contrato`() {
        assertEquals(listOf("assedio", "discriminacao", "risco_seguranca", "outro"), MotivoDenuncia.entries.map { it.chave })
        assertEquals(listOf("profissional", "estabelecimento"), TipoDeAlvo.entries.map { it.chave })
    }

    @Test
    fun `codigos de erro 0_2_73 existem no enum com a chave do contrato`() {
        assertEquals(
            CodigoErroAPI.ULTIMO_ADMINISTRADOR,
            Json.decodeFromString(CodigoErroAPI.serializer(), "\"ultimo_administrador\""),
        )
        assertEquals(
            CodigoErroAPI.CONVITE_INVALIDO,
            Json.decodeFromString(CodigoErroAPI.serializer(), "\"convite_invalido\""),
        )
    }
}
