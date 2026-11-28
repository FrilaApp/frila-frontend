package br.com.frila.feature.chamadas.profissional

import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/**
 * Cartão 30KrG0lm (item 287): as especialidades de Meus serviços saem em ordem alfabética, como no iOS (`.order("nome")`,
 * `SupabaseApiCliente.swift:386-388`). A ordem é do servidor (PostgREST): o pedido tem de levar `order=nome.asc`, porque nem o
 * view model nem a tela ordenam. Outros parâmetros do pedido seguem como estavam.
 *
 * JUnit: nenhum método devolve valor (um `@Test` que devolve valor é ignorado).
 */
class ServicoDeEspecialidadesOrdemTest {

    private fun consultaDoPedido(): Map<String, String> {
        val rede = RedeDeTeste()
        rede.ok("/rest/v1/especialidade", Fixtures.especialidadesJson())
        runBlocking { ServicoDeEspecialidades(rede.cliente).especialidadesDaFuncao(Fixtures.FUNCAO) }
        return rede.pedidos.single().consulta.split("&").associate { par ->
            val (chave, valor) = par.split("=", limit = 2)
            chave to java.net.URLDecoder.decode(valor, "UTF-8")
        }
    }

    @Test
    fun `o pedido pede as especialidades em ordem alfabetica pelo nome`() {
        assertEquals("nome.asc", consultaDoPedido()["order"])
    }

    @Test
    fun `a ordem nao troca o select nem os filtros da funcao e dos ativos`() {
        val consulta = consultaDoPedido()

        assertEquals("id,funcao_id,nome,ativo", consulta["select"])
        assertEquals("eq.${Fixtures.FUNCAO}", consulta["funcao_id"])
        assertEquals("eq.true", consulta["ativo"])
        assertEquals(setOf("select", "funcao_id", "ativo", "order"), consulta.keys)
    }
}
