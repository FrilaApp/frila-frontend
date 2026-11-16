package br.com.frila.feature.chamadas.profissional

import br.com.frila.core.rede.ClienteSupabase
import br.com.frila.core.rede.EspecialidadeDto
import io.ktor.client.request.get
import io.ktor.client.request.parameter

/**
 * `GET /rest/v1/especialidade` (contrato `listarEspecialidades`, RN44): as especialidades ativas de uma função, para o
 * profissional marcar até 8 em cada serviço. Leitura direta da tabela, aberta a qualquer usuário autenticado.
 * Fica aqui, e não no `:core:rede`, porque só a edição de serviços a usa.
 */
class ServicoDeEspecialidades(private val provedorDeCliente: () -> ClienteSupabase) {
    constructor(cliente: ClienteSupabase) : this({ cliente })

    private val cliente: ClienteSupabase get() = provedorDeCliente()

    suspend fun especialidadesDaFuncao(funcaoId: String): List<EspecialidadeDto> {
        val resposta = cliente.http.get(cliente.urlCompleta("/rest/v1/especialidade")) {
            parameter("select", "id,funcao_id,nome,ativo")
            parameter("funcao_id", "eq.$funcaoId")
            parameter("ativo", "eq.true")
        }
        return cliente.corpoOuErro(resposta)
    }
}
