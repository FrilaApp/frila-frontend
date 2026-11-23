package br.com.frila.core.rede

import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType

class ServicoTelemetria(private val provedorDeCliente: () -> ClienteSupabase) {
    constructor(cliente: ClienteSupabase) : this({ cliente })

    suspend fun registrarEvento(registro: RegistroDeEventoDto): Boolean {
        val cliente = provedorDeCliente()
        val resposta = cliente.http.post(cliente.urlRpc("registrar_evento")) {
            contentType(ContentType.Application.Json)
            setBody(registro)
        }
        return cliente.corpoOuErro<EventoRegistradoDto>(resposta).registrado
    }
}
