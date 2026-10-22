package br.com.frila.core.rede

import io.ktor.client.request.get
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType

/** Perfil de profissional do chamador (RF03/RF16/RF25/RN15/RNF08, UC09/UC16). */
class ServicoPerfil(private val cliente: ClienteSupabase) {

    /** `GET /rest/v1/rpc/meu_perfil_profissional`. Perfil com reputação agregada (RF03/RF16). */
    suspend fun obterMeuPerfilProfissional(): PerfilProfissionalDto {
        val resposta = cliente.http.get(cliente.urlRpc("meu_perfil_profissional"))
        return cliente.corpoOuErro(resposta)
    }

    /**
     * `POST /functions/v1/excluir-conta`. Edge Function que anonimiza os dados em `usuario`,
     * cancela turnos futuros sem gerar falta e apaga a credencial no Supabase Auth
     * (RF25/RN15/UC16). Idempotente: reenviar em conta já anonimizada devolve 202 de novo com
     * `turnos_cancelados: 0`. Erros: `409 administrador_unico` (precisa transferir a
     * administração do estabelecimento antes), `401 nao_autenticado`.
     */
    suspend fun excluirConta(): ExclusaoDeContaDto {
        val resposta = cliente.http.post(cliente.urlFunction("excluir-conta")) {
            contentType(ContentType.Application.Json)
            setBody(ConfirmarExclusaoDto(confirmar = true))
        }
        return cliente.corpoOuErro(resposta)
    }
}
