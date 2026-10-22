package br.com.frila.core.rede

import io.ktor.client.request.get

/** Perfil de profissional do chamador (RF03/RF16, UC09). */
class ServicoPerfil(private val cliente: ClienteSupabase) {

    /** `GET /rest/v1/rpc/meu_perfil_profissional`. Perfil com reputação agregada (RF03/RF16). */
    suspend fun obterMeuPerfilProfissional(): PerfilProfissionalDto {
        val resposta = cliente.http.get(cliente.urlRpc("meu_perfil_profissional"))
        return cliente.corpoOuErro(resposta)
    }
}
