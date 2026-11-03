package br.com.frila.core.rede

import java.io.Closeable

/**
 * Gerencia a instância ativa de [ClienteSupabase] (Cartão 101).
 *
 * Permite fechamento seguro e recriação do cliente Ktor sem vazamento de cabeçalhos de autenticação,
 * cookies ou conexões ativas após logout ou encerramento de sessão (LGPD).
 */
class GestorClienteKtor(
    private val fabrica: () -> ClienteSupabase,
) : Closeable {

    @Volatile
    private var _clienteAtual: ClienteSupabase = fabrica()

    val clienteAtual: ClienteSupabase
        get() = _clienteAtual

    @Synchronized
    fun recriar(): ClienteSupabase {
        val antigo = _clienteAtual
        val novo = fabrica()
        _clienteAtual = novo
        antigo.close()
        return novo
    }

    override fun close() {
        _clienteAtual.close()
    }
}
