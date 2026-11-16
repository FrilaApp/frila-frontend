package br.com.frila.feature.chamadas.casa

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.RegiaoAdministrativaDto
import io.ktor.client.request.get
import io.ktor.client.request.parameter

/**
 * `GET /rest/v1/regiao_administrativa`: as Regiões Administrativas ativas do DF, na ordem do `id`, para o filtro
 * "região" da busca. Leitura direta da tabela, como o iOS (`regioesAdministrativas`). Fica aqui, e não no
 * `:core:rede`, porque só a busca a usa.
 */
class ServicoDeRegioes(private val provedorDeCliente: () -> ClienteSupabase) {
    constructor(cliente: ClienteSupabase) : this({ cliente })

    private val cliente: ClienteSupabase get() = provedorDeCliente()

    suspend fun regioesAtivas(): List<RegiaoAdministrativaDto> {
        val resposta = cliente.http.get(cliente.urlCompleta("/rest/v1/regiao_administrativa")) {
            parameter("select", "id,numero,nome,ativo")
            parameter("ativo", "eq.true")
            parameter("order", "id.asc")
        }
        return cliente.corpoOuErro(resposta)
    }
}
