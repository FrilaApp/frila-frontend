package br.com.frila.core.rede

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpStatusCode
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotSame
import org.junit.jupiter.api.Assertions.assertSame
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class GestorClienteKtorTest {

    private fun criarCliente() = ClienteSupabase(
        baseUrl = "https://frila.supabase.co",
        apiKey = "chave-teste",
        engine = MockEngine { respond("ok", HttpStatusCode.OK) },
    )

    @Test
    fun `cliente inicial e instanciado aberto`() {
        val gestor = GestorClienteKtor { criarCliente() }
        val cliente = gestor.clienteAtual

        assertFalse(cliente.estaFechado)
        assertSame(cliente, gestor.clienteAtual)
    }

    @Test
    fun `recriar fecha cliente antigo e instancia novo aberto`() {
        val gestor = GestorClienteKtor { criarCliente() }
        val antigo = gestor.clienteAtual
        assertFalse(antigo.estaFechado)

        val novo = gestor.recriar()

        assertTrue(antigo.estaFechado, "Cliente antigo deveria estar fechado após recriação")
        assertFalse(novo.estaFechado, "Novo cliente deveria estar aberto")
        assertNotSame(antigo, novo, "Nova instância de ClienteSupabase deveria ser criada")
        assertSame(novo, gestor.clienteAtual)
    }

    @Test
    fun `close fecha o cliente atual`() {
        val gestor = GestorClienteKtor { criarCliente() }
        val cliente = gestor.clienteAtual
        assertFalse(cliente.estaFechado)

        gestor.close()

        assertTrue(cliente.estaFechado)
    }
}
