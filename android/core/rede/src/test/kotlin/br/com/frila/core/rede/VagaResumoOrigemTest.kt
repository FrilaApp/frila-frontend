package br.com.frila.core.rede

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test

/** `VagaResumo.origem` (contrato 0.2.55): `chamada_direta` na vaga criada por `chamar_profissional`; ausente vale `publicacao`. */
class VagaResumoOrigemTest {
    private fun json(origem: String?) = """
        {"id":"v1","funcao":"Garçom","local":"SQN 108","regiao_administrativa":"Asa Norte",
         "inicio_em":"2026-11-12T21:00:00Z","fim_em":"2026-11-13T03:00:00Z","valor_centavos":16000${origem?.let { ",\"origem\":\"$it\"" } ?: ""}}
    """.trimIndent()

    private fun ler(texto: String) = ClienteSupabase.jsonFrila.decodeFromString(VagaResumoDto.serializer(), texto)

    @Test
    fun `le a origem da vaga direta e da publicada`() {
        assertEquals("chamada_direta", ler(json("chamada_direta")).origem)
        assertEquals("publicacao", ler(json("publicacao")).origem)
    }

    @Test
    fun `sem origem no JSON o campo e nulo e a leitura nao falha`() {
        assertNull(ler(json(null)).origem)
    }
}
