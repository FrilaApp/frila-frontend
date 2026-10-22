package br.com.frila.core.rede

import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType

/** Registro de token de push do aparelho (RF06/RN15/RNF02). */
class ServicoDispositivo(private val cliente: ClienteSupabase) {

    /**
     * `POST /rest/v1/rpc/registrar_dispositivo`. Chamar a cada abertura do app e sempre que o
     * token FCM mudar — o mesmo token reenviado só atualiza a data. A resposta traz o
     * `vinculo_id` deste token com a conta ativa (RN15): o app deve guardar esse valor junto
     * com a sessão (`Sessao.vinculoId` em `:core:seguranca`).
     */
    suspend fun registrarDispositivo(tokenFcm: String, plataforma: String = "android"): DispositivoDto {
        val resposta = cliente.http.post(cliente.urlRpc("registrar_dispositivo")) {
            contentType(ContentType.Application.Json)
            setBody(RegistrarDispositivoDto(tokenFcm = tokenFcm, plataforma = plataforma))
        }
        return cliente.corpoOuErro(resposta)
    }
}
