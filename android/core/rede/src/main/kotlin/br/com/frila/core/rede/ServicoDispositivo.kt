package br.com.frila.core.rede

import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType

/** Registro de token de push do aparelho (RF06/RN15/RNF02). */
class ServicoDispositivo(private val provedorDeCliente: () -> ClienteSupabase) {
    constructor(cliente: ClienteSupabase) : this({ cliente })

    /** Lido a cada chamada: após `GestorClienteKtor.recriar()` o cliente anterior está fechado. */
    private val cliente: ClienteSupabase get() = provedorDeCliente()


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

    /**
     * `POST /rest/v1/rpc/remover_dispositivo`. Chamar no logout, ainda com a sessão válida, para
     * encerrar o vínculo deste token com a conta: o registro seguinte recebe `vinculo_id` novo.
     * A resposta (`removido` verdadeiro ou falso) não muda nada para o app e é descartada.
     */
    suspend fun removerDispositivo(tokenFcm: String) {
        val resposta = cliente.http.post(cliente.urlRpc("remover_dispositivo")) {
            contentType(ContentType.Application.Json)
            setBody(RemoverDispositivoDto(tokenFcm = tokenFcm))
        }
        cliente.corpoOuErro<Unit>(resposta)
    }
}
