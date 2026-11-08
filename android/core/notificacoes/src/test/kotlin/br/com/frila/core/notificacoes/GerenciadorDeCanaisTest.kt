package br.com.frila.core.notificacoes

import android.app.NotificationManager
import org.junit.jupiter.api.Assertions.assertArrayEquals
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class GerenciadorDeCanaisTest {

    @Test
    fun `especificacoes devolve exatamente os tres canais esperados`() {
        val ids = GerenciadorDeCanais.especificacoes().map { it.id }

        assertEquals(
            listOf(GerenciadorDeCanais.CANAL_URGENCIA, GerenciadorDeCanais.CANAL_TURNOS, GerenciadorDeCanais.CANAL_SISTEMA),
            ids,
        )
    }

    @Test
    fun `canal_urgencia tem IMPORTANCE_HIGH`() {
        val espec = GerenciadorDeCanais.especificacoes().first { it.id == GerenciadorDeCanais.CANAL_URGENCIA }

        assertEquals(NotificationManager.IMPORTANCE_HIGH, espec.importancia)
    }

    @Test
    fun `canal_turnos tem IMPORTANCE_DEFAULT`() {
        val espec = GerenciadorDeCanais.especificacoes().first { it.id == GerenciadorDeCanais.CANAL_TURNOS }

        assertEquals(NotificationManager.IMPORTANCE_DEFAULT, espec.importancia)
    }

    @Test
    fun `canal_sistema tem IMPORTANCE_DEFAULT`() {
        val espec = GerenciadorDeCanais.especificacoes().first { it.id == GerenciadorDeCanais.CANAL_SISTEMA }

        assertEquals(NotificationManager.IMPORTANCE_DEFAULT, espec.importancia)
    }

    @Test
    fun `canal_urgencia tem padrao de vibracao configurado`() {
        val espec = GerenciadorDeCanais.especificacoes().first { it.id == GerenciadorDeCanais.CANAL_URGENCIA }

        assertNotNull(espec.padraoVibracao)
        assertArrayEquals(GerenciadorDeCanais.PADRAO_VIBRACAO_URGENCIA, espec.padraoVibracao)
    }

    @Test
    fun `demais canais nao tem vibracao customizada`() {
        val outros = GerenciadorDeCanais.especificacoes().filter { it.id != GerenciadorDeCanais.CANAL_URGENCIA }

        outros.forEach { assertNull(it.padraoVibracao, "canal ${it.id} não deveria ter vibração customizada") }
    }

    @Test
    fun `nenhum canal tem nome ou descricao em branco`() {
        GerenciadorDeCanais.especificacoes().forEach { espec ->
            assertTrue(espec.nome.isNotBlank(), "canal ${espec.id} sem nome")
            assertTrue(espec.descricao.isNotBlank(), "canal ${espec.id} sem descrição")
        }
    }

    @Test
    fun `ids dos canais sao unicos`() {
        val ids = GerenciadorDeCanais.especificacoes().map { it.id }

        assertEquals(ids.distinct().size, ids.size)
    }
}
