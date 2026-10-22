package br.com.frila.core.rede

import io.ktor.client.request.get

/** Leitura de vagas abertas (`GET /rest/v1/rpc/vagas_abertas`). */
class ServicoVagas(private val cliente: ClienteSupabase) {

    suspend fun listarVagasAbertas(): List<VagaAbertaDto> {
        val resposta = cliente.http.get(cliente.urlRpc("vagas_abertas"))
        return cliente.corpoOuErro(resposta)
    }
}
